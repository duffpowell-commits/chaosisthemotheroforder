shader_type canvas_item;
// Cuts a woodcut medallion to its circle (the PNGs have square paper corners).
void fragment() {
	float d = distance(UV, vec2(0.5));
	COLOR.a *= 1.0 - smoothstep(0.475, 0.49, d);
}
