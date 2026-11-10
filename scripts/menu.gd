extends Control

const BACKGROUND := Color("33324f")
const PATH_DONE := Color("6bcb77")
const PATH_LOCKED := Color("4b4778")
const LOCKED := Color("4b4778")
const NODE_SIZE := 120.0
const CURRENT_SIZE := 150.0
const STEP := 190.0      # расстояние между уровнями по вертикали
const WAVE := 160.0      # насколько дорожка виляет влево-вправо
const FREQUENCY := 0.9   # как часто виляет
const MARGIN := 150.0    # отступ сверху и снизу дорожки

var completed := 0
var scroll: ScrollContainer
var map: Control
var buttons: Array[Button] = []


func _ready() -> void:
	completed = Progress.completed()

	var background := ColorRect.new()
	background.color = BACKGROUND
	background.set_anchors_preset(PRESET_FULL_RECT)
	add_child(background)

	var layout := VBoxContainer.new()
	layout.set_anchors_preset(PRESET_FULL_RECT)
	layout.add_theme_constant_override("separation", 0)
	add_child(layout)

	var header := VBoxContainer.new()
	header.add_theme_constant_override("separation", 0)
	layout.add_child(padded(header, 24, 8))
	header.add_child(UI.label("Уровни", 56))
	var info := UI.label("Пройдено %d из %d" % [completed, Level.count()], 26)
	info.modulate = Color(1, 1, 1, 0.7)
	header.add_child(info)

	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.scroll_deadzone = 12  # чтобы прокрутка пальцем не нажимала кнопки
	layout.add_child(scroll)

	map = Control.new()
	map.size_flags_horizontal = SIZE_EXPAND_FILL
	map.custom_minimum_size.y = MARGIN * 2 + STEP * (Level.count() - 1)
	map.mouse_filter = MOUSE_FILTER_PASS
	map.draw.connect(draw_path)
	map.resized.connect(layout_levels)
	scroll.add_child(map)

	for i in Level.count():
		var b := make_level_button(i)
		map.add_child(b)
		buttons.append(b)

	if completed < Level.count():
		var play := UI.button("Играть · уровень %d" % (completed + 1), UI.GREEN, start.bind(completed), Vector2(460, 104), 40)
		play.size_flags_horizontal = SIZE_SHRINK_CENTER
		layout.add_child(padded(play, 12, 36))
	else:
		layout.add_child(padded(UI.label("Все уровни пройдены!", 40), 12, 40))

	await get_tree().process_frame
	layout_levels()
	scroll_to(mini(completed, Level.count() - 1))


func padded(control: Control, top: int, bottom: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_top", top)
	margin.add_theme_constant_override("margin_bottom", bottom)
	margin.add_child(control)
	return margin


func make_level_button(i: int) -> Button:
	var b: Button
	if i < completed:
		b = UI.button(str(i + 1), UI.GREEN, Callable(), Vector2.ONE * NODE_SIZE, 48, int(NODE_SIZE / 2))
		b.disabled = true
		b.add_theme_color_override("font_disabled_color", Color.WHITE)
	elif i == completed:
		b = UI.button(str(i + 1), UI.ORANGE, start.bind(i), Vector2.ONE * CURRENT_SIZE, 60, int(CURRENT_SIZE / 2))
	else:
		b = UI.button(str(i + 1), LOCKED, Callable(), Vector2.ONE * NODE_SIZE, 48, int(NODE_SIZE / 2))
		b.disabled = true
		b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.35))
		b.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)
	# Кнопки пропускают события дальше, иначе по ним нельзя прокручивать дорожку.
	b.mouse_filter = MOUSE_FILTER_PASS
	return b


# Точка дорожки: f — номер уровня (дробный — между уровнями). Первый уровень внизу.
func point_at(f: float) -> Vector2:
	var x := map.size.x / 2.0 + sin(f * FREQUENCY) * WAVE
	var y := map.size.y - MARGIN - f * STEP
	return Vector2(x, y)


func layout_levels() -> void:
	for i in buttons.size():
		var b := buttons[i]
		b.size = b.custom_minimum_size
		b.pivot_offset = b.size / 2.0
		b.position = point_at(i) - b.size / 2.0
	map.queue_redraw()

	# Текущий уровень «дышит», чтобы было видно, куда жать.
	if completed < buttons.size() and not buttons[completed].has_meta("pulse"):
		var b := buttons[completed]
		b.set_meta("pulse", true)
		var t := b.create_tween().set_loops()
		t.tween_property(b, "scale", Vector2.ONE * 1.08, 0.6).set_trans(Tween.TRANS_SINE)
		t.tween_property(b, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_SINE)


func draw_path() -> void:
	var done := PackedVector2Array()
	var locked := PackedVector2Array()
	var steps_per_level := 12
	for k in (Level.count() - 1) * steps_per_level + 1:
		var f := float(k) / steps_per_level
		var p := point_at(f)
		if f <= completed:
			done.append(p)
		if f >= completed:
			locked.append(p)
	if locked.size() > 1:
		map.draw_polyline(locked, PATH_LOCKED, 22, true)
	if done.size() > 1:
		map.draw_polyline(done, PATH_DONE, 22, true)


func scroll_to(i: int) -> void:
	scroll.scroll_vertical = int(point_at(i).y - scroll.size.y / 2.0)


func start(i: int) -> void:
	Game.level_index = i
	get_tree().change_scene_to_file("res://scenes/game.tscn")
