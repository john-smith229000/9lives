extends Node
class_name SceneFlow
## Base class for a scene's scripted "screenplay". Attach a subclass (e.g.
## scene1_flow.gd) as a child of a level's World node and override `_run()`; write
## the beats top-to-bottom with `await`. It resolves world/camera/player for you and
## gives a small awaitable API so gating on player actions ("wait until the crate is
## pushed") is a single line.
##
## Timing defaults come from the Timing autoload; pass explicit values to override a
## single beat. Run two things at once by calling a coroutine method WITHOUT await
## (it runs concurrently); await it to run in sequence.
##
## Setting up a new scene:
##   1. Make my_scene_flow.gd  ->  extends SceneFlow, override func _run().
##   2. Add it as a child of the scene's World node.
##   3. Reference scene nodes via @onready get_node; get procedural props (balls,
##      crates, goal tile) from `world` accessors.

var world: Node
var camera: Node
var player: Node

func _ready() -> void:
	world = _find_world()
	if world:
		camera = world.get_node_or_null("Camera")
		player = world.get_node_or_null("Player")
	# Deferred so the World's _ready (which spawns terrain/balls/crates/goal) has run.
	_boot.call_deferred()

func _boot() -> void:
	await get_tree().process_frame
	await _run()

## Override this in the scene's flow subclass.
func _run() -> void:
	pass

# --- Time -----------------------------------------------------------------

## Wait `seconds` (defaults to Timing.default_wait).
func wait(seconds := -1.0) -> void:
	if seconds < 0.0:
		seconds = Timing.default_wait
	await get_tree().create_timer(seconds).timeout

# --- Dialogue -------------------------------------------------------------

## Speak a line or lines and wait until the conversation closes.
func say(speaker: String, lines) -> void:
	var arr: Array = lines if lines is Array else [lines]
	if arr.is_empty():
		return
	Dialogue.start_speech(speaker, arr)
	await Dialogue.finished

## Player choice (returns the chosen index). Not implemented yet — reserved so
## flows can be written choice-first now; currently just shows the prompt.
func ask(speaker: String, prompt, _choices: Array) -> int:
	push_warning("SceneFlow.ask(): choices not implemented yet.")
	await say(speaker, prompt)
	return -1

## Non-blocking hint banner.
func hint(text: String) -> void:
	Dialogue.show_hint(text)

func hide_hint() -> void:
	Dialogue.hide_hint()

# --- Camera ---------------------------------------------------------------

func camera_focus(node: Node3D) -> void:
	if camera and camera.has_method("focus_on"):
		camera.focus_on(node)

func camera_release() -> void:
	if camera and camera.has_method("release_focus"):
		camera.release_focus()

## Cinematic beat: hold on the cat, pan to `node`, linger, pan back. Times default
## to Timing.camera_pre_hold / camera_hold.
func camera_hold(node: Node3D, pre := -1.0, hold := -1.0) -> void:
	if pre < 0.0:
		pre = Timing.camera_pre_hold
	if hold < 0.0:
		hold = Timing.camera_hold
	await wait(pre)
	camera_focus(node)
	await wait(hold)
	camera_release()

# --- Highlight ------------------------------------------------------------

func highlight(node: Node3D) -> void:
	if node:
		Outline.add(node, Timing.outline_color, Timing.outline_scale,
			Timing.outline_pulse_min, Timing.outline_pulse_period)

func unhighlight(node: Node3D) -> void:
	if node:
		Outline.remove(node)

# --- Waiting on things ----------------------------------------------------

## Await a signal by name (e.g. until(talk, "talked")).
func until(obj: Object, sig: StringName) -> void:
	if obj == null:
		return
	await Signal(obj, sig)

## The grid tile a node sits on.
func tile_of(node: Node3D) -> Vector2i:
	var cell: float = world.cell_size if world else 1.0
	var p := node.global_position
	return Vector2i(roundi(p.x / cell), roundi(p.z / cell))

## Wait until `node` leaves `from_tile` (e.g. the player pushes a crate or ball).
func until_tile_changes(node: Node3D, from_tile: Vector2i) -> void:
	while is_instance_valid(node) and tile_of(node) == from_tile:
		await get_tree().process_frame

# --- NPC movement ---------------------------------------------------------

## Walk a placed NPC to `goal_tile` (by default to the walkable tile next to it),
## following terrain, and wait until it arrives (with a safety timeout).
func move_npc(npc: Node, goal_tile: Vector2i, adjacent := true) -> void:
	if world == null or npc == null:
		return
	var cell: float = world.cell_size
	var start := tile_of(npc)
	var dest := goal_tile
	if adjacent:
		dest = _approach_tile(start, goal_tile)
		if dest.x < 0:
			return
	var path: Array = world.find_path_min_turns(start, dest)
	if path.is_empty():
		return
	var w := world
	var height_fn := func(t: Vector2i) -> float:
		return w.get_elevation(t.x, t.y) + w.ground_y
	npc.go_to(path, cell, world.ground_y, Timing.npc_walk_speed, height_fn)
	var t0 := Time.get_ticks_msec()
	while is_instance_valid(npc) and tile_of(npc) != dest and Time.get_ticks_msec() - t0 < 20000:
		await get_tree().process_frame

## The walkable tile next to `goal` that's closest to `start`, or (-1,-1) if none.
func _approach_tile(start: Vector2i, goal: Vector2i) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := 1 << 30
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var n: Vector2i = goal + d
		if n == start:
			return start
		if not world.path_walkable(n):
			continue
		var dist: int = abs(n.x - start.x) + abs(n.y - start.y)
		if dist < best_d:
			best_d = dist
			best = n
	return best

# --- Attention arrow ------------------------------------------------------

## Float a bobbing arrow over `over` (a Node3D). Returns it so you can queue_free()
## it later. The bob is a self-running tween (no per-frame code needed).
func spawn_arrow(over: Node3D, model_path := "res://models/arrow.glb") -> Node3D:
	if over == null:
		return null
	var scene := load(model_path) as PackedScene
	if scene == null:
		return null
	var arrow := scene.instantiate() as Node3D
	over.add_child(arrow)
	arrow.scale = Vector3.ONE * Timing.arrow_scale
	var y := Timing.arrow_height
	arrow.position = Vector3(0.0, y, 0.0)
	var tw := arrow.create_tween().set_loops()
	tw.tween_property(arrow, "position:y", y + Timing.arrow_bob_amp, 0.5).set_trans(Tween.TRANS_SINE)
	tw.tween_property(arrow, "position:y", y - Timing.arrow_bob_amp, 0.5).set_trans(Tween.TRANS_SINE)
	return arrow

# --- Internals ------------------------------------------------------------

func _find_world() -> Node:
	var n := get_parent()
	while n != null:
		if n.has_method("ball_goal_tile") or n.has_method("get_elevation"):
			return n
		n = n.get_parent()
	return null
