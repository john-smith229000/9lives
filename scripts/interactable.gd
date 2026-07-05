extends Node3D
class_name Interactable
## Drop this under an NPC (or a prop) to make it talkable. When the cat faces the
## tile this occupies and presses Interact (I), its lines play through the
## Dialogue box. Detection is tile-based (like jump/push), so it's deterministic.
##
## Content lives right here as exported strings so lines can be written/edited in
## the Godot inspector with no code.

## Name shown above the text (blank = no name line).
@export var speaker: String = ""
## The lines, in order. Each is one press-to-advance screen.
@export_multiline var lines: PackedStringArray
## Turn the owner NPC's "Model" child to face the cat when talked to.
@export var face_player: bool = true
## Snap the owner to the tile's ground surface at start (handy on smooth terrain,
## so you don't have to hand-place the Y).
@export var snap_to_surface: bool = true

func _ready() -> void:
	add_to_group("interactable")

## The grid tile this interactable currently sits on.
func interact_tile(cell: float) -> Vector2i:
	var p := global_position
	return Vector2i(roundi(p.x / cell), roundi(p.z / cell))

## The lines as a plain Array (what Dialogue.start_speech expects).
func get_lines() -> Array:
	var a: Array = []
	for l in lines:
		a.append(l)
	return a

## Rotate the owner NPC's model to look at `world_pos` (the cat). NPC models here
## face +Z, so we add PI to match npc.gd's model_yaw_offset.
func face_toward(world_pos: Vector3) -> void:
	if not face_player:
		return
	var model := _find_model()
	if model == null:
		return
	var d := world_pos - global_position
	if Vector2(d.x, d.z).length() < 0.001:
		return
	model.rotation.y = atan2(-d.x, -d.z) + PI

func _find_model() -> Node3D:
	var p := get_parent()
	if p and p.has_node("Model"):
		return p.get_node("Model") as Node3D
	return null
