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

@export_group("Pushable Blocks")
## Tiles (grid x, z) that start with a pushable block on them.
@export var block_tiles: Array[Vector2i] = [Vector2i(12, 10)]

@export_group("Rolling Balls")
## Tiles (grid x, z) that start with a rollable ball on them.
@export var ball_tiles: Array[Vector2i] = [Vector2i(7, 10)]
## Speed (m/s) a ball gets when the cat shoves it.
@export var ball_launch_speed: float = 4.5
## Energy cost per tile on flat ground — lower = rolls farther.
@export var ball_friction: float = 2.5
## How much each tile of elevation change adds/removes from the roll distance
## (uphill shortens it, downhill lengthens it).
@export var ball_slope_accel: float = 12.0

var _heights: Array = []
var _noise: FastNoiseLite
var _defs: Array = []           # [{scene, mask, top}]
var _blocks: Dictionary = {}    # Vector2i(tile) -> block Node3D
var _block_starts: Array = []   # [{block, tile}] for restart
var _block_bottom := -0.375     # crate's lowest point relative to its origin
var _crate_scene: PackedScene

# --- Goal ---
var _goal_tile := Vector2i(-1, -1)
var _goal_node: Node3D
var _goal_scene: PackedScene
var _goal_triggered_scene: PackedScene
var _goal_bottom := 0.0
var _goal_tri_bottom := 0.0
var _goal_h_untriggered := 0.2  # pad height when not triggered
var _goal_h_triggered := 0.1    # pad height when smushed
var _goal_pad_extra := 0.0      # current pad height added to the goal tile
var won := false                # true once the crate is sitting on the goal
var _player_start := Vector3.ZERO   # cat's start position, for Restart

# --- Balls ---
var _ball_scene: PackedScene
var _balls: Array = []          # [{node, dir, speed, resting, tile, start}]
var _ball_radius := 0.375

@onready var _grid_root: Node3D = $Grid
@onready var _player: CharacterBody3D = $Player
@onready var _sun: DirectionalLight3D = $Sun

func _ready() -> void:
	if _sun:
		_sun.rotation_degrees = Vector3(-50.0, -55.0, 0.0)
	_build_grid()
	_spawn_blocks()
	_spawn_goal()
	_spawn_balls()
	if _player:
		_player.grid_size = grid_size
		_player.cell_size = cell_size
		_player.ground_y = ground_y
		_player.height_provider = Callable(self, "get_elevation")
		_player.block_handler = Callable(self, "can_enter")
		_player.sync_to_grid()
		_player_start = _player.global_position

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
## Includes the goal pad's current height so the cat / crate stand on top of it.
func get_elevation(x: int, z: int) -> float:
	if x >= 0 and x < grid_size and z >= 0 and z < grid_size:
		var e: float = _heights[x][z]
		if x == _goal_tile.x and z == _goal_tile.y:
			e += _goal_pad_extra
		return e
	return 0.0

# --- Pushable blocks ------------------------------------------------------

func _spawn_blocks() -> void:
	if block_tiles.is_empty():
		return
	_crate_scene = load("res://models/crate.glb")
	if _crate_scene == null:
		push_warning("World: could not load crate.glb")
		return
	_block_bottom = _measure_block_bottom()
	for tile in block_tiles:
		if tile.x < 0 or tile.x >= grid_size or tile.y < 0 or tile.y >= grid_size:
			continue
		if _blocks.has(tile):
			continue
		var block := _make_crate()
		block.position = _block_world_pos(tile)
		_grid_root.add_child(block)
		_blocks[tile] = block
		_block_starts.append({"block": block, "tile": tile})

## crate.glb currently holds the whole Blender scene, so pull out just the node
## named "crate" and drop everything else (the tiles / grass cubes).
func _make_crate() -> Node3D:
	var src := _crate_scene.instantiate()
	var holder := Node3D.new()
	var crate := src.find_child("crate", true, false)
	if crate:
		crate.get_parent().remove_child(crate)
		holder.add_child(crate)
	else:
		push_warning("World: no 'crate' node inside crate.glb")
	src.queue_free()
	return holder

## The crate's lowest point relative to its origin, so we can rest it on a tile.
func _measure_block_bottom() -> float:
	var inst := _make_crate()
	add_child(inst)
	var min_y := INF
	for mi in _all_mesh_instances(inst):
		var m := mi as MeshInstance3D
		var box: AABB = m.global_transform * m.get_aabb()
		min_y = minf(min_y, box.position.y)
	inst.queue_free()
	return -0.375 if is_inf(min_y) else min_y - global_position.y

func _all_mesh_instances(node: Node, acc: Array = []) -> Array:
	if node is MeshInstance3D:
		acc.append(node)
	for c in node.get_children():
		_all_mesh_instances(c, acc)
	return acc

## Send every block back to the tile it started on (used by the Restart button).
func reset_blocks() -> void:
	_blocks.clear()
	for s in _block_starts:
		var block: Node3D = s["block"]
		var tile: Vector2i = s["tile"]
		block.position = _block_world_pos(tile)
		block.rotation = Vector3.ZERO
		_blocks[tile] = block
	# Reset the goal back to its un-triggered tile.
	if won:
		won = false
		_place_goal(false)
	# Reset balls to their start tiles, stationary.
	for ball in _balls:
		ball["resting"] = true
		ball["speed"] = 0.0
		ball["dir"] = Vector2i.ZERO
		ball["tile"] = ball["start"]
		var node: Node3D = ball["node"]
		node.position = _ball_world_pos(ball["start"])
		node.rotation = Vector3.ZERO
	# Reset the cat back to its starting position.
	if _player and _player.has_method("reset_to_start"):
		_player.reset_to_start(_player_start)

func _block_world_pos(tile: Vector2i) -> Vector3:
	# Rest the crate's bottom on the tile's top surface (tile top = elevation + 0.5).
	var surface := get_elevation(tile.x, tile.y) + 0.5
	return Vector3(tile.x * cell_size, surface - _block_bottom, tile.y * cell_size)

## Called by the player: can it step onto `tile` moving in `dir`?
## Returns true (free), false (blocked), or {block, from, to} when a block is
## being pushed — the player then slides that block in lockstep with itself.
func can_enter(tile: Vector2i, dir: Vector2i) -> Variant:
	# A ball (rolling or resting): (re)shove it and step into the tile it vacates.
	# If it can't move (obstacle right behind it), the cat is blocked too.
	var ball := _ball_at(tile)
	if not ball.is_empty():
		return _launch_ball(ball, dir)
	if not _blocks.has(tile):
		return true
	var dest := tile + dir
	# Must stay on the board and the destination must be empty.
	if dest.x < 0 or dest.x >= grid_size or dest.y < 0 or dest.y >= grid_size:
		return false
	if _blocks.has(dest) or not _ball_at(dest).is_empty():
		return false
	# Update occupancy now; hand the slide off to the player for perfect sync.
	var block: Node3D = _blocks[tile]
	_blocks.erase(tile)
	_blocks[dest] = block
	return {"block": block, "from": block.position, "to": _block_world_pos(dest)}

# --- Goal ----------------------------------------------------------------

func _spawn_goal() -> void:
	if block_tiles.is_empty():
		return                      # only meaningful where there's a crate to push
	_goal_scene = load("res://models/goal_tile.glb")
	_goal_triggered_scene = load("res://models/goal_tile_triggered.glb")
	if _goal_scene == null or _goal_triggered_scene == null:
		push_warning("World: goal tile glb(s) missing.")
		return
	var a0 := _measure_aabb_y(_goal_scene)            # untriggered (min_y, max_y)
	var a1 := _measure_aabb_y(_goal_triggered_scene)  # triggered
	_goal_bottom = a0.x
	_goal_tri_bottom = a1.x
	_goal_h_untriggered = a0.y - a0.x
	_goal_h_triggered = a1.y - a1.x
	_goal_tile = _pick_goal_tile()
	_place_goal(false)

## A random tile that isn't the player's or a crate's start tile.
func _pick_goal_tile() -> Vector2i:
	var rng := RandomNumberGenerator.new()
	rng.seed = terrain_seed + 7
	var player_tile := Vector2i(10, 10)
	if _player:
		player_tile = Vector2i(roundi(_player.global_position.x / cell_size), roundi(_player.global_position.z / cell_size))
	for _i in 100:
		var t := Vector2i(rng.randi_range(0, grid_size - 1), rng.randi_range(0, grid_size - 1))
		if t == player_tile or t in block_tiles:
			continue
		return t
	return Vector2i(0, 0)

func _place_goal(triggered: bool) -> void:
	if _goal_node:
		_goal_node.queue_free()
	var scene := _goal_triggered_scene if triggered else _goal_scene
	_goal_node = scene.instantiate()
	# Use the RAW terrain height (not get_elevation, which adds the pad) so the
	# pad always rests on the ground instead of floating on its own height.
	var surface := float(_heights[_goal_tile.x][_goal_tile.y]) + 0.5
	var bottom := _goal_tri_bottom if triggered else _goal_bottom
	_goal_node.position = Vector3(_goal_tile.x * cell_size, surface - bottom, _goal_tile.y * cell_size)
	_grid_root.add_child(_goal_node)
	# Things standing on the goal tile ride on top of the pad at its current height.
	_goal_pad_extra = _goal_h_triggered if triggered else _goal_h_untriggered

func _process(delta: float) -> void:
	_update_goal()
	_update_crate_heights(delta)
	_update_balls(delta)

## Keep each crate sitting on whatever surface is under it (ground, or the goal
## pad at its current height), easing the Y so it rides the pad / smush smoothly.
## The player drives crate X/Z while pushing; World owns the Y.
func _update_crate_heights(delta: float) -> void:
	for tile in _blocks:
		var b: Node3D = _blocks[tile]
		var tx := roundi(b.position.x / cell_size)
		var tz := roundi(b.position.z / cell_size)
		var target_y := (get_elevation(tx, tz) + 0.5) - _block_bottom
		b.position.y = lerpf(b.position.y, target_y, 1.0 - exp(-15.0 * delta))

## Toggle the goal based on how much a crate actually covers it. Triggers once a
## crate covers ~40% of the tile and releases when it slides back off (hysteresis
## prevents flicker right at the threshold).
func _update_goal() -> void:
	if _goal_tile.x < 0 or _goal_node == null:
		return
	var gx := _goal_tile.x * cell_size
	var gz := _goal_tile.y * cell_size
	var best_cover := 0.0
	for tile in _blocks:
		var b: Node3D = _blocks[tile]
		var d := Vector2(b.position.x - gx, b.position.z - gz).length()
		best_cover = maxf(best_cover, clampf(1.0 - d / cell_size, 0.0, 1.0))
	if not won and best_cover >= 0.4:
		won = true
		_place_goal(true)
	elif won and best_cover < 0.3:
		won = false
		_place_goal(false)

# --- Rolling balls -------------------------------------------------------

func _spawn_balls() -> void:
	if ball_tiles.is_empty():
		return
	_ball_scene = load("res://models/ball.glb")
	if _ball_scene == null:
		push_warning("World: could not load ball.glb")
		return
	var ab := _measure_aabb_y(_ball_scene)
	_ball_radius = (ab.y - ab.x) * 0.5
	for tile in ball_tiles:
		if tile.x < 0 or tile.x >= grid_size or tile.y < 0 or tile.y >= grid_size:
			continue
		var node := _ball_scene.instantiate() as Node3D
		node.position = _ball_world_pos(tile)
		_grid_root.add_child(node)
		_balls.append({
			"node": node, "dir": Vector2i.ZERO, "speed": 0.0,
			"resting": true, "tile": tile, "start": tile,
		})

func _ball_world_pos(tile: Vector2i) -> Vector3:
	return Vector3(tile.x * cell_size, get_elevation(tile.x, tile.y) + 0.5 + _ball_radius, tile.y * cell_size)

## Any ball (rolling or resting) currently over this tile.
func _ball_at(tile: Vector2i) -> Dictionary:
	for ball in _balls:
		var n: Node3D = ball["node"]
		if Vector2i(roundi(n.position.x / cell_size), roundi(n.position.z / cell_size)) == tile:
			return ball
	return {}

func _player_tile() -> Vector2i:
	if _player == null:
		return Vector2i(-9999, -9999)
	return Vector2i(roundi(_player.global_position.x / cell_size), roundi(_player.global_position.z / cell_size))

func _launch_ball(ball: Dictionary, dir: Vector2i) -> bool:
	var node: Node3D = ball["node"]
	var cur := Vector2i(roundi(node.position.x / cell_size), roundi(node.position.z / cell_size))
	if _ball_blocked(cur + dir, ball):
		return false                       # obstacle right behind it — can't shove

	# Walk the elevation map in `dir`, spending kinetic energy per tile. Uphill
	# tiles cost more, downhill less, so the ball travels a whole number of tiles
	# that depends on the shove and the terrain. Round at the end.
	var ke := 0.5 * ball_launch_speed * ball_launch_speed
	var tile := cur
	var tiles := 0
	while not _ball_blocked(tile + dir, ball) and tiles < grid_size * 2:
		var nxt := tile + dir
		var de := _base_elev(nxt) - _base_elev(tile)
		var cost := ball_friction * cell_size + ball_slope_accel * de
		if cost <= 0.0:
			ke -= cost                     # downhill: gains energy, keeps rolling
			tile = nxt
			tiles += 1
		elif ke >= cost:
			ke -= cost
			tile = nxt
			tiles += 1
		else:
			if ke / cost >= 0.5:           # reaches past the midpoint: round up
				tiles += 1
			break
	if tiles < 1:
		tiles = 1                          # cur+dir is free, so at least one tile

	var dist := float(tiles) * cell_size
	ball["dir"] = dir
	ball["resting"] = false
	ball["target"] = Vector2((cur.x + dir.x * tiles) * cell_size, (cur.y + dir.y * tiles) * cell_size)
	# Deceleration that stops exactly at the target center, starting at launch speed.
	ball["decel"] = (ball_launch_speed * ball_launch_speed) / (2.0 * dist)
	return true

func _ball_blocked(tile: Vector2i, self_ball: Dictionary) -> bool:
	if tile.x < 0 or tile.x >= grid_size or tile.y < 0 or tile.y >= grid_size:
		return true
	if _blocks.has(tile):
		return true
	if tile == _player_tile():
		return true                     # don't roll through the cat
	for b in _balls:
		if b != self_ball and b["resting"] and b["tile"] == tile:
			return true
	return false

func _base_elev(tile: Vector2i) -> float:
	if tile.x >= 0 and tile.x < grid_size and tile.y >= 0 and tile.y < grid_size:
		return float(_heights[tile.x][tile.y])
	return 0.0

func _update_balls(delta: float) -> void:
	for ball in _balls:
		if not ball["resting"]:
			_roll_ball(ball, delta)
		_update_ball_height(ball, delta)

func _roll_ball(ball: Dictionary, delta: float) -> void:
	var node: Node3D = ball["node"]
	var d: Vector2i = ball["dir"]
	var target: Vector2 = ball["target"]
	var rem := (target - Vector2(node.position.x, node.position.z)).length()
	if rem <= 0.005:
		node.position.x = target.x
		node.position.z = target.y
		_rest_ball(ball)
		return
	# Constant deceleration toward the precomputed target: v = sqrt(2*a*remaining)
	# gives a smooth slow-down that reaches exactly 0 at the tile centre.
	var v: float = sqrt(2.0 * ball["decel"] * rem)
	var move := minf(v * delta, rem)
	# Stop centred on the last free tile if something (the cat, a crate) is now in
	# the way — so a rolling ball can't pass through the player.
	var cur_tile := Vector2i(roundi(node.position.x / cell_size), roundi(node.position.z / cell_size))
	var next_tile := Vector2i(roundi((node.position.x + d.x * move) / cell_size), roundi((node.position.z + d.y * move) / cell_size))
	if next_tile != cur_tile and _ball_blocked(next_tile, ball):
		node.position.x = cur_tile.x * cell_size
		node.position.z = cur_tile.y * cell_size
		_rest_ball(ball)
		return
	node.position.x += d.x * move
	node.position.z += d.y * move
	_spin(node, d, move)
	if rem - move <= 0.005:
		node.position.x = target.x
		node.position.z = target.y
		_rest_ball(ball)

func _spin(node: Node3D, d: Vector2i, dist: float) -> void:
	var axis := Vector3(d.y, 0.0, -d.x)
	if axis.length() > 0.0:
		node.rotate(axis.normalized(), dist / _ball_radius)

func _rest_ball(ball: Dictionary) -> void:
	ball["resting"] = true
	ball["speed"] = 0.0
	ball["dir"] = Vector2i.ZERO
	var node: Node3D = ball["node"]
	ball["tile"] = Vector2i(roundi(node.position.x / cell_size), roundi(node.position.z / cell_size))

func _update_ball_height(ball: Dictionary, delta: float) -> void:
	var node: Node3D = ball["node"]
	var tx := roundi(node.position.x / cell_size)
	var tz := roundi(node.position.z / cell_size)
	var target_y := get_elevation(tx, tz) + 0.5 + _ball_radius
	node.position.y = lerpf(node.position.y, target_y, 1.0 - exp(-15.0 * delta))

## Min and max Y of a single-node glb relative to its origin (bottom & top).
func _measure_aabb_y(scene: PackedScene) -> Vector2:
	var inst := scene.instantiate()
	add_child(inst)
	var min_y := INF
	var max_y := -INF
	for mi in _all_mesh_instances(inst):
		var m := mi as MeshInstance3D
		var box: AABB = m.global_transform * m.get_aabb()
		min_y = minf(min_y, box.position.y)
		max_y = maxf(max_y, box.position.y + box.size.y)
	inst.queue_free()
	if is_inf(min_y):
		return Vector2(0.0, 0.2)
	return Vector2(min_y - global_position.y, max_y - global_position.y)
