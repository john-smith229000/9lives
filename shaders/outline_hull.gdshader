shader_type spatial;
// Uniform-thickness outline for SKINNED meshes. The hull is a copy of the mesh with
// SMOOTHED (averaged-per-position) normals + the same skin, so pushing every vertex
// out along its normal by a constant `grow`:
//   * gives an even rim all the way around (constant thickness), and
//   * stays connected on hard-edged low-poly models (smooth normals match at seams),
//   * and follows the animation (NORMAL is skinned by the engine).
// Front-culled + unshaded. Works on GL Compatibility.
render_mode cull_front, unshaded, shadows_disabled;

uniform vec3 line_color : source_color = vec3(1.0, 0.92, 0.25);
uniform float grow = 0.03;      // metres pushed out along the (smoothed) normal
uniform float alpha = 1.0;      // pulsed by Outline

void vertex() {
	VERTEX += normalize(NORMAL) * grow;
}

void fragment() {
	ALBEDO = line_color;
	ALPHA = alpha;
}
