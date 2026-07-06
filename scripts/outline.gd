class_name Outline
## Crisp outline via a UNIFORMLY SCALED duplicate of the mesh, drawn front-culled
## and unshaded so only its rim shows behind the object. Uniform scaling (rather
## than growing each vertex along its normal) keeps the shell connected, so
## faceted low-poly meshes don't get the seams/gaps that normal-grow produces.
## No screen-space post-processing, so it works in the GL Compatibility renderer.
##
## Best for convex, roughly-centred objects (balls, crates). Usage:
##   Outline.add(node, Color.YELLOW, 1.06)  ...  Outline.remove(node)

const _NAME := "__outline_hull"

## Outline every mesh under `root`. `scale` is the hull size relative to the mesh
## (1.06 = 6% larger); bigger = thicker outline. The outline slowly pulses its
## opacity between `pulse_min` and full over `pulse_period` seconds (set
## pulse_period <= 0 for a steady, non-pulsing outline).
static func add(root: Node, color: Color = Color(1.0, 0.92, 0.25), scale: float = 1.06, pulse_min: float = 0.2, pulse_period: float = 1.6) -> void:
	for mi in _meshes(root):
		if mi.has_node(_NAME) or mi.mesh == null:
			continue
		# A skinned mesh (an animated character) needs a hull bound to the same
		# skeleton + a grow-along-normal shader, or the outline shows the rest pose.
		var skel: Node = mi.get_node_or_null(mi.skeleton) if mi.skeleton != NodePath("") else null
		var skinned := skel != null
		var hull := MeshInstance3D.new()
		hull.name = _NAME
		hull.mesh = mi.mesh
		hull.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mat: Material
		var pulse_path := "albedo_color:a"
		if skinned:
			hull.mesh = _smooth_hull_mesh(mi.mesh)   # smoothed normals = even, seamless rim
			hull.skin = mi.skin
			mat = _hull_material(color, _grow_for(mi, scale))
			pulse_path = "shader_parameter/alpha"
		else:
			mat = _outline_material(color)
			hull.scale = Vector3.ONE * scale    # grows evenly about the mesh origin
		hull.material_override = mat
		mi.add_child(hull)
		if skinned:
			hull.skeleton = hull.get_path_to(skel)   # follow the same animation
		if pulse_period > 0.0:
			# Ease the alpha down and back up on a loop (dies with the hull).
			var tw := hull.create_tween().set_loops()
			tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tw.tween_property(mat, pulse_path, pulse_min * color.a, pulse_period * 0.5)
			tw.tween_property(mat, pulse_path, color.a, pulse_period * 0.5)

## Remove the outline hull(s).
static func remove(root: Node) -> void:
	for mi in _meshes(root):
		var hull: Node = mi.get_node_or_null(_NAME)
		if hull:
			hull.queue_free()

static func is_outlined(root: Node) -> bool:
	for mi in _meshes(root):
		if mi.has_node(_NAME):
			return true
	return false

## Constant grow-along-(smoothed)-normal material for skinned meshes.
static func _hull_material(color: Color, grow: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/outline_hull.gdshader")
	m.set_shader_parameter("line_color", Color(color.r, color.g, color.b))
	m.set_shader_parameter("grow", grow)
	m.set_shader_parameter("alpha", color.a)
	return m

## Convert the relative `scale` (1.06 = 6%) into a constant metres grow, sized to the
## mesh so the outline reads at a similar thickness across characters.
static func _grow_for(mi: MeshInstance3D, scale: float) -> float:
	var s := mi.mesh.get_aabb().size
	var avg := (s.x + s.y + s.z) / 3.0
	return maxf(scale - 1.0, 0.0) * avg

# Cache of smoothed hull meshes, keyed by the source mesh (built once per mesh).
static var _smooth_cache: Dictionary = {}

## A copy of `mesh` with normals averaged across coincident vertices (so a constant
## normal-grow gives an even, seamless rim). Bones/weights are kept so it still skins.
static func _smooth_hull_mesh(mesh: Mesh) -> Mesh:
	if _smooth_cache.has(mesh):
		return _smooth_cache[mesh]
	var out := ArrayMesh.new()
	for si in mesh.get_surface_count():
		var arrays: Array = mesh.surface_get_arrays(si)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var norms = arrays[Mesh.ARRAY_NORMAL]
		if norms != null and not (norms as PackedVector3Array).is_empty():
			var sums: Dictionary = {}
			for i in verts.size():
				var k := _pkey(verts[i])
				sums[k] = sums.get(k, Vector3.ZERO) + norms[i]
			var smooth := PackedVector3Array()
			smooth.resize(verts.size())
			for i in verts.size():
				var n: Vector3 = sums[_pkey(verts[i])]
				smooth[i] = n.normalized() if n.length_squared() > 0.0 else norms[i]
			arrays[Mesh.ARRAY_NORMAL] = smooth
		var flags := 0
		var bones = arrays[Mesh.ARRAY_BONES]
		if bones != null and verts.size() > 0 and (bones as PackedInt32Array).size() == verts.size() * 8:
			flags = Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags)
	_smooth_cache[mesh] = out
	return out

static func _pkey(v: Vector3) -> Vector3i:
	return Vector3i(roundi(v.x * 1000.0), roundi(v.y * 1000.0), roundi(v.z * 1000.0))

static func _outline_material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED   # flat, bright, ignores lighting
	m.albedo_color = color
	m.cull_mode = BaseMaterial3D.CULL_FRONT                 # only the shell's far faces = a rim
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA      # so the pulse can fade it
	return m

## All MeshInstance3D under `node`, skipping outline hulls themselves.
static func _meshes(node: Node, acc: Array = []) -> Array:
	if node is MeshInstance3D and node.name != _NAME:
		acc.append(node)
	for c in node.get_children():
		_meshes(c, acc)
	return acc
