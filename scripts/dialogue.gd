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
var _hint_text := ""                  # the standing hint, if any (restored after speech)

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
	if _hint_text != "":
		_box.hide_hint()          # don't stack a hint under the speech box
	_box.show_speech(_speaker, str(_lines[0]))

## Wipe all conversation/hint state and hide the box. Called on every scene
## change (see SceneManager.goto) so nothing lingers across levels or into the
## menu.
func clear() -> void:
	_active = false
	_lines = []
	_idx = 0
	_on_close = Callable()
	_hint_text = ""
	if _box:
		_box.hide_all()

## Show a non-blocking hint banner. Held back while a speech box is up, then shown.
func show_hint(text: String) -> void:
	if text == "":
		return
	_hint_text = text
	if not _active:
		_box.show_hint(text)

func hide_hint() -> void:
	_hint_text = ""
	_box.hide_hint()

func hint_visible() -> bool:
	return _box.hint_visible()

func _process(_delta: float) -> void:
	# Poll (rather than _unhandled_input) so advancing works even when the game is
	# rendered inside a SubViewport (retro mode), where event routing differs.
	if not _active:
		return
	# Ignore the very press that opened this conversation.
	if Engine.get_frames_drawn() == _started_frame:
		return
	if Input.is_action_just_pressed("interact"):
		_advance()

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
	# Bring back a standing hint that was held during the conversation.
	if _hint_text != "":
		_box.show_hint(_hint_text)
	finished.emit()
