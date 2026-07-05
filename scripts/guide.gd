extends Node
## A scripted follow-up for a placed, talkable NPC. After the first conversation
## with the sibling Interactable ("Talk"), it walks the NPC (its parent) to the
## ball goal tile. The Interactable's `lines_after` then takes over, so the next
## conversation explains the goal.
##
## Add as a child of an npc.tscn instance that also has a "Talk" Interactable child.

var _world: Node
var _npc: Node                       # the NPC (parent, runs npc.gd)
var _talk: Interactable

func _ready() -> void:
	_npc = get_parent()
	_world = _find_world()
	if _npc:
		_talk = _npc.get_node_or_null("Talk")
	if _talk:
		_talk.talked.connect(_on_first_talk)

## Walk up the tree to the World (the node that knows the goals).
func _find_world() -> Node:
	var n := get_parent()
	while n != null:
		if n.has_method("ball_goal_tile"):
			return n
		n = n.get_parent()
	return null

func _on_first_talk() -> void:
	if _world == null or _npc == null:
		return
	var goal: Vector2i = _world.ball_goal_tile()
	if goal.x < 0:
		return
	var cell: float = _world.cell_size
	var start := Vector2i(roundi(_npc.global_position.x / cell), roundi(_npc.global_position.z / cell))
	# Stand NEXT TO the pad, not on it: walk to the walkable neighbour nearest the
	# villager (keeps the approach short and straight).
	var dest := _approach_tile(start, goal)
	if dest.x < 0:
		return
	var path: Array = _world.find_path_min_turns(start, dest)
	if path.is_empty():
		return
	var world := _world
	var height_fn := func(t: Vector2i) -> float:
		return world.get_elevation(t.x, t.y) + world.ground_y
	_npc.go_to(path, cell, _world.ground_y, 1.6, height_fn)

## The walkable tile adjacent to `goal` that's closest to `start` (Manhattan), or
## (-1, -1) if none is reachable.
func _approach_tile(start: Vector2i, goal: Vector2i) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := 1 << 30
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var n: Vector2i = goal + d
		if n == start:
			return start           # already adjacent — no need to move
		if not _world.path_walkable(n):
			continue
		var dist: int = abs(n.x - start.x) + abs(n.y - start.y)
		if dist < best_d:
			best_d = dist
			best = n
	return best
