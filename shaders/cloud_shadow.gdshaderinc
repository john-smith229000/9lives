// Shared cloud-shadow sampling. Included by grass_wind.gdshader (applied inline to
// the blades) and by cloud_overlay.gdshader (a blend_mul next_pass drawn over every
// other surface), so the whole scene dims under the same drifting clouds — no
// physical cloud meshes, so nothing clips the orthographic camera.
//
// Include-only: no shader_type / no varyings here. Each including shader passes in
// the fragment's world position and the current time.

uniform sampler2D cloud_tex : repeat_enable, filter_linear;
uniform float cloud_strength = 0.0;       // 0 = off; how dark the deepest shadow gets
uniform float cloud_scale = 0.03;         // world units -> uv (smaller = bigger clouds)
uniform float cloud_speed = 0.015;        // drift speed
uniform vec2 cloud_dir = vec2(1.0, 0.4);  // drift direction across the world (XZ)
uniform float cloud_coverage = 0.5;       // threshold: higher = more of the map shaded
uniform float cloud_softness = 0.15;      // edge feather of the shadow's rim
uniform vec2 cloud_light_xz = vec2(0.0);  // sun travel direction (XZ), skews the cast
uniform float cloud_height = 12.0;        // notional cloud height, for the skew

// Light multiplier in [1 - cloud_strength .. 1]: 1.0 in open sun, darker under a
// cloud. `world_pos` is this fragment's world position; `t` is TIME (for drift).
float cloud_shadow_factor(vec3 world_pos, float t) {
	if (cloud_strength <= 0.0) {
		return 1.0;
	}
	// Project the point onto a plane at cloud_height along the sun direction, so a
	// shadow lands offset from whatever "casts" it (as under a low sun), not straight
	// down. Higher ground therefore shifts its shadow less than the floor.
	vec2 p = world_pos.xz + cloud_light_xz * (cloud_height - world_pos.y);
	vec2 uv = p * cloud_scale + cloud_dir * (t * cloud_speed);
	float n = texture(cloud_tex, uv).r;
	// Soft threshold: n above coverage = lit, below = clouded, feathered by softness.
	float lit = smoothstep(cloud_coverage - cloud_softness, cloud_coverage + cloud_softness, n);
	return mix(1.0 - cloud_strength, 1.0, lit);
}
