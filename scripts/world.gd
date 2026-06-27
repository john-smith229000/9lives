extends Node3D
## Builds the board from a beveled-tile set. Each tile picks the mesh + rotation
## that matches which of its edges are "free" (neighbour missing or lower), so
## flat same-height regions stay flush (no_bev) and only exposed edges are
## beveled. Also wires the player.

# Tile meshes (1 m cubes; bevels only on the listed FREE sides, in Godot axes).
const T_NO := preload("res://models/no_bev.glb")      # free: none
const T_ONE := preload("res://models/one_bev.glb")    # free: +Z
const T_TWO := preload("res://models/two_bev.glb")    # free: +X, +Z
const T_THREE := preload("res://models/three_bev.glb")# free: +X, -Z, +Z
const T_OPP := preload("res://models/two_opp_bev.glb")# free: -Z, +Z (opposite)
const T_FULL := preload("res://models/full_bev.glb")  # free: all

# Side bits used for matching/rotation. Cycle order E->N->W->S (a +90° Y turn
# shifts each side one step forward), so a rotation is a circular bit-shift.
const BIT_E := 1   # +X
const BIT_N := 2   # -Z
const BIT_W := 4   # -X
const BIT_S := 8   # +Z

@export var grid_size: int = 20
@export var cell_size: float = 1.0
@export var ground_y: float = 1.0

@export_group("Terrain")
@export var height_gradient: float = 0.1
@export var noise_amplitude: float = 0.6
@export var noise_frequency: float = 0.16
@export var height_step: float = 0.1
@export var terrain_seed: int = 1337

var _heights: Array = []
var _noise: FastNoiseLite
var _defs: Array = []           # [{scene, mask, top}]

@onready var _grid_root: Node3D = $Grid
@onready var _player: CharacterBody3D = $Player
@onready var _sun: DirectionalLight3D = $Sun

func _ready() -> void:
	if _sun:
		_sun.rotation_degrees = Vector3(-50.0, -55.0, 0.0)
	_build_grid()
	if _player:
		_player.grid_size = grid_size
		_player.cell_size = cell_size
		_player.ground_y = ground_y
		_player.height_provider = Callable(self, "get_elevation")
		_player.sync_to_grid()

func _build_grid() -> void:
	_noise = FastNoiseLite.new()
	_noise.seed = terrain_seed
	_noise.frequency = noise_frequency
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH

	# Canonical free-edge masks for each tile (from the Blender orientation).
	_defs = [
		{"scene": T_NO, "mask": 0},
		{"scene": T_ONE, "mask": BIT_S},
		{"scene": T_TWO, "mask": BIT_E | BIT_S},
		{"scene": T_THREE, "mask": BIT_E | BIT_N | BIT_S},
		{"scene": T_OPP, "mask": BIT_N | BIT_S},
		{"scene": T_FULL, "mask": BIT_E | BIT_N | BIT_W | BIT_S},
	]
	for d in _defs:
		d["top"] = _measure_top(d["scene"])

	# Pass 1: heights.
	_heights.resize(grid_size)
	for x in grid_size:
		var column: Array = []
		column.resize(grid_size)
		for z in grid_size:
			column[z] = _elevation_for(x, z)
		_heights[x] = column

	# Pass 2: place a matching beveled tile per cell.
	for x in grid_size:
		for z in grid_size:
			_place_tile(x, z)

func _place_tile(x: int, z: int) -> void:
	var e: float = float(_heights[x][z])
	var top := e + 0.5

	# Which sides are free (neighbour missing or strictly lower).
	var mask := 0
	if _is_free(top, x + 1, z): mask |= BIT_E   # +X
	if _is_free(top, x, z - 1): mask |= BIT_N   # -Z
	if _is_free(top, x - 1, z): mask |= BIT_W   # -X
	if _is_free(top, x, z + 1): mask |= BIT_S   # +Z

	# Find the tile + rotation whose beveled edges match this pattern.
	var scene: PackedScene = T_FULL          # fallback (shouldn't trigger now)
	var rot := 0
	var mesh_top: float = _defs[_defs.size() - 1]["top"]   # T_FULL is last
	for d in _defs:
		var matched := false
		for k in 4:
			if _rotl(d["mask"], k) == mask:
				scene = d["scene"]
				rot = k
				mesh_top = d["top"]
				matched = true
				break
		if matched:
			break

	var container := Node3D.new()
	var inst := scene.instantiate()
	container.add_child(inst)
	# (No material override — let each glb keep its own baked materials/colors.)
	# Align this mesh's own top to the tile surface so all tops are flush and the
	# cat's feet land correctly, regardless of tile type.
	container.position = Vector3(x * cell_size, top - mesh_top, z * cell_size)
	container.rotation.y = deg_to_rad(90.0 * rot)
	# Tiny X/Z overlap so flush neighbour walls don't z-fight.
	container.scale = Vector3(1.01, 1.0, 1.01)
	_grid_root.add_child(container)

func _is_free(top: float, nx: int, nz: int) -> bool:
	var nt := _tile_top(nx, nz)
	return is_nan(nt) or nt < top - 0.001

func _tile_top(x: int, z: int) -> float:
	if x < 0 or x >= grid_size or z < 0 or z >= grid_size:
		return NAN
	return float(_heights[x][z]) + 0.5

## Circular left-shift of the 4-bit side mask by k (one step = a +90° Y turn).
func _rotl(mask: int, k: int) -> int:
	for _i in k:
		mask = ((mask << 1) | (mask >> 3)) & 0xF
	return mask

## Top Y of a tile mesh in its own local space (after its baked root scale).
func _measure_top(scene: PackedScene) -> float:
	var inst := scene.instantiate()
	add_child(inst)
	var mi := _find_mesh_instance(inst)
	var t := 0.5
	if mi:
		t = (mi.global_transform * mi.get_aabb()).end.y - global_position.y
	inst.queue_free()
	return t

func _find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for c in node.get_children():
		var found := _find_mesh_instance(c)
		if found:
			return found
	return null

func _elevation_for(x: int, z: int) -> float:
	var slope := float((grid_size - 1 - x) + (grid_size - 1 - z)) * height_gradient
	var n := (_noise.get_noise_2d(float(x), float(z)) * 0.5 + 0.5) * noise_amplitude
	var ev := maxf(slope + n, 0.0)
	if height_step > 0.0:
		ev = roundf(ev / height_step) * height_step
	return ev

## Elevation (meters) of a tile's top surface above the base. Used by the player.
func get_elevation(x: int, z: int) -> float:
	if x >= 0 and x < grid_size and z >= 0 and z < grid_size:
		return _heights[x][z]
	return 0.0
