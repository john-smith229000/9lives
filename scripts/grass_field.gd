extends MultiMeshInstance3D
class_name GrassField
## Scatters a grass tuft (models/grass.glb) as a MultiMesh over the parent World's
## grid and drives it with the wind shader. Wind-only for now. Add this node as a
## child of a World; the tuft's base should sit at local Y = 0.

const _WIND_SHADER: Shader = preload("res://shaders/grass_wind.gdshader")

@export_group("Scatter")
## Tufts per tile.
@export var per_tile: int = 4
## Random XZ offset within a tile (m).
@export var jitter: float = 0.42
@export var scale_min: float = 0.8
@export var scale_max: float = 1.3
## Random spin around the vertical, so tufts don't look tiled.
@export var random_yaw: bool = true
## Fixed grid size to use if this isn't parented to a World.
@export var fallback_grid: int = 20

@export_group("Wind")
@export var wind_dir: Vector2 = Vector2(1.0, 0.3)
@export var wind_strength: float = 0.12
@export var wind_speed: float = 1.5
@export var sway_scale: float = 0.6
@export var flutter: float = 0.3
## Set to your tuft's height (used to normalize the sway/colour gradient).
@export var blade_height: float = 0.5
@export var base_color: Color = Color(0.13, 0.35, 0.11)
@export var tip_color: Color = Color(0.40, 0.72, 0.28)

func _ready() -> void:
	var mesh := _grass_mesh()
	if mesh == null:
		push_warning("GrassField: models/grass.glb missing or has no mesh — nothing to scatter.")
		return
	var world := get_parent()
	var gs: int = fallback_grid
	if world and "grid_size" in world:
		gs = world.grid_size
	var cell := 1.0
	if world and "cell_size" in world:
		cell = world.cell_size
	var rng := RandomNumberGenerator.new()
	var xforms: Array[Transform3D] = []
	for x in gs:
		for z in gs:
			var tile := Vector2i(x, z)
			if world and world.has_method("has_water") and world.has_water(tile):
				continue
			if world and world.has_method("has_hole") and world.has_hole(tile):
				continue
			var top := 0.5
			if world and world.has_method("get_elevation"):
				top = world.get_elevation(x, z) + 0.5
			for _i in per_tile:
				var t := Transform3D.IDENTITY
				if random_yaw:
					t = t.rotated(Vector3.UP, rng.randf() * TAU)
				t = t.scaled(Vector3.ONE * rng.randf_range(scale_min, scale_max))
				t.origin = Vector3(
					x * cell + rng.randf_range(-jitter, jitter),
					top,
					z * cell + rng.randf_range(-jitter, jitter))
				xforms.append(t)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	multimesh = mm
	material_override = _wind_material()

## First mesh found inside grass.glb (kept as a shared resource for the MultiMesh).
func _grass_mesh() -> Mesh:
	var scene := load("res://models/grass.glb") as PackedScene
	if scene == null:
		return null
	var inst := scene.instantiate()
	var mesh: Mesh = null
	for mi in _find_meshes(inst):
		mesh = (mi as MeshInstance3D).mesh
		break
	inst.queue_free()
	return mesh

func _wind_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _WIND_SHADER
	m.set_shader_parameter("wind_dir", wind_dir)
	m.set_shader_parameter("wind_strength", wind_strength)
	m.set_shader_parameter("wind_speed", wind_speed)
	m.set_shader_parameter("sway_scale", sway_scale)
	m.set_shader_parameter("flutter", flutter)
	m.set_shader_parameter("blade_height", blade_height)
	m.set_shader_parameter("base_color", base_color)
	m.set_shader_parameter("tip_color", tip_color)
	return m

func _find_meshes(node: Node, acc: Array = []) -> Array:
	if node is MeshInstance3D:
		acc.append(node)
	for c in node.get_children():
		_find_meshes(c, acc)
	return acc
