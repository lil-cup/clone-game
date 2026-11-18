class_name UI

# Общие элементы интерфейса для меню и игры.

const GREEN := Color("4cc46a")
const ORANGE := Color("ff9f43")
const PURPLE := Color("7d6fc4")
const CARD := Color("2a2942")
const CARD_BORDER := Color("4b4778")

static var click_player: AudioStreamPlayer


static func number_font() -> Font:
	return preload("res://fonts/nunito_numbers.tres")


# Глянцевое сердце в стиле монетки: тёмная подошва снизу, обводка, светлая фаска, блик.
# Заливка многоугольника в Godot без сглаживания, поэтому каждый слой обводим тонкой
# сглаженной линией своего же цвета — иначе на маленьком сердце края идут ступеньками.
# width — ширина сердца в пикселях; cracked — с трещиной посередине.
static func draw_heart(c: CanvasItem, center: Vector2, width: float, cracked := false) -> void:
	const RED := Color("ff3b55")
	const RED_LIGHT := Color("ff7a8a")
	const RED_DARK := Color("b0102a")
	const INK := Color("10224d")
	var k := width / 32.0
	var line := maxf(width * 0.075, 2.5)
	var depth := Vector2(0, width * 0.07)
	var shape := heart_shape(center - Vector2(0, 3.5 * k), k)
	smooth_polygon(c, shift(shape, depth), INK, line * 2.0)
	smooth_polygon(c, shape, INK, line * 2.0)
	smooth_polygon(c, shift(shape, depth), RED_DARK, 1.5)
	smooth_polygon(c, shape, RED, 1.5)
	# Светлая фаска: сердце поменьше и чуть выше.
	smooth_polygon(c, heart_shape(center - Vector2(0, 3.5 * k + width * 0.05), k * 0.78), RED_LIGHT.lerp(RED, 0.45), 1.5)
	smooth_polygon(c, heart_shape(center - Vector2(0, 3.5 * k + width * 0.02), k * 0.72), RED, 1.5)
	# Блики: вытянутый овал на левой половинке и точка рядом.
	c.draw_set_transform(center + Vector2(-8.5, -8.5) * k, -0.7, Vector2(4.2, 2.4) * k)
	c.draw_circle(Vector2.ZERO, 1.0, Color(1, 1, 1, 0.8), true, -1.0, true)
	c.draw_set_transform(Vector2.ZERO)
	c.draw_circle(center + Vector2(-3.5, -11) * k, 1.1 * k, Color(1, 1, 1, 0.8), true, -1.0, true)
	if cracked:
		var top := center + Vector2(0, -6.5) * k
		var crack := PackedVector2Array([top, top + Vector2(-2.6, 5) * k, top + Vector2(1.6, 9) * k,
				top + Vector2(-1.8, 14) * k, top + Vector2(-0.6, 18) * k])
		c.draw_polyline(crack, INK, line * 1.1, true)


static func heart_shape(center: Vector2, k: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 96:
		var p := center + ResultScreen.heart_point(TAU * i / 96) * k
		if points.is_empty() or p.distance_to(points[-1]) > 0.6:
			points.append(p)
	return points


static func shift(points: PackedVector2Array, by: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in points:
		out.append(p + by)
	return out


# Заливка с гладким краем: многоугольник плюс сглаженная обводка того же цвета.
static func smooth_polygon(c: CanvasItem, points: PackedVector2Array, color: Color, edge: float) -> void:
	c.draw_colored_polygon(points, color)
	var outline := points.duplicate()
	outline.append(points[0])
	c.draw_polyline(outline, color, edge, true)


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
	b.button_down.connect(play_click.bind(b))
	if action.is_valid():
		b.pressed.connect(action)
	return b


# Короткий «тук» при нажатии любой кнопки. Один плеер на всю игру живёт в корне дерева,
# поэтому звук не обрывается, когда кнопка переключает сцену.
static func play_click(from: Node) -> void:
	if not is_instance_valid(click_player):
		click_player = AudioStreamPlayer.new()
		click_player.stream = load("res://sounds/button_press.wav")
		click_player.volume_db = -8.0
		click_player.max_polyphony = 3
		click_player.process_mode = Node.PROCESS_MODE_ALWAYS
		from.get_tree().root.add_child(click_player)
	click_player.play()
	vibrate(12)


# Короткая вибрация телефона. В браузере работает на Android; на iPhone и компьютере
# браузер вибрацию не поддерживает, и вызов просто ничего не делает.
static func vibrate(ms: int) -> void:
	Input.vibrate_handheld(ms)


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
