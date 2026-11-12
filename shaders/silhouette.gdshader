shader_type canvas_item;
// Flat team-colour silhouette for the hidden part of a cutout character
// (drawn under the real rig, so it only shows where a wall clips the rig).
uniform vec4 tint : source_color = vec4(1.0, 0.45, 0.3, 0.45);

void fragment() {
	COLOR = vec4(tint.rgb, tint.a * COLOR.a);
}
