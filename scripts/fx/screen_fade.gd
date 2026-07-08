extends CanvasLayer
class_name ScreenFade
## Simple full-screen black fade for day transitions (sleep out / wake in). Add it as
## a child of the level and call setup(); it renders on top of the scene as a black
## ColorRect whose alpha is tweened. All the fade calls are awaitable so a flow (or
## World.end_day) can `await fade.to_black()` and continue once it's fully dark.

var _rect: ColorRect

## Build the overlay. Pass start_black = true to begin fully opaque (so the scene can
## fade IN from black on the very first frame, e.g. waking at dawn).
func setup(start_black := false) -> void:
	layer = 80                                  # above the game, below menus/post FX
	_rect = ColorRect.new()
	_rect.color = Color(0.0, 0.0, 0.0, 1.0 if start_black else 0.0)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.anchor_right = 1.0
	_rect.anchor_bottom = 1.0
	add_child(_rect)

## Snap fully black immediately (no tween).
func set_black() -> void:
	if _rect:
		_rect.color.a = 1.0

## Fade the screen to black over `secs`, returning once it's fully dark.
func to_black(secs := 1.0) -> void:
	await _fade_to(1.0, secs)

## Fade from black back to clear over `secs`, returning once fully visible.
func from_black(secs := 1.0) -> void:
	await _fade_to(0.0, secs)

func _fade_to(target_a: float, secs: float) -> void:
	if _rect == null:
		return
	var tw := create_tween()
	tw.tween_property(_rect, "color:a", target_a, maxf(secs, 0.01))
	await tw.finished
