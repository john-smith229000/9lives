extends Node3D
## Background NPC that roams the map, routing around buildings via World's grid
## pathfinding. It eases out of a standing pose (intro frames), loops the mid-
## section of the walk, and eases back to standing (outro frames) for occasional
## random pauses. It turns to face each path corner mid-stride (a smooth ease).
##
## Clip layout (authored): intro = [intro_start_frame .. loop_start_frame],
## loop = [loop_start_frame .. loop_end_frame], outro = [loop_end_frame .. end].
## The outro is only ever entered at the end of a full loop.

## Metres per second at full walk.
@export var walk_speed: float = 1.6
## Clip frames (at anim_fps). Intro rests->walk, loop is the stride, outro
## walk->rests. The loop plays between loop_start_frame and loop_end_frame.
@export var intro_start_frame: float = 0.0
@export var loop_start_frame: float = 40.0
@export var loop_end_frame: float = 129.0
@export var anim_fps: float = 60.0
## Added to the facing yaw. This model's front points +Z, so it needs a half
## turn (PI) to face travel; set to 0.0 if a future model already faces -Z.
@export var model_yaw_offset: float = PI
## How fast the model turns to face travel (lower = slower, smoother turns).
@export var turn_rate: float = 6.0
## Random pause length range (seconds) while standing.
@export var idle_min: float = 0.7
@export var idle_max: float = 2.6
## Chance, per completed loop, of a random pause.
@export var pause_chance: float = 0.25

enum State { IDLE, STARTING, WALKING, STOPPING }

var _world: Node                    # World, for pathfinding + random tiles
var _cell := 1.0
var _ground_y := 1.0
var _cur_tile: Vector2i             # tile most recently occupied
var _path: Array = []               # remaining tiles to the current destination
var _dir_target: Vector3            # world position of the next waypoint

var _model: Node3D
var _anim: AnimationPlayer
var _walk := ""
var _t_intro := 0.0
var _t_loop_start := 0.0
var _t_loop_end := 0.0
var _t_clip_end := 0.0
var _anim_t := 0.0                  # manual clip clock (seconds), drives seek
var _state: State = State.IDLE
var _idle_left := 0.0
var _stop_requested := false
var _height_fn: Callable             # optional: tile -> standing world Y (sloped ground)
var _level: Node                     # the World (found by walking up), for player_tile()
var _bump_cd := 0.0                  # cooldown so a bump line doesn't repeat every frame
const BUMP_COOLDOWN := 4.0

## Called by World right after instancing (after _ready): roam from start_tile.
func setup_roam(world: Node, start_tile: Vector2i, cell: float, gy: float, speed: float = -1.0) -> void:
	_world = world
	_cell = cell
	_ground_y = gy
	_cur_tile = start_tile
	global_position = _tile_world(start_tile)
	if speed > 0.0:
		walk_speed = speed
	_idle_left = randf_range(idle_min, idle_max)
	_state = State.IDLE
	_pick_destination()
	_update_target()
	# Face the first waypoint immediately (no spin-up on the opening step).
	var d := _dir_target - global_position
	if _model and Vector2(d.x, d.z).length() > 0.001:
		_model.rotation.y = atan2(-d.x, -d.z) + model_yaw_offset

func _ready() -> void:
	_model = get_node_or_null("Model")
	_anim = _find_anim_player(self)
	_t_intro = intro_start_frame / anim_fps
	_t_loop_start = loop_start_frame / anim_fps
	_t_loop_end = loop_end_frame / anim_fps
	_t_clip_end = _t_loop_end
	if _anim:
		var clips := _anim.get_animation_list()
		for n in clips:
			if n.to_lower().contains("walk"):
				_walk = n
				break
		if _walk == "" and clips.size() > 0:
			_walk = clips[0]
		if _walk != "":
			var clip := _anim.get_animation(_walk)
			if clip:
				clip.loop_mode = Animation.LOOP_NONE   # we drive the clock ourselves
				_t_clip_end = clip.length
			_anim.play(_walk)
			_anim.pause()                              # posed manually via seek()
			_anim.seek(_t_intro, true)
	_anim_t = _t_intro

func _process(delta: float) -> void:
	_bump_cd = maxf(0.0, _bump_cd - delta)
	# Stand still (and hold the pose) while a conversation is on screen.
	if Dialogue.is_active():
		if _anim and _walk != "":
			_anim.seek(_anim_t, true)
		return
	match _state:
		State.IDLE:
			_do_idle(delta)
		State.STARTING:
			_do_starting(delta)
		State.WALKING:
			_do_walking(delta)
		State.STOPPING:
			_do_stopping(delta)
	if _anim and _walk != "":
		_anim.seek(_anim_t, true)

func _do_idle(delta: float) -> void:
	_anim_t = _t_intro                                 # standing pose
	_idle_left -= delta
	if _idle_left <= 0.0:
		if _path.is_empty():
			_pick_destination()
			_update_target()
		if not _path.is_empty():
			_state = State.STARTING
			_anim_t = _t_intro

func _do_starting(delta: float) -> void:
	_anim_t += delta
	var span := _t_loop_start - _t_intro
	var prog := clampf((_anim_t - _t_intro) / span, 0.0, 1.0) if span > 0.0 else 1.0
	_face_move(_dir_target - global_position, delta)
	_move(delta, walk_speed * prog)                    # ramp up with the intro
	if _anim_t >= _t_loop_start:
		_state = State.WALKING

func _do_walking(delta: float) -> void:
	_anim_t += delta
	if _anim_t >= _t_loop_end:
		if _stop_requested:
			_state = State.STOPPING                    # continue into the outro
			return
		_anim_t = _t_loop_start + (_anim_t - _t_loop_end)   # wrap the loop
		_on_loop_complete()
	# Collision with the cat: never step onto its tile. If we're walking into it,
	# hold position, face it, and say a one-off bump line. Resume when it moves.
	if not _path.is_empty() and _is_player_tile(_path[0]):
		if _bump_cd <= 0.0 and not Dialogue.is_active():
			_bump_cd = BUMP_COOLDOWN
			_speak_bump()
		_face_move(_dir_target - global_position, delta)
		return
	# A crate or ball got pushed into the way? Drop this path and find a new route.
	if not _path.is_empty() and _world != null and _world.has_method("is_blocked") and _world.is_blocked(_path[0]):
		_path.clear()
	if _path.is_empty():
		_pick_destination()
		_update_target()
		if _path.is_empty():
			_stop_requested = true                     # nowhere to go — pause soon
			return
	if _flat_dist(_dir_target) < 0.08:
		_arrive_waypoint()
	_face_move(_dir_target - global_position, delta)
	_move(delta, walk_speed)

func _do_stopping(delta: float) -> void:
	_anim_t += delta
	var span := _t_clip_end - _t_loop_end
	var prog := clampf((_anim_t - _t_loop_end) / span, 0.0, 1.0) if span > 0.0 else 1.0
	_face_move(_dir_target - global_position, delta)
	_move(delta, walk_speed * (1.0 - prog))            # ramp down with the outro
	if _anim_t >= _t_clip_end:
		_state = State.IDLE
		_idle_left = randf_range(idle_min, idle_max)
		_stop_requested = false
		_anim_t = _t_intro

## On a completed loop (not stopping): maybe take a random pause.
func _on_loop_complete() -> void:
	if randf() < pause_chance:
		_stop_requested = true

## Arrived at the next waypoint: advance along the path, pick a new destination
## when the path runs out.
func _arrive_waypoint() -> void:
	if not _path.is_empty():
		_cur_tile = _path[0]
		_path.remove_at(0)
	if _path.is_empty():
		_pick_destination()
	_update_target()

## Choose a random reachable tile and path to it (a few tries in case a pick is
## unreachable). Leaves _path empty if none found (rare; retried later).
func _pick_destination() -> void:
	_path = []
	if _world == null:
		return
	for _i in 12:
		var goal: Vector2i = _world.npc_random_tile()
		if goal == Vector2i(-1, -1) or goal == _cur_tile:
			continue
		var p: Array = _world.npc_find_path(_cur_tile, goal)
		if not p.is_empty():
			_path = p
			return

func _update_target() -> void:
	if _path.is_empty():
		_dir_target = global_position
	else:
		_dir_target = _tile_world(_path[0])

func _tile_world(tile: Vector2i) -> Vector3:
	var y := _ground_y
	if _height_fn.is_valid():
		y = float(_height_fn.call(tile))
	return Vector3(tile.x * _cell, y, tile.y * _cell)

## Walk once along an explicit tile path (as from World.find_path), then idle.
## Used for scripted moves on placed NPCs that have no roaming director.
## `height_fn(Vector2i) -> float` (optional) gives the standing Y per tile so the
## NPC follows sloped terrain; otherwise it walks at `gy`.
func go_to(path: Array, cell: float, gy: float, speed: float, height_fn := Callable()) -> void:
	_cell = cell
	_ground_y = gy
	walk_speed = speed
	_height_fn = height_fn
	_cur_tile = Vector2i(roundi(global_position.x / _cell), roundi(global_position.z / _cell))
	_path = path.duplicate()
	_stop_requested = false
	_update_target()
	if not _path.is_empty():
		_state = State.STARTING
		_anim_t = _t_intro

func _move(delta: float, speed: float) -> void:
	if speed <= 0.0:
		return
	# Move horizontally at `speed`, and ease Y toward the waypoint's height so the
	# NPC rides sloped ground (roaming targets are flat, so this is a no-op there).
	var flat := _dir_target - global_position
	flat.y = 0.0
	var dist := flat.length()
	if dist < 0.001:
		return
	var step := minf(speed * delta, dist)
	global_position += (flat / dist) * step
	global_position.y = lerp(global_position.y, _dir_target.y, minf(1.0, step / dist))

func _face_move(dir: Vector3, delta: float) -> void:
	if _model == null:
		return
	if Vector2(dir.x, dir.z).length() < 0.001:
		return
	var target_yaw := atan2(-dir.x, -dir.z) + model_yaw_offset
	_model.rotation.y = lerp_angle(_model.rotation.y, target_yaw, 1.0 - exp(-turn_rate * delta))

func _flat_dist(p: Vector3) -> float:
	var d := p - global_position
	d.y = 0.0
	return d.length()

## The World (found by walking up the tree), which knows where the cat is. Works
## for both roaming NPCs and scripted/placed ones.
func _level_world() -> Node:
	if _level == null or not is_instance_valid(_level):
		var n := get_parent()
		while n != null:
			if n.has_method("player_tile"):
				_level = n
				break
			n = n.get_parent()
	return _level

func _is_player_tile(tile: Vector2i) -> bool:
	var w := _level_world()
	return w != null and w.player_tile() == tile

## Say this character's "bump" line (from the sibling Talk Interactable's profile).
func _speak_bump() -> void:
	var talk := get_node_or_null("Talk")
	if talk == null:
		return
	var prof = talk.get("profile")
	if prof == null:
		return
	var lines: Array = prof.expression("bump")
	if lines.is_empty():
		return
	Dialogue.start_speech(prof.display_name, lines, Callable(), prof.voice)

func _find_anim_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for c in node.get_children():
		var f := _find_anim_player(c)
		if f:
			return f
	return null
