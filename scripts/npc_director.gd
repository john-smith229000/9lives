extends Node
class_name NpcDirector
## Spawns one roaming background NPC and provides its navigation: the set of tiles
## it may stand on plus BFS pathfinding between them. Created at runtime by World
## when npc_enabled is on. Queries World for the static-obstacle map and does its
## own floor raycasts. The NPC calls back here for `npc_random_tile` / `npc_find_path`.

const _NPC_SCENE: PackedScene = preload("res://scenes/npc.tscn")

var _world: Node
var _grid := 20
var _cell := 1.0
var _ground_y := 1.0
var _speed := 1.6
var _walk_set: Dictionary = {}          # Vector2i -> true, tiles the NPC may stand on
var _walk_list: Array[Vector2i] = []    # same tiles, for random picks
var _spawned := false
var _npc_node: Node3D                    # the roaming NPC instance, once spawned

func setup(world: Node, grid_size: int, cell_size: float, ground_y: float, speed: float) -> void:
	_world = world
	_grid = grid_size
	_cell = cell_size
	_ground_y = ground_y
	_speed = speed

## Spawn is deferred until physics is ready (obstacle probe + floor rays need the
## space state) and the World's obstacle map is built, so we poll each frame.
func _process(_delta: float) -> void:
	if _spawned or _world == null:
		return
	if get_viewport().find_world_3d().direct_space_state == null:
		return                                # physics not ready — retry next frame
	if not _world.ensure_obstacle_map():
		return
	_build_walkable()
	if _walk_list.is_empty():
		_spawned = true                       # nowhere to walk; don't retry
		push_warning("NpcDirector: no walkable tiles found for the NPC.")
		return
	var start: Vector2i = _walk_list[randi() % _walk_list.size()]
	var npc := _NPC_SCENE.instantiate()
	add_child(npc)
	npc.setup_roam(self, start, _cell, _ground_y, _speed)
	_npc_node = npc
	_spawned = true

## The tile the roaming NPC currently occupies (nearest tile to its position), or
## (-1, -1) before it spawns. Used by World to keep the player off its tile.
func npc_tile() -> Vector2i:
	if _npc_node == null:
		return Vector2i(-1, -1)
	var p := _npc_node.global_position
	return Vector2i(roundi(p.x / _cell), roundi(p.z / _cell))

## A tile the NPC may stand on: not a static obstacle (building/wall) AND with
## floor beneath it (so it never wanders onto an off-map edge).
func _walkable(tile: Vector2i) -> bool:
	if tile.x < 0 or tile.x >= _grid or tile.y < 0 or tile.y >= _grid:
		return false
	if _world.is_map_obstacle(tile):
		return false
	var space := get_viewport().find_world_3d().direct_space_state
	if space == null:
		return false
	var w := Vector3(tile.x * _cell, 0.0, tile.y * _cell)
	var params := PhysicsRayQueryParameters3D.create(
		Vector3(w.x, _ground_y + 5.0, w.z), Vector3(w.x, _ground_y - 2.0, w.z))
	return not space.intersect_ray(params).is_empty()

## Build the set/list of tiles the NPC may stand on (once), so roaming and its
## pathfinding are cheap lookups instead of per-tile raycasts.
func _build_walkable() -> void:
	_walk_set.clear()
	_walk_list.clear()
	for x in _grid:
		for z in _grid:
			var t := Vector2i(x, z)
			if _walkable(t):
				_walk_set[t] = true
				_walk_list.append(t)

## A random tile the NPC can stand on (for picking roam destinations).
func npc_random_tile() -> Vector2i:
	if _walk_list.is_empty():
		return Vector2i(-1, -1)
	return _walk_list[randi() % _walk_list.size()]

## Is this tile currently occupied by a crate or ball? (Dynamic, so the NPC routes
## around them and stops if one is pushed into its path.)
func is_blocked(tile: Vector2i) -> bool:
	return _world != null and _world.has_method("has_pushable") and _world.has_pushable(tile)

## BFS over NPC-walkable tiles (routes around buildings and off-map gaps).
## Returns tiles from the first step to goal (cardinal-adjacent), or [] if
## unreachable.
func npc_find_path(start: Vector2i, goal: Vector2i) -> Array:
	if start == goal or not _walk_set.has(goal) or is_blocked(goal):
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
			if came.has(n) or not _walk_set.has(n) or is_blocked(n):
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
