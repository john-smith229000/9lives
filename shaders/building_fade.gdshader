// Whole-building fade. Each building mesh gets its own copy of this material;
// World drives `fade` (1 = solid, 0 = invisible) when the building occludes the
// cat. Uses dithered (screen-door) transparency so the material stays opaque and
// depth-sorts normally in the GL Compatibility renderer (no flicker / dropouts).
shader_type spatial;
render_mode cull_back;

// Preserved from the original material so the building keeps its look.
uniform sampler2D albedo_tex : source_color, hint_default_white;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform bool use_tex = false;

uniform float fade = 1.0;   // 1 = solid, lower = more see-through

const float BAYER[16] = float[](
	 0.0 / 16.0,  8.0 / 16.0,  2.0 / 16.0, 10.0 / 16.0,
	12.0 / 16.0,  4.0 / 16.0, 14.0 / 16.0,  6.0 / 16.0,
	 3.0 / 16.0, 11.0 / 16.0,  1.0 / 16.0,  9.0 / 16.0,
	15.0 / 16.0,  7.0 / 16.0, 13.0 / 16.0,  5.0 / 16.0
);

void fragment() {
	// Multiply in COLOR so vertex-painted glb meshes keep their colors.
	vec4 col = albedo_color * COLOR;
	if (use_tex) {
		col *= texture(albedo_tex, UV);
	}
	ALBEDO = col.rgb;

	if (fade < 1.0) {
		int ix = int(mod(FRAGCOORD.x, 4.0));
		int iy = int(mod(FRAGCOORD.y, 4.0));
		if (fade < BAYER[iy * 4 + ix]) {
			discard;
		}
	}
}
