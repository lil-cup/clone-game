class_name NoveltyScreen
extends Control

# «Новинка!» — знакомство с новым видом стрелка перед уровнем.
# Затемнение, крупный заголовок, за стрелком крутятся лучи, внизу пояснение и «Далее».

const RAYS := Color(0.75, 0.6, 1.0)
const BOX_SIZE := Vector2(250, 210)

# Что показываем: скрытого стрелка или связанную пару.
const HIDDEN := 0
const LINKED := 1
const PAIR := [Color("ff7a00"), Color("ffd400")]

var kind := HIDDEN

var content: Control
var rays: Control
var picture: Node2D  # Node2D, а не Control: контролы стоят на целых пикселях, и покачивание дёргалось
var title: Label
var button: Button
var on_close: Callable


static func make(text: String, what: int, closed: Callable) -> NoveltyScreen:
	var screen := NoveltyScreen.new()
	screen.kind = what
	screen.on_close = closed
	screen.build(text)
	return screen


func build(text: String) -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	process_mode = PROCESS_MODE_ALWAYS  # игра под ним стоит на паузе

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.75)
	dim.set_anchors_preset(PRESET_FULL_RECT)
	add_child(dim)

	content = Control.new()
	content.set_anchors_preset(PRESET_CENTER)
	content.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(content)

	rays = Control.new()
	rays.position = Vector2(0, -60)
	rays.draw.connect(func(): draw_rays(rays))
	content.add_child(rays)

	picture = Node2D.new()
	picture.position = Vector2(0, -60)
	picture.draw.connect(func(): draw_mystery(picture) if kind == HIDDEN else draw_pair(picture))
	content.add_child(picture)

	title = outlined("Новинка!", 96, 22)
	title.size = Vector2(700, 130)
	title.position = Vector2(-350, -390)
	title.pivot_offset = title.size / 2.0
	content.add_child(title)

	var caption := outlined(text, 34, 10)
	caption.size = Vector2(700, 100)
	caption.position = Vector2(-350, 140)
	content.add_child(caption)

	button = UI.button("Далее", UI.GREEN, close, Vector2(420, 120), 60, 34)
	button.add_theme_color_override("font_outline_color", ResultScreen.OUTLINE)
	button.add_theme_constant_override("outline_size", 14)
	button.position = Vector2(-210, 290)
	button.pivot_offset = Vector2(210, 60)
	content.add_child(button)


func outlined(text: String, font_size: int, outline: int) -> Label:
	var l := UI.label(text, font_size)
	l.uppercase = font_size >= 90
	l.add_theme_color_override("font_outline_color", ResultScreen.OUTLINE)
	l.add_theme_constant_override("outline_size", outline)
	return l


func close() -> void:
	button.disabled = true
	if on_close.is_valid():
		on_close.call()
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.2)
	t.tween_callback(queue_free)


# ---------- Анимация ----------

func _ready() -> void:
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.2)
	title.scale = Vector2.ZERO
	picture.scale = Vector2.ZERO
	button.scale = Vector2.ZERO
	var t := create_tween()
	t.tween_property(title, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(picture, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(button, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Стрелок покачивается, будто прячется.
	t.tween_callback(func():
		var wobble := picture.create_tween().set_loops()
		wobble.tween_property(picture, "rotation", 0.06, 0.8).set_trans(Tween.TRANS_SINE)
		wobble.tween_property(picture, "rotation", -0.06, 0.8).set_trans(Tween.TRANS_SINE))


func _process(delta: float) -> void:
	rays.rotation += delta * 0.3


# ---------- Рисование ----------

func draw_rays(c: Control) -> void:
	var clear := Color(RAYS, 0.0)
	for i in 14:
		var angle := TAU * i / 14
		var half := TAU / 14 * 0.22
		var points := PackedVector2Array([Vector2.ZERO, Vector2.from_angle(angle - half) * 420.0, Vector2.from_angle(angle + half) * 420.0])
		c.draw_polygon(points, PackedColorArray([Color(RAYS, 0.45), clear, clear]))
	for k in 5:
		c.draw_circle(Vector2.ZERO, 50.0 * (5 - k), Color(RAYS, 0.07))


# Скрытый стрелок: фиолетовый кубик со стволом сверху, как в игре, только плоский.
func draw_mystery(c: CanvasItem) -> void:
	draw_shooter(c, Vector2.ZERO, BOX_SIZE, Shooter.MYSTERY)
	# Вопросы рисуем прямо на картинке, а не надписями: надписи — контролы и при покачивании дёргались бы.
	var font: Font = preload("res://fonts/nunito_ui.tres")
	for mark in [[Vector2(-40, -10), 96], [Vector2(70, -70), 46], [Vector2(-95, 45), 38], [Vector2(80, 40), 40]]:
		var size: int = mark[1]
		var at: Vector2 = mark[0] + Vector2(-60, size * 0.36)
		c.draw_string_outline(font, at, "?", HORIZONTAL_ALIGNMENT_CENTER, 120, size, 12, Shooter.MYSTERY.darkened(0.45))
		c.draw_string(font, at, "?", HORIZONTAL_ALIGNMENT_CENTER, 120, size, Color(1, 1, 1, 0.85))


# Два стрелка рядом, их стволы соединяет дуга-трубка.
func draw_pair(c: CanvasItem) -> void:
	var box := BOX_SIZE * 0.78
	var left := Vector2(-box.x * 0.52, 10)
	var right := Vector2(box.x * 0.52, 30)
	var tube_center := (left + right) / 2.0 + Vector2(0, -box.y / 2.0 - 30)
	var radius := (right.x - left.x) / 2.0
	c.draw_arc(tube_center, radius, PI, TAU, 32, ResultScreen.OUTLINE, 34, true)
	c.draw_arc(tube_center, radius, PI, PI * 1.5, 16, PAIR[0].lightened(0.15), 22, true)
	c.draw_arc(tube_center, radius, PI * 1.5, TAU, 16, PAIR[1].lightened(0.15), 22, true)
	draw_shooter(c, left, box, PAIR[0])
	draw_shooter(c, right, box, PAIR[1])


func draw_shooter(c: CanvasItem, center: Vector2, box: Vector2, color: Color) -> void:
	var body := Rect2(center - box / 2.0, box)
	var barrel := Rect2(center + Vector2(-box.x * 0.136, -box.y / 2.0 - box.y * 0.22), Vector2(box.x * 0.27, box.y * 0.33))
	for part in [[barrel, 18], [body, 46]]:
		var style := StyleBoxFlat.new()
		style.bg_color = color
		style.border_color = color.darkened(0.35)
		style.border_width_bottom = 22
		style.set_corner_radius_all(part[1])
		style.anti_aliasing = true
		style.shadow_color = ResultScreen.OUTLINE
		style.shadow_size = 6
		c.draw_style_box(style, part[0])
	# Блик сверху слева.
	c.draw_line(body.position + Vector2(40, 22), body.position + Vector2(box.x * 0.48, 22), Color(1, 1, 1, 0.35), 12, true)
