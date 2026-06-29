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
## While pushing a block, movement and walk animation run at this fraction of normal.
@export var push_speed_scale: float = 0.6
## Pushed blocks tilt to the step slope, scaled a bit beyond the cat's own pitch.
@export var block_tilt_extra: float = 1.3
## Movement speed (m/s) when in free (interior) mode.
@export var free_speed: float = 3.5
## How far above the feet the grid wall-check probes, so a floor mesh under the
## cat isn't mistaken for a wall (only upright features block).
@export var wall_check_lift: float = 0.35

# Set by World. Lets WASD follow the camera as it rotates (Q/E) so "up" on
# screen always walks the cat up-screen, no matter which way the view faces.
var view_camera: Node = null

var _grid: Vector2i           # tile we last fully occupied
var _tile_box: BoxShape3D     # reusable probe box for the tile-overlap wall check
var _target_tile: Vector2i    # tile we're currently gliding toward
var _moving := false
var _speed := 0.0             # current scalar speed (units/sec)
var _facing := Vector2i.ZERO  # last direction the model was turned to
var _seg_from: Vector3        # world pos at the start of the current segment
var _seg_len := 0.0           # length of the current segment
var _push: Dictionary = {}    # {block, from, to} while pushing this segment
var _pushing := false         # true while a push is in progress (slows speed/anim)
var _was_pushing := false     # previous frame's push state (to detect release)
var _tilted_block: Node3D     # block currently tilted by a push, so we can level it
var _tilt_tween: Tween        # active tilt tween (killed on retilt/abort)
var _turn_tween: Tween        # active model turn/pitch tween (killed on re-turn)
var _model: Node3D
var _anim: AnimationPlayer
var _walk_name := ""    # seamless looping copy, played while moving
var _rest_name := ""    # original clip; frame 0 is the rest pose for idle
var _walking := false

# --- Click-to-move path ---
var _path: Array = []         # queued tiles to walk to (cardinal-adjacent steps)

# --- Free (interior) mode ---
const FREE_GRAVITY := 20.0
var _free_mode := false       # true while moving freely (interior, physics-based)
var _free_cam: Camera3D       # camera used to orient WASD while free
var _free_floor_y := 1.0      # min Y, so we never fall through (floor safety net)

## Set by World: returns a tile's elevation (meters). Lets the cat ride terrain.
var height_provider: Callable
## Set by World: called as can_enter(tile, dir) -> bool. Returns false if a block
## is in the way and can't be pushed; pushes the block if it can.
var block_handler: Callable

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

## Cancel any in-progress move/push and snap to the nearest tile. Used on restart
## so a half-finished push doesn't keep driving a block that was just reset.
func is_in_free_mode() -> bool:
	return _free_mode

## Teleport back to a start position and stop, leaving the house if inside.
func reset_to_start(pos: Vector3) -> void:
	if _free_mode:
		exit_free_mode()      # leave interior mode (camera reverts via controller)
	global_position = pos
	abort()

func abort() -> void:
	if _free_mode:
		return            # interior free-movement isn't part of the puzzle reset
	_moving = false
	_speed = 0.0
	_push = {}
	_pushing = false
	_was_pushing = false
	_tilted_block = null
	if _tilt_tween and _tilt_tween.is_valid():
		_tilt_tween.kill()
	sync_to_grid()

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
	if _free_mode:
		_free_move(delta)
		_update_anim_speed()
		return
	# Manual input cancels any click-to-move path.
	if _read_dir() != Vector2i.ZERO:
		_path.clear()
	var dir := _auto_dir()
	if not _moving and dir != Vector2i.ZERO:
		if not _begin_segment(dir):
			_path.clear()        # path blocked — abandon it
	if _moving:
		_advance(delta, dir)
	_set_walking(_moving)
	_update_anim_speed()

## The tile to plan a path from: where we're heading if moving, else current.
func nav_tile() -> Vector2i:
	return _target_tile if _moving else _grid

## Would the cat be blocked by static geometry on this tile? Uses a small,
## symmetric probe (same one the grid wall-check uses) so movement and
## pathfinding agree and tight gaps stay passable.
func is_tile_blocked(tile: Vector2i) -> bool:
	return _tile_blocked(tile)

const _TILE_SAMPLES := [
	Vector2(0, 0),
	Vector2(0.4, 0), Vector2(-0.4, 0), Vector2(0, 0.4), Vector2(0, -0.4),
	Vector2(0.4, 0.4), Vector2(-0.4, -0.4), Vector2(0.4, -0.4), Vector2(-0.4, 0.4),
]

func _tile_blocked(tile: Vector2i) -> bool:
	var space := get_world_3d().direct_space_state
	if space == null:
		return false
	# Cast straight down at several points across the tile. A hit well above the
	# walkable surface means a wall/feature occupies it — sampling the whole tile
	# (not just the centre) catches walls that don't sit on the tile centre.
	var w := _tile_to_world(tile)
	var surface := w.y - 0.5
	for o in _TILE_SAMPLES:
		var params := PhysicsRayQueryParameters3D.create(
			Vector3(w.x + o.x, w.y + 9.0, w.z + o.y),
			Vector3(w.x + o.x, surface - 1.0, w.z + o.y))
		params.collision_mask = collision_mask
		params.exclude = [get_rid()]
		var hit := space.intersect_ray(params)
		if not hit.is_empty() and float(hit["position"].y) > surface + wall_check_lift:
			return true
	# The rays above can slip between thin walls (e.g. a 0.16 m collision box that
	# doesn't line up with a probe point). Also overlap-test a box covering the
	# whole tile footprint, sitting just above the floor so it ignores the ground
	# but catches any upright wall the rays missed.
	if _tile_box == null:
		_tile_box = BoxShape3D.new()
		_tile_box.size = Vector3(cell_size * 0.9, 0.4, cell_size * 0.9)
	var sp := PhysicsShapeQueryParameters3D.new()
	sp.shape = _tile_box
	sp.transform = Transform3D(Basis(), Vector3(w.x, surface + wall_check_lift + 0.2, w.z))
	sp.collision_mask = collision_mask
	sp.exclude = [get_rid()]
	return not space.intersect_shape(sp, 1).is_empty()

## Follow this list of tiles (each step cardinal-adjacent). Manual input cancels.
func set_path(path: Array) -> void:
	_path = path.duplicate()

## Current desired direction: manual key, else toward the next path tile.
func _auto_dir() -> Vector2i:
	var manual := _read_dir()
	if manual != Vector2i.ZERO:
		return manual
	while not _path.is_empty() and _path[0] == _grid:
		_path.remove_at(0)
	if _path.is_empty():
		return Vector2i.ZERO
	return _step_dir(_grid, _path[0])

func _step_dir(a: Vector2i, b: Vector2i) -> Vector2i:
	return Vector2i(signi(b.x - a.x), signi(b.y - a.y))

## Direction of the step that would follow the current target tile (for deciding
## whether to keep speed up). ZERO if nothing follows (ease to a stop).
func _lookahead_dir() -> Vector2i:
	var manual := _read_dir()
	if manual != Vector2i.ZERO:
		return manual          # held key continues in the same direction
	if _path.size() >= 2:      # _path[0] is the current target, _path[1] is next
		return _step_dir(_path[0], _path[1])
	return Vector2i.ZERO

# --- Free (interior) mode ---------------------------------------------------

## Switch to free, physics-based, camera-relative movement (interior). The cat
## collides with the house mesh via move_and_slide. Entering/leaving is handled
## by the house's doorway trigger, not here.
func enter_free_mode(cam: Camera3D) -> void:
	_free_cam = cam
	_free_floor_y = global_position.y   # never fall below where we entered
	_free_mode = true
	_moving = false
	_speed = 0.0
	_push = {}
	velocity = Vector3.ZERO
	if _model:
		_model.rotation.x = 0.0   # clear any leftover climbing pitch

func exit_free_mode() -> void:
	_free_mode = false
	_free_cam = null
	velocity = Vector3.ZERO
	sync_to_grid()

func _free_move(delta: float) -> void:
	# Camera-relative input: W = into the screen, S = toward camera, A/D strafe.
	var fwd_amt := Input.get_action_strength("move_up") - Input.get_action_strength("move_down")
	var side_amt := Input.get_action_strength("move_right") - Input.get_action_strength("move_left")

	var dir := Vector3.ZERO
	if _free_cam:
		var cam_basis := _free_cam.global_transform.basis
		var fwd := -cam_basis.z; fwd.y = 0.0
		var right := cam_basis.x; right.y = 0.0
		dir = fwd.normalized() * fwd_amt + right.normalized() * side_amt
	dir.y = 0.0
	var moving := dir.length() > 0.01
	if moving:
		dir = dir.normalized()

	# Horizontal velocity from input; gravity settles us onto the floor and
	# move_and_slide makes us collide/slide along the house walls.
	velocity.x = dir.x * free_speed
	velocity.z = dir.z * free_speed
	velocity.y -= FREE_GRAVITY * delta
	move_and_slide()

	# Safety net: if the house mesh has no floor collision, don't fall through.
	if global_position.y < _free_floor_y:
		global_position.y = _free_floor_y
		velocity.y = 0.0

	if moving:
		var target_yaw := atan2(-dir.x, -dir.z)
		_model.rotation.y = lerp_angle(_model.rotation.y, target_yaw, 1.0 - exp(-12.0 * delta))
	_moving = moving
	_set_walking(moving)

func _update_anim_speed() -> void:
	_pushing = _moving and not _push.is_empty()
	# When a push ends, level the block back out.
	if _was_pushing and not _pushing:
		_level_block()
	_was_pushing = _pushing
	if _anim:
		var want := walk_anim_speed * (push_speed_scale if _pushing else 1.0)
		if not is_equal_approx(_anim.speed_scale, want):
			_anim.speed_scale = want

## Tilt the pushed block to match the upcoming step's slope (a touch past the
## cat's own pitch for a heavier feel).
func _tilt_block(dir: Vector2i) -> void:
	if _push.is_empty():
		return
	var block: Node3D = _push["block"]
	_tilted_block = block
	var de := (_push["to"] as Vector3).y - (_push["from"] as Vector3).y
	var pitch := atan2(de, cell_size) * block_tilt_extra
	# Tilt about the axis perpendicular to travel so the leading edge follows the slope.
	var rot := Vector3.ZERO
	if dir.x != 0:
		rot.z = dir.x * pitch
	else:
		rot.x = -dir.y * pitch
	_start_tilt_tween(block, rot)

func _level_block() -> void:
	if _tilted_block:
		_start_tilt_tween(_tilted_block, Vector3.ZERO)
		_tilted_block = null

func _start_tilt_tween(block: Node3D, target: Vector3) -> void:
	if _tilt_tween and _tilt_tween.is_valid():
		_tilt_tween.kill()
	_tilt_tween = create_tween()
	_tilt_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_tilt_tween.tween_property(block, "rotation", target, turn_time)

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
	var base := Vector2i.ZERO
	if Input.is_action_pressed("move_up"):
		base = Vector2i(0, -1)
	elif Input.is_action_pressed("move_down"):
		base = Vector2i(0, 1)
	elif Input.is_action_pressed("move_left"):
		base = Vector2i(-1, 0)
	elif Input.is_action_pressed("move_right"):
		base = Vector2i(1, 0)
	if base == Vector2i.ZERO:
		return base
	# Spin the key direction by however many 90° steps the camera is rotated, so
	# the controls stay locked to the screen rather than the world axes.
	return _rotate_dir(base, _cam_quadrant())

## Current camera rotation in 90° steps (0..3); 0 if no camera is wired.
func _cam_quadrant() -> int:
	if view_camera and view_camera.has_method("get_quadrant"):
		return view_camera.get_quadrant()
	return 0

## Rotate a grid direction by q quarter-turns about the vertical axis, matching
## the camera's yaw so movement reads correctly after Q/E rotation.
func _rotate_dir(v: Vector2i, q: int) -> Vector2i:
	var r := v
	for _i in range(((q % 4) + 4) % 4):
		r = Vector2i(r.y, -r.x)
	return r

func _begin_segment(dir: Vector2i) -> bool:
	_push = {}
	var t := _grid + dir
	if not _in_bounds(t):
		return false           # edge of board: don't move
	# Don't let grid steps phase through solid colliders (house walls, map
	# features). Uses the same symmetric probe as the pathfinder so they agree.
	if _tile_blocked(t):
		return false
	# Ask World whether the tile is enterable. Returns: false = blocked,
	# true = free, or {block, from, to} when a block is being pushed.
	if block_handler.is_valid():
		var res: Variant = block_handler.call(t, dir)
		if res is Dictionary:
			_push = res        # we'll drive this block in lockstep
		elif res is bool and not res:
			return false       # unpushable block in the way
	_seg_from = global_position
	_target_tile = t
	_seg_len = _seg_from.distance_to(_tile_to_world(t))
	_moving = true
	_orient(dir, _elevation(t) - _elevation(_grid))
	_tilt_block(dir)   # tilt the pushed block (if any) to the step slope
	return true

func _advance(delta: float, _dir: Vector2i) -> void:
	var target_world := _tile_to_world(_target_tile)
	var remaining := global_position.distance_to(target_world)
	# Pushing a block slows everything down.
	var top_speed := move_speed * (push_speed_scale if not _push.is_empty() else 1.0)
	# Keep gliding past this tile (no stop) only if there's a valid next step
	# (held key continuing, or another path tile). Otherwise ease to a stop.
	var look := _lookahead_dir()
	var chain := look != Vector2i.ZERO and _in_bounds(_target_tile + look)
	var desired_speed: float
	if chain:
		desired_speed = top_speed
	else:
		# Cap speed so we coast to ~0 right at the target tile (ease-out).
		desired_speed = minf(top_speed, sqrt(2.0 * acceleration * maxf(remaining, 0.0)))
	_speed = move_toward(_speed, desired_speed, acceleration * delta)

	var step := _speed * delta
	if step >= remaining:
		var leftover := step - remaining
		_grid = _target_tile
		global_position = target_world
		_drive_block(1.0)          # snap pushed block to its destination
		# Re-aim from the (now updated) tile — handles path corners and key changes.
		var nd := _auto_dir()
		if chain and nd != Vector2i.ZERO and _begin_segment(nd):
			if leftover > 0.0:
				global_position = global_position.move_toward(_tile_to_world(_target_tile), leftover)
		else:
			_moving = false
			_speed = 0.0
	else:
		global_position = global_position.move_toward(target_world, step)
		var prog := 1.0 - global_position.distance_to(target_world) / _seg_len if _seg_len > 0.0 else 1.0
		_drive_block(clampf(prog, 0.0, 1.0))

## Slide the block being pushed in lockstep with the player's progress (0..1).
func _drive_block(progress: float) -> void:
	if _push.is_empty():
		return
	var block: Node3D = _push["block"]
	# Drive only X/Z; World sets the crate's Y so it rides the surface/goal pad.
	var p := (_push["from"] as Vector3).lerp(_push["to"] as Vector3, progress)
	block.position.x = p.x
	block.position.z = p.z

func _orient(dir: Vector2i, delta_e: float) -> void:
	if _model == null or dir == Vector2i.ZERO:
		return
	# Kill any in-flight turn so two tweens can't fight (the "double turn" glitch).
	if _turn_tween and _turn_tween.is_valid():
		_turn_tween.kill()
	_turn_tween = create_tween().set_parallel(true)
	# Yaw: face travel direction (model front is -Z), taking the SHORTEST path so
	# it never spins the long way around the circle.
	if dir != _facing:
		_facing = dir
		var d := Vector3(dir.x, 0.0, dir.y)
		var target_yaw := atan2(-d.x, -d.z)
		target_yaw = _model.rotation.y + wrapf(target_yaw - _model.rotation.y, -PI, PI)
		_turn_tween.tween_property(_model, "rotation:y", target_yaw, turn_time)
	# Pitch: tilt the body to match the step slope (nose up climbing, down descending).
	var target_pitch := atan2(delta_e, cell_size)
	_turn_tween.tween_property(_model, "rotation:x", target_pitch, turn_time)

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
