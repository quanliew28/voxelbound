shader_type spatial;
// Procedural star field for VOXELBOUND (zero assets). Rendered on a large
// sphere viewed from inside (cull_front). Grid-hashed star cells fade in
// with the "night" uniform (0..1) driven by the DayNight cycle.
render_mode unshaded, cull_front, depth_draw_never, blend_add;

uniform float night : hint_range(0.0, 1.0) = 1.0;
uniform vec3 star_color : source_color = vec3(0.85, 0.9, 1.0);
uniform float grid : hint_range(10.0, 200.0) = 70.0;
uniform float density : hint_range(0.0, 1.0) = 0.96;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	vec2 cell = floor(UV * grid);
	float h = hash21(cell);
	float star = step(density, h);
	// twinkle-ish brightness variation per star, fade near the horizon
	float horizon_fade = smoothstep(0.0, 0.15, VERTEX.y);
	float brightness = star * (0.4 + 0.6 * h) * horizon_fade * night;
	ALBEDO = star_color;
	ALPHA = brightness;
}
