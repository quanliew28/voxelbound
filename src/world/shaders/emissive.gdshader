shader_type spatial;
// Procedural emissive material for VOXELBOUND (crystal blocks).
// Vertex color drives both albedo (with per-face brightness) and emission,
// so the glow naturally dims on side/bottom faces.
render_mode cull_disabled, blend_mix, depth_draw_opaque;

uniform float emission_energy : hint_range(0.0, 8.0) = 2.0;

void fragment() {
	ALBEDO = COLOR.rgb;
	ALPHA = COLOR.a;
	EMISSION = COLOR.rgb * emission_energy;
	ROUGHNESS = 0.6;
}
