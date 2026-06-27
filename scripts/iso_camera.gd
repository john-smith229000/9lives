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
## Follow smoothing. 0 = instant snap, higher = smoother lag.
@export var follow_smooth: float = 8.0
## Tight near/far planes. The default range (0.05..4000) wrecks depth-buffer
## precision in orthographic mode and causes coplanar cube faces to z-fight
## (the flickering edges). Keeping the range small fixes it.
@export var near_plane: float = 1.0
@export var far_plane: float = 120.0

var _target: Node3D
var _offset: Vector3

func _ready() -> void:
	projection = PROJECTION_ORTHOGONAL
	ortho_size = clampf(ortho_size, zoom_min, zoom_max)
	size = ortho_size
	near = near_plane
	far = far_plane
	rotation = Vector3(deg_to_rad(pitch_deg), deg_to_rad(yaw_deg), 0.0)
	# basis.z is the camera's local +Z (pointing backward), so target + that * distance
	# places the camera behind/above the target along the view axis.
	_offset = global_transform.basis.z * distance
	if target_path != NodePath(""):
		_target = get_node_or_null(target_path) as Node3D
	if _target:
		global_position = _target.global_position + _offset
	make_current()

func _unhandled_input(event: InputEvent) -> void:
	# Mouse middle/wheel scroll: each notch steps the zoom.
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_apply_zoom(-zoom_step)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_apply_zoom(zoom_step)
	# Trackpad pinch (magnify gesture): factor > 1 = fingers spreading = zoom in.
	elif event is InputEventMagnifyGesture:
		_set_zoom(ortho_size / event.factor)

func _apply_zoom(delta_size: float) -> void:
	_set_zoom(ortho_size + delta_size)

func _set_zoom(new_size: float) -> void:
	ortho_size = clampf(new_size, zoom_min, zoom_max)
	size = ortho_size

func _process(delta: float) -> void:
	if _target == null:
		return
	var desired := _target.global_position + _offset
	if follow_smooth <= 0.0:
		global_position = desired
	else:
		global_position = global_position.lerp(desired, 1.0 - exp(-follow_smooth * delta))
