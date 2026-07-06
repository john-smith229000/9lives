extends Node3D
class_name Interactable
## Drop this under an NPC (or a prop) to make it talkable. When the cat faces the
## tile this occupies and presses Interact (I), its lines play through the
## Dialogue box. Detection is tile-based (like jump/push), so it's deterministic.
##
## Content lives right here as exported strings so lines can be written/edited in
## the Godot inspector with no code.

## Emitted the first time a conversation with this interactable finishes.
signal talked
## Emitted every time a conversation with this interactable finishes.
signal conversation_ended

## The character this belongs to (a CharacterProfile). If set, the dialogue box
## shows their name + plays their voice. Blank = use the plain `speaker` string.
@export var profile: CharacterProfile
## Name shown above the text when there's no profile (blank = no name line).
@export var speaker: String = ""
## The lines, in order. Each is one press-to-advance screen.
@export_multiline var lines: PackedStringArray
## Optional alternate lines used after the first conversation (blank = keep `lines`).
@export_multiline var lines_after: PackedStringArray
## If set, this Interactable speaks the character's expression of this key instead
## of `lines` (handy for a placed/roaming character with no scene story lines).
@export var expression_key: String = ""

var _talked_once := false
var _use_after := false
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

## The lines as a plain Array (what Dialogue.start_speech expects). Uses
## `lines_after` once use_after_lines() has been called (a scripted follow-up),
## otherwise the default `lines`.
func get_lines() -> Array:
	if expression_key != "" and profile:
		return profile.expression(expression_key)
	var src := lines_after if (_use_after and not lines_after.is_empty()) else lines
	var a: Array = []
	for l in src:
		a.append(l)
	return a

## The name to show above the text: the character's if a profile is set.
func speaker_name() -> String:
	return profile.display_name if profile else speaker

## The voice blip to play while typing, or null.
func voice() -> AudioStream:
	return profile.voice if profile else null

## Switch future conversations to `lines_after` (called by a guide once the story
## beat that unlocks them happens).
func use_after_lines() -> void:
	_use_after = true

## Whether this interactable has been talked to at least once. This is PERSISTENT
## state (unlike the one-shot `talked` signal), so a SceneFlow can gate on it as a
## live predicate — correct even if the player talked before the flow started
## watching, or the flow re-checks after the signal already fired.
func has_talked() -> bool:
	return _talked_once

## Called by the InteractionController when a conversation with this node closes.
## Emits `talked` on the first close (for scripted follow-ups).
func on_conversation_closed() -> void:
	var first := not _talked_once
	_talked_once = true
	if first:
		talked.emit()
	conversation_ended.emit()

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

## The grid direction this character is currently facing (its model's front), or
## Vector2i.ZERO if unknown. Used so the player walks up to the FRONT of them.
func front_dir() -> Vector2i:
	var model := _find_model()
	if model == null:
		return Vector2i.ZERO
	var f := model.global_transform.basis.z    # npc models face local +Z
	var v := Vector2(f.x, f.z)
	if v.length() < 0.001:
		return Vector2i.ZERO
	if absf(v.x) >= absf(v.y):
		return Vector2i(1 if v.x >= 0.0 else -1, 0)
	return Vector2i(0, 1 if v.y >= 0.0 else -1)
