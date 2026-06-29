// Keyhole / x-ray see-through. Applied to building & map materials.
// Fades a soft circle around the cat's on-screen position on any surface that
// sits between the camera and the cat. Uses DITHERED (screen-door) transparency
// rather than alpha blending: the material stays fully opaque, so it depth-sorts
// normally (no flicker / dropped faces, which alpha blend causes in the GL
// Compatibility renderer). "Transparency" = discarding a stipple of pixels.
shader_type spatial;
// cull_disabled so single-sided walls stay visible from the inside too (the
// original glb materials are double-sided; cull_back would hide interior faces).
render_mode cull_disabled;

// Preserved from the original material so the building keeps its look.
uniform sampler2D albedo_tex : source_color, hint_default_white;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform bool use_tex = false;

// Driven from World each frame.
uniform vec2 player_screen = vec2(0.5);   // cat position in 0..1 screen UV
uniform vec3 player_world = vec3(0.0);     // cat world position
uniform vec3 cam_forward = vec3(0.0, 0.0, -1.0); // camera look direction
uniform float aspect = 1.777;              // viewport width / height

// Tunables.
uniform float radius = 0.16;     // circle size, in screen-height fractions
uniform float softness = 0.07;   // edge feather
uniform float min_alpha = 0.0;   // opacity at the center of the circle
uniform float depth_bias = 0.0;  // metres a surface must be IN FRONT of the cat
                                 // before it starts dissolving (keeps side walls
                                 // at the cat's depth solid)
// Hard clear zone: pixels within this screen-height fraction of the player are
// always fully discarded (vis forced to 0), giving a completely dot-free centre.
// Set to 0.0 to disable. Good starting value: ~0.5–0.7 * radius.
uniform float clear_radius = 0.10;

// 0 = this building is NOT between the camera and the cat, so leave it fully
// solid. 1 = it is occluding, so run the circle. Eased by World for a soft pop.
uniform float active = 0.0;

// 4x4 ordered (Bayer) dither thresholds.
const float BAYER[16] = float[](
	 0.0 / 16.0,  8.0 / 16.0,  2.0 / 16.0, 10.0 / 16.0,
	12.0 / 16.0,  4.0 / 16.0, 14.0 / 16.0,  6.0 / 16.0,
	 3.0 / 16.0, 11.0 / 16.0,  1.0 / 16.0,  9.0 / 16.0,
	15.0 / 16.0,  7.0 / 16.0, 13.0 / 16.0,  5.0 / 16.0
);

varying vec3 v_world;
varying vec3 v_world_n;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_world_n = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	// Multiply in COLOR so vertex-painted glb meshes keep their colors.
	vec4 col = albedo_color * COLOR;
	if (use_tex) {
		col *= texture(albedo_tex, UV);
	}
	ALBEDO = col.rgb;

	// With cull_disabled we draw back faces too (e.g. interior wall faces). Flip
	// their normal so lights — like the house spotlight — illuminate them instead
	// of treating them as lit-from-behind and leaving them dark.
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}

	float vis = 1.0;
	// `active` already means "this building is the one occluding the cat", so we
	// just cut a clean circular window through the whole building — no per-pixel
	// depth/normal test (which left far-side corners poking through the circle).
	if (active > 0.001) {
		vec2 d = SCREEN_UV - player_screen;
		d.x *= aspect;                       // make the circle round, not oval
		float dist = length(d);

		// Curved falloff: high exponent keeps most of the interior near-zero and
		// only ramps steeply to opaque at the rim. Raise for a sharper edge.
		float k = pow(smoothstep(0.0, radius + softness, dist), 4.5);
		float circle_vis = mix(min_alpha, 1.0, k);

		// Fade the effect in/out with `active` so a building only dissolves while
		// it's actually occluding, and pops back solid smoothly when it isn't.
		vis = mix(1.0, circle_vis, clamp(active, 0.0, 1.0));

		// Hard clear zone applied AFTER the active mix, so the centre is dot-free
		// for the entire duration of the fade-in, not just once active reaches 1.
		// min() clamps vis to 0 inside clear_radius regardless of active value.
		float clear_blend = smoothstep(clear_radius, clear_radius + 0.02, dist);
		vis = min(vis, clear_blend);
	}

	// Screen-door: discard a stipple of pixels so denser = more see-through.
	// `<=` means a fully-clear region (vis 0) discards EVERY pixel — no leftover
	// dots in the centre — instead of keeping one cell of the 4x4 pattern.
	if (vis < 1.0) {
		int ix = int(mod(FRAGCOORD.x, 4.0));
		int iy = int(mod(FRAGCOORD.y, 4.0));
		if (vis <= BAYER[iy * 4 + ix]) {
			discard;
		}
	}
}
