extends Node
## Doorway-based house entry. A thin trigger box near the entrance toggles
## between the isometric exterior and the free-movement interior. The house
## mesh gets runtime trimesh collision so the cat collides with the real walls.

@export var player_path: NodePath
@export var exterior_camera_path: NodePath
@export var house_path: NodePath              # the house1.tscn instance
@export var inside_camera_name: String = "inside_view"
## Path (within the house) to the CollisionShape3D used as the doorway trigger.
@export var collision_path: String = "inside_house/inside_house_collision"

var _player: Node3D
var _ext_cam: Camera3D
var _inside_cam: Camera3D
var _trigger: CollisionShape3D
var _trigger_size := Vector3.ONE
var _inside := false
var _was_in_trigger := false

func _ready() -> void:
	_player = get_node_or_null(player_path)
	_ext_cam = get_node_or_null(exterior_camera_path)
	var house := get_node_or_null(house_path)
	if house == null or _player == null:
		push_warning("HouseController: missing player or house.")
		set_process(false)
		return
	_inside_cam = house.get_node_or_null(inside_camera_name)
	_trigger = house.get_node_or_null(collision_path) as CollisionShape3D
	if _trigger and _trigger.shape is BoxShape3D:
		_trigger_size = (_trigger.shape as BoxShape3D).size
		# Make sure the trigger box itself never physically blocks the cat.
		var body := _trigger.get_parent()
		if body is PhysicsBody3D:
			(body as PhysicsBody3D).collision_layer = 0
			(body as PhysicsBody3D).collision_mask = 0
	else:
		push_warning("HouseController: doorway trigger box not found.")
		set_process(false)
		return
	# Wall collision comes from the hand-placed "house_collisions" StaticBody in
	# the house scene, so there's nothing to generate here.

func _process(_delta: float) -> void:
	if _player == null:
		return
	# If something else (e.g. Restart) took the cat out of free mode, snap back
	# to the exterior view (toggle from inside -> outside).
	if _inside and _player.has_method("is_in_free_mode") and not _player.is_in_free_mode():
		_toggle()
		return
	var in_trigger := _point_in_trigger(_player.global_position)
	if in_trigger and not _was_in_trigger:
		_toggle()            # crossed the doorway
	_was_in_trigger = in_trigger

func _point_in_trigger(p: Vector3) -> bool:
	# Test in the trigger box's local space (handles any rotation); ignore height.
	var local := _trigger.global_transform.affine_inverse() * p
	var h := _trigger_size * 0.5
	return absf(local.x) <= h.x and absf(local.z) <= h.z

func _toggle() -> void:
	_inside = not _inside
	if _inside:
		if _inside_cam:
			_inside_cam.current = true
		if _player.has_method("enter_free_mode"):
			_player.enter_free_mode(_inside_cam)
	else:
		if _ext_cam:
			_ext_cam.current = true
		if _player.has_method("exit_free_mode"):
			_player.exit_free_mode()
