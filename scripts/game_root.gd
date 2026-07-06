extends Node
## Persistent app host. Levels render into a low-res SubViewport (crisp PS1-style
## upscale) while menus render full-resolution on top. SceneManager loads scenes
## through this node (see SceneManager.set_host / mount_level / mount_menu).
##
## When RetroMode is off, levels are mounted directly at full resolution (the
## SubViewport is bypassed), so the game looks and behaves exactly as before.

@onready var _stage: SubViewportContainer = $Stage
@onready var _stage_vp: SubViewport = $Stage/Stage3D
@onready var _menu_layer: CanvasLayer = $MenuLayer
@onready var _pause: CanvasLayer = $PauseMenu

var _level: Node = null
var _menu: Node = null

func _ready() -> void:
	# Keep the window from shrinking so small the low-res stage collapses. The window
	# is resizable and can go fullscreen (F11 / Alt+Enter); everything scales to fit.
	var win := get_window()
	if win:
		win.min_size = Vector2i(640, 360)
	# Configure the low-res stage up front. Whether a level actually uses it is
	# decided per-load in mount_level (RetroMode.active), so the menu toggle applies
	# on the next scene load.
	_stage_vp.own_world_3d = true
	_stage_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_stage.stretch = true
	_stage.stretch_shrink = maxi(RetroMode.SHRINK, 1)
	_stage.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# MSAA anti-aliases blade/edge stair-stepping inside the low-res buffer, which
	# is the main fix for the moving-grass twinkle. Keep FXAA/TAA off (they'd blur
	# or smear the whole low-res image).
	match RetroMode.MSAA:
		1: _stage_vp.msaa_3d = Viewport.MSAA_2X
		2: _stage_vp.msaa_3d = Viewport.MSAA_4X
		3: _stage_vp.msaa_3d = Viewport.MSAA_8X
		_: _stage_vp.msaa_3d = Viewport.MSAA_DISABLED
	_stage_vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	_add_post_process()
	SceneManager.set_host(self)
	# Boot into the main menu.
	mount_menu(load(SceneManager.MENU))

## Global window shortcuts (work on any scene, menu or level): F11 or Alt+Enter
## toggles fullscreen. Handled here in the persistent host as unhandled key input, so
## a focused text field still gets first crack at the key and gameplay/menu input is
## untouched. The window is resizable and the render pipeline (full-res or the retro
## SubViewport) already tracks the window size, so fullscreen and free resizing both
## adapt with no extra work.
func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	if k.keycode == KEY_F11 or (k.keycode == KEY_ENTER and k.alt_pressed):
		_toggle_fullscreen()
		get_viewport().set_input_as_handled()

func _toggle_fullscreen() -> void:
	var mode := DisplayServer.window_get_mode()
	var fs := mode == DisplayServer.WINDOW_MODE_FULLSCREEN \
		or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_WINDOWED if fs else DisplayServer.WINDOW_MODE_FULLSCREEN)

## The level currently on screen (a World), or null on the menu. Used by the
## pause menu.
func current_level() -> Node:
	return _level

## Add the palette-limit + dithering pass INSIDE the low-res SubViewport, on top,
## so it operates at the chunky pixel grid before the nearest-neighbour upscale.
func _add_post_process() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/retro_post.gdshader")
	mat.set_shader_parameter("levels", RetroMode.COLOR_LEVELS)
	mat.set_shader_parameter("dither_strength", RetroMode.DITHER)
	var layer := CanvasLayer.new()
	layer.layer = 90                     # above the game, below the root UI
	var bbc := BackBufferCopy.new()
	bbc.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	layer.add_child(bbc)
	var rect := ColorRect.new()
	rect.material = mat
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.anchor_right = 1.0
	rect.anchor_bottom = 1.0
	layer.add_child(rect)
	_stage_vp.add_child(layer)

## Put a level on screen. In retro mode it renders inside the low-res SubViewport;
## otherwise it renders at full resolution (SubViewport bypassed).
func mount_level(scene: PackedScene) -> void:
	_clear()
	if RetroMode.active:
		_stage.visible = true
		_level = scene.instantiate()
		_stage_vp.add_child(_level)
	else:
		_stage.visible = false
		_level = scene.instantiate()
		add_child(_level)

## Put a menu (a Control) on screen at full resolution.
func mount_menu(scene: PackedScene) -> void:
	_clear()
	_stage.visible = false
	_menu = scene.instantiate()
	_menu_layer.add_child(_menu)

func _clear() -> void:
	if _pause and _pause.has_method("force_close"):
		_pause.force_close()
	if _level:
		_level.queue_free()
		_level = null
	if _menu:
		_menu.queue_free()
		_menu = null
