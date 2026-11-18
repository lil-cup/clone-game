class_name HexButton
extends Button

# Уровень на дорожке главного экрана: объёмный шестиугольник с номером.
# Тёмная «подошва» снизу, светлая фаска сверху; при нажатии кнопка опускается.

const NUMBER_FONT := preload("res://fonts/nunito_numbers.tres")
const DEPTH := 0.09  # высота подошвы, доля размера

var color := Color.WHITE
var number := ""
# Увеличение при «дыхании». Рисуем его сами в _draw, а не через scale узла:
# позиция контрола привязана к целым пикселям, и при scale кнопка дёргалась по пикселю.
var grow := 1.0:
	set(value):
		grow = value
		queue_redraw()


static func make(text: String, fill: Color, diameter: float) -> HexButton:
	var b := HexButton.new()
	b.number = text
	b.color = fill
	b.custom_minimum_size = Vector2.ONE * diameter
	b.focus_mode = FOCUS_NONE
	b.button_down.connect(UI.play_click.bind(b))
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	return b


func _draw() -> void:
	draw_set_transform(size / 2.0 * (1.0 - grow), 0.0, Vector2.ONE * grow)
	var r := minf(size.x, size.y) / 2.0
	var depth := r * 2.0 * DEPTH
	var c := size / 2.0 - Vector2(0, depth / 2.0)
	if is_pressed() and not disabled:
		c.y += depth * 0.6
	var fill := color.lightened(0.1) if is_hovered() and not disabled else color

	draw_hexagon(hexagon(c + Vector2(0, depth), r * 0.94), color.darkened(0.5))
	draw_hexagon(hexagon(c, r * 0.94), color.darkened(0.35))
	draw_hexagon(hexagon(c, r * 0.82), fill.lightened(0.35))
	draw_hexagon(hexagon(c + Vector2(0, r * 0.05), r * 0.78), fill)
	# Блик вдоль верхней левой грани (от левого верхнего угла к верхнему).
	var shine := hexagon(c, r * 0.68)
	draw_line(shine[22], shine[1], Color(1, 1, 1, 0.55), r * 0.07, true)

	var font_size := int(r * (0.62 if number.length() < 3 else 0.5))
	var width := size.x
	var base := Vector2(0, c.y + font_size * 0.36)
	draw_string_outline(NUMBER_FONT, base, number, HORIZONTAL_ALIGNMENT_CENTER, width, font_size,
			int(r * 0.16), color.darkened(0.6))
	draw_string(NUMBER_FONT, base, number, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, Color.WHITE)


# Заливка без сглаживания даёт «лесенку» по краям, поэтому обводим её тонкой сглаженной линией.
func draw_hexagon(points: PackedVector2Array, fill: Color) -> void:
	draw_colored_polygon(points, fill)
	var outline := points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, fill, 1.5, true)


# Шестиугольник остриём вверх со скруглёнными углами.
static func hexagon(center: Vector2, r: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var corner := r * 0.16
	for k in 6:
		var angle := -PI / 2.0 + TAU * k / 6.0
		# Центр скругления чуть ближе к середине, чем сам угол.
		var round_center := center + Vector2.from_angle(angle) * (r - corner / cos(PI / 6.0))
		for step in 4:
			var a := angle - PI / 6.0 + (PI / 3.0) * step / 3.0
			points.append(round_center + Vector2.from_angle(a) * corner)
	return points
