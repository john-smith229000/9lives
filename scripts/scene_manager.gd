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
var _host: Node = null               # the game_root host (set at startup)

## Registered by game_root.gd so scene loading routes through the SubViewport host.
func set_host(host: Node) -> void:
	_host = host

## The World of the level currently on screen, or null (on the menu / no host).
func current_world() -> Node:
	if _host and _host.has_method("current_level"):
		return _host.current_level()
	return null

## Load a scene by its res:// path. Always unpauses first so the new scene never
## starts frozen (e.g. when switching from the pause menu). When the host is
## present, levels go into its (optionally low-res) SubViewport and menus render
## full-resolution; otherwise it falls back to a plain scene change.
func goto(path: String) -> void:
	get_tree().paused = false
	Dialogue.clear()                     # never let a text box survive a transition
	_current = path
	if _host == null:
		get_tree().change_scene_to_file(path)
		return
	if path == MENU:
		_host.mount_menu(load(path))
	else:
		_host.mount_level(load(path))

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
