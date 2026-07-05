extends CanvasLayer
## The on-screen text UI: a bottom-center speech panel with a typewriter reveal,
## plus a lighter "hint" banner just above it. Built entirely in code so there
## are no scene-anchor gotchas. Driven by the Dialogue autoload; it never reads
## input itself.

## Characters revealed per second by the typewriter.
const REVEAL_CPS := 45.0

var _speech: PanelContainer
var _speaker_lbl: Label
var _body: RichTextLabel
var _cont: Label
var _hint: PanelContainer
var _hint_lbl: Label

var _revealed := 0.0
var _typing := false

func _ready() -> void:
	layer = 50
	_build()
	hide_all()

func _process(delta: float) -> void:
	if not _typing:
		return
	_revealed += REVEAL_CPS * delta
	var n := int(_revealed)
	if n >= _body.get_total_character_count():
		n = _body.get_total_character_count()
		_typing = false
	_body.visible_characters = n
	_cont.visible = not _typing

# --- Speech ---------------------------------------------------------------

## Show one line of speech (starts the typewriter). Empty speaker hides the name.
func show_speech(speaker: String, text: String) -> void:
	_speech.visible = true
	_speaker_lbl.text = speaker
	_speaker_lbl.visible = speaker != ""
	_body.text = text
	_body.visible_characters = 0
	_revealed = 0.0
	_typing = true
	_cont.visible = false

## True while the typewriter is still revealing the current line.
func is_typing() -> bool:
	return _typing

## Skip the typewriter and show the whole current line at once.
func reveal_all() -> void:
	_typing = false
	_body.visible_characters = -1
	_cont.visible = true

func hide_speech() -> void:
	_speech.visible = false
	_typing = false

# --- Hint (non-blocking banner) ------------------------------------------

func show_hint(text: String) -> void:
	_hint.visible = true
	_hint_lbl.text = text

func hide_hint() -> void:
	_hint.visible = false

func hint_visible() -> bool:
	return _hint.visible

func hide_all() -> void:
	hide_speech()
	hide_hint()

# --- Construction ---------------------------------------------------------

func _build() -> void:
	# Speech panel.
	_speech = _make_panel(Color(0.08, 0.09, 0.12, 0.93), Color(1, 1, 1, 0.16))
	add_child(_speech)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	_wrap_margin(_speech, vb, 22, 22, 14, 14)

	_speaker_lbl = Label.new()
	_speaker_lbl.add_theme_font_size_override("font_size", 20)
	_speaker_lbl.add_theme_color_override("font_color", Color(1.0, 0.82, 0.42))
	vb.add_child(_speaker_lbl)

	_body = RichTextLabel.new()
	_body.bbcode_enabled = false
	_body.scroll_active = false
	_body.fit_content = true
	_body.custom_minimum_size = Vector2(0, 52)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_font_size_override("normal_font_size", 22)
	_body.add_theme_color_override("default_color", Color(0.96, 0.96, 0.98))
	vb.add_child(_body)

	_cont = Label.new()
	_cont.text = "[I] ▸"
	_cont.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_cont.add_theme_font_size_override("font_size", 14)
	_cont.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	vb.add_child(_cont)

	_anchor_bottom_center(_speech, 0.62, 150.0, 40.0)

	# Hint banner (sits above where the speech panel would be).
	_hint = _make_panel(Color(0.10, 0.12, 0.10, 0.86), Color(1.0, 0.9, 0.4, 0.55))
	add_child(_hint)
	_hint_lbl = Label.new()
	_hint_lbl.add_theme_font_size_override("font_size", 18)
	_hint_lbl.add_theme_color_override("font_color", Color(1.0, 0.96, 0.82))
	_hint_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wrap_margin(_hint, _hint_lbl, 18, 18, 10, 10)
	_anchor_bottom_center(_hint, 0.5, 60.0, 210.0)

func _make_panel(bg: Color, border: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(10)
	sb.set_border_width_all(2)
	sb.border_color = border
	p.add_theme_stylebox_override("panel", sb)
	return p

## Put `child` inside `parent` behind a uniform inner margin.
func _wrap_margin(parent: Control, child: Control, l: int, r: int, t: int, b: int) -> void:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", l)
	m.add_theme_constant_override("margin_right", r)
	m.add_theme_constant_override("margin_top", t)
	m.add_theme_constant_override("margin_bottom", b)
	parent.add_child(m)
	m.add_child(child)

## Anchor a control to the bottom-center of the screen, spanning `width_ratio` of
## the width, `min_h` tall, sitting `bottom_margin` px up from the bottom edge.
func _anchor_bottom_center(c: Control, width_ratio: float, min_h: float, bottom_margin: float) -> void:
	c.anchor_left = 0.5 - width_ratio * 0.5
	c.anchor_right = 0.5 + width_ratio * 0.5
	c.anchor_top = 1.0
	c.anchor_bottom = 1.0
	c.offset_left = 0.0
	c.offset_right = 0.0
	c.offset_top = -(min_h + bottom_margin)
	c.offset_bottom = -bottom_margin
	c.grow_horizontal = Control.GROW_DIRECTION_BOTH
	c.grow_vertical = Control.GROW_DIRECTION_BEGIN
