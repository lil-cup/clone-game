class_name BoosterBar
extends HBoxContainer

# Панель бустеров внизу экрана игры (появляется с Game.BOOSTERS_FROM-го уровня).
# Каждый бустер открывается со своего уровня, до этого его ячейка под замком.
# За уровень каждый бустер можно применить один раз. Кончились — можно купить (Progress.BOOSTER_PRICE).

const COLOR := Color("2f8ff0")
const LOCKED := Color("3a3f6b")
const BADGE := Color("1b4fc4")
const BADGE_EMPTY := Color("4cc46a")
const SIZE := Vector2(124, 124)

# id — какой бустер, level — с какого уровня (с единицы); до него ячейка под замком.
const KINDS := [
	{"id": "slot", "level": 3},
	{"id": "pick", "level": 9},
	{"id": "shuffle", "level": 15},
]

# Цвета значков.
const DISC_TOP := Color("e4edff")
const DISC_SIDE := Color("8ea7e6")
const DISC_MARK := Color("27357f")
const GLOVE := Color("eef3ff")
const GLOVE_SHADE := Color("a9bdf0")
const CUFF := Color("5b4fd6")

var game: Game
var buttons := {}  # id -> {button, badge, label}
var used := {}     # id -> true, если на этом уровне уже применён
var active_tween: Tween


static func make(for_game: Game) -> BoosterBar:
	var bar := BoosterBar.new()
	bar.game = for_game
	bar.build()
	return bar


static func unlocked(kind: Dictionary, level_index: int) -> bool:
	return kind.id != "" and level_index + 1 >= kind.level


static func caption(id: String) -> String:
	match id:
		"slot":
			return "+1 место на ленте"
		"pick":
			return "Выбери любую пушку\nв очереди"
	return "Перемешивает пушки\nв колонках"


static func hint(id: String) -> String:
	match id:
		"slot":
			return "Используй бустер, чтобы добавить\nодно место на ленту!"
		"pick":
			return "Используй бустер, чтобы выбрать\nлюбую пушку в очереди!"
	return "Используй бустер, чтобы перемешать\nпушки в колонках!"


static func draw_icon(id: String, c: CanvasItem, center: Vector2, r: float) -> void:
	match id:
		"slot":
			draw_slot_icon(c, center, r)
		"pick":
			draw_pick_icon(c, center, r)
		"shuffle":
			draw_shuffle_icon(c, center, r)


func build() -> void:
	add_theme_constant_override("separation", 22)
	set_anchors_and_offsets_preset(PRESET_CENTER_BOTTOM)
	grow_horizontal = GROW_DIRECTION_BOTH
	grow_vertical = GROW_DIRECTION_BEGIN
	offset_bottom = -28
	offset_top = offset_bottom - SIZE.y

	for kind in KINDS:
		if unlocked(kind, game.level_index):
			add_child(make_booster(kind.id))
		else:
			add_child(make_locked(kind.level))
	refresh()


func make_booster(id: String) -> Button:
	var b := UI.button("", COLOR, use.bind(id), SIZE, 36, 30)
	# Значок — Node2D: он «дышит», пока бустер ждёт цель, а контролы при этом дёргаются по пикселям.
	var icon := Node2D.new()
	icon.position = SIZE / 2.0 - Vector2(0, 6)
	icon.draw.connect(func(): draw_icon(id, icon, Vector2.ZERO, 40.0))
	b.add_child(icon)

	# Кружок со счётчиком в правом нижнем углу; пусто — зелёный плюс.
	var badge := Control.new()
	badge.position = SIZE - Vector2(14, 14)
	badge.mouse_filter = MOUSE_FILTER_IGNORE
	badge.draw.connect(func():
		var empty := Progress.boosters(id) == 0
		badge.draw_circle(Vector2.ZERO, 26, ResultScreen.OUTLINE)
		badge.draw_circle(Vector2.ZERO, 22, BADGE_EMPTY if empty else BADGE))
	b.add_child(badge)
	var label := UI.label("", 30)
	label.add_theme_color_override("font_outline_color", ResultScreen.OUTLINE)
	label.add_theme_constant_override("outline_size", 8)
	label.size = Vector2(52, 52)
	label.position = Vector2(-26, -28)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_child(label)
	buttons[id] = {"button": b, "icon": icon, "badge": badge, "label": label}
	return b


func make_locked(level: int) -> Button:
	var b := UI.button("", LOCKED, Callable(), SIZE, 36, 30)
	b.disabled = true
	var lock := Control.new()
	lock.position = Vector2(SIZE.x / 2.0, 46)
	lock.mouse_filter = MOUSE_FILTER_IGNORE
	lock.draw.connect(func(): draw_lock(lock))
	b.add_child(lock)
	var l := UI.label("Ур. %d" % level, 26)
	l.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	l.size = Vector2(SIZE.x, 30)
	l.position = Vector2(0, 76)
	b.add_child(l)
	return b


# Первый бустер, который уже открыт, но ещё не подарен.
func next_gift() -> String:
	for id in buttons:
		if not Progress.booster_gift_taken(id):
			return id
	return ""


func refresh() -> void:
	for id in buttons:
		var count := Progress.boosters(id)
		buttons[id].label.text = str(count) if count > 0 else "+"
		buttons[id].badge.queue_redraw()
		buttons[id].button.modulate = Color(1, 1, 1, 0.5) if used.has(id) else Color.WHITE


func button_of(id: String) -> Button:
	return buttons[id].button


func center_of(id: String) -> Vector2:
	var b := button_of(id)
	return b.global_position + b.size / 2.0


func use(id: String) -> void:
	var b := button_of(id)
	if game.finished or used.has(id):
		shake(b)
		return
	if Progress.boosters(id) <= 0:
		offer(id)
		return
	match id:
		"slot":
			spend(id)
			game.add_belt_slot()
		"shuffle":
			spend(id)
			game.shuffle_columns()
		"pick":
			# Второе нажатие — передумал выбирать. Бустер тратится, только когда стрелка выбрали.
			if game.picking:
				game.stop_picking()
			else:
				game.start_picking()


# Бустеров этого вида нет — предлагаем купить. Купленный добавляется к счётчику,
# а применяется, как обычно, нажатием на бустер.
func offer(id: String) -> void:
	game.get_tree().paused = true
	game.hud.add_child(CardScreen.buy_booster(id, func():
		game.get_tree().paused = false
		if Progress.buy_booster(id):
			refresh()
			bump(buttons[id].badge), func(): game.get_tree().paused = false))


# Кружок со счётчиком подпрыгивает, чтобы было видно, что бустер прибавился.
func bump(badge: Control) -> void:
	var t := badge.create_tween()
	t.tween_property(badge, "scale", Vector2.ONE * 1.5, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(badge, "scale", Vector2.ONE, 0.2)


func spend(id: String) -> void:
	Progress.use_booster(id)
	used[id] = true
	set_active(id, false)
	refresh()


# Бустер ждёт, пока игрок выберет цель: кнопка «дышит».
func set_active(id: String, on: bool) -> void:
	var icon: Node2D = buttons[id].icon
	if active_tween:
		active_tween.kill()
		active_tween = null
	icon.scale = Vector2.ONE
	if on:
		active_tween = icon.create_tween().set_loops()
		active_tween.tween_property(icon, "scale", Vector2.ONE * 1.18, 0.35).set_trans(Tween.TRANS_SINE)
		active_tween.tween_property(icon, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_SINE)


func shake(c: Control) -> void:
	c.pivot_offset = c.size / 2.0
	var t := c.create_tween()
	for x in [8.0, -8.0, 5.0, 0.0]:
		t.tween_property(c, "rotation", deg_to_rad(x), 0.05)


# ---------- Рисование ----------

func draw_lock(c: Control) -> void:
	var o := ResultScreen.OUTLINE
	c.draw_arc(Vector2(0, -6), 13, PI, TAU, 16, o, 12, true)
	c.draw_arc(Vector2(0, -6), 13, PI, TAU, 16, Color("c9d2ee"), 6, true)
	var body := StyleBoxFlat.new()
	body.bg_color = Color("c9d2ee")
	body.border_color = o
	body.set_border_width_all(4)
	body.set_corner_radius_all(8)
	c.draw_style_box(body, Rect2(-20, -8, 40, 32))
	c.draw_circle(Vector2(0, 6), 4, o)


# Значок «+1 место»: стопка из трёх дисков, на верхнем — плюс.
static func draw_slot_icon(c: CanvasItem, center: Vector2, r: float) -> void:
	var flat := 0.45            # во сколько раз диск сплющен по высоте
	var thick := r * 0.28       # толщина диска
	var step := r * 0.34        # насколько диски сдвинуты друг над другом
	var line := maxf(r * 0.08, 3.0)
	for k in 3:
		var top := center + Vector2(0, (1 - k) * step)
		var bottom := top + Vector2(0, thick)
		var ring := r + line
		# Обводка: нижний овал, бок и верхний овал чуть шире самого диска.
		ellipse(c, bottom, ring, flat, ResultScreen.OUTLINE)
		c.draw_rect(Rect2(top.x - ring, top.y, ring * 2.0, thick), ResultScreen.OUTLINE)
		ellipse(c, top, ring, flat, ResultScreen.OUTLINE)
		ellipse(c, bottom, r, flat, DISC_SIDE.darkened(0.15))
		c.draw_rect(Rect2(top.x - r, top.y, r * 2.0, thick), DISC_SIDE)
		ellipse(c, top, r, flat, DISC_TOP)
	# Плюс лежит на верхнем диске, поэтому сплющен так же.
	var top := center + Vector2(0, -step)
	c.draw_set_transform(top, 0, Vector2(1, flat))
	c.draw_rect(Rect2(-r * 0.5, -r * 0.14, r, r * 0.28), DISC_MARK)
	c.draw_rect(Rect2(-r * 0.14, -r * 0.5, r * 0.28, r), DISC_MARK)
	c.draw_set_transform(Vector2.ZERO)


# Значок «любой стрелок»: перчатка с поднятым большим пальцем и манжетой.
static func draw_pick_icon(c: CanvasItem, center: Vector2, r: float) -> void:
	var line := maxf(r * 0.1, 3.0)
	var s := r / 40.0
	var palm := Rect2(center + Vector2(-30, -6) * s, Vector2(52, 42) * s)
	var cuff := Rect2(center + Vector2(-34, 30) * s, Vector2(46, 16) * s)
	var thumb_from := center + Vector2(8, -4) * s
	var thumb_to := center + Vector2(14, -26) * s
	for layer in 2:
		var grow := line if layer == 0 else 0.0
		var skin := ResultScreen.OUTLINE if layer == 0 else GLOVE
		var dark := ResultScreen.OUTLINE if layer == 0 else GLOVE_SHADE
		capsule(c, thumb_from, thumb_to, 12 * s + grow, skin)
		var box := StyleBoxFlat.new()
		box.bg_color = dark
		box.set_corner_radius_all(int(16 * s + grow))
		box.anti_aliasing = true
		c.draw_style_box(box, palm.grow(grow))
		if layer == 1:
			box.bg_color = skin
			c.draw_style_box(box, Rect2(palm.position, palm.size - Vector2(0, 8 * s)))
			# Поджатые пальцы — полоски поперёк ладони.
			for k in 3:
				var y := palm.position.y + (8 + k * 11) * s
				c.draw_line(Vector2(palm.position.x + 4 * s, y), Vector2(palm.position.x + 24 * s, y), GLOVE_SHADE, 3 * s, true)
		box.bg_color = ResultScreen.OUTLINE if layer == 0 else CUFF
		box.set_corner_radius_all(int(6 * s + grow))
		c.draw_style_box(box, cuff.grow(grow))
	# Блик на пальце.
	c.draw_line(thumb_to + Vector2(-4, 6) * s, thumb_to + Vector2(-6, 16) * s, Color.WHITE, 4 * s, true)


# Значок «перемешать»: две толстые дуги-стрелки по кругу, навстречу друг другу.
static func draw_shuffle_icon(c: CanvasItem, center: Vector2, r: float) -> void:
	var ring := r * 0.7
	var width := r * 0.36
	var line := maxf(r * 0.09, 3.0)
	for layer in 2:
		var color := ResultScreen.OUTLINE if layer == 0 else Color("c8d8ff")
		var grow := line * 2.4 if layer == 0 else 0.0
		for half in 2:
			var start := PI * half + 0.35
			var finish := start + PI - 0.9
			c.draw_arc(center, ring, start, finish, 24, color, width + grow, true)
			# Наконечник в конце дуги, смотрит по ходу вращения.
			var tip := center + Vector2.from_angle(finish) * ring
			var along := Vector2.from_angle(finish + PI / 2.0)
			var out := Vector2.from_angle(finish)
			var head := r * 0.5 + grow
			c.draw_colored_polygon(PackedVector2Array([
				tip + along * head,
				tip + out * head * 0.95 - along * head * 0.15,
				tip - out * head * 0.95 - along * head * 0.15]), color)
	# Тень снизу на дугах.
	c.draw_arc(center, ring - width * 0.3, 0.5, PI - 0.6, 20, DISC_SIDE, width * 0.25, true)


static func capsule(c: CanvasItem, a: Vector2, b: Vector2, r: float, color: Color) -> void:
	var side := (b - a).normalized().orthogonal() * r
	c.draw_colored_polygon(PackedVector2Array([a + side, b + side, b - side, a - side]), color)
	c.draw_circle(a, r, color, true, -1.0, true)
	c.draw_circle(b, r, color, true, -1.0, true)


static func ellipse(c: CanvasItem, at: Vector2, r: float, flat: float, color: Color) -> void:
	c.draw_set_transform(at, 0, Vector2(1, flat))
	c.draw_circle(Vector2.ZERO, r, color, true, -1.0, true)
	c.draw_set_transform(Vector2.ZERO)
