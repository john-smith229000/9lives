extends Node
class_name KeyholeEffect
## Soft-circle x-ray: buildings that sit between the camera and the cat dissolve a
## dither hole around the cat so it stays visible. Created at runtime by World when
## enable_keyhole is on; World passes the building root nodes and the tuning params.

const _SHADER: Shader = preload("res://shaders/keyhole.gdshader")

var _camera: Camera3D
var _player: Node3D
# One entry per building mesh: {node, mats:[ShaderMaterial], aabb:AABB, active:float}.
# `active` eases toward 1 while the building sits between the camera and the cat.
var _buildings: Array = []
# While inside (free mode) we strip the keyhole materials so the building renders
# with its original material (spotlight, culling, etc. all behave normally).
var _inside := false
var _radius: float
var _softness: float
var _min_alpha: float
var _depth_bias: float
var _clear_radius: float

## Register every mesh under `roots` with a keyhole material, and remember the
## camera/player + tuning params. Call once after the scene is built.
func setup(camera: Camera3D, player: Node3D, roots: Array,
		radius: float, softness: float, min_alpha: float, depth_bias: float, clear_radius: float) -> void:
	_camera = camera
	_player = player
	_radius = radius
	_softness = softness
	_min_alpha = min_alpha
	_depth_bias = depth_bias
	_clear_radius = clear_radius
	_buildings.clear()
	for r in roots:
		for mi in _mesh_instances(r):
			_register(mi as MeshInstance3D)

func _register(mi: MeshInstance3D) -> void:
	if mi.mesh == null:
		return
	var mats: Array = []
	for i in mi.mesh.get_surface_count():
		var mat := ShaderMaterial.new()
		mat.shader = _SHADER
		var orig := mi.get_active_material(i)
		if orig is BaseMaterial3D:
			mat.set_shader_parameter("albedo_color", (orig as BaseMaterial3D).albedo_color)
			var tex := (orig as BaseMaterial3D).albedo_texture
			if tex:
				mat.set_shader_parameter("albedo_tex", tex)
				mat.set_shader_parameter("use_tex", true)
		mat.set_shader_parameter("radius", _radius)
		mat.set_shader_parameter("softness", _softness)
		mat.set_shader_parameter("min_alpha", _min_alpha)
		mat.set_shader_parameter("depth_bias", _depth_bias)
		mat.set_shader_parameter("clear_radius", _clear_radius)
		mat.set_shader_parameter("active", 0.0)
		mi.set_surface_override_material(i, mat)
		mats.append(mat)
	# World-space bounds, used to test whether the camera->cat line passes through
	# this building (i.e. it's actually occluding the cat).
	var world_aabb: AABB = mi.global_transform * mi.get_aabb()
	_buildings.append({"node": mi, "mats": mats, "aabb": world_aabb, "active": 0.0})

## Swap the keyhole shader on (true) or restore each building's original glb
## material (false, used while inside in free mode).
func _set_materials(enabled: bool) -> void:
	for b in _buildings:
		var mi = b["node"]
		if not is_instance_valid(mi):
			continue
		var mats: Array = b["mats"]
		for i in mats.size():
			mi.set_surface_override_material(i, mats[i] if enabled else null)

## Feed the cat's screen position to every building, and switch each building's
## effect on/off depending on whether it actually sits between camera and cat.
func _process(delta: float) -> void:
	if _buildings.is_empty() or _camera == null or _player == null:
		return
	# When the cat steps inside (free mode) we render the building with its
	# ORIGINAL material so its lighting (spotlight), culling, etc. all behave;
	# the keyhole shader only goes back on once we're outside in the iso view.
	var inside: bool = _player.has_method("is_in_free_mode") and _player.is_in_free_mode()
	if inside != _inside:
		_inside = inside
		_set_materials(not inside)
	if inside:
		return
	var vp := get_viewport().get_visible_rect().size
	if vp.x <= 0.0 or vp.y <= 0.0:
		return
	var pw := _player.global_position
	pw.y -= 0.1   # aim at the cat's body
	var screen := _camera.unproject_position(pw)
	var su := Vector2(screen.x / vp.x, screen.y / vp.y)
	# Horizontal-only look direction so a tall wall behind the cat doesn't read as
	# "in front" just because it's high.
	var fwd := -_camera.global_transform.basis.z
	fwd.y = 0.0
	if fwd.length() > 0.0001:
		fwd = fwd.normalized()
	var asp := vp.x / vp.y
	# Sample lines from the camera to points along the cat's VERTICAL axis only
	# (feet / middle / head). Staying on the cat's exact x,z means these lines
	# can't reach a wall behind the cat, so a building only activates when it's
	# truly between the camera and the cat — not one the cat is standing before.
	var cam_pos := _camera.global_position
	var foot := _player.global_position
	var targets: Array[Vector3] = [
		foot + Vector3(0.0, 0.05, 0.0),
		foot + Vector3(0.0, 0.45, 0.0),
		foot + Vector3(0.0, 0.85, 0.0),
	]
	var ease_w := 1.0 - exp(-14.0 * delta)
	for b in _buildings:
		var aabb: AABB = b["aabb"]
		var occluding := false
		# Skip occlusion if the cat is inside/under this building's bounding box —
		# the AABB test would fire even through open arches or when walking inside.
		if not aabb.has_point(foot):
			for t in targets:
				if aabb.intersects_segment(cam_pos, t):
					occluding = true
					break
		var target := 1.0 if occluding else 0.0
		b["active"] = lerpf(float(b["active"]), target, ease_w)
		for m in b["mats"]:
			m.set_shader_parameter("player_screen", su)
			m.set_shader_parameter("player_world", pw)
			m.set_shader_parameter("cam_forward", fwd)
			m.set_shader_parameter("aspect", asp)
			m.set_shader_parameter("active", b["active"])
			m.set_shader_parameter("radius", _radius)
			m.set_shader_parameter("softness", _softness)
			m.set_shader_parameter("min_alpha", _min_alpha)
			m.set_shader_parameter("depth_bias", _depth_bias)
			m.set_shader_parameter("clear_radius", _clear_radius)

## Every MeshInstance3D under a node (recursive).
func _mesh_instances(node: Node, acc: Array = []) -> Array:
	if node is MeshInstance3D:
		acc.append(node)
	for c in node.get_children():
		_mesh_instances(c, acc)
	return acc
