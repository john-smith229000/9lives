extends Camera3D
## Orthographic isometric follow camera.
## Holds a fixed isometric angle and smoothly trails the player so the cat
## stays centered while the grid scrolls underneath.

## The node to follow (the Player). Set in the scene or assigned by World.
@export var target_path: NodePath
## Pitch / yaw that define the isometric look. (-30, 45) is a classic 2:1 iso feel.
@export var pitch_deg: float = -30.0
@export var yaw_deg: float = 45.0
## How far back along the view direction the camera sits (orthographic, so this
## only affects clipping/position, not apparent size).
@export var distance: float = 30.0
## Orthographic zoom: smaller = more zoomed in. Roughly the vertical span in meters.
@export var ortho_size: float = 10.0
## Zoom limits (orthographic size). Smaller = closer.
@export var zoom_min: float = 4.0
@export var zoom_max: float = 16.0
## Units of orthographic size changed per mouse-wheel notch.
@export var zoom_step: float = 1.0
## Follow smoothing. 0 = instant snap, higher = snappier catch-up.
@export var follow_smooth: float = 8.0
## Smoothing used while panning to/from a spotlight target (focus_on / release).
## Lower than follow_smooth = a slower, more deliberate pan.
@export var focus_smooth: float = 1.5
## Seconds for one 90° swing when rotating (Q/E). Higher = slower, smoother turn.
@export var rotate_time: float = 0.9
## Tight near/far planes. The default range (0.05..4000) wrecks depth-buffer
## precision in orthographic mode and causes coplanar cube faces to z-fight
## (the flickering edges). Keeping the range small fixes it.
@export var near_plane: float = 1.0
@export var far_plane: float = 120.0

var _target: Node3D
## When set, the camera pans to focus this node instead of the player. Cleared to
## return to the player. Used to spotlight an object (e.g. a hint).
var _focus_target: Node3D = null
# While > 0, overrides follow_smooth for a slow pan; reset once the pan arrives.
var _pan_smooth: float = 0.0
var _offset: Vector3
# Smoothed point the camera orbits/looks at. Equals the player when standing
# still, lags a touch while it moves. We orbit THIS so the cat stays centered.
var _focus: Vector3
# How many 90° steps we've rotated from the default view. +1 per E, -1 per Q.
var _quadrant: int = 0
# Eased 90° turn: yaw lerps from _yaw_from to _yaw_to as _rot_t goes 0 -> 1.
var _cur_yaw: float = 0.0
var _yaw_from: float = 0.0
var _yaw_to: float = 0.0
var _rot_t: float = 1.0

func _ready() -> void:
	projection = PROJECTION_ORTHOGONAL
	ortho_size = clampf(ortho_size, zoom_min, zoom_max)
	size = ortho_size
	near = near_plane
	far = far_plane
	_cur_yaw = deg_to_rad(yaw_deg)
	_yaw_from = _cur_yaw
	_yaw_to = _cur_yaw
	rotation = Vector3(deg_to_rad(pitch_deg), _cur_yaw, 0.0)
	# basis.z is the camera's local +Z (pointing backward), so focus + that * distance
	# places the camera behind/above the focus point along the view axis.
	_offset = global_transform.basis.z * distance
	if target_path != NodePath(""):
		_target = get_node_or_null(target_path) as Node3D
	if _target:
		_focus = _target.global_position
		global_position = _focus + _offset
	make_current()

## How many 90° steps the view is rotated from default, normalized to 0..3.
## The player reads this to keep WASD aligned with the on-screen view.
func get_quadrant() -> int:
	return ((_quadrant % 4) + 4) % 4

## Pan to spotlight `node` (instead of the player) until release_focus(). The pan
## uses the slower focus_smooth until it arrives.
func focus_on(node: Node3D) -> void:
	_focus_target = node
	_pan_smooth = focus_smooth

## Return the camera focus to the player, panning back at the slower focus rate.
func release_focus() -> void:
	_focus_target = null
	_pan_smooth = focus_smooth

## Snap the view back to the default orientation (used on restart).
func reset_rotation() -> void:
	_quadrant = 0
	_cur_yaw = deg_to_rad(yaw_deg)
	_yaw_from = _cur_yaw
	_yaw_to = _cur_yaw
	_rot_t = 1.0

## Kick off a fresh eased swing toward the current quadrant's yaw.
func _start_turn() -> void:
	_yaw_from = _cur_yaw
	_yaw_to = deg_to_rad(yaw_deg + float(_quadrant) * 90.0)
	_rot_t = 0.0

func _unhandled_input(event: InputEvent) -> void:
	# No camera control while a conversation is on screen.
	if Dialogue.is_active():
		return
	# Mouse middle/wheel scroll: each notch steps the zoom.
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_apply_zoom(-zoom_step)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_apply_zoom(zoom_step)
	# Trackpad pinch (magnify gesture): factor > 1 = fingers spreading = zoom in.
	elif event is InputEventMagnifyGesture:
		_set_zoom(ortho_size / event.factor)
	# Q / E swing the view 90° at a time.
	if event.is_action_pressed("rotate_left"):
		_quadrant -= 1
		_start_turn()
	elif event.is_action_pressed("rotate_right"):
		_quadrant += 1
		_start_turn()

func _apply_zoom(delta_size: float) -> void:
	_set_zoom(ortho_size + delta_size)

func _set_zoom(new_size: float) -> void:
	ortho_size = clampf(new_size, zoom_min, zoom_max)
	size = ortho_size

func _process(delta: float) -> void:
	# Ease the yaw over a fixed duration with a smoothstep so the 90° turn starts
	# and ends gently. lerp_angle takes the short way, so it's a clean quarter turn.
	if _rot_t < 1.0:
		_rot_t = minf(1.0, _rot_t + delta / maxf(rotate_time, 0.0001))
		var e := _rot_t * _rot_t * (3.0 - 2.0 * _rot_t)   # smoothstep ease
		_cur_yaw = lerp_angle(_yaw_from, _yaw_to, e)
	rotation = Vector3(deg_to_rad(pitch_deg), _cur_yaw, 0.0)
	_offset = global_transform.basis.z * distance
	# Follow the spotlight target if one is set, else the player.
	var look: Node3D = _focus_target if _focus_target != null else _target
	if look == null:
		return
	# Smooth the focus point toward the target, then place the camera at a rigid
	# offset from it. Rotation orbits this focus, so the cat never swings off
	# center while the view spins.
	# Use the slow pan rate while panning to/from a focus; snap back to the normal
	# follow rate once the pan has essentially arrived.
	var smooth := _pan_smooth if _pan_smooth > 0.0 else follow_smooth
	if smooth <= 0.0:
		_focus = look.global_position
	else:
		_focus = _focus.lerp(look.global_position, 1.0 - exp(-smooth * delta))
	if _pan_smooth > 0.0 and _focus.distance_to(look.global_position) < 0.05:
		_pan_smooth = 0.0
	global_position = _focus + _offset
