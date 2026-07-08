extends Node3D
## Friendly cat that lies down when the player comes close. Attach this to a
## friend_cat.glb instance. On entering range it plays the "lay" clip forward
## (and holds the final pose); when the player wanders off again it plays the
## clip in reverse to stand back up, so the greeting can repeat.

## Distance (metres) at which the cat lies down.
@export var trigger_distance: float = 2.5
## Extra distance past trigger_distance before the cat stands up. Prevents
## flip-flopping when the player lingers right on the edge of the range.
@export var release_margin: float = 0.8
## Begin curled up (asleep), holding the final lie-down pose — the cat you wake beside
## at dawn. It stands the first time the player walks away.
@export var start_asleep: bool = false
## Gate the lie-down: when true, approaching does NOT curl the friend until enable_sleep()
## is called (e.g. at evening, once the day's objectives are done); it emits curled_up
## when it finally lies down again. When false, it's the plain greeting behaviour
## (curls whenever the player is near). Leave off for scenes that just want a friendly cat.
@export var gated_sleep: bool = false

## Emitted the first time the friend stands up (the player has walked away).
signal stood_up
## Emitted when the friend curls back up (only possible once enable_sleep() is called
## in gated_sleep mode) — the flow uses this as the "sleep to end the day" trigger.
signal curled_up
## Name of the lie-down clip inside the model.
@export var lay_anim: String = "lay"
## Play the clip in reverse to stand up when the player leaves. If false, the
## cat simply stays lying down once triggered.
@export var stand_up_when_far: bool = true
## Optional explicit path to the player. Leave empty to auto-detect a sibling
## "Player" node, then fall back to the "player" group.
@export var player_path: NodePath

var _anim: AnimationPlayer
var _player: Node3D
var _laying := false
# gated_sleep only: false until enable_sleep() lets the friend curl up again.
var _can_curl := false

func _ready() -> void:
	_anim = _find_anim_player(self)
	if _anim == null:
		push_warning("friend_cat: no AnimationPlayer found in model.")
	elif not _anim.has_animation(lay_anim):
		push_warning("friend_cat: animation '%s' not found. Available: %s"
			% [lay_anim, ", ".join(_anim.get_animation_list())])
	_player = _resolve_player()
	# Wake beside a sleeping friend: hold the final frame of the lie-down clip.
	if start_asleep and _anim and _anim.has_animation(lay_anim):
		_laying = true
		_anim.play(lay_anim)
		_anim.seek(_anim.get_animation(lay_anim).length, true)

func _process(_delta: float) -> void:
	if _anim == null or not _anim.has_animation(lay_anim):
		return
	if not is_instance_valid(_player):
		_player = _resolve_player()
		if not is_instance_valid(_player):
			return

	var a := global_position
	var b := _player.global_position
	# Horizontal distance only; ignore any vertical offset between the two.
	var dist := Vector2(a.x - b.x, a.z - b.z).length()

	if not _laying:
		# In gated mode the friend only lies down once sleep is enabled (evening +
		# objectives done); otherwise it curls whenever the player comes near.
		var may_curl := _can_curl if gated_sleep else true
		if may_curl and dist <= trigger_distance:
			_laying = true
			_anim.play(lay_anim)
			if gated_sleep:
				_can_curl = false        # one-shot so it doesn't re-fire
			curled_up.emit()
	else:
		if stand_up_when_far and dist > trigger_distance + release_margin:
			_laying = false
			# Play backwards from the end to ease back up to the rest pose.
			_anim.play(lay_anim, -1, -1.0, true)
			stood_up.emit()

## Let the friend curl up again the next time the player is close (gated_sleep mode).
## Call this at evening once the day's objectives are met; the resulting lie-down emits
## curled_up, which the flow treats as "the cat sleeps → end the day".
func enable_sleep() -> void:
	_can_curl = true

## Is the friend currently curled up?
func is_curled() -> bool:
	return _laying

func _resolve_player() -> Node3D:
	if player_path != NodePath():
		var explicit := get_node_or_null(player_path)
		if explicit is Node3D:
			return explicit
	var parent := get_parent()
	if parent:
		var sibling := parent.get_node_or_null("Player")
		if sibling is Node3D:
			return sibling
	var grouped := get_tree().get_first_node_in_group("player")
	if grouped is Node3D:
		return grouped
	return null

func _find_anim_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for c in node.get_children():
		var f := _find_anim_player(c)
		if f:
			return f
	return null
