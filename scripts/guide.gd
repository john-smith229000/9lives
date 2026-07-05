extends Node
## A scripted follow-up for a placed, talkable NPC. Sequence:
##   1. First conversation with the sibling "Talk" Interactable -> highlight a crate.
##   2. Player pushes that crate -> the NPC walks to the ball goal tile and its
##      dialogue switches to `lines_after` (the goal tip).
##
## Add as a child of an npc.tscn instance that also has a "Talk" Interactable child.

## Seconds to wait after the crate is pushed before the NPC walks off.
@export var walk_delay: float = 2.5
## Arrow indicator shown over the NPC after the ball is pushed.
@export var arrow_path: String = "res://models/arrow.glb"
@export var arrow_delay: float = 1.0        # wait before the arrow appears
@export var arrow_height: float = 1.8       # local Y above the NPC's origin
@export var arrow_scale: float = 1.0
@export var arrow_bob_amp: float = 0.15     # bob distance (metres)
@export var arrow_bob_speed: float = 3.0

var _world: Node
var _npc: Node                       # the NPC (parent, runs npc.gd)
var _talk: Interactable
var _arrow: Node3D
var _bob_t: float = 0.0

func _ready() -> void:
	_npc = get_parent()
	_world = _find_world()
	if _npc:
		_talk = _npc.get_node_or_null("Talk")
	if _talk:
		_talk.talked.connect(_on_first_talk)
	if _world:
		_world.connect("ball_pushed", Callable(self, "_on_ball_pushed"), CONNECT_ONE_SHOT)

func _process(delta: float) -> void:
	if _arrow:
		_bob_t += delta
		_arrow.position.y = arrow_height + sin(_bob_t * arrow_bob_speed) * arrow_bob_amp

## Ball pushed: float an arrow over the NPC until the player talks to it again.
func _on_ball_pushed() -> void:
	if _npc == null or _arrow != null:
		return
	await get_tree().create_timer(arrow_delay).timeout
	if _npc == null or _arrow != null:
		return
	var scene := load(arrow_path) as PackedScene
	if scene == null:
		return
	_arrow = scene.instantiate() as Node3D
	_npc.add_child(_arrow)
	_arrow.position = Vector3(0.0, arrow_height, 0.0)
	_arrow.scale = Vector3(arrow_scale, arrow_scale, arrow_scale)
	_bob_t = 0.0
	if _talk:
		_talk.connect("conversation_ended", Callable(self, "_remove_arrow"), CONNECT_ONE_SHOT)

func _remove_arrow() -> void:
	if _arrow:
		_arrow.queue_free()
		_arrow = null

## Walk up the tree to the World (the node that knows the goals).
func _find_world() -> Node:
	var n := get_parent()
	while n != null:
		if n.has_method("ball_goal_tile"):
			return n
		n = n.get_parent()
	return null

## First talk: spotlight a crate and wait for the player to push it.
func _on_first_talk() -> void:
	if _world == null:
		return
	_world.highlight_hint_crate()
	_world.connect("hint_crate_pushed", Callable(self, "_on_crate_pushed"), CONNECT_ONE_SHOT)

## Crate pushed: wait a beat, then switch the villager's dialogue to the goal tip
## and walk over.
func _on_crate_pushed() -> void:
	await get_tree().create_timer(walk_delay).timeout
	if _talk:
		_talk.use_after_lines()
	_walk_to_ball_goal()

func _walk_to_ball_goal() -> void:
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
