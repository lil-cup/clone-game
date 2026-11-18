class_name ResultScreen
extends Control

# Итог уровня поверх игры: затемнение и синяя карточка с лентой.
# Победа: из-за ленты выскакивает кубок с крыльями и лучами, внутри монета награды.
# Проигрыш: из-за карточки выглядывает череп в облачке, сердце трескается пополам.

const BLUE := Color("2f8ff0")
const BLUE_DARK := Color("1b5fc4")
const RIBBON := Color("2a7be8")
const RIBBON_DARK := Color("174fa8")
const OUTLINE := Color("10224d")
const WING := Color("f4f9ff")
const WING_SHADE := Color("a9d4ff")
const GLOW := Color(1.0, 0.93, 0.55)
const HEART := Color("ef3b4f")
const HEART_DARK := Color("8f1022")
const BONE := Color("f3ead2")
const BONE_DARK := Color("6b4a3a")
const CLOUD := Color("8a8c99")
const CLOSE := Color("e0393e")
const RETRY := Color("ffb31f")

const BADGE_Y := -238.0    # кубок или череп над лентой
const RIBBON_Y := -140.0
const BADGE_SCALE := 1.3   # кубок и череп рисуются мелко, на экране их увеличиваем

var won := false
var dim: ColorRect
var content: Control
var rays: Control      # только у победы
var wings: Control     # только у победы
var cloud: Control     # только у проигрыша
var badge: Control     # кубок или череп
var stage: Control
var stage_rays: Control
var prize: Control     # монета или сердце
var amount: Label
var button: Button
var crack := 0.0       # насколько разошлись половинки сердца, 0..1
var sparkle_wait := 0.6


static func win(title: String, subtitle: String, reward: int, on_claim: Callable) -> ResultScreen:
	var screen := ResultScreen.new()
	screen.won = true
	screen.build(title, subtitle)
	screen.rays = screen.canvas(Vector2(0, BADGE_Y - 10), func(c): screen.draw_rays(c, 16, 300.0, GLOW))
	screen.wings = screen.canvas(Vector2(0, BADGE_Y), screen.draw_wings)
	screen.badge = screen.canvas(Vector2(0, BADGE_Y), screen.draw_trophy)
	var box := screen.add_card("Награда")
	var coin := CoinIcon.make(140)
	screen.amount = screen.outlined(str(reward), 64, 14)
	screen.add_stage(box, coin, Color(0.75, 0.9, 1.0))
	screen.stage.add_child(screen.amount)
	screen.add_button(box, "Забрать", UI.GREEN, on_claim)
	screen.add_ribbon()
	return screen


static func fail(title: String, on_retry: Callable, on_close: Callable) -> ResultScreen:
	var screen := ResultScreen.new()
	screen.build(title, "")
	screen.cloud = screen.canvas(Vector2(0, RIBBON_Y - 22), screen.draw_cloud)
	screen.badge = screen.canvas(Vector2(0, RIBBON_Y - 52), screen.draw_skull)
	var box := screen.add_card("")
	var heart := Control.new()
	heart.custom_minimum_size = Vector2(150, 140)
	heart.size = heart.custom_minimum_size
	heart.pivot_offset = heart.size / 2.0
	heart.draw.connect(func(): screen.draw_heart(heart))
	screen.add_stage(box, heart, Color(1.0, 0.75, 0.85))
	box.add_child(screen.make_divider("Не получилось"))
	screen.add_button(box, "Заново", RETRY, on_retry)
	screen.add_ribbon()
	screen.add_close(on_close)
	return screen


# ---------- Сборка ----------

var title_text := ""
var subtitle_text := ""
var card: PanelContainer


func build(title: String, subtitle: String) -> void:
	title_text = title
	subtitle_text = subtitle
	set_anchors_preset(PRESET_FULL_RECT)
	process_mode = PROCESS_MODE_ALWAYS

	dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(PRESET_FULL_RECT)
	add_child(dim)

	# Порядок детей важен: кубок и череп рисуются раньше карточки и ленты,
	# поэтому прячутся за ними, пока не выскочат.
	content = Control.new()
	content.set_anchors_preset(PRESET_CENTER)
	content.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(content)


func canvas(pos: Vector2, painter: Callable) -> Control:
	var c := Control.new()
	c.position = pos
	c.mouse_filter = MOUSE_FILTER_IGNORE
	c.draw.connect(func(): painter.call(c))
	content.add_child(c)
	return c


func add_card(heading: String) -> VBoxContainer:
	card = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = BLUE
	style.border_color = OUTLINE
	style.set_border_width_all(5)
	style.set_corner_radius_all(40)
	style.shadow_color = BLUE_DARK.darkened(0.3)
	style.shadow_offset = Vector2(0, 12)
	style.shadow_size = 1
	style.content_margin_top = 96 if won else 120
	style.content_margin_bottom = 36
	style.content_margin_left = 34
	style.content_margin_right = 34
	card.add_theme_stylebox_override("panel", style)
	card.custom_minimum_size.x = 540
	card.position = Vector2(-270, RIBBON_Y)
	card.mouse_filter = MOUSE_FILTER_IGNORE
	content.add_child(card)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 22)
	card.add_child(box)
	if heading != "":
		box.add_child(outlined(heading, 40, 10))
	return box


# Тёмная рамка с лучами и главным предметом посередине: монетой или сердцем.
func add_stage(box: VBoxContainer, item: Control, ray_color: Color) -> void:
	var frame := PanelContainer.new()
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = BLUE_DARK
	frame_style.set_corner_radius_all(28)
	frame.add_theme_stylebox_override("panel", frame_style)
	box.add_child(frame)

	stage = Control.new()
	stage.custom_minimum_size.y = 220
	stage.clip_contents = true
	stage.mouse_filter = MOUSE_FILTER_IGNORE
	frame.add_child(stage)
	stage_rays = Control.new()
	stage_rays.draw.connect(func(): draw_rays(stage_rays, 14, 260.0, ray_color))
	stage.add_child(stage_rays)
	prize = item
	prize.scale = Vector2.ZERO  # выпрыгнет позже
	stage.add_child(prize)
	stage.resized.connect(place_prize)


func place_prize() -> void:
	var center := stage.size / 2.0
	stage_rays.position = center
	prize.position = center - prize.size / 2.0
	if amount:
		amount.position = center + Vector2(4, 8)


# Надпись между двумя тонкими линиями с ромбиками на концах.
func make_divider(text: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	for side in 2:
		var line := Control.new()
		line.custom_minimum_size = Vector2(0, 20)
		line.size_flags_horizontal = SIZE_EXPAND_FILL
		line.draw.connect(func():
			var y := line.size.y / 2.0
			var tip := line.size.x if side == 0 else 0.0
			line.draw_line(Vector2(0, y), Vector2(line.size.x, y), OUTLINE, 4)
			UI.smooth_polygon(line, PackedVector2Array([
				Vector2(tip, y - 8), Vector2(tip + 8, y), Vector2(tip, y + 8), Vector2(tip - 8, y)]), OUTLINE, 1.5))
		row.add_child(line)
		if side == 0:
			row.add_child(outlined(text, 40, 10))
	return row


# Контейнер сбрасывает масштаб своим детям, поэтому кнопка лежит в простой обёртке,
# иначе она не сможет выпрыгнуть.
func add_button(box: VBoxContainer, text: String, color: Color, action: Callable) -> void:
	button = UI.button(text, color, action, Vector2(300, 92), 40)
	button.scale = Vector2.ZERO
	var holder := Control.new()
	holder.custom_minimum_size = button.get_combined_minimum_size()
	holder.size_flags_horizontal = SIZE_SHRINK_CENTER
	holder.mouse_filter = MOUSE_FILTER_IGNORE
	holder.add_child(button)
	box.add_child(holder)


func add_ribbon() -> void:
	var ribbon := canvas(Vector2(0, RIBBON_Y), draw_ribbon if won else draw_header)
	var text := VBoxContainer.new()
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.add_theme_constant_override("separation", -8)
	text.position = Vector2(-250, -62) if won else Vector2(-250, 0)
	text.size = Vector2(500, 112 if won else 96)
	text.mouse_filter = MOUSE_FILTER_IGNORE
	text.add_child(outlined(title_text, 52, 12))
	if subtitle_text != "":
		text.add_child(outlined(subtitle_text, 30, 9))
	ribbon.add_child(text)


# Красный крестик справа в шапке карточки.
func add_close(action: Callable) -> void:
	var close := UI.button("", CLOSE, action, Vector2(76, 76), 36, 20)
	close.position = Vector2(270 - 76 - 16, RIBBON_Y + 8)
	var cross := Control.new()
	cross.position = Vector2(38, 34)
	cross.mouse_filter = MOUSE_FILTER_IGNORE
	cross.draw.connect(func():
		for d in [Vector2(1, 1), Vector2(1, -1)]:
			cross.draw_line(-d * 13, d * 13, Color.WHITE, 9))
	close.add_child(cross)
	content.add_child(close)


func outlined(text: String, font_size: int, outline: int) -> Label:
	var l := UI.label(text, font_size)
	l.uppercase = true
	l.add_theme_color_override("font_outline_color", OUTLINE)
	l.add_theme_constant_override("outline_size", outline)
	return l


# ---------- Анимация ----------

func _ready() -> void:
	dim.modulate.a = 0.0
	create_tween().tween_property(dim, "modulate:a", 1.0, 0.25)

	# Карточка проявляется и чуть сжимается до своего размера.
	content.modulate.a = 0.0
	content.scale = Vector2.ONE * 1.12
	var t := create_tween().set_parallel()
	t.tween_property(content, "modulate:a", 1.0, 0.2)
	t.tween_property(content, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Кубок или череп выпрыгивает из-за ленты.
	var rest := badge.position.y
	badge.position.y = rest + 90
	badge.scale = Vector2.ONE * 0.6 * BADGE_SCALE
	t = create_tween()
	t.tween_interval(0.15)
	t.tween_property(badge, "position:y", rest, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(badge, "scale", Vector2.ONE * BADGE_SCALE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	if won:
		# Салют поверх затемнения, но под карточкой.
		var fireworks := Fireworks.make()
		add_child(fireworks)
		move_child(fireworks, dim.get_index() + 1)
		# Крылья раскрываются от кубка в стороны, за ним разгораются лучи.
		wings.scale = Vector2(0.0, 0.4) * BADGE_SCALE
		t = create_tween()
		t.tween_interval(0.35)
		t.tween_property(wings, "scale", Vector2.ONE * BADGE_SCALE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		rays.modulate.a = 0.0
		t = create_tween()
		t.tween_interval(0.4)
		t.tween_property(rays, "modulate:a", 1.0, 0.4)
	else:
		# Облачко пыли клубится вокруг черепа.
		cloud.scale = Vector2.ZERO
		t = create_tween()
		t.tween_interval(0.2)
		t.tween_property(cloud, "scale", Vector2.ONE * BADGE_SCALE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	await get_tree().process_frame
	place_prize()
	if amount:
		amount.pivot_offset = amount.size / 2.0
		amount.scale = Vector2.ZERO
	button.pivot_offset = button.size / 2.0
	t = create_tween()
	t.tween_interval(0.25)
	t.tween_property(prize, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if amount:
		t.tween_property(amount, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		# Сердце трескается: половинки расходятся, а само сердце вздрагивает.
		t.tween_method(set_crack, 0.0, 1.0, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(prize, "rotation", 0.12, 0.05)
		t.chain().tween_property(prize, "rotation", -0.08, 0.06)
		t.tween_property(prize, "rotation", 0.0, 0.06)
	t.tween_property(button, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func set_crack(value: float) -> void:
	crack = value
	prize.queue_redraw()


func _process(delta: float) -> void:
	stage_rays.rotation -= delta * 0.25
	if not won:
		return
	rays.rotation += delta * 0.35
	# Время от времени на монете и у кубка вспыхивают искорки.
	sparkle_wait -= delta
	if sparkle_wait <= 0.0:
		sparkle_wait = randf_range(0.25, 0.5)
		if randf() < 0.6:
			Sparkle.spawn(stage, stage.size / 2.0 + Vector2(randf_range(-55, 55), randf_range(-55, 55)), randf_range(10, 18))
		else:
			Sparkle.spawn(content, Vector2(randf_range(-110, 110), BADGE_Y + randf_range(-90, 30)), randf_range(10, 18))


# ---------- Рисование ----------

# Лучи из центра: узкие клинья, которые гаснут к краям.
func draw_rays(c: Control, count: int, radius: float, color: Color) -> void:
	var clear := Color(color, 0.0)
	for i in count:
		var angle := TAU * i / count
		var half := TAU / count * 0.22
		var points := PackedVector2Array([Vector2.ZERO, Vector2.from_angle(angle - half) * radius, Vector2.from_angle(angle + half) * radius])
		c.draw_polygon(points, PackedColorArray([Color(color, 0.55), clear, clear]))
	for k in 5:
		c.draw_circle(Vector2.ZERO, radius * 0.12 * (5 - k), Color(color, 0.07), true, -1.0, true)


# Два крыла по три пера, веером вверх и в стороны.
func draw_wings(c: Control) -> void:
	for side in [-1.0, 1.0]:
		for i in range(2, -1, -1):
			var angle := deg_to_rad(-15.0 - i * 30.0)
			var dir := Vector2(cos(angle) * side, sin(angle))
			var length := 112.0 - i * 14.0
			var center := Vector2(side * 34.0, -26.0) + dir * length * 0.5
			for layer in 2:
				var grow := 1.12 if layer == 0 else 1.0
				c.draw_set_transform(center, dir.angle(), Vector2(length / 2.0, 17.0 - i * 2.0) * grow)
				c.draw_circle(Vector2.ZERO, 1.0, WING_SHADE if layer == 0 else WING)
	c.draw_set_transform(Vector2.ZERO)


# Золотой кубок: ручки, чаша с бликом, ножка и подставка.
func draw_trophy(c: Control) -> void:
	for side in [-1.0, 1.0]:
		var from := -PI / 2 if side > 0 else PI / 2
		c.draw_arc(Vector2(side * 46, -34), 24, from, from + PI, 16, CoinIcon.RIM, 13, true)
		c.draw_arc(Vector2(side * 46, -34), 24, from, from + PI, 16, CoinIcon.GOLD, 6, true)
	var bowl := PackedVector2Array()
	for k in 17:
		var a := PI * k / 16
		bowl.append(Vector2(52 * cos(a), -64 + 66 * sin(a)))
	var outline := bowl.duplicate()
	outline.append(bowl[0])
	UI.smooth_polygon(c, bowl, CoinIcon.GOLD, 1.5)
	c.draw_polyline(outline, CoinIcon.RIM, 5, true)
	c.draw_rect(Rect2(-58, -74, 116, 16), CoinIcon.EDGE)
	c.draw_rect(Rect2(-58, -74, 116, 16), CoinIcon.RIM, false, 4)
	c.draw_line(Vector2(-32, -50), Vector2(-24, -18), CoinIcon.LIGHT, 9)
	c.draw_rect(Rect2(-10, 0, 20, 24), CoinIcon.EDGE)
	c.draw_rect(Rect2(-36, 22, 72, 14), CoinIcon.GOLD)
	c.draw_rect(Rect2(-44, 34, 88, 16), CoinIcon.RIM)


# Серое облачко пыли из нескольких кругов.
func draw_cloud(c: Control) -> void:
	var puffs := [Vector2(-78, 6), Vector2(-46, -14), Vector2(0, -24), Vector2(46, -14), Vector2(78, 6), Vector2(0, 8)]
	var sizes := [30.0, 38.0, 42.0, 38.0, 30.0, 44.0]
	for k in puffs.size():
		c.draw_circle(puffs[k] + Vector2(0, 5), sizes[k], CLOUD.darkened(0.25), true, -1.0, true)
	for k in puffs.size():
		c.draw_circle(puffs[k], sizes[k], CLOUD, true, -1.0, true)


# Мультяшный череп с ушками: круглая голова, челюсть с зубами, тёмные глазницы.
func draw_skull(c: Control) -> void:
	for side in [-1.0, 1.0]:
		UI.smooth_polygon(c, PackedVector2Array([
			Vector2(side * 30, -50), Vector2(side * 52, -78), Vector2(side * 54, -30)]), BONE_DARK, 1.5)
		UI.smooth_polygon(c, PackedVector2Array([
			Vector2(side * 33, -48), Vector2(side * 49, -70), Vector2(side * 50, -34)]), BONE, 1.5)
	c.draw_circle(Vector2(0, -20), 54, BONE_DARK, true, -1.0, true)
	c.draw_rect(Rect2(-32, 6, 64, 40), BONE_DARK)
	c.draw_circle(Vector2(0, -20), 49, BONE, true, -1.0, true)
	c.draw_rect(Rect2(-27, 6, 54, 35), BONE)
	for side in [-1.0, 1.0]:
		c.draw_circle(Vector2(side * 20, -18), 14, BONE_DARK, true, -1.0, true)
	UI.smooth_polygon(c, PackedVector2Array([Vector2(0, 2), Vector2(-6, 12), Vector2(6, 12)]), BONE_DARK, 1.5)
	for x in [-9.0, 9.0]:
		c.draw_line(Vector2(x, 26), Vector2(x, 41), BONE_DARK, 4)
	c.draw_line(Vector2(-27, 26), Vector2(27, 26), BONE_DARK, 4)


# Сердце из двух половинок, между ними зигзаг трещины.
# crack раздвигает половинки в стороны и чуть наклоняет их.
func draw_heart(c: Control) -> void:
	var center := c.size / 2.0
	var k := 4.2
	var right := PackedVector2Array()
	var left := PackedVector2Array()
	for i in 25:
		var t := PI * i / 24
		right.append(heart_point(t) * k)
		left.append(heart_point(PI + t) * k)
	# Трещина от нижнего кончика к ямке сверху. Концы трещины уже есть в контуре половинок,
	# поэтому берём только изломы между ними. Изломы начинаются повыше: у острого кончика
	# сердце узкое, и излом вылез бы за край.
	var top := heart_point(0) * k
	var tip := heart_point(PI) * k
	var zigzag := PackedVector2Array()
	for bend in [[0.3, 5.0], [0.5, -5.0], [0.7, 5.0], [0.85, -4.0]]:
		zigzag.append(tip.lerp(top, bend[0]) + Vector2(bend[1], 0))
	var right_half := right.duplicate()
	right_half.append_array(zigzag)
	var back := zigzag.duplicate()
	back.reverse()
	var left_half := left.duplicate()
	left_half.append_array(back)
	for half in [[right_half, 1.0], [left_half, -1.0]]:
		var side: float = half[1]
		c.draw_set_transform(center + Vector2(side * 7 * crack, 2 * crack), side * 0.1 * crack)
		var shape := without_crowding(half[0])
		var outline := shape.duplicate()
		outline.append(shape[0])
		UI.smooth_polygon(c, shape, HEART, 1.5)
		c.draw_polyline(outline, HEART_DARK, 5, true)
	# Блик на левой половинке.
	c.draw_set_transform(center + Vector2(-7 * crack - 30, -28), -0.6, Vector2(14, 8))
	c.draw_circle(Vector2.ZERO, 1.0, Color(1, 1, 1, 0.75))
	c.draw_set_transform(Vector2.ZERO)


# Убирает точки, стоящие почти вплотную к предыдущей: на таких заливка не может
# разбить контур на треугольники (у ямки и кончика сердца кривая их даёт).
func without_crowding(points: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in points:
		if out.is_empty() or p.distance_to(out[-1]) > 2.0:
			out.append(p)
	if out.size() > 1 and out[0].distance_to(out[-1]) <= 2.0:
		out.remove_at(out.size() - 1)
	return out


# Классическая кривая сердца, ямка сверху при t = 0, кончик снизу при t = PI.
static func heart_point(t: float) -> Vector2:
	var x := 16.0 * pow(sin(t), 3)
	var y := 13.0 * cos(t) - 5.0 * cos(2 * t) - 2.0 * cos(3 * t) - cos(4 * t)
	return Vector2(x, -y + 2.0)


# Лента с загнутыми хвостами по бокам.
func draw_ribbon(c: Control) -> void:
	for side in [-1.0, 1.0]:
		var tail := PackedVector2Array([
			Vector2(side * 220, -22), Vector2(side * 296, -22), Vector2(side * 270, 14),
			Vector2(side * 296, 50), Vector2(side * 220, 50)])
		UI.smooth_polygon(c, tail, RIBBON_DARK, 1.5)
		UI.smooth_polygon(c, PackedVector2Array([Vector2(side * 230, 48), Vector2(side * 250, 48), Vector2(side * 250, 66)]), OUTLINE, 1.5)
	var style := StyleBoxFlat.new()
	style.bg_color = RIBBON
	style.border_color = OUTLINE
	style.set_border_width_all(5)
	style.border_width_bottom = 12
	style.set_corner_radius_all(18)
	style.draw(c.get_canvas_item(), Rect2(-252, -64, 504, 122))


# Шапка карточки проигрыша: полоса во всю ширину со скруглёнными верхними углами.
func draw_header(c: Control) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = RIBBON
	style.border_color = OUTLINE
	style.set_border_width_all(5)
	style.border_width_bottom = 8
	style.corner_radius_top_left = 40
	style.corner_radius_top_right = 40
	style.draw(c.get_canvas_item(), Rect2(-270, 0, 540, 100))
