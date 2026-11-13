extends Control

# Главный экран: дорожка уровней без прокрутки. Видно только текущий уровень
# и пару следующих — назад отмотать и заглянуть далеко вперёд нельзя.

# Фон — яркий синий градиент от центра к краям, поверх бледные значки.
const BACKGROUND_CENTER := Color("3cc4ff")
const BACKGROUND_MIDDLE := Color("1a86f2")
const BACKGROUND_EDGE := Color("0d55c7")
const DOODLE := Color(1, 1, 1, 0.09)
const DOODLE_STEP := 170.0
const PATH := Color("ffc93a")
const PATH_EDGE := Color("b8720f")
const PLAY := Color("ffbe2e")
const NODE_SIZE := 150.0
const CURRENT_SIZE := 190.0
const STEP := 210.0       # расстояние между уровнями по вертикали
const AHEAD := 3          # сколько следующих уровней видно
const CURRENT_AT := 0.78  # высота текущего уровня (доля высоты дорожки сверху)
const DIFFICULTY_NAMES := ["Легко", "Средне", "Сложно"]
const DIFFICULTY_COLORS := [Color("2f80ff"), Color("ff8a1f"), Color("8b3ff0")]
const SETTINGS_COLOR := Color("17357a")
const COIN_DROPS := 10    # на сколько монеток делится награда, пока капает в счётчик

var completed := 0
var map: Control
var buttons: Array[HexButton] = []
var badge: PanelContainer
var coins_shown := 0
var coins_label: Label
var coins_icon: CoinIcon
var coin_sound: AudioStreamPlayer
var settings_panel: ColorRect
var settings_buttons: VBoxContainer
var settings_title: Label
var settings_text: Label


func _ready() -> void:
	completed = Progress.completed()
	var new_coins := Progress.take_coins_to_show()
	coins_shown = Progress.coins() - new_coins

	var background := TextureRect.new()
	background.texture = radial_gradient()
	background.stretch_mode = TextureRect.STRETCH_SCALE
	background.set_anchors_preset(PRESET_FULL_RECT)
	add_child(background)

	var doodles := Control.new()
	doodles.set_anchors_preset(PRESET_FULL_RECT)
	doodles.mouse_filter = MOUSE_FILTER_IGNORE
	doodles.draw.connect(func(): draw_doodles(doodles))
	add_child(doodles)

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
		var difficulty := difficulty_of(completed)
		badge = make_badge(DIFFICULTY_NAMES[difficulty], DIFFICULTY_COLORS[difficulty])
		map.add_child(badge)

		var play := UI.button("Играть", PLAY, start.bind(completed), Vector2(400, 124), 64, 34)
		play.add_theme_color_override("font_outline_color", PLAY.darkened(0.6))
		play.add_theme_constant_override("outline_size", 16)
		play.add_theme_constant_override("shadow_offset_y", 0)
		play.size_flags_horizontal = SIZE_SHRINK_CENTER
		layout.add_child(padded(play, 12, 64))
	else:
		var done := UI.label("Все уровни пройдены!", 44)
		done.add_theme_color_override("font_outline_color", BACKGROUND_EDGE.darkened(0.4))
		done.add_theme_constant_override("outline_size", 12)
		done.set_anchors_and_offsets_preset(PRESET_CENTER)
		done.grow_horizontal = GROW_DIRECTION_BOTH
		done.grow_vertical = GROW_DIRECTION_BOTH
		map.add_child(done)

	add_child(make_coins_counter())
	add_child(make_settings_button())
	make_settings_panel()
	coin_sound = AudioStreamPlayer.new()
	coin_sound.stream = load("res://sounds/coin.wav")
	coin_sound.max_polyphony = 4
	coin_sound.volume_db = -20.0
	add_child(coin_sound)

	await get_tree().process_frame
	layout_levels()
	if new_coins > 0:
		drop_coins(new_coins)


func difficulty_of(i: int) -> int:
	return mini(Level.load_map(i).difficulty, DIFFICULTY_NAMES.size() - 1)


func radial_gradient() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	gradient.colors = PackedColorArray([BACKGROUND_CENTER, BACKGROUND_MIDDLE, BACKGROUND_EDGE])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.15, 0.5)
	texture.width = 256
	texture.height = 256
	return texture


func padded(control: Control, top: int, bottom: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_top", top)
	margin.add_theme_constant_override("margin_bottom", bottom)
	margin.add_child(control)
	return margin


func make_level_button(i: int) -> HexButton:
	var current := i == completed
	# Дальние уровни чуть темнее (не прозрачнее, чтобы сквозь них не просвечивала дорожка).
	var fill: Color = DIFFICULTY_COLORS[difficulty_of(i)].darkened(0.1 * (i - completed))
	var b := HexButton.make(str(i + 1), fill, CURRENT_SIZE if current else NODE_SIZE)
	if current:
		b.pressed.connect(start.bind(i))
	else:
		b.disabled = true
	return b


# Плашка сложности под текущим уровнем.
func make_badge(text: String, color: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color.WHITE
	style.set_border_width_all(4)
	style.set_corner_radius_all(22)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 0
	style.content_margin_bottom = 2
	panel.add_theme_stylebox_override("panel", style)
	var l := UI.label(text, 28)
	l.add_theme_color_override("font_outline_color", color.darkened(0.5))
	l.add_theme_constant_override("outline_size", 8)
	panel.add_child(l)
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
		badge.position = point_at(0) + Vector2(-badge.size.x / 2.0, CURRENT_SIZE / 2.0 - 18)
	map.queue_redraw()

	# Текущий уровень «дышит», чтобы было видно, куда жать.
	if not buttons.is_empty() and not buttons[0].has_meta("pulse"):
		var b := buttons[0]
		b.set_meta("pulse", true)
		var t := b.create_tween().set_loops()
		t.tween_property(b, "scale", Vector2.ONE * 1.06, 0.6).set_trans(Tween.TRANS_SINE)
		t.tween_property(b, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_SINE)


func draw_path() -> void:
	if buttons.is_empty():
		return
	var current := point_at(0)
	# Мягкое свечение вокруг текущего уровня.
	for k in 6:
		map.draw_circle(current, CURRENT_SIZE * (0.62 + 0.09 * k), Color(1, 1, 1, 0.05))
	# Золотая дорожка от уровня к уровню, выше — до края экрана, всё бледнее.
	var top := buttons.size()
	for k in top:
		var from := point_at(k)
		var to := point_at(k + 1) if k + 1 < top else Vector2(from.x, 0)
		var alpha := 1.0 - 0.25 * k
		map.draw_line(from, to, Color(PATH_EDGE, alpha), 30)
		map.draw_line(from, to, Color(PATH, alpha), 18)


# Бледные значки по фону: рожицы, звёздочки, кубики, колечки. Раскладка одна и та же
# при каждом запуске, но без ровной сетки.
func draw_doodles(canvas: Control) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var cols := ceili(canvas.size.x / DOODLE_STEP) + 1
	var rows := ceili(canvas.size.y / DOODLE_STEP) + 1
	for row in rows:
		for col in cols:
			var shift := DOODLE_STEP / 2.0 if row % 2 else 0.0
			var c := Vector2(col * DOODLE_STEP + shift, row * DOODLE_STEP)
			c += Vector2(rng.randf_range(-30, 30), rng.randf_range(-30, 30))
			var r := rng.randf_range(24, 36)
			var turn := rng.randf_range(-0.5, 0.5)
			match (row * 3 + col) % 4:
				0:
					canvas.draw_arc(c, r, 0, TAU, 28, DOODLE, 5, true)
					for side in [-1, 1]:
						canvas.draw_circle(c + Vector2(side * r * 0.35, -r * 0.15).rotated(turn), r * 0.12, DOODLE)
					canvas.draw_arc(c, r * 0.55, 0.3 + turn, PI - 0.3 + turn, 12, DOODLE, 5, true)
				1:
					var star := PackedVector2Array()
					for k in 11:
						var rr := r if k % 2 == 0 else r * 0.45
						star.append(c + Vector2.from_angle(turn - PI / 2.0 + PI * k / 5.0) * rr)
					canvas.draw_polyline(star, DOODLE, 5, true)
				2:
					var hex := PackedVector2Array()
					for k in 7:
						hex.append(c + Vector2.from_angle(turn - PI / 2.0 + TAU * k / 6.0) * r)
					canvas.draw_polyline(hex, DOODLE, 5, true)
					for k in [1, 3, 5]:
						canvas.draw_line(c, hex[k], DOODLE, 5, true)
				_:
					canvas.draw_arc(c, r * 0.8, 0, TAU, 24, DOODLE, 5, true)
					canvas.draw_arc(c, r * 0.35, 0, TAU, 16, DOODLE, 5, true)


# ---------- Монеты ----------

# Счётчик монет в левом верхнем углу: тёмная плашка, монетка и число.
func make_coins_counter() -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.12, 0.35, 0.55)
	style.set_corner_radius_all(32)
	style.content_margin_left = 10
	style.content_margin_right = 26
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", style)
	panel.position = Vector2(24, 32)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	coins_icon = CoinIcon.make(56)
	row.add_child(coins_icon)
	coins_label = UI.label(str(coins_shown), 38)
	coins_label.add_theme_color_override("font_outline_color", BACKGROUND_EDGE.darkened(0.5))
	coins_label.add_theme_constant_override("outline_size", 10)
	row.add_child(coins_label)
	return panel


# Награда разлетается монетками из текущего уровня, и они по одной со звоном
# падают в счётчик.
func drop_coins(amount: int) -> void:
	var origin := map.global_position + (point_at(0) if not buttons.is_empty() else map.size / 2.0)
	var target := coins_icon.global_position + coins_icon.size / 2.0
	for i in COIN_DROPS:
		# Последняя монетка добирает остаток, чтобы в сумме вышло ровно amount.
		var value := amount / COIN_DROPS + (amount % COIN_DROPS if i == COIN_DROPS - 1 else 0)
		var coin := CoinIcon.make(60)
		add_child(coin)
		coin.position = origin - coin.size / 2.0
		coin.scale = Vector2.ZERO
		var spot := origin + Vector2.from_angle(TAU * i / COIN_DROPS) * randf_range(90, 160) - coin.size / 2.0
		var t := coin.create_tween()
		t.tween_property(coin, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(coin, "position", spot, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_interval(0.25 + i * 0.09)
		t.tween_property(coin, "position", target - coin.size / 2.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.parallel().tween_property(coin, "scale", Vector2.ONE * 0.8, 0.45)
		t.tween_callback(coin_arrived.bind(coin, value, i))


func coin_arrived(coin: CoinIcon, value: int, i: int) -> void:
	coin.queue_free()
	coins_shown += value
	coins_label.text = str(coins_shown)
	coin_sound.pitch_scale = 1.0 + i * 0.015
	coin_sound.play()
	var t := coins_icon.create_tween()
	t.tween_property(coins_icon, "scale", Vector2.ONE * 1.25, 0.06)
	t.tween_property(coins_icon, "scale", Vector2.ONE, 0.12)


# ---------- Настройки ----------

# Круглая кнопка с шестерёнкой в правом верхнем углу.
func make_settings_button() -> Button:
	var button := UI.button("", SETTINGS_COLOR, show_settings, Vector2(88, 88), 36, 44)
	button.set_anchors_and_offsets_preset(PRESET_TOP_RIGHT)
	button.grow_horizontal = GROW_DIRECTION_BEGIN
	button.position = Vector2(button.position.x - 24, 22)
	var gear := Control.new()
	gear.position = Vector2(44, 40)
	gear.mouse_filter = MOUSE_FILTER_IGNORE
	gear.draw.connect(func(): draw_gear(gear, SETTINGS_COLOR))
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
