extends Node
## Autoload singleton that owns all scene loading / transitions, so the
## change_scene calls aren't scattered across the menu scripts. Registered in
## project.godot under [autoload] as "SceneManager", so it's reachable globally.

const MENU := "res://scenes/start_menu.tscn"
const LEVELS := [
	"res://scenes/scene1.tscn",
	"res://scenes/scene2.tscn",
	"res://scenes/scene3.tscn",
	"res://scenes/scene4.tscn",
	"res://scenes/scene5.tscn",
]

var _current := ""

## Load a scene by its res:// path. Always unpauses first so the new scene never
## starts frozen (e.g. when switching from the pause menu).
func goto(path: String) -> void:
	get_tree().paused = false
	_current = path
	get_tree().change_scene_to_file(path)

## Load level N (1-based, matching the scene names).
func goto_level(n: int) -> void:
	if n >= 1 and n <= LEVELS.size():
		goto(LEVELS[n - 1])

## The next level after the current one, if any (for goal → next-level progression).
func goto_next_level() -> void:
	var i := LEVELS.find(_current)
	if i != -1 and i + 1 < LEVELS.size():
		goto(LEVELS[i + 1])

## Back to the main menu.
func goto_menu() -> void:
	goto(MENU)

## Reload the current level (e.g. a full "retry").
func reload() -> void:
	if _current != "":
		goto(_current)
