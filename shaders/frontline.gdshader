// Frontline grade: documentary-photo look that warms into color as a district is liberated.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float liberation : hint_range(0.0, 1.0) = 0.0;
uniform float grain_seed = 0.0;
// Tactical map turns these down so the grid and cover stay readable (J1).
uniform float grain_mul = 1.0;
uniform float crush_mul = 1.0;
// Colour kept under the regime. 0.07 on the street; the tactical map keeps more so the cast
// (real 3D since Nov 25) still shows faces and the movement red.
uniform float regime_sat = 0.07;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	float lum = dot(c, vec3(0.299, 0.587, 0.114));
	// Regime: near-monochrome. Liberated: full color.
	c = mix(vec3(lum), c, mix(regime_sat, 0.85, liberation));
	// Harsher contrast under the regime.
	c = (c - 0.5) * (1.0 + (mix(1.28, 1.06, liberation) - 1.0) * crush_mul) + 0.5;
	// Cold to warm tint.
	c *= mix(vec3(0.94, 1.0, 1.07), vec3(1.03, 1.0, 0.95), liberation);
	// Film grain, heavier under the regime.
	float g = hash(floor(FRAGCOORD.xy) + grain_seed) - 0.5;
	c += g * mix(0.13, 0.035, liberation) * grain_mul;
	// Vignette.
	vec2 d = SCREEN_UV - 0.5;
	c *= 1.0 - dot(d, d) * mix(1.5, 0.75, liberation) * crush_mul;
	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}
