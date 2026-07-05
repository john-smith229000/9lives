shader_type canvas_item;
// Retro post-process: ordered (Bayer 4x4) dithering + per-channel colour
// quantisation. Runs on a full-screen ColorRect INSIDE the low-res SubViewport,
// so the dither pattern sits on the chunky pixel grid (like PS1), then the whole
// thing is upscaled with nearest filtering.

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform int levels = 5;
uniform float dither_strength = 1.0;

// 4x4 Bayer threshold matrix, normalised to roughly -0.5..0.5.
const float bayer[16] = float[](
	0.0,  8.0,  2.0, 10.0,
	12.0, 4.0, 14.0,  6.0,
	3.0, 11.0,  1.0,  9.0,
	15.0, 7.0, 13.0,  5.0
);

void fragment() {
	vec3 col = texture(screen_tex, SCREEN_UV).rgb;
	float steps = max(float(levels) - 1.0, 1.0);
	// Bayer value for this (low-res) pixel, centred around 0.
	int bx = int(mod(FRAGCOORD.x, 4.0));
	int by = int(mod(FRAGCOORD.y, 4.0));
	float threshold = (bayer[by * 4 + bx] / 16.0) - 0.5;
	// Nudge by the dither threshold, then snap to the nearest palette step.
	col += (threshold / steps) * dither_strength;
	col = floor(col * steps + 0.5) / steps;
	COLOR = vec4(clamp(col, 0.0, 1.0), 1.0);
}
