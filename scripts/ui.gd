class_name UI

# Общие элементы интерфейса для меню и игры.

const GREEN := Color("4cc46a")
const ORANGE := Color("ff9f43")
const PURPLE := Color("7d6fc4")
const CARD := Color("2a2942")
const CARD_BORDER := Color("4b4778")


static func label(text: String, font_size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


static func button(text: String, color: Color, action: Callable, min_size := Vector2(380, 92), font_size := 36, radius := 26) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", font_size)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(state, Color.WHITE)
	b.add_theme_color_override("font_shadow_color", color.darkened(0.45))
	b.add_theme_constant_override("shadow_offset_y", 3)
	b.add_theme_stylebox_override("normal", button_style(color, false, radius))
	b.add_theme_stylebox_override("hover", button_style(color.lightened(0.12), false, radius))
	b.add_theme_stylebox_override("pressed", button_style(color.darkened(0.08), true, radius))
	b.add_theme_stylebox_override("disabled", button_style(color, false, radius))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	if action.is_valid():
		b.pressed.connect(action)
	return b


# Объёмная кнопка: тёмная «подошва» снизу, при нажатии кнопка опускается на неё.
static func button_style(color: Color, pressed: bool, radius := 26) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = color.darkened(0.35)
	style.set_corner_radius_all(radius)
	style.border_width_bottom = 3 if pressed else 10
	style.content_margin_top = 14 if pressed else 8
	style.content_margin_bottom = 8
	style.content_margin_left = 32
	style.content_margin_right = 32
	return style


# Карточка с рамкой и скруглёнными углами.
static func card() -> PanelContainer:
	var c := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = CARD
	style.border_color = CARD_BORDER
	style.set_border_width_all(4)
	style.set_corner_radius_all(36)
	style.set_content_margin_all(44)
	c.add_theme_stylebox_override("panel", style)
	return c
