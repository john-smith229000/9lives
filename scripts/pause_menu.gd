extends CanvasLayer
## Simple pause menu. Press H to toggle a darkened overlay with a Restart button.
## More options can be added to the menu later.

@onready var _root: Control = $Root

# The World node (this menu is a child of it in main.tscn).
@onready var _world: Node = get_parent()

func _ready() -> void:
	_root.visible = false
	$Root/Center/Buttons/Restart.pressed.connect(_on_restart_pressed)
	$Root/Center/Buttons/MainMenu.pressed.connect(_on_main_menu_pressed)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu"):
		_toggle()
		get_viewport().set_input_as_handled()

func _toggle() -> void:
	if _root.visible:
		_close()
	else:
		_open()

func _open() -> void:
	_root.visible = true
	get_tree().paused = true     # freeze gameplay while the menu is up

func _close() -> void:
	_root.visible = false
	get_tree().paused = false

func _on_restart_pressed() -> void:
	if _world and _world.has_method("reset_blocks"):
		_world.reset_blocks()
	var player := _world.get_node_or_null("Player")
	if player and player.has_method("abort"):
		player.abort()
	_close()

func _on_main_menu_pressed() -> void:
	# Always unpause before switching scenes, or the new scene starts frozen.
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/start_menu.tscn")
