class_name Tutorial
extends Control

# Обучение на первом уровне. Подсказки появляются по ходу игры:
# 1. В начале — рука на стрелке: нажми, и он поедет по ленте.
# 2. Лента впервые заполнилась — игра на паузе, объясняем лимит в 5 стрелков.
# 3. Стрелок впервые вернулся в слот с зарядами — рука на нём: его можно отправить снова.

const BUBBLE := Color("dcebff")
const BUBBLE_SHADE := Color("8fb3f0")
const AVATAR_RING := Color("9b6cf0")
const AVATAR_FACE := Color("ff9f43")

var game: Game
var hud: CanvasLayer
var dim: ColorRect
var bubble: PanelContainer
var bubble_text: Label
var hand: PointerHand
var target: Shooter   # на кого показывает рука
var waiting_tap := false
var belt_full_shown := false
var slot_shown := false
var basics := false        # подсказки первого уровня (start) — на других уровнях молчат
var booster_hand: PointerHand


static func make(for_game: Game, layer: CanvasLayer) -> Tutorial:
	var tutorial := Tutorial.new()
	tutorial.game = for_game
	tutorial.hud = layer
	tutorial.build()
	return tutorial


func build() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	process_mode = PROCESS_MODE_ALWAYS

	dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(PRESET_FULL_RECT)
	dim.hide()
	dim.gui_input.connect(func(event: InputEvent):
		if waiting_tap and event is InputEventMouseButton and event.pressed:
			resume())
	add_child(dim)

	bubble = make_bubble()
	add_child(bubble)
	bubble.hide()

	hand = PointerHand.make()
	add_child(hand)
	hand.hide()


# Плашка-подсказка: кружок с рожицей слева и текст.
func make_bubble() -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = BUBBLE
	style.border_color = ResultScreen.OUTLINE
	style.set_border_width_all(4)
	style.border_width_bottom = 10
	style.set_corner_radius_all(32)
	style.content_margin_left = 14
	style.content_margin_right = 26
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = MOUSE_FILTER_IGNORE

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	panel.add_child(row)
	var avatar := Control.new()
	avatar.custom_minimum_size = Vector2(96, 96)
	avatar.draw.connect(func(): draw_avatar(avatar))
	row.add_child(avatar)
	bubble_text = UI.label("", 30)
	bubble_text.add_theme_color_override("font_color", ResultScreen.OUTLINE)
	bubble_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	bubble_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bubble_text.size_flags_horizontal = SIZE_EXPAND_FILL
	bubble_text.size_flags_vertical = SIZE_FILL
	row.add_child(bubble_text)
	return panel


# Рожица стрелка в фиолетовом кольце: оранжевый кубик с глазками и улыбкой.
func draw_avatar(c: Control) -> void:
	var center := c.size / 2.0
	c.draw_circle(center, 48, ResultScreen.OUTLINE, true, -1.0, true)
	c.draw_circle(center, 44, AVATAR_RING, true, -1.0, true)
	c.draw_circle(center, 34, AVATAR_RING.lightened(0.5), true, -1.0, true)
	var face := Rect2(center - Vector2(26, 22), Vector2(52, 46))
	var box := StyleBoxFlat.new()
	box.bg_color = AVATAR_FACE
	box.border_color = AVATAR_FACE.darkened(0.35)
	box.border_width_bottom = 6
	box.set_corner_radius_all(14)
	box.anti_aliasing = true
	c.draw_style_box(box, face)
	for side in [-1, 1]:
		c.draw_circle(center + Vector2(side * 10, -4), 4.5, ResultScreen.OUTLINE, true, -1.0, true)
		c.draw_circle(center + Vector2(side * 9, -6), 1.6, Color.WHITE, true, -1.0, true)
		c.draw_circle(center + Vector2(side * 17, 6), 4, Color(1, 0.45, 0.45, 0.6), true, -1.0, true)
	c.draw_arc(center + Vector2(0, 4), 8, 0.25, PI - 0.25, 12, ResultScreen.OUTLINE, 4, true)


func say(text: String) -> void:
	bubble_text.text = text
	# Плашка по размеру текста, по центру экрана под заголовком уровня.
	var view := get_viewport_rect().size
	bubble.reset_size()
	bubble.position = Vector2((view.x - bubble.size.x) / 2.0, 120)
	if not bubble.visible:
		bubble.show()
		bubble.modulate.a = 0.0
		bubble.scale = Vector2.ONE * 0.9
		bubble.pivot_offset = bubble.size / 2.0
		var t := bubble.create_tween().set_parallel()
		t.tween_property(bubble, "modulate:a", 1.0, 0.2)
		t.tween_property(bubble, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func hush() -> void:
	if not bubble.visible:
		return
	var t := bubble.create_tween()
	t.tween_property(bubble, "modulate:a", 0.0, 0.2)
	t.tween_callback(bubble.hide)


func point_at(s: Shooter) -> void:
	target = s
	hand.show()


func stop_pointing() -> void:
	target = null
	hand.hide()


func _process(_delta: float) -> void:
	if target and is_instance_valid(target):
		# Кончик пальца — чуть ниже середины стрелка, чтобы цифра оставалась видна.
		hand.position = game.camera.unproject_position(target.global_position + Vector3(0.3, 0, 1.0))


# ---------- Шаги ----------

func start() -> void:
	basics = true
	var first := game.first_in_columns()
	if first:
		say("Нажми на стрелка — он поедет\nи собьёт блоки своего цвета")
		point_at(first)


# Игрок отправил стрелка на ленту.
func shooter_sent(s: Shooter) -> void:
	if not basics:
		return
	if s == target:
		stop_pointing()
		get_tree().create_timer(1.2, false).timeout.connect(func():
			if not target and not waiting_tap:
				hush())


func belt_full() -> void:
	if not basics or belt_full_shown:
		return
	belt_full_shown = true
	stop_pointing()
	say("На ленте одновременно\nмогут ехать 5 стрелков")
	pause_until_tap()


# Стрелок проехал круг, но патроны остались — он лёг в слот.
func landed_in_slot(s: Shooter) -> void:
	if not basics or slot_shown or waiting_tap:
		return
	slot_shown = true
	say("У стрелка остались заряды.\nНажми, чтобы отправить его снова!")
	point_at(s)


# Подарили бустер: затемняем всё, кроме панели бустеров, и показываем на него рукой.
# Игра стоит, пока бустер не нажмут.
func booster_hint(bar: BoosterBar, id: String) -> void:
	say(BoosterBar.hint(id))
	get_tree().paused = true
	dim.show()
	dim.modulate.a = 0.0
	dim.create_tween().tween_property(dim, "modulate:a", 1.0, 0.25)
	hud.move_child(self, -1)
	hud.move_child(bar, -1)
	booster_hand = PointerHand.make()
	hud.add_child(booster_hand)
	booster_hand.position = bar.center_of(id)


# Бустер из подсказки нажали: снимаем затемнение и объясняем, что дальше.
func booster_used(id: String) -> void:
	if not booster_hand:
		return
	booster_hand.queue_free()
	booster_hand = null
	get_tree().paused = false
	var t := dim.create_tween()
	t.tween_property(dim, "modulate:a", 0.0, 0.2)
	t.tween_callback(dim.hide)
	match id:
		"slot":
			say("Теперь на ленте %d мест!" % game.belt_limit)
			get_tree().create_timer(2.0, false).timeout.connect(hush)
		"shuffle":
			say("Стрелки перемешаны!")
			get_tree().create_timer(2.0, false).timeout.connect(hush)
		_:
			say("Нажми на любого стрелка в очереди —\nон сразу поедет на ленту")


# Стрелка выбрали бустером — подсказка больше не нужна.
func picked() -> void:
	if not waiting_tap:
		hush()


func pause_until_tap() -> void:
	waiting_tap = true
	get_tree().paused = true
	dim.show()
	dim.modulate.a = 0.0
	dim.create_tween().tween_property(dim, "modulate:a", 1.0, 0.25)
	# Счётчик ленты поднимаем над затемнением (подсказка сверху, он внизу — не пересекаются)
	# и даём ему вздрогнуть, чтобы было видно, о чём речь.
	var badge := game.belt_badge
	hud.move_child(self, badge.get_index())
	var base := badge.scale
	var t := badge.create_tween().set_loops(3)
	t.tween_property(badge, "scale", base * 1.2, 0.25)
	t.tween_property(badge, "scale", base, 0.25)


func resume() -> void:
	waiting_tap = false
	get_tree().paused = false
	var t := dim.create_tween()
	t.tween_property(dim, "modulate:a", 0.0, 0.2)
	t.tween_callback(dim.hide)
	hush()
