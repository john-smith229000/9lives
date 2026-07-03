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
		var mat := _outline_material(color)     # own material per hull, so pulses don't clash
		var hull := MeshInstance3D.new()
		hull.name = _NAME
		hull.mesh = mi.mesh
		hull.material_override = mat
		hull.scale = Vector3.ONE * scale        # grows evenly about the mesh origin
		hull.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.add_child(hull)
		if pulse_period > 0.0:
			# Ease the alpha down and back up on a loop (dies with the hull).
			var tw := hull.create_tween().set_loops()
			tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tw.tween_property(mat, "albedo_color:a", pulse_min * color.a, pulse_period * 0.5)
			tw.tween_property(mat, "albedo_color:a", color.a, pulse_period * 0.5)

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
