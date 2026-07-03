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

// Player interaction is per-blade: the CPU writes each blade's current bend and
// push direction into INSTANCE_CUSTOM (r = bend amount 0..1, g/b = world-XZ push
// direction encoded to 0..1). Each blade fades on its own timer, so the wake
// settles gradually with no travelling wave. bend_strength scales the push.
uniform float bend_strength = 0.5;

varying float v_mask;

void vertex() {
	// 0 at the root, 1 at the tip — how much this vertex sways / how light it is.
	float h = clamp(VERTEX.y / max(blade_height, 0.001), 0.0, 1.0);
	v_mask = h;
	// Per-tuft phase from its world origin, so they don't all wave in unison.
	vec3 origin = MODEL_MATRIX[3].xyz;
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
}

void fragment() {
	ALBEDO = mix(base_color, tip_color, v_mask);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
