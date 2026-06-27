extends CharacterBody3D
## Grid-step (puzzle-style) player movement with smooth easing.
## The cat always lands on whole tiles, but motion eases in from rest,
## glides at a constant speed across tiles while a key is held (no per-tile
## stop), and eases out to a clean stop when the key is released.
##
## Key mapping (Project Settings > Input Map):
##   move_up    -> -Z     move_down  -> +Z
##   move_left  -> -X     move_right -> +X
## With the 45-degree iso camera these read as the four diagonal tile edges.

## Set by World after the grid is built so the player can't walk off the edge.
@export var grid_size: int = 20
@export var cell_size: float = 1.0
## World Y the player's origin rides at (block top 0.5 + capsule half-height 0.5).
@export var ground_y: float = 1.0
## Top gliding speed in tiles per second.
@export var move_speed: float = 3.0
## How quickly speed ramps up/down. Higher = snappier ease in/out.
@export var acceleration: float = 45.0
## Seconds to turn the model toward a new travel direction.
@export var turn_time: float = 0.08
## Walk animation playback speed multiplier (tune so feet don't slide).
@export var walk_anim_speed: float = 2.0

var _grid: Vector2i           # tile we last fully occupied
var _target_tile: Vector2i    # tile we're currently gliding toward
var _moving := false
var _speed := 0.0             # current scalar speed (units/sec)
var _facing := Vector2i.ZERO  # last direction the model was turned to
var _model: Node3D
var _anim: AnimationPlayer
var _walk_name := ""    # seamless looping copy, played while moving
var _rest_name := ""    # original clip; frame 0 is the rest pose for idle
var _walking := false

## Set by World: returns a tile's elevation (meters). Lets the cat ride terrain.
var height_provider: Callable

func _ready() -> void:
	_model = $Model
	_setup_animation()
	sync_to_grid()

## Recompute the current tile from world X/Z and snap onto the terrain. Called
## again by World once the height provider is wired up.
func sync_to_grid() -> void:
	_grid = _world_to_tile(global_position)
	_target_tile = _grid
	global_position = _tile_to_world(_grid)

func _setup_animation() -> void:
	# Find the AnimationPlayer anywhere under the cat model (its exact path /
	# node name depends on how the .glb was imported).
	_anim = _find_anim_player(self)
	if _anim == null:
		push_warning("Player: no AnimationPlayer found under the cat model.")
		return
	_anim.speed_scale = walk_anim_speed
	# Find the walk clip. Match a name containing "walk"; if there's only one
	# clip, just use it.
	var clips := _anim.get_animation_list()
	var base_name := ""
	for n in clips:
		if n.to_lower().contains("walk"):
			base_name = n
			break
	if base_name == "" and clips.size() == 1:
		base_name = clips[0]
	if base_name == "":
		push_warning("Player: walk clip not found. Available: %s" % str(clips))
		return
	# Keep the original clip untouched for the idle/rest pose (its frame 0).
	_rest_name = base_name
	_walk_name = base_name
	# Build a SEPARATE seamless looping copy for walking by cropping the duplicate
	# bookend frames (rest pose at frame 0 + the end frame that copies frame 1).
	# Done on a duplicate so the rest pose stays available on the original clip.
	var original := _anim.get_animation(base_name)
	if original:
		var loop_clip: Animation = original.duplicate(true)
		_make_seamless_loop(loop_clip)
		var lib := _anim.get_animation_library("")
		if lib == null:
			lib = AnimationLibrary.new()
			_anim.add_animation_library("", lib)
		if lib.has_animation("walk_loop"):
			lib.remove_animation("walk_loop")
		lib.add_animation("walk_loop", loop_clip)
		_walk_name = "walk_loop"
	# Start idle on the rest pose.
	_anim.play(_rest_name)
	_anim.seek(0.0, true)
	_anim.pause()

func _make_seamless_loop(clip: Animation) -> void:
	var length := clip.length
	var step := _detect_frame_step(clip)
	if step <= 0.0:
		clip.loop_mode = Animation.LOOP_LINEAR
		return
	var eps := step * 0.5
	for ti in range(clip.get_track_count()):
		var kc := clip.track_get_key_count(ti)
		if kc <= 2:
			continue  # static track: leave constant, it can't jitter
		# Remove the first frame (rest-pose duplicate) and the final frame
		# (copy of the first cycle frame). Iterate high->low so indices stay valid.
		for ki in range(kc - 1, -1, -1):
			var t := clip.track_get_key_time(ti, ki)
			if t <= eps or t >= length - eps:
				clip.track_remove_key(ti, ki)
		# Shift the remaining keys earlier by one frame so the cycle starts at t=0.
		var remaining := clip.track_get_key_count(ti)
		for ki in range(remaining):
			var nt: float = clip.track_get_key_time(ti, ki) - step
			clip.track_set_key_time(ti, ki, maxf(nt, 0.0))
	# One extra frame of length lets the last frame interpolate cleanly back to
	# the first on wrap.
	clip.length = length - step
	clip.loop_mode = Animation.LOOP_LINEAR

func _detect_frame_step(clip: Animation) -> float:
	# Frame spacing isn't assumed to be 1/60 (Godot may resample on import), so
	# derive it from the most densely keyed track.
	var dense_track := -1
	var dense_count := 2
	for ti in range(clip.get_track_count()):
		var kc := clip.track_get_key_count(ti)
		if kc > dense_count:
			dense_count = kc
			dense_track = ti
	if dense_track < 0:
		return 0.0
	var smallest := INF
	for ki in range(1, clip.track_get_key_count(dense_track)):
		var gap: float = clip.track_get_key_time(dense_track, ki) - clip.track_get_key_time(dense_track, ki - 1)
		if gap > 0.0 and gap < smallest:
			smallest = gap
	return 0.0 if smallest == INF else smallest

func _find_anim_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for c in node.get_children():
		var found := _find_anim_player(c)
		if found:
			return found
	return null

func _process(delta: float) -> void:
	var dir := _read_dir()
	if not _moving and dir != Vector2i.ZERO:
		_begin_segment(dir)
	if _moving:
		_advance(delta, dir)
	_set_walking(_moving)

func _set_walking(walking: bool) -> void:
	if _anim == null or _walk_name == "" or walking == _walking:
		return
	_walking = walking
	if walking:
		_anim.play(_walk_name)   # seamless looping walk copy
	else:
		# Settle on the rest pose (frame 0 of the original clip) while idle,
		# and level the body back to horizontal.
		_anim.play(_rest_name)
		_anim.seek(0.0, true)
		_anim.pause()
		_level_out()

func _read_dir() -> Vector2i:
	if Input.is_action_pressed("move_up"):
		return Vector2i(0, -1)
	if Input.is_action_pressed("move_down"):
		return Vector2i(0, 1)
	if Input.is_action_pressed("move_left"):
		return Vector2i(-1, 0)
	if Input.is_action_pressed("move_right"):
		return Vector2i(1, 0)
	return Vector2i.ZERO

func _begin_segment(dir: Vector2i) -> void:
	var t := _grid + dir
	if not _in_bounds(t):
		return            # wall ahead: don't start a step
	_target_tile = t
	_moving = true
	_orient(dir, _elevation(t) - _elevation(_grid))

func _advance(delta: float, dir: Vector2i) -> void:
	var target_world := _tile_to_world(_target_tile)
	var remaining := global_position.distance_to(target_world)
	# Keep gliding past this tile (no stop) only if a key is held AND the next
	# tile in that direction is on the board.
	var chain := dir != Vector2i.ZERO and _in_bounds(_target_tile + dir)
	var desired_speed: float
	if chain:
		desired_speed = move_speed
	else:
		# Cap speed so we coast to ~0 right at the target tile (ease-out).
		desired_speed = minf(move_speed, sqrt(2.0 * acceleration * maxf(remaining, 0.0)))
	_speed = move_toward(_speed, desired_speed, acceleration * delta)

	var step := _speed * delta
	if step >= remaining:
		var leftover := step - remaining
		_grid = _target_tile
		global_position = target_world
		if chain:
			_begin_segment(dir)
			if _moving and leftover > 0.0:
				global_position = global_position.move_toward(_tile_to_world(_target_tile), leftover)
		else:
			_moving = false
			_speed = 0.0
	else:
		global_position = global_position.move_toward(target_world, step)

func _orient(dir: Vector2i, delta_e: float) -> void:
	if _model == null or dir == Vector2i.ZERO:
		return
	# Yaw: turn to face travel direction (model front is -Z). Only re-tween when
	# the direction actually changes.
	if dir != _facing:
		_facing = dir
		var d := Vector3(dir.x, 0.0, dir.y)
		var target_yaw := atan2(-d.x, -d.z)
		var ty := create_tween()
		ty.tween_property(_model, "rotation:y", target_yaw, turn_time)
	# Pitch: tilt the body to match the slope of the upcoming step (nose up when
	# climbing, down when descending).
	var target_pitch := atan2(delta_e, cell_size)
	var tp := create_tween()
	tp.tween_property(_model, "rotation:x", target_pitch, turn_time)

func _level_out() -> void:
	# Return the body to horizontal when standing still.
	if _model == null:
		return
	var t := create_tween()
	t.tween_property(_model, "rotation:x", 0.0, turn_time)

func _in_bounds(t: Vector2i) -> bool:
	return t.x >= 0 and t.x < grid_size and t.y >= 0 and t.y < grid_size

func _world_to_tile(pos: Vector3) -> Vector2i:
	return Vector2i(roundi(pos.x / cell_size), roundi(pos.z / cell_size))

func _tile_to_world(t: Vector2i) -> Vector3:
	return Vector3(t.x * cell_size, ground_y + _elevation(t), t.y * cell_size)

func _elevation(t: Vector2i) -> float:
	if height_provider.is_valid():
		return height_provider.call(t.x, t.y)
	return 0.0
