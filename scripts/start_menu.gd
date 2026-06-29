extends Control
## First screen on launch. Pick which scene to play.

func _ready() -> void:
	$Center/Panel/Scene1.pressed.connect(_on_scene1)
	$Center/Panel/Scene2.pressed.connect(_on_scene2)
	$Center/Panel/Scene3.pressed.connect(_on_scene3)
	$Center/Panel/Scene4.pressed.connect(_on_scene4)

func _on_scene1() -> void:
	get_tree().change_scene_to_file("res://scenes/scene1.tscn")

func _on_scene2() -> void:
	get_tree().change_scene_to_file("res://scenes/scene2.tscn")

func _on_scene3() -> void:
	get_tree().change_scene_to_file("res://scenes/scene3.tscn")

func _on_scene4() -> void:
	get_tree().change_scene_to_file("res://scenes/scene4.tscn")
