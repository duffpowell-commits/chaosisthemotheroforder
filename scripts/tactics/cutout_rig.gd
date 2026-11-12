class_name CutoutRig
extends Node2D
## HD-2D cutout character (Duff's call, Nov 11): one Canva drawing per facing,
## split into body / arms / legs meshes that bend over a Skeleton2D. No frame
## cycles: idle, walk, shoot, hit and down are all bone poses driven in code.
##
## Origin = between the feet. The rig is drawn in 2D above the street grade, so
## it keeps its colour; the tactical scene places, scales and clips it.

## Joints in source-art pixels (the Canva cut-out, 72x196). "L"/"R" are screen
## left/right in the art, which faces screen right.
const DUFF := {
	"texture": "res://assets/characters/duff_front.png",
	"src_size": Vector2(72, 196),
	"faces_right": true,
	"gun_arm": "R",
	"j": {
		"head_top": Vector2(39, 2), "neck": Vector2(40, 33), "hip": Vector2(38, 90),
		"shoulder_L": Vector2(15, 49), "elbow_L": Vector2(9, 77), "hand_L": Vector2(10, 106),
		"shoulder_R": Vector2(60, 52), "elbow_R": Vector2(64, 79), "hand_R": Vector2(61, 107),
		"hip_L": Vector2(27, 94), "knee_L": Vector2(23, 136), "ankle_L": Vector2(19, 172), "toe_L": Vector2(9, 192),
		"hip_R": Vector2(50, 94), "knee_R": Vector2(52, 138), "ankle_R": Vector2(60, 174), "toe_R": Vector2(63, 194),
	},
}

## Capsule radius per segment (source px): how far a pixel can be from a
## segment's line and still belong to it. Wide torso, thin limbs.
const RADIUS := {"head": 11.0, "spine": 15.0, "upper_L": 5.0, "fore_L": 5.0, "upper_R": 5.0,
	"fore_R": 5.0, "thigh_L": 8.0, "shin_L": 7.0, "thigh_R": 8.0, "shin_R": 7.0}

## Mesh parts, back to front, with the bones each part is skinned to. The
## first bone is the parent it blends into at the joint, so limbs stay attached.
const PARTS := [
	["arm_L", ["spine", "upper_L", "fore_L"]],
	["leg_L", ["hip", "thigh_L", "shin_L"]],
	["leg_R", ["hip", "thigh_R", "shin_R"]],
	["body", ["hip", "spine", "head"]],
	["arm_R", ["spine", "upper_R", "fore_R"]],
]
const PART_SEGMENTS := {
	"arm_L": ["upper_L", "fore_L"], "leg_L": ["thigh_L", "shin_L"], "leg_R": ["thigh_R", "shin_R"],
	"body": ["spine", "head"], "arm_R": ["upper_R", "fore_R"],
}
const GRID := 2.0  # mesh cell size in texture pixels

var spec: Dictionary
var tex: Texture2D
var s := 1.0               # texture px per source px
var skel: Skeleton2D
var bones := {}            # name -> Bone2D
var segs := {}             # segment name -> [a, b] in texture px
var facing_right := true
var state := "idle"
var state_t := 0.0
var t := 0.0
var flash_node: Polygon2D
var body_root: Node2D      # everything that tips over when downed
var _hit_flash := 0.0
var follow: CutoutRig      # set on a silhouette: copy this rig's pose every frame


static func create(char_spec: Dictionary) -> CutoutRig:
	var r := CutoutRig.new()
	r.spec = char_spec
	r._build()
	return r


func height_px() -> float:
	return float(tex.get_height())


## "walk" loops until set back to "idle"; "shoot" and "hit" play once and return
## to idle; "down" stays down.
func play(anim: String) -> void:
	if state == "down" and anim != "down":
		return
	if anim == state and anim in ["idle", "walk", "down"]:
		return
	state = anim
	state_t = 0.0
	if anim == "hit":
		_hit_flash = 0.18


func face(right: bool) -> void:
	facing_right = right
	var flip := right != bool(spec.faces_right)
	scale.x = -absf(scale.x) if flip else absf(scale.x)


# ---------- build ----------

func _build() -> void:
	tex = load(spec.texture)
	s = tex.get_height() / spec.src_size.y
	var j: Dictionary = {}
	for k in spec.j:
		j[k] = spec.j[k] * s
	segs = {
		"head": [j.neck, j.head_top], "spine": [j.hip, j.neck],
		"upper_L": [j.shoulder_L, j.elbow_L], "fore_L": [j.elbow_L, j.hand_L],
		"upper_R": [j.shoulder_R, j.elbow_R], "fore_R": [j.elbow_R, j.hand_R],
		"thigh_L": [j.hip_L, j.knee_L], "shin_L": [j.knee_L, j.toe_L.lerp(j.ankle_L, 0.3)],
		"thigh_R": [j.hip_R, j.knee_R], "shin_R": [j.knee_R, j.toe_R.lerp(j.ankle_R, 0.3)],
	}
	var origin := Vector2(tex.get_width() * 0.5, tex.get_height())  # feet
	body_root = Node2D.new()
	add_child(body_root)
	skel = Skeleton2D.new()
	body_root.add_child(skel)
	# Bone tree. Positions are in rig space (texture px minus the feet origin).
	var hip := _bone("hip", skel, j.hip - origin)
	_bone("spine", hip, Vector2.ZERO)
	var head := _bone("head", bones.spine, j.neck - j.hip)
	head.set_meta("len", (j.head_top - j.neck).length())
	for side in ["L", "R"]:
		var up := _bone("upper_" + side, bones.spine, j["shoulder_" + side] - j.hip)
		_bone("fore_" + side, up, j["elbow_" + side] - j["shoulder_" + side])
		var th := _bone("thigh_" + side, hip, j["hip_" + side] - j.hip)
		_bone("shin_" + side, th, j["knee_" + side] - j["hip_" + side])
	for b in bones.values():
		b.rest = b.transform
	_build_meshes(origin)
	_build_gun()


func _bone(bone_name: String, parent: Node, pos: Vector2) -> Bone2D:
	var b := Bone2D.new()
	b.name = bone_name
	b.position = pos
	b.set_autocalculate_length_and_angle(false)
	b.set_length(4.0)
	parent.add_child(b)
	bones[bone_name] = b
	return b


## Label every opaque pixel with the nearest segment (capsule distance), then
## build one quad mesh per part from the cells that part owns.
func _build_meshes(origin: Vector2) -> void:
	var img := tex.get_image()
	var w := img.get_width()
	var h := img.get_height()
	var part_of_seg := {}
	for p in PART_SEGMENTS:
		for sg in PART_SEGMENTS[p]:
			part_of_seg[sg] = p
	var cells := {}  # part -> Array[Vector2i] of cell coords
	for p in PART_SEGMENTS:
		cells[p] = []
	var cw := int(ceil(w / GRID))
	var ch := int(ceil(h / GRID))
	for cy in range(ch):
		for cx in range(cw):
			var votes := {}
			var any := false
			for dy in range(int(GRID)):
				for dx in range(int(GRID)):
					var px := cx * int(GRID) + dx
					var py := cy * int(GRID) + dy
					if px >= w or py >= h or img.get_pixel(px, py).a < 0.05:
						continue
					any = true
					var sg := _nearest_seg(Vector2(px + 0.5, py + 0.5))
					votes[part_of_seg[sg]] = votes.get(part_of_seg[sg], 0) + 1
			if not any:
				continue
			var best := ""
			for p in votes:
				if best == "" or votes[p] > votes[best]:
					best = p
			cells[best].append(Vector2i(cx, cy))
	for entry in PARTS:
		var part: String = entry[0]
		var part_bones: Array = entry[1]
		_make_part(part, cells[part], part_bones, origin)


func _nearest_seg(p: Vector2) -> String:
	var best := ""
	var bd := INF
	for sg in segs:
		var d: float = _seg_dist(p, segs[sg][0], segs[sg][1]) - RADIUS[sg] * s
		if d < bd:
			bd = d
			best = sg
	return best


static func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var tt := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return p.distance_to(a + ab * tt)


func _make_part(part: String, part_cells: Array, part_bones: Array, origin: Vector2) -> void:
	if part_cells.is_empty():
		return
	var verts := PackedVector2Array()
	var index := {}
	var polys := []
	for c: Vector2i in part_cells:
		var quad := PackedInt32Array()
		for k in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
			var v: Vector2i = c + k
			if not index.has(v):
				index[v] = verts.size()
				verts.append(Vector2(v) * GRID)
			quad.append(index[v])
		polys.append(quad)
	var poly := Polygon2D.new()
	poly.name = part
	poly.texture = tex
	poly.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	poly.uv = verts
	var shifted := PackedVector2Array()
	for v in verts:
		shifted.append(v - origin)
	poly.polygon = shifted
	poly.polygons = polys
	poly.internal_vertex_count = verts.size()
	body_root.add_child(poly)
	poly.skeleton = poly.get_path_to(skel)
	# Weights: inverse capsule distance to each of the part's bones' segments.
	# The parent bone (first) only uses its own segment, so it pulls the joint end.
	var seg_of := {"hip": "spine", "spine": "spine", "head": "head"}
	var weights := {}
	for b in part_bones:
		weights[b] = PackedFloat32Array()
		weights[b].resize(verts.size())
	for i in range(verts.size()):
		var total := 0.0
		var raw := {}
		for b in part_bones:
			var sg: String = seg_of.get(b, b)
			var d: float = maxf(_seg_dist(verts[i], segs[sg][0], segs[sg][1]) - RADIUS[sg] * s, 0.0)
			var wgt := 1.0 / pow(d + 1.0, 4.0)
			if b == "hip" and part == "body":
				wgt *= 0.0001 if verts[i].y < segs.spine[0].y - 6.0 * s else 1.0
			raw[b] = wgt
			total += wgt
		for b in part_bones:
			weights[b][i] = raw[b] / total
	for b in part_bones:
		poly.add_bone(poly.get_path_to(bones[b]), weights[b])


## A plain black pistol on the gun hand (Canva won't draw guns), barrel along
## the forearm, plus a muzzle flash that blinks on the shot.
func _build_gun() -> void:
	var side: String = spec.gun_arm
	var fore: Bone2D = bones["fore_" + side]
	var a: Vector2 = segs["fore_" + side][0]
	var b: Vector2 = segs["fore_" + side][1]
	var dir := (b - a).normalized()
	var perp := Vector2(-dir.y, dir.x)
	var hand := b - a  # in forearm-bone space (bone sits at the elbow)
	var grip := 2.2 * s * 2.0
	var length := 4.0 * s * 2.0
	var gun := Polygon2D.new()
	gun.color = Color(0.06, 0.06, 0.07)
	gun.polygon = PackedVector2Array([
		hand - perp * grip * 0.5, hand + dir * length - perp * grip * 0.35,
		hand + dir * length + perp * grip * 0.25, hand + perp * grip * 0.6,
		hand + perp * grip * 1.1 - dir * grip * 0.6, hand + perp * grip * 0.2 - dir * grip * 0.7])
	fore.add_child(gun)
	flash_node = Polygon2D.new()
	flash_node.color = Color(1.0, 0.8, 0.35)
	var tip := hand + dir * (length + 1.0)
	flash_node.polygon = PackedVector2Array([tip - perp * 2.0 * s, tip + dir * 7.0 * s, tip + perp * 2.0 * s,
		tip + dir * 3.0 * s + perp * 4.0 * s, tip + dir * 3.0 * s - perp * 4.0 * s])
	flash_node.visible = false
	fore.add_child(flash_node)


# ---------- animate ----------

## A flat-colour copy of `of` that mirrors its pose: drawn under the real rig
## and left unclipped, so a body behind a wall still shows as a silhouette.
static func silhouette(of: CutoutRig, tint: Color) -> CutoutRig:
	var g := create(of.spec)
	g.follow = of
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/silhouette.gdshader")
	m.set_shader_parameter("tint", tint)
	g.body_root.material = m
	for c in g.body_root.find_children("*", "Polygon2D", true, false):
		c.use_parent_material = true
	return g


func _process(delta: float) -> void:
	if follow:
		t = follow.t
		_pose(follow.state, follow.state_t)
		flash_node.visible = false
		return
	t += delta
	state_t += delta
	_pose(state, state_t)
	if _hit_flash > 0.0:
		_hit_flash -= delta
	body_root.modulate = Color(2.2, 2.0, 2.0) if _hit_flash > 0.0 else (Color(0.7, 0.62, 0.62) if state == "down" else Color.WHITE)


## Sets every bone for this moment. Angles are in radians; with the art facing
## screen right, negative rotation on an arm swings it forward (to the right).
func _pose(anim: String, at: float) -> void:
	for b in bones.values():
		b.rotation = 0.0
	bones.hip.position = bones.hip.rest.origin
	body_root.rotation = 0.0
	body_root.position = Vector2.ZERO
	flash_node.visible = false
	var gun: String = spec.gun_arm
	var off: String = "L" if gun == "R" else "R"
	match anim:
		"idle":
			var br := sin(t * 2.1)
			bones.hip.position.y += br * 0.5 * s
			bones.head.rotation = br * 0.02
			bones["upper_" + gun].rotation = -0.04 + br * 0.02
			bones["upper_" + off].rotation = 0.04 - br * 0.02
		"walk":
			var ph := t * TAU * 1.9
			var sw := sin(ph)
			bones.thigh_L.rotation = 0.1 * sw
			bones.thigh_R.rotation = -0.1 * sw
			bones.shin_L.rotation = maxf(0.0, -sw) * -0.3
			bones.shin_R.rotation = maxf(0.0, sw) * -0.3
			bones["upper_" + off].rotation = 0.16 * sw
			bones["upper_" + gun].rotation = -0.1 * sw
			bones["fore_" + off].rotation = -0.15 - 0.1 * absf(sw)
			bones.hip.position.y -= absf(cos(ph)) * 2.0 * s
			bones.spine.rotation = -0.04
			bones.head.rotation = 0.02 * sw
		"shoot":
			# Raise (0-0.18s), fire at 0.22s with a kick, hold, lower by 0.7s.
			var up := clampf(at / 0.18, 0.0, 1.0) * clampf((0.7 - at) / 0.2, 0.0, 1.0)
			var kick := 0.0
			if at > 0.22 and at < 0.34:
				kick = sin((at - 0.22) / 0.12 * PI) * 0.18
			bones["upper_" + gun].rotation = lerpf(0.0, -1.42, ease(up, -2.0)) + kick
			bones["fore_" + gun].rotation = lerpf(0.0, -0.08, up) + kick * 0.5
			bones.spine.rotation = -0.05 * up + kick * 0.2
			bones["upper_" + off].rotation = 0.08 * up
			flash_node.visible = at > 0.22 and at < 0.29
			if at > 0.75:
				play("idle")
		"hit":
			var k := sin(clampf(at / 0.35, 0.0, 1.0) * PI)
			bones.spine.rotation = 0.14 * k
			bones.head.rotation = 0.18 * k
			bones["upper_" + gun].rotation = 0.08 * k
			bones["upper_" + off].rotation = 0.1 * k
			bones.hip.position.x -= 2.0 * s * k
			if at > 0.4:
				play("idle")
		"down":
			# Knees go, then he tips over backwards onto the ground and stays.
			var f := clampf(at / 0.45, 0.0, 1.0)
			var e := f * f
			bones.thigh_L.rotation = -0.5 * minf(f * 2.0, 1.0)
			bones.thigh_R.rotation = -0.3 * minf(f * 2.0, 1.0)
			bones.shin_L.rotation = 0.7 * minf(f * 2.0, 1.0)
			bones.shin_R.rotation = 0.5 * minf(f * 2.0, 1.0)
			bones.upper_L.rotation = 0.5 * e
			bones.upper_R.rotation = -0.6 * e
			bones.head.rotation = 0.25 * e
			body_root.rotation = -1.48 * e
			body_root.position = Vector2(0.45 * height_px() * e, 0.0)
