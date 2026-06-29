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
## When false, skip generating the tile terrain (use a custom map mesh instead).
@export var generate_terrain: bool = true
## Optional custom map node to auto-generate trimesh collision for (Scene 3).
@export var map_path: NodePath

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

# --- Goals ---
# Each goal: {tile, untriggered, triggered, bottom, tri_bottom, h_unt, h_tri,
#             node, won, by ("crate"/"ball"), pad_extra}
var _goals: Array = []
var _player_start := Vector3.ZERO   # cat's start position, for Restart

# --- Balls ---
var _ball_scene: PackedScene
var _balls: Array = []          # [{node, dir, speed, resting, tile, start}]
var _ball_radius := 0.375

@onready var _grid_root: Node3D = $Grid
@onready var _player: CharacterBody3D = $Player
@onready var _sun: DirectionalLight3D = $Sun
@onready var _camera: Camera3D = get_node_or_null("Camera")

var _obstacle: Dictionary = {}   # cached map-feature blocked tiles (lazy)
var _obstacle_built := false

func _ready() -> void:
	if _sun:
		_sun.rotation_degrees = Vector3(-50.0, -55.0, 0.0)
	_build_grid()
	_build_map_collision()
	_spawn_blocks()
	_spawn_goal()
	_spawn_balls()
	if _player:
		_player.grid_size = grid_size
		_player.cell_size = cell_size
		_player.ground_y = ground_y
		_player.height_provider = Callable(self, "get_elevation")
		_player.block_handler = Callable(self, "can_enter")
		_player.view_camera = _camera
		_player.sync_to_grid()
		_player_start = _player.global_position
	_setup_click_catcher()

## Generate trimesh collision for a custom map mesh (Scene 3) so grid movement
## is blocked by its walls/features.
func _build_map_collision() -> void:
	if map_path == NodePath(""):
		return
	var map := get_node_or_null(map_path)
	if map == null:
		push_warning("World: map_path '%s' not found — no map collision generated." % str(map_path))
		return
	var meshes := _all_mesh_instances(map)
	if meshes.is_empty():
		push_warning("World: map has no MeshInstance3D to build collision from.")
	print("[map] generating collision for ", meshes.size(), " mesh(es) under ", map_path)
	for mi in meshes:
		(mi as MeshInstance3D).create_trimesh_collision()

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

	# Pass 1: heights (flat when terrain generation is off, e.g. a custom map).
	_heights.resize(grid_size)
	for x in grid_size:
		var column: Array = []
		column.resize(grid_size)
		for z in grid_size:
			column[z] = _elevation_for(x, z) if generate_terrain else 0.0
		_heights[x] = column

	# Pass 2: place a matching beveled tile per cell (skipped for custom maps).
	if generate_terrain:
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
		for goal in _goals:
			if goal["tile"].x == x and goal["tile"].y == z:
				e += goal["pad_extra"]
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
		crate.owner = null            # avoid the reparent/owner-inconsistency warning
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
	# Reset every goal back to its un-triggered state.
	for goal in _goals:
		if goal["won"]:
			goal["won"] = false
			_place_goal(goal, false)
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
	# Swing the camera back to the default orientation.
	if _camera and _camera.has_method("reset_rotation"):
		_camera.reset_rotation()

func _block_world_pos(tile: Vector2i) -> Vector3:
	# Rest the crate's bottom on the tile's top surface (tile top = elevation + 0.5).
	var surface := get_elevation(tile.x, tile.y) + 0.5
	return Vector3(tile.x * cell_size, surface - _block_bottom, tile.y * cell_size)

# --- Click to move -------------------------------------------------------

# A full-screen Control captures clicks: its local mouse position and size are
# in the same coordinate space, sidestepping the project_ray stretch bug.
func _setup_click_catcher() -> void:
	var layer := CanvasLayer.new()
	layer.layer = -1                       # below the pause menu
	add_child(layer)
	var catcher := Control.new()
	catcher.set_anchors_preset(Control.PRESET_FULL_RECT)
	catcher.mouse_filter = Control.MOUSE_FILTER_PASS
	layer.add_child(catcher)
	catcher.gui_input.connect(_on_click.bind(catcher))

func _on_click(event: InputEvent, catcher: Control) -> void:
	if _camera == null or _player == null:
		return
	if _player.has_method("is_in_free_mode") and _player.is_in_free_mode():
		return                               # interior uses free WASD, not click
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var tile := _click_to_tile(event.position, catcher.size)
	if tile.x < 0:
		return
	var start: Vector2i = _player.nav_tile() if _player.has_method("nav_tile") else _player_tile()
	if not _player.has_method("set_path"):
		return

	# Push/interact gesture: if the cat is right next to a crate/ball and you
	# click straight past it (same row or column, that direction), walk straight
	# INTO it to push/shove rather than pathfinding around.
	var delta := tile - start
	if delta != Vector2i.ZERO and (delta.x == 0 or delta.y == 0):
		var dir := Vector2i(signi(delta.x), signi(delta.y))
		if _is_pushable_tile(start + dir):
			_player.set_path(_straight_line(start, dir, tile))
			return

	# Otherwise pathfind around obstacles.
	var path := find_path(start, tile)
	if not path.is_empty():
		_player.set_path(path)

func _is_pushable_tile(tile: Vector2i) -> bool:
	return _blocks.has(tile) or not _ball_at(tile).is_empty()

## Straight cardinal line of tiles from start (exclusive) toward target, used for
## push gestures so the path runs through the object instead of around it.
func _straight_line(start: Vector2i, dir: Vector2i, target: Vector2i) -> Array:
	var path: Array = []
	var c := start
	while c != target:
		c += dir
		if c.x < 0 or c.x >= grid_size or c.y < 0 or c.y >= grid_size:
			break
		path.append(c)
	return path

## Unproject a click (Control-local pos within `screen_size`) and return the tile
## it lands on. Manual ortho unprojection (immune to the project_ray stretch bug)
## plus a height-field raymarch so it's correct over elevated terrain too.
func _click_to_tile(local_pos: Vector2, screen_size: Vector2) -> Vector2i:
	if screen_size.x <= 0.0 or screen_size.y <= 0.0:
		return Vector2i(-1, -1)
	var ndc := Vector2(local_pos.x / screen_size.x, local_pos.y / screen_size.y) * 2.0 - Vector2.ONE
	var cam := _camera.global_transform
	var half_h := _camera.size * 0.5
	var half_w := half_h * (screen_size.x / screen_size.y)
	var origin := cam.origin + cam.basis.x * (ndc.x * half_w) + cam.basis.y * (-ndc.y * half_h)
	var fwd := -cam.basis.z
	if absf(fwd.y) < 0.00001:
		return Vector2i(-1, -1)
	# March the ray down through the terrain; stop at the first tile whose top
	# surface (elevation + 0.5) the ray drops to or below.
	var step := 0.15
	var p := origin
	for _i in 1200:
		p += fwd * step
		var tx := roundi(p.x / cell_size)
		var tz := roundi(p.z / cell_size)
		if tx >= 0 and tx < grid_size and tz >= 0 and tz < grid_size:
			if p.y <= get_elevation(tx, tz) + 0.5:
				return Vector2i(tx, tz)
		if p.y < -5.0:
			break
	return Vector2i(-1, -1)

## BFS over walkable tiles. Returns the list of tiles from the first step to the
## goal (cardinal-adjacent), or [] if unreachable.
func find_path(start: Vector2i, goal: Vector2i) -> Array:
	if start == goal:
		return []
	_ensure_obstacles()
	if not _path_walkable(goal):
		return []
	var came := {start: start}
	var queue: Array[Vector2i] = [start]
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var found := false
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		if cur == goal:
			found = true
			break
		for d in dirs:
			var n: Vector2i = cur + d
			if came.has(n) or not _path_walkable(n):
				continue
			came[n] = cur
			queue.append(n)
	if not found:
		return []
	var path: Array = []
	var c := goal
	while c != start:
		path.push_front(c)
		c = came[c]
	return path

func _path_walkable(tile: Vector2i) -> bool:
	if tile.x < 0 or tile.x >= grid_size or tile.y < 0 or tile.y >= grid_size:
		return false
	if _blocks.has(tile):
		return false
	for ball in _balls:
		if ball["resting"] and ball["tile"] == tile:
			return false
	return not _obstacle.has(tile)

## Cache which tiles are blocked by static geometry (house walls, map features),
## once, using the cat's own collision so it matches what blocks movement.
func _ensure_obstacles() -> void:
	if _obstacle_built:
		return
	if _player == null or not _player.has_method("is_tile_blocked"):
		_obstacle_built = true
		return
	if get_world_3d().direct_space_state == null:
		return                                # physics not ready yet — retry next click
	_obstacle_built = true
	for x in grid_size:
		for z in grid_size:
			if _player.is_tile_blocked(Vector2i(x, z)):
				_obstacle[Vector2i(x, z)] = true

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
	# Crate-triggered goal (only where there's a crate), and a ball-triggered one.
	if not block_tiles.is_empty():
		_add_goal("res://models/goal_tile.glb", "res://models/goal_tile_triggered.glb", "crate")
	if not ball_tiles.is_empty():
		_add_goal("res://models/goal_tile_b.glb", "res://models/goal_tile_b_triggered.glb", "ball")

func _add_goal(unt_path: String, tri_path: String, by: String) -> void:
	var unt: PackedScene = load(unt_path)
	var tri: PackedScene = load(tri_path)
	if unt == null or tri == null:
		push_warning("World: goal glb(s) missing for " + by)
		return
	var a0 := _measure_aabb_y(unt)
	var a1 := _measure_aabb_y(tri)
	var goal := {
		"tile": _pick_goal_tile(), "untriggered": unt, "triggered": tri,
		"bottom": a0.x, "tri_bottom": a1.x,
		"h_unt": a0.y - a0.x, "h_tri": a1.y - a1.x,
		"node": null, "won": false, "by": by, "pad_extra": 0.0,
	}
	_goals.append(goal)
	_place_goal(goal, false)

## A random tile not used by the player, crates, balls, or an existing goal.
func _pick_goal_tile() -> Vector2i:
	var rng := RandomNumberGenerator.new()
	rng.seed = terrain_seed + 7
	var player_tile := Vector2i(10, 10)
	if _player:
		player_tile = Vector2i(roundi(_player.global_position.x / cell_size), roundi(_player.global_position.z / cell_size))
	for _i in 200:
		var t := Vector2i(rng.randi_range(0, grid_size - 1), rng.randi_range(0, grid_size - 1))
		if t == player_tile or t in block_tiles or t in ball_tiles:
			continue
		var clash := false
		for g in _goals:
			if g["tile"] == t:
				clash = true
				break
		if not clash:
			return t
	return Vector2i(0, 0)

func _place_goal(goal: Dictionary, triggered: bool) -> void:
	if goal["node"]:
		(goal["node"] as Node3D).queue_free()
	var scene: PackedScene = goal["triggered"] if triggered else goal["untriggered"]
	var node := scene.instantiate() as Node3D
	var tile: Vector2i = goal["tile"]
	# Raw terrain height (not get_elevation, which adds the pad) so the pad rests
	# on the ground rather than floating on its own height.
	var surface := float(_heights[tile.x][tile.y]) + 0.5
	var bottom: float = goal["tri_bottom"] if triggered else goal["bottom"]
	node.position = Vector3(tile.x * cell_size, surface - bottom, tile.y * cell_size)
	_grid_root.add_child(node)
	goal["node"] = node
	# Things standing on the tile ride on top of the pad at its current height.
	goal["pad_extra"] = goal["h_tri"] if triggered else goal["h_unt"]

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

## Toggle each goal by how much its triggering object (crate or ball) covers it.
## Triggers at ~40% coverage, releases below 30% (hysteresis avoids flicker).
func _update_goal() -> void:
	for goal in _goals:
		if goal["node"] == null:
			continue
		var tile: Vector2i = goal["tile"]
		var gx := tile.x * cell_size
		var gz := tile.y * cell_size
		var best := 0.0
		if goal["by"] == "ball":
			for ball in _balls:
				var n: Node3D = ball["node"]
				best = maxf(best, clampf(1.0 - Vector2(n.position.x - gx, n.position.z - gz).length() / cell_size, 0.0, 1.0))
		else:
			for bt in _blocks:
				var b: Node3D = _blocks[bt]
				best = maxf(best, clampf(1.0 - Vector2(b.position.x - gx, b.position.z - gz).length() / cell_size, 0.0, 1.0))
		if not goal["won"] and best >= 0.4:
			goal["won"] = true
			_place_goal(goal, true)
		elif goal["won"] and best < 0.3:
			goal["won"] = false
			_place_goal(goal, false)

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
