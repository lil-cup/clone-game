class_name CardScreen
extends Control

# Сиреневая карточка с фиолетовой шапкой поверх игры: посередине картинка в лучах,
# под ней подпись и зелёная кнопка. Из неё сделаны «Новый бустер» и «Вы уверены?».

const CARD := Color("c9c2ff")
const HEADER := Color("7a5ce6")
const WIDTH := 560.0

var title_text := ""
var caption_text := ""
var button_text := ""
var painter: Callable    # рисует картинку: painter.call(control), центр картинки — (0, 0)
var glow := Color.WHITE  # цвет лучей за картинкой
var sparkles := true
var on_ok: Callable
var on_cancel: Callable  # если задан — в шапке крестик

var content: Control
var stage: Control
var rays: Control
var icon: Node2D  # Node2D, а не Control: контролы стоят на целых пикселях, и покачивание дёргалось
var button: Button
var sparkle_wait := 0.3


# «Новый бустер»: подарок перед уровнем, где бустер открывается.
static func booster_gift(id: String, claimed: Callable) -> CardScreen:
	var screen := CardScreen.new()
	screen.title_text = "Новый бустер"
	screen.caption_text = BoosterBar.caption(id)
	screen.button_text = "Забрать!"
	screen.painter = func(c: CanvasItem): BoosterBar.draw_icon(id, c, Vector2.ZERO, 92.0)
	screen.on_ok = claimed
	screen.build()
	return screen


# «Ещё бустер»: бустеры кончились — можно взять ещё за монеты.
# Если монет не хватает, вместо покупки кнопка просто закрывает карточку.
static func buy_booster(id: String, bought: Callable, cancelled: Callable) -> CardScreen:
	var screen := CardScreen.new()
	screen.title_text = "Ещё бустер"
	var coins := Progress.coins()
	if coins >= Progress.BOOSTER_PRICE:
		screen.caption_text = BoosterBar.caption(id)
		screen.button_text = "За %d" % Progress.BOOSTER_PRICE
		screen.on_ok = bought
	else:
		screen.caption_text = "Нужно %d монет,\nа у тебя %d" % [Progress.BOOSTER_PRICE, coins]
		screen.button_text = "Понятно"
		screen.on_ok = cancelled
	screen.painter = func(c: CanvasItem): BoosterBar.draw_icon(id, c, Vector2.ZERO, 92.0)
	screen.on_cancel = cancelled
	screen.build()
	return screen


# «Вы уверены?»: выход из уровня стоит жизни.
static func lose_life(action: String, confirmed: Callable, cancelled: Callable) -> CardScreen:
	var screen := CardScreen.new()
	screen.title_text = "Вы уверены?"
	screen.caption_text = "Вы потеряете 1 жизнь"
	screen.button_text = action
	screen.painter = draw_broken_heart
	screen.glow = Color(1.0, 0.55, 0.65)
	screen.sparkles = false
	screen.on_ok = confirmed
	screen.on_cancel = cancelled
	screen.build()
	return screen


func build() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	process_mode = PROCESS_MODE_ALWAYS  # игра под ним стоит на паузе

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(PRESET_FULL_RECT)
	add_child(dim)

	content = Control.new()
	content.set_anchors_preset(PRESET_CENTER)
	content.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(content)

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", box_style(CARD, 40, 0, true))
	card.custom_minimum_size.x = WIDTH
	card.mouse_filter = MOUSE_FILTER_IGNORE
	content.add_child(card)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	card.add_child(column)

	var header := PanelContainer.new()
	var header_style := box_style(HEADER, 0, 18, false)
	header_style.corner_radius_top_left = 36
	header_style.corner_radius_top_right = 36
	header_style.border_width_bottom = 6
	header_style.border_color = HEADER.darkened(0.3)
	header.add_theme_stylebox_override("panel", header_style)
	header.add_child(outlined(title_text, 52, 14))
	column.add_child(header)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 18)
	var margin := MarginContainer.new()
	for side in ["left", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 34)
	margin.add_child(body)
	column.add_child(margin)

	stage = Control.new()
	stage.custom_minimum_size.y = 300
	stage.clip_contents = true
	stage.mouse_filter = MOUSE_FILTER_IGNORE
	body.add_child(stage)
	rays = Control.new()
	rays.draw.connect(func(): draw_rays(rays))
	stage.add_child(rays)
	icon = Node2D.new()
	icon.draw.connect(func(): painter.call(icon))
	stage.add_child(icon)
	stage.resized.connect(func():
		rays.position = stage.size / 2.0
		icon.position = stage.size / 2.0)

	body.add_child(outlined(caption_text, 36, 10))

	# Кнопка в обёртке: контейнер сбрасывает масштаб детям, а ей нужно выпрыгнуть.
	button = UI.button(button_text, UI.GREEN, ok, Vector2(360, 110), 54, 32)
	button.add_theme_color_override("font_outline_color", ResultScreen.OUTLINE)
	button.add_theme_constant_override("outline_size", 14)
	var holder := Control.new()
	holder.custom_minimum_size = button.get_combined_minimum_size()
	holder.size_flags_horizontal = SIZE_SHRINK_CENTER
	holder.mouse_filter = MOUSE_FILTER_IGNORE
	holder.add_child(button)
	body.add_child(holder)

	card.reset_size()
	card.position = -card.size / 2.0
	if on_cancel.is_valid():
		add_close(card)


# Тёмный крестик без кнопки-подложки в правом углу шапки.
func add_close(card: Control) -> void:
	var close := Button.new()
	close.custom_minimum_size = Vector2(72, 72)
	close.focus_mode = FOCUS_NONE
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		close.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	close.position = card.position + Vector2(card.size.x - 72 - 16, 14)
	close.button_down.connect(UI.play_click.bind(close))
	close.pressed.connect(cancel)
	var cross := Control.new()
	cross.position = Vector2(36, 36)
	cross.mouse_filter = MOUSE_FILTER_IGNORE
	cross.draw.connect(func():
		for d in [Vector2(1, 1), Vector2(1, -1)]:
			cross.draw_line(-d * 15, d * 15, HEADER.darkened(0.5), 12, true))
	close.add_child(cross)
	content.add_child(close)


func box_style(color: Color, radius: int, margin: int, border: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(margin)
	if border:
		style.border_color = ResultScreen.OUTLINE
		style.set_border_width_all(5)
		style.border_width_bottom = 12
	return style


func outlined(text: String, font_size: int, outline: int) -> Label:
	var l := UI.label(text, font_size)
	l.uppercase = font_size >= 50
	l.add_theme_color_override("font_outline_color", ResultScreen.OUTLINE)
	l.add_theme_constant_override("outline_size", outline)
	return l


func ok() -> void:
	close_with(on_ok)


func cancel() -> void:
	close_with(on_cancel)


func close_with(action: Callable) -> void:
	button.disabled = true
	mouse_filter = MOUSE_FILTER_IGNORE
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.2)
	t.tween_callback(func():
		if action.is_valid():
			action.call()
		queue_free())


# ---------- Анимация ----------

func _ready() -> void:
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.2)
	content.scale = Vector2.ONE * 1.12
	create_tween().tween_property(content, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	icon.scale = Vector2.ZERO
	button.scale = Vector2.ZERO
	await get_tree().process_frame
	button.pivot_offset = button.size / 2.0
	var t := create_tween()
	t.tween_interval(0.2)
	t.tween_property(icon, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(button, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Картинка плавно покачивается вверх-вниз.
	t.tween_callback(func():
		var bob := icon.create_tween().set_loops()
		bob.tween_property(icon, "position:y", icon.position.y - 8, 0.8).set_trans(Tween.TRANS_SINE)
		bob.tween_property(icon, "position:y", icon.position.y, 0.8).set_trans(Tween.TRANS_SINE))


func _process(delta: float) -> void:
	rays.rotation += delta * 0.3
	if not sparkles:
		return
	sparkle_wait -= delta
	if sparkle_wait <= 0.0:
		sparkle_wait = randf_range(0.2, 0.45)
		var spot := Vector2.from_angle(randf() * TAU) * randf_range(100, 140)
		Sparkle.spawn(stage, stage.size / 2.0 + spot, randf_range(10, 18))


func draw_rays(c: Control) -> void:
	var clear := Color(glow, 0.0)
	for i in 14:
		var angle := TAU * i / 14
		var half := TAU / 14 * 0.22
		var points := PackedVector2Array([Vector2.ZERO, Vector2.from_angle(angle - half) * 300.0, Vector2.from_angle(angle + half) * 300.0])
		c.draw_polygon(points, PackedColorArray([Color(glow, 0.6), clear, clear]))
	for k in 5:
		c.draw_circle(Vector2.ZERO, 32.0 * (5 - k), Color(glow, 0.1))


# Сердце с трещиной сверху вниз и «-1» сбоку.
static func draw_broken_heart(c: CanvasItem) -> void:
	UI.draw_heart(c, Vector2.ZERO, 210.0, true)

	var font: Font = UI.number_font()
	var at := Vector2(52, 62)
	c.draw_string_outline(font, at, "-1", HORIZONTAL_ALIGNMENT_LEFT, -1, 84, 22, ResultScreen.OUTLINE)
	c.draw_string(font, at, "-1", HORIZONTAL_ALIGNMENT_LEFT, -1, 84, Color.WHITE)
