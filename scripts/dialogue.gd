extends Node
## Autoload singleton ("Dialogue") that owns the single on-screen text box and
## the conversation state. Registered in project.godot under [autoload].
##
## Two modes:
##   - Speech: a blocking conversation. is_active() is true; the player/camera
##     freeze their input while it runs. Press Interact (I) to advance / to skip
##     the typewriter, and again to close at the end.
##   - Hint: a non-blocking banner (e.g. the rolling-ball tip). Movement is NOT
##     frozen, so hints can point at things the player then goes and does.
##
## The InteractionController opens speech; World shows/hides hints.

signal finished

var _box: CanvasLayer
var _lines: Array = []
var _speaker := ""
var _idx := 0
var _active := false
var _started_frame := -1
var _on_close: Callable

func _ready() -> void:
	# The box builds its own UI (see dialogue_box.gd).
	var box_script := load("res://scripts/dialogue_box.gd")
	_box = box_script.new()
	_box.name = "DialogueBox"
	add_child(_box)

## True only during a blocking speech conversation (used to freeze input).
func is_active() -> bool:
	return _active

## Begin a blocking conversation. `lines` is an Array of Strings. `on_close` (if
## valid) is called once when the conversation ends.
func start_speech(speaker: String, lines: Array, on_close := Callable()) -> void:
	if lines.is_empty():
		return
	_speaker = speaker
	_lines = lines
	_idx = 0
	_active = true
	_on_close = on_close
	_started_frame = Engine.get_frames_drawn()
	_box.show_speech(_speaker, str(_lines[0]))

## Show a non-blocking hint banner.
func show_hint(text: String) -> void:
	if text != "":
		_box.show_hint(text)

func hide_hint() -> void:
	_box.hide_hint()

func hint_visible() -> bool:
	return _box.hint_visible()

func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return
	if event.is_action_pressed("interact"):
		# Swallow the very press that opened this conversation (belt-and-braces;
		# the InteractionController usually consumes it first).
		if Engine.get_frames_drawn() == _started_frame:
			get_viewport().set_input_as_handled()
			return
		_advance()
		get_viewport().set_input_as_handled()

func _advance() -> void:
	# First press finishes the typewriter; the next moves on.
	if _box.is_typing():
		_box.reveal_all()
		return
	_idx += 1
	if _idx >= _lines.size():
		_close()
	else:
		_box.show_speech(_speaker, str(_lines[_idx]))

func _close() -> void:
	_active = false
	_box.hide_speech()
	var cb := _on_close
	_on_close = Callable()
	if cb.is_valid():
		cb.call()
	finished.emit()
