extends Control

# Главный экран: дорожка уровней без прокрутки. Видно только текущий уровень
# и пару следующих — назад отмотать и заглянуть далеко вперёд нельзя.

const BACKGROUND_TOP := Color("4a4590")
const BACKGROUND := Color("33324f")
const PATH := Color("4b4778")
const PATH_LIT := Color("ff9f43")
const LOCKED := Color("5a5590")
const NODE_SIZE := 110.0
const CURRENT_SIZE := 150.0
const STEP := 190.0       # расстояние между уровнями по вертикали
const AHEAD := 3          # сколько следующих уровней видно
const CURRENT_AT := 0.8   # высота текущего уровня (доля высоты дорожки сверху)
const DIFFICULTY_NAMES := ["Легко", "Средне", "Сложно"]
const DIFFICULTY_COLORS := [UI.GREEN, UI.ORANGE, Color("ff6b6b")]

var completed := 0
var map: Control
var buttons: Array[Button] = []
var badge: PanelContainer
var settings_panel: ColorRect
var settings_buttons: VBoxContainer
var settings_title: Label
var settings_text: Label


func _ready() -> void:
	completed = Progress.completed()

	var background := TextureRect.new()
	background.texture = vertical_gradient(BACKGROUND_TOP, BACKGROUND)
	background.stretch_mode = TextureRect.STRETCH_SCALE
	background.set_anchors_preset(PRESET_FULL_RECT)
	add_child(background)

	var layout := VBoxContainer.new()
	layout.set_anchors_preset(PRESET_FULL_RECT)
	layout.add_theme_constant_override("separation", 0)
	add_child(layout)

	map = Control.new()
	map.size_flags_vertical = SIZE_EXPAND_FILL
	map.clip_contents = true
	map.draw.connect(draw_path)
	map.resized.connect(layout_levels)
	layout.add_child(map)

	if completed < Level.count():
		for i in range(completed, mini(completed + AHEAD + 1, Level.count())):
			var b := make_level_button(i)
			map.add_child(b)
			buttons.append(b)
		badge = make_badge(DIFFICULTY_NAMES[mini(Level.load_map(completed).difficulty, 2)],
				DIFFICULTY_COLORS[mini(Level.load_map(completed).difficulty, 2)])
		map.add_child(badge)

		# Верхние уровни растворяются в фоне.
		var fade := TextureRect.new()
		fade.texture = vertical_gradient(BACKGROUND_TOP, Color(BACKGROUND_TOP, 0.0))
		fade.stretch_mode = TextureRect.STRETCH_SCALE
		fade.mouse_filter = MOUSE_FILTER_IGNORE
		fade.set_anchors_and_offsets_preset(PRESET_TOP_WIDE)
		fade.offset_bottom = 300
		map.add_child(fade)

		var play := UI.button("Играть", UI.GREEN, start.bind(completed), Vector2(420, 116), 52, 32)
		play.size_flags_horizontal = SIZE_SHRINK_CENTER
		layout.add_child(padded(play, 12, 56))
	else:
		var done := UI.label("Все уровни пройдены!", 44)
		done.set_anchors_and_offsets_preset(PRESET_CENTER)
		done.grow_horizontal = GROW_DIRECTION_BOTH
		done.grow_vertical = GROW_DIRECTION_BOTH
		map.add_child(done)

	add_child(make_settings_button())
	make_settings_panel()

	await get_tree().process_frame
	layout_levels()


func vertical_gradient(top: Color, bottom: Color) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, top)
	gradient.set_color(1, bottom)
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0, 0)
	texture.fill_to = Vector2(0, 1)
	return texture


func padded(control: Control, top: int, bottom: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_top", top)
	margin.add_theme_constant_override("margin_bottom", bottom)
	margin.add_child(control)
	return margin


func make_level_button(i: int) -> Button:
	var b: Button
	if i == completed:
		b = UI.button(str(i + 1), UI.ORANGE, start.bind(i), Vector2.ONE * CURRENT_SIZE, 64, int(CURRENT_SIZE / 2))
	else:
		b = UI.button(str(i + 1), LOCKED, Callable(), Vector2.ONE * NODE_SIZE, 48, int(NODE_SIZE / 2))
		b.disabled = true
		b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.6))
	return b


# Плашка сложности под текущим уровнем.
func make_badge(text: String, color: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = color.darkened(0.25)
	style.border_color = color.darkened(0.5)
	style.set_border_width_all(3)
	style.set_corner_radius_all(18)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 2
	style.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", style)
	panel.add_child(UI.label(text, 26))
	return panel


# Позиция уровня на дорожке: k — сколько уровней вперёд от текущего.
func point_at(k: int) -> Vector2:
	return Vector2(map.size.x / 2.0, map.size.y * CURRENT_AT - k * STEP)


func layout_levels() -> void:
	for k in buttons.size():
		var b := buttons[k]
		b.size = b.custom_minimum_size
		b.pivot_offset = b.size / 2.0
		b.position = point_at(k) - b.size / 2.0
	if badge:
		badge.size = badge.get_combined_minimum_size()
		badge.position = point_at(0) + Vector2(-badge.size.x / 2.0, CURRENT_SIZE / 2.0 - 4)
	map.queue_redraw()

	# Текущий уровень «дышит», чтобы было видно, куда жать.
	if not buttons.is_empty() and not buttons[0].has_meta("pulse"):
		var b := buttons[0]
		b.set_meta("pulse", true)
		var t := b.create_tween().set_loops()
		t.tween_property(b, "scale", Vector2.ONE * 1.08, 0.6).set_trans(Tween.TRANS_SINE)
		t.tween_property(b, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_SINE)


func draw_path() -> void:
	if buttons.is_empty():
		return
	var current := point_at(0)
	# Подсвеченный отрезок к следующему уровню, дальше — тёмная дорожка до верха экрана.
	map.draw_line(current, Vector2(current.x, 0), PATH, 22)
	if buttons.size() > 1:
		map.draw_line(current, point_at(1), PATH_LIT, 22)
	map.draw_circle(current, CURRENT_SIZE / 2.0 + 14, Color(PATH_LIT, 0.25))


# ---------- Настройки ----------

# Круглая кнопка с шестерёнкой в правом верхнем углу.
func make_settings_button() -> Button:
	var button := UI.button("", UI.PURPLE, show_settings, Vector2(88, 88), 36, 44)
	button.set_anchors_and_offsets_preset(PRESET_TOP_RIGHT)
	button.grow_horizontal = GROW_DIRECTION_BEGIN
	button.position = Vector2(button.position.x - 24, 22)
	var gear := Control.new()
	gear.position = Vector2(44, 40)
	gear.mouse_filter = MOUSE_FILTER_IGNORE
	gear.draw.connect(func(): draw_gear(gear, UI.PURPLE))
	button.add_child(gear)
	return button


func draw_gear(canvas: Control, hole: Color) -> void:
	var teeth := 8
	for k in teeth:
		var angle := TAU * k / teeth
		var dir := Vector2.from_angle(angle)
		var side := dir.orthogonal() * 5.0
		var points := PackedVector2Array([dir * 12 - side, dir * 22 - side, dir * 22 + side, dir * 12 + side])
		canvas.draw_colored_polygon(points, Color.WHITE)
	canvas.draw_circle(Vector2.ZERO, 16, Color.WHITE)
	canvas.draw_circle(Vector2.ZERO, 7, hole)


# Затемнение и карточка по центру, как пауза в игре.
func make_settings_panel() -> void:
	settings_panel = ColorRect.new()
	settings_panel.color = Color(0, 0, 0, 0.65)
	settings_panel.set_anchors_preset(PRESET_FULL_RECT)
	settings_panel.hide()
	add_child(settings_panel)

	var card := UI.card()
	card.set_anchors_and_offsets_preset(PRESET_CENTER)
	card.grow_horizontal = GROW_DIRECTION_BOTH
	card.grow_vertical = GROW_DIRECTION_BOTH
	settings_panel.add_child(card)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 20)
	card.add_child(box)
	settings_title = UI.label("", 56)
	box.add_child(settings_title)
	settings_text = UI.label("", 30)
	box.add_child(settings_text)
	settings_buttons = VBoxContainer.new()
	settings_buttons.add_theme_constant_override("separation", 14)
	box.add_child(settings_buttons)


func show_settings_card(title: String, text: String, actions: Array) -> void:
	settings_title.text = title
	settings_text.text = text
	settings_text.visible = text != ""
	for b in settings_buttons.get_children():
		b.queue_free()
	for a in actions:
		settings_buttons.add_child(UI.button(a[0], a[1], a[2]))
	if not settings_panel.visible:
		settings_panel.show()
		settings_panel.modulate.a = 0.0
		settings_panel.create_tween().tween_property(settings_panel, "modulate:a", 1.0, 0.3)


func show_settings() -> void:
	show_settings_card("Настройки", "", [
		["Сбросить прогресс", UI.ORANGE, confirm_reset],
		["Назад", UI.PURPLE, settings_panel.hide],
	])


func confirm_reset() -> void:
	show_settings_card("Сбросить?", "Все пройденные уровни\nснова станут закрыты", [
		["Да, сбросить", UI.ORANGE, reset_progress],
		["Отмена", UI.PURPLE, show_settings],
	])


func reset_progress() -> void:
	Progress.reset()
	get_tree().reload_current_scene()


func start(i: int) -> void:
	Game.level_index = i
	get_tree().change_scene_to_file("res://scenes/game.tscn")
