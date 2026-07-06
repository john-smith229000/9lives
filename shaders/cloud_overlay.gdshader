shader_type spatial;
// Whole-scene cloud shadows. Attached as a next_pass on every environment material,
// this pass re-draws the surface unshaded and MULTIPLIES the framebuffer by the
// cloud factor (1.0 in sun, darker under a cloud). It reuses the same
// cloud_shadow_factor() as the grass, so blades and ground drift together. Works in
// the GL Compatibility renderer (no decals, no screen-space depth needed).
render_mode blend_mul, unshaded, cull_back, shadows_disabled, ambient_light_disabled, fog_disabled, depth_draw_never;

#include "res://shaders/cloud_shadow.gdshaderinc"

varying vec3 v_world;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float f = cloud_shadow_factor(v_world, TIME);
	// blend_mul: destination *= ALBEDO. f<1 darkens where a cloud passes.
	ALBEDO = vec3(f);
	ALPHA = 1.0;
}
