shader_type spatial;
// Wind sway for grass tufts. Roots stay planted, tips sway on a time-based wave
// with per-tuft phase variation. Lit (responds to the sun/ambient, so it fits the
// day/night cycle) with a base->tip colour gradient. Vertex-only motion, so it's
// fine in the GL Compatibility renderer. Give the tuft its base at local Y = 0.
render_mode cull_disabled;   // thin blades are visible from both sides

// Wind (world-space direction, so all tufts lean together even if randomly turned).
uniform vec2 wind_dir = vec2(1.0, 0.3);
uniform float wind_strength = 0.12;   // tip displacement in metres
uniform float wind_speed = 1.5;
uniform float sway_scale = 0.6;       // spatial phase variation between tufts
uniform float flutter = 0.3;          // amount of a faster secondary wave
uniform float blade_height = 0.5;     // your tuft's height (normalizes the mask)

uniform vec3 base_color : source_color = vec3(0.13, 0.35, 0.11);
uniform vec3 tip_color : source_color = vec3(0.40, 0.72, 0.28);
// Sun-kissed tips: a warmer/lighter colour blended into just the top of the blade.
uniform vec3 tip_highlight : source_color = vec3(0.65, 0.85, 0.40);
uniform float tip_kiss : hint_range(0.0, 1.0) = 0.35;
// Soft wrap lighting: lifts the shadow side of the field so it reads as dim grass
// instead of a crushed, flat, dark mass (view-independent, so it works for the
// fixed isometric camera). 0 = normal hard lighting, 1 = fully soft/wrapped.
uniform float shadow_lift : hint_range(0.0, 1.0) = 0.5;
// Thin vertical blades self-shade to black under an overhead sun. Bending their
// normals toward straight up lets the whole field read as a soft mass lit from
// the sky instead of dark slivers. 0 = raw mesh normals, 1 = fully up-facing.
uniform float normal_up : hint_range(0.0, 1.0) = 0.65;
// Per-blade colour variation so the field isn't one flat green: a warm/cool hue
// nudge and a brightness nudge per blade, plus a slow large-scale patchiness.
uniform float hue_variation = 0.06;         // warm (yellow-green) <-> cool (blue-green)
uniform float brightness_variation = 0.12;  // lighter / darker blades
uniform float patch_variation = 0.08;       // field-scale colour patches
uniform float patch_scale = 0.35;           // size of those patches (smaller = bigger)

// Player interaction is per-blade: the CPU writes each blade's current bend and
// push direction into INSTANCE_CUSTOM (r = bend amount 0..1, g/b = world-XZ push
// direction encoded to 0..1). Each blade fades on its own timer, so the wake
// settles gradually with no travelling wave. bend_strength scales the push.
uniform float bend_strength = 0.5;

varying float v_mask;
varying float v_hue;    // per-blade warm/cool random (-0.5..0.5)
varying float v_bright; // per-blade brightness random (-0.5..0.5)
varying float v_kiss;   // per-blade sun-kiss strength random (0..1)
varying vec2 v_origin;  // blade world XZ, for large-scale colour patches
varying vec3 v_world;   // world position of this (displaced) vertex, for object clipping
varying vec3 v_root;    // this blade's root (instance origin), same for all its fragments

// Solid objects (crates/balls) that CLIP the grass: any fragment inside one of these
// volumes is discarded, so a blade keeps full height everywhere EXCEPT the exact part
// that would poke through the mesh — no shortening, no bare tile. Set per-frame by
// GrassField from the objects' live positions.
const int CLIP_MAX = 8;
uniform int clip_count = 0;
uniform vec4 clip_center[CLIP_MAX];   // xyz = world centre, w = kind (0 = box, 1 = sphere)
uniform vec4 clip_ext[CLIP_MAX];      // box: xyz half-extents; sphere: x = radius

void vertex() {
	// 0 at the root, 1 at the tip — how much this vertex sways / how light it is.
	float h = clamp(VERTEX.y / max(blade_height, 0.001), 0.0, 1.0);
	v_mask = h;
	// Per-tuft phase from its world origin, so they don't all wave in unison.
	vec3 origin = MODEL_MATRIX[3].xyz;
	v_root = origin;   // the blade's base, for whole-blade object clipping in fragment()
	v_hue = fract(sin(dot(origin.xz, vec2(45.11, 12.73))) * 91.377) - 0.5;
	v_bright = fract(sin(dot(origin.xz, vec2(9.41, 71.53))) * 47843.13) - 0.5;
	v_kiss = fract(sin(dot(origin.xz, vec2(63.7, 21.31))) * 3571.19);
	v_origin = origin.xz;
	float phase = (origin.x + origin.z) * sway_scale;
	float wave = sin(TIME * wind_speed + phase)
		+ flutter * sin(TIME * wind_speed * 2.7 + phase * 1.7);
	// Bend by a world-space wind vector (converted into local space so random
	// per-instance rotation doesn't change the wind direction).
	vec3 world_push = vec3(wind_dir.x, 0.0, wind_dir.y) * (wave * h * wind_strength);
	// Per-blade bend: the CPU stamps blades the cat walks over with a bend amount
	// (fading on each blade's own timer) and a push direction. No shared moving
	// point, so the wake settles gradually with no travelling wave.
	float bend = INSTANCE_CUSTOM.r;
	if (bend > 0.0) {
		vec2 dir2 = INSTANCE_CUSTOM.gb * 2.0 - vec2(1.0);   // decode world-XZ direction
		float rnd = fract(sin(dot(origin.xz, vec2(12.9898, 78.233))) * 43758.5453);
		float ang = (rnd - 0.5) * 0.7;                 // per-blade angle wobble
		dir2 = mat2(vec2(cos(ang), sin(ang)), vec2(-sin(ang), cos(ang))) * dir2;
		float amt = bend_strength * bend * h * mix(0.6, 1.0, rnd);  // per-blade strength
		world_push += vec3(dir2.x, 0.0, dir2.y) * amt;
		world_push.y -= amt * 0.4;                     // press the tips down a touch
	}
	// Scale the sway/bend with the blade's own size so small blades don't over-swing.
	float iscale = length(MODEL_MATRIX[0].xyz);
	VERTEX += inverse(mat3(MODEL_MATRIX)) * (world_push * iscale);
	// World position of the displaced vertex, so the fragment stage can clip away just
	// the part of a blade that sits inside a crate/ball volume.
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Remove grass that a crate/ball covers. Two tests per object:
	//  (1) whole-blade: if this blade's ROOT sits under the object's footprint (and
	//      below its top), discard the entire blade — root, middle AND the tip that
	//      would otherwise poke out the open top.
	//  (2) per-fragment: also clip just the slice of a blade that leans in through a
	//      side of the volume (its root is outside, so (1) doesn't catch it).
	for (int i = 0; i < CLIP_MAX; i++) {
		if (i >= clip_count) { break; }
		vec3 c = clip_center[i].xyz;
		vec3 e = clip_ext[i].xyz;
		if (clip_center[i].w < 0.5) {                       // box
			vec3 rd = abs(v_root - c);
			if (rd.x <= e.x && rd.z <= e.z && v_root.y <= c.y + e.y) { discard; }
			vec3 d = abs(v_world - c);
			if (d.x <= e.x && d.y <= e.y && d.z <= e.z) { discard; }
		} else {                                            // sphere (e.g. a ball)
			// Keep the blade BELOW the ball's curved underside and cut the part that is
			// inside it OR above it, following the sphere's lower surface. So grass still
			// peeks out around the ball's base instead of leaving a bare disc.
			vec2 rxz = v_world.xz - c.xz;
			float r2 = dot(rxz, rxz);
			if (r2 <= e.x * e.x && v_world.y >= c.y - sqrt(max(e.x * e.x - r2, 0.0))) { discard; }
		}
	}
	vec3 col = mix(base_color, tip_color, v_mask);
	// Warm/cool hue nudge per blade (push red up + blue down for warm, and back).
	col.r += v_hue * 2.0 * hue_variation;
	col.b -= v_hue * 2.0 * hue_variation;
	// Per-blade brightness, then a slow large-scale patchiness across the field.
	col *= 1.0 + v_bright * 2.0 * brightness_variation;
	float patch = sin(v_origin.x * patch_scale) * sin(v_origin.y * patch_scale * 0.8) * 0.5 + 0.5;
	col *= mix(1.0 - patch_variation, 1.0 + patch_variation, patch);
	// Sun-kissed tips: warm highlight concentrated at the very top of the blade,
	// its strength varying per blade so some catch the light more than others.
	col = mix(col, tip_highlight, pow(v_mask, 3.0) * tip_kiss * mix(0.3, 1.3, v_kiss));
	ALBEDO = clamp(col, vec3(0.0), vec3(1.0));
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	// Lean the shading normal toward world-up so overhead light doesn't graze the
	// thin blades into darkness (VIEW space, since NORMAL is view-space here).
	vec3 up_view = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	NORMAL = normalize(mix(NORMAL, up_view, normal_up));
}

// Soft "wrap" diffuse: instead of light falling to black at the terminator, it
// eases down to a soft floor, so blades facing away from the sun stay readably
// lit. This is what keeps the shadow side of the field from looking flat/dark.
void light() {
	float ndl = dot(normalize(NORMAL), normalize(LIGHT));
	float hard = max(ndl, 0.0);                       // ordinary lambert
	float soft = ndl * 0.5 + 0.5;                     // wrapped: 0.5 at the terminator
	soft *= soft;                                     // half-Lambert falloff
	float diff = mix(hard, soft, shadow_lift);
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * ATTENUATION * diff;
}
