extends Control
## First screen on launch. Pick which scene to play.

func _ready() -> void:
	$Center/Panel/Scene1.pressed.connect(_on_scene1)
	$Center/Panel/Scene2.pressed.connect(_on_scene2)
	$Center/Panel/Scene3.pressed.connect(_on_scene3)
	$Center/Panel/Scene4.pressed.connect(_on_scene4)
	$Center/Panel/Scene5.pressed.connect(_on_scene5)
	var retro: CheckButton = $Center/Panel/RetroToggle
	retro.button_pressed = RetroMode.active
	retro.toggled.connect(_on_retro_toggled)

func _on_retro_toggled(on: bool) -> void:
	RetroMode.active = on   # applies on the next scene you enter

func _on_scene1() -> void:
	GameState.reset()   # a fresh run: wipe story flags / back to day 1
	SceneManager.goto_level(1)

func _on_scene2() -> void:
	SceneManager.goto_level(2)

func _on_scene3() -> void:
	SceneManager.goto_level(3)

func _on_scene4() -> void:
	SceneManager.goto_level(4)

func _on_scene5() -> void:
	SceneManager.goto_level(5)
