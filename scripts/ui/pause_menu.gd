extends CanvasLayer
## Pause menu. Lives on the app host (game_root) at full resolution, so it stays
## crisp and correctly sized even when the game renders into the low-res retro
## SubViewport. Press the "menu" action (H) to toggle it, but only while a level is
## on screen. Uses Input polling + PROCESS_MODE_ALWAYS so it works whether or not
## the tree is paused.

@onready var _root: Control = $Root

func _ready() -> void:
	_root.visible = false
	$Root/Center/Buttons/Restart.pressed.connect(_on_restart_pressed)
	$Root/Center/Buttons/MainMenu.pressed.connect(_on_main_menu_pressed)

func _process(_delta: float) -> void:
	if not Input.is_action_just_pressed("menu"):
		return
	if _root.visible:
		_close()
	elif SceneManager.current_world() != null:
		_open()          # only pausable while actually in a level

func _open() -> void:
	_root.visible = true
	get_tree().paused = true

func _close() -> void:
	_root.visible = false
	get_tree().paused = false

func _on_restart_pressed() -> void:
	var world := SceneManager.current_world()
	if world and world.has_method("reset_blocks"):
		world.reset_blocks()
	var player: Node = world.get_node_or_null("Player") if world else null
	if player and player.has_method("abort"):
		player.abort()
	_close()

func _on_main_menu_pressed() -> void:
	SceneManager.goto_menu()   # unpauses, then switches to the menu

## Hide the overlay without touching pause state (used on scene transitions).
func force_close() -> void:
	_root.visible = false
