// Unit rim light (J1): a cool fresnel edge added on top of every unit surface,
// so a body separates from the crates and barrels in the dark yard. Units only.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back;

uniform vec3 rim_color : source_color = vec3(0.78, 0.86, 1.0);
uniform float power = 2.6;
uniform float strength = 0.42;

void fragment() {
	float f = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), power);
	ALBEDO = rim_color * f * strength;
}
