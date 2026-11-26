shader_type canvas_item;
// Rubber-stamp ink: blotchy, uneven coverage over text + border (action picker, Nov 25).
uniform sampler2D ink : repeat_enable, filter_linear;
uniform float scale = 70.0;
varying vec2 p;
void vertex() { p = VERTEX; }
void fragment() {
	float n = texture(ink, p / scale).r;
	COLOR.a *= clamp((n - 0.18) * 2.4, 0.18, 0.95);
}
