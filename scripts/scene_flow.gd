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

## Origin tiles for movable props, captured with mark_start() so has_moved() always
## measures from the TRUE start (not from wherever a beat first happens to look).
var _start_tiles: Dictionary = {}   # instance_id -> Vector2i
## Named objectives: id -> Callable() -> bool. Each is a LIVE predicate over world /
## GameState, so it reads correctly regardless of WHEN (or whether) a beat watched it.
var _objectives: Dictionary = {}

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

## Speak story lines AS a character: the text comes from the flow, but the name and
## voice come from the character. `character` may be a CharacterProfile, an id
## String ("bob"), or a node with a `profile` (e.g. an Interactable / NPC).
func say_as(character, lines) -> void:
	var prof := _profile_of(character)
	if prof == null:
		await say("", lines)
		return
	var arr: Array = lines if lines is Array else [lines]
	if arr.is_empty():
		return
	Dialogue.start_speech(prof.display_name, arr, Callable(), prof.voice)
	await Dialogue.finished

## Play a character's own expression (a personality bark keyed by name).
func express(character, key: String) -> void:
	var prof := _profile_of(character)
	if prof == null:
		return
	await say_as(prof, prof.expression(key))

## Resolve a CharacterProfile from a profile / id string / node with `profile`.
func _profile_of(character) -> CharacterProfile:
	if character is CharacterProfile:
		return character
	if character is String or character is StringName:
		return Characters.get_profile(character)
	if character is Object:
		var p = character.get("profile")
		if p is CharacterProfile:
			return p
	return null

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
## NOTE: prefer mark_start()+has_moved() / a "moved" objective — those measure from
## the true origin and never deadlock on a push the player already performed. This
## remains for one-off waits where you truly want "from HERE".
func until_tile_changes(node: Node3D, from_tile: Vector2i) -> void:
	while is_instance_valid(node) and tile_of(node) == from_tile:
		await get_tree().process_frame

# --- Order-independent beats ----------------------------------------------
# The player can act ahead of the script (shove the crate before being asked, talk
# early, skip the ball). These helpers make a flow tolerant of that: every gate is
# "is this ALREADY done? if so skip it; else set up the affordances, wait, tear them
# down." No stale outlines, no waiting forever on something already finished.

## Record a movable prop's starting tile at scene setup, so has_moved() can always
## measure from its true origin. Returns the tile. Safe to call with null.
func mark_start(node: Node3D) -> Vector2i:
	if node == null:
		return Vector2i(-1, -1)
	var t := tile_of(node)
	_start_tiles[node.get_instance_id()] = t
	return t

## Has a marked prop left its start tile? A freed/invalid node counts as moved
## (it's gone, so whatever we were waiting on is over). Unmarked nodes read false.
func has_moved(node: Node3D) -> bool:
	if not is_instance_valid(node):
		return true
	var id := node.get_instance_id()
	if not _start_tiles.has(id):
		return false
	return tile_of(node) != _start_tiles[id]

## Register a named objective as a LIVE predicate (e.g. func(): return has_moved(crate)).
## Because it reads real state, is_done()/complete() are correct no matter the order.
func objective(id: StringName, cond: Callable) -> void:
	_objectives[id] = cond

## Is a registered objective satisfied right now?
func is_done(id: StringName) -> bool:
	var c: Callable = _objectives.get(id, Callable())
	return c.is_valid() and c.call()

## Await a registered objective (returns instantly if already done). Optionally wake
## on a signal instead of polling — e.g. complete(&"talked", talk, &"talked").
func complete(id: StringName, sig_obj: Object = null, sig: StringName = &"") -> void:
	await until_true(_objectives.get(id, Callable()), sig_obj, sig)

## Wait until `cond` returns true. Returns IMMEDIATELY if it's already true — this is
## what stops deadlocks on actions the player already did. Wakes on `sig` if given
## (cheaper than polling), otherwise checks every frame. Re-checks `cond` after each
## wake, so a one-shot signal that already fired is never required.
func until_true(cond: Callable, sig_obj: Object = null, sig: StringName = &"") -> void:
	if not cond.is_valid():
		return
	while not cond.call():
		if sig_obj != null and sig != &"":
			await Signal(sig_obj, sig)
		else:
			await get_tree().process_frame

## Run one objective "beat", doing work ONLY if it isn't already satisfied:
##   - already complete (player did it early) -> return at once. No stale outline,
##     no arrow, no wait, no deadlock.
##   - otherwise -> show the affordances you pass, wait for completion, then tear
##     every affordance back down.
## cfg keys (need one completion source; the rest are optional):
##   objective        : String id registered with objective()   (completion source)
##   done             : Callable() -> bool                        (completion source)
##   signal_obj/signal: wake on this signal instead of polling each frame
##   highlight        : Node3D to outline while waiting
##   hint             : String tip banner to show while waiting
##   arrow            : Node3D to float an attention arrow over while waiting
func beat(cfg: Dictionary) -> void:
	var cond: Callable = _cond_for(cfg)
	if cond.is_valid() and cond.call():
		return
	var node: Node3D = cfg.get("highlight")
	if node:
		highlight(node)
	var tip: String = cfg.get("hint", "")
	if tip != "":
		hint(tip)
	var arrow: Node3D = null
	var arrow_over = cfg.get("arrow")
	if arrow_over is Node3D:
		arrow = spawn_arrow(arrow_over)
	await until_true(cond, cfg.get("signal_obj"), cfg.get("signal", &""))
	if node:
		unhighlight(node)
	if tip != "":
		hide_hint()
	if arrow and is_instance_valid(arrow):
		arrow.queue_free()

## Resolve a beat()/objective's completion predicate from cfg.
func _cond_for(cfg: Dictionary) -> Callable:
	if cfg.has("done") and cfg["done"] is Callable:
		return cfg["done"]
	if cfg.has("objective"):
		return _objectives.get(cfg["objective"], Callable())
	return Callable()

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
