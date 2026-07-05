extends Node
class_name InteractionController
## Runtime component spawned by World (see world.gd._ready). Watches the Interact
## action: when the cat faces an Interactable, it opens that conversation through
## the Dialogue autoload.
##
## It's added to the tree AFTER the camera, so its _unhandled_input runs first and
## can consume the key — meaning talking never doubles as a camera action. It also
## snaps talkable NPCs to the ground surface once at setup.

var _world: Node
var _player: Node
var _cell := 1.0

func setup(world: Node, player: Node, cell: float) -> void:
	_world = world
	_player = player
	_cell = cell
	_snap_interactables()

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact"):
		return
	if Dialogue.is_active():
		return                                  # the Dialogue autoload advances it
	var it := _facing_interactable()
	if it != null:
		get_viewport().set_input_as_handled()
		if _player is Node3D:
			it.face_toward((_player as Node3D).global_position)
		Dialogue.start_speech(it.speaker, it.get_lines())
	elif Dialogue.hint_visible():
		get_viewport().set_input_as_handled()
		Dialogue.hide_hint()                    # I also dismisses a standing hint

## The Interactable on the tile the cat faces (or, if it isn't facing anywhere
## yet, on any of the four neighbours), else null.
func _facing_interactable() -> Interactable:
	if _player == null:
		return null
	var base: Vector2i = _player.grid_tile()
	var facing: Vector2i = _player.facing_dir()
	var targets: Array = []
	if facing != Vector2i.ZERO:
		targets.append(base + facing)
	else:
		targets = [base + Vector2i.RIGHT, base + Vector2i.LEFT,
			base + Vector2i(0, 1), base + Vector2i(0, -1)]
	for node in get_tree().get_nodes_in_group("interactable"):
		if node is Interactable and (node.interact_tile(_cell) in targets):
			return node
	return null

## Place each talkable NPC on its tile's ground surface (root Y = elevation +
## ground_y, matching how the roaming NPC sits).
func _snap_interactables() -> void:
	if _world == null or not _world.has_method("get_elevation"):
		return
	for node in get_tree().get_nodes_in_group("interactable"):
		if node is Interactable and node.snap_to_surface:
			var owner_node := node.get_parent()
			if owner_node is Node3D:
				var tile: Vector2i = node.interact_tile(_cell)
				var e: float = _world.get_elevation(tile.x, tile.y)
				var pos := (owner_node as Node3D).global_position
				pos.y = e + _world.ground_y
				(owner_node as Node3D).global_position = pos
