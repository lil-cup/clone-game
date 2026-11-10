extends Node3D

const MAX_ON_BELT := 5
const SPEED := 14.0          # клеток в секунду
const ENDGAME_SHOOTERS := 5  # когда стрелков осталось столько или меньше — лента ускоряется
const ENDGAME_BOOST := 1.8
const ACCELERATION := 6.0    # насколько быстро лента разгоняется (клеток/с за секунду)
const SPACING := 2.6         # расстояние между стрелками на ленте
const MOVE_TIME := 0.3
const COLUMN_STEP := Vector2(4.6, 3.6)
const SLOT_STEP := 4.0
const BIG := 1.5             # стрелки внизу крупнее, чем на ленте
const BOARD_COLOR := Color("2a2942")
const SLOT_COLOR := Color("2a2942")
const HUD_TEXT := Color.WHITE
const BUTTON_GREEN := Color("4cc46a")
const BUTTON_ORANGE := Color("ff9f43")
const BUTTON_PURPLE := Color("7d6fc4")

static var level_index := 0

@export var grid: Board
@export var conveyor: Conveyor
@export var camera: Camera3D

var level: Level
var columns: Array[Array] = []
var slots: Array = []
var pending: Array[Shooter] = []
var belt: Array[Shooter] = []
var entering := 0
var last_entry := -100.0
var finished := false
var belt_speed := SPEED
var materials := {}
var bullet_mesh := SphereMesh.new()
var piece_mesh: ArrayMesh

var belt_label: Label
var result_panel: Control
var result_title: Label
var result_text: Label
var result_buttons: VBoxContainer


func _ready() -> void:
	level = Level.load_map(level_index)
	bullet_mesh.radius = 0.25
	bullet_mesh.height = 0.5
	bullet_mesh.radial_segments = 12
	bullet_mesh.rings = 6
	piece_mesh = RoundedBox.make(grid.BLOCK_SIZE, grid.BLOCK_RADIUS, 2)
	slots.resize(level.settings.slots)
	grid.build_level(level)
	conveyor.build(level.size)
	make_board_visuals()
	make_hud()

	var rng := RandomNumberGenerator.new()
	rng.seed = Level.seed_for(level_index)
	for c in Level.COLUMNS:
		columns.append([])
	var data := level.make_columns(rng)
	for c in Level.COLUMNS:
		for item in data[c]:
			var s := Shooter.new()
			add_child(s)
			s.scale = Vector3.ONE * BIG
			s.setup(item.color, item.ammo)
			s.column = c
			columns[c].append(s)
	layout_columns(false)

	get_viewport().size_changed.connect(fit_camera)
	fit_camera()


func _process(delta: float) -> void:
	if finished:
		return
	var target := SPEED * ENDGAME_BOOST if shooters_left() <= ENDGAME_SHOOTERS else SPEED
	belt_speed = move_toward(belt_speed, target, ACCELERATION * delta)
	try_enter()
	for s in belt.duplicate():
		move_on_belt(s, delta)
	belt_label.text = "%d/%d" % [on_belt_count(), MAX_ON_BELT]


func _unhandled_input(event: InputEvent) -> void:
	if finished:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var s := pick(screen_to_world(event.position))
		if s:
			send_to_belt(s)


# ---------- Выбор и очередь ----------

func pick(point: Vector3) -> Shooter:
	var candidates: Array = []
	for col in columns:
		if not col.is_empty():
			candidates.append(col[0])
	for s in slots:
		if s and s.state == Shooter.State.IN_SLOT:
			candidates.append(s)
	for s: Shooter in candidates:
		var p := s.position
		if absf(p.x - point.x) < 1.8 and absf(p.z - point.z) < 1.8:
			return s
	return null


func send_to_belt(s: Shooter) -> void:
	if on_belt_count() >= MAX_ON_BELT:
		flash(belt_label)
		return
	if s.state == Shooter.State.IN_COLUMN:
		columns[s.column].erase(s)
		s.column = -1
		layout_columns(true)
	else:
		slots[s.slot] = null
		s.slot = -1
	s.state = Shooter.State.WAITING
	pending.append(s)
	layout_pending()


func try_enter() -> void:
	if pending.is_empty():
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - last_entry < SPACING / belt_speed:
		return
	# Не заезжаем, если кто-то заканчивает круг прямо у въезда.
	for b in belt:
		if b.distance > conveyor.length - SPACING - belt_speed * MOVE_TIME:
			return

	var s: Shooter = pending.pop_front()
	last_entry = now
	entering += 1
	s.state = Shooter.State.MOVING
	layout_pending()

	var t := move(s, conveyor.point(0.0))
	t.parallel().tween_property(s, "rotation:y", rotation_towards(conveyor.inward(0.0)), MOVE_TIME)
	t.parallel().tween_property(s, "scale", Vector3.ONE, MOVE_TIME)
	t.tween_callback(func():
		entering -= 1
		s.state = Shooter.State.ON_BELT
		s.distance = 0.0
		s.last_lane = Vector2i(-1, -1)
		belt.append(s))


func columns_empty() -> bool:
	return columns.all(func(col): return col.is_empty())


# Все стрелки, которые ещё не отстрелялись: в колонках, слотах и на ленте.
func shooters_left() -> int:
	var count := on_belt_count()
	for col in columns:
		count += col.size()
	for s in slots:
		if s:
			count += 1
	return count


func on_belt_count() -> int:
	return pending.size() + entering + belt.size()


# ---------- Лента и стрельба ----------

func move_on_belt(s: Shooter, delta: float) -> void:
	# Двигаемся маленькими шагами, чтобы не пропустить полосу при подлагивании.
	var left := belt_speed * delta
	while left > 0.0:
		var step := minf(left, 0.5)
		left -= step
		s.distance += step
		if s.distance >= conveyor.length:
			if columns_empty():
				s.distance -= conveyor.length  # брать больше некого — едет ещё круг
			else:
				finish_lap(s)
				return
		var lane: Vector2i = conveyor.lane_at(s.distance)
		if lane != s.last_lane:
			s.last_lane = lane
			if lane.x >= 0 and shoot(s, lane):
				return
	s.position = conveyor.point(s.distance)
	s.rotation.y = rotation_towards(conveyor.inward(s.distance))


# Возвращает true, если у стрелка кончились патроны.
func shoot(s: Shooter, lane: Vector2i) -> bool:
	var cell := level.first_block(lane.x, lane.y)
	if cell.x < 0 or level.get_cell(cell.x, cell.y) != s.color:
		return false

	level.remove(cell)
	s.ammo -= 1
	s.update_label()
	fire_projectile(s, cell)

	if level.blocks_left() == 0:
		get_tree().create_timer(0.8).timeout.connect(show_result.bind(true))

	if s.ammo > 0:
		return false
	belt.erase(s)
	s.state = Shooter.State.MOVING
	var t := create_tween()
	t.tween_property(s, "scale", Vector3.ZERO, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.tween_callback(s.queue_free)
	return true


func finish_lap(s: Shooter) -> void:
	belt.erase(s)
	var i := slots.find(null)
	if i == -1:
		show_result(false)
		return
	slots[i] = s
	s.slot = i
	s.state = Shooter.State.MOVING
	var t := move(s, slot_position(i))
	t.parallel().tween_property(s, "rotation:y", 0.0, MOVE_TIME)
	t.parallel().tween_property(s, "scale", Vector3.ONE * BIG, MOVE_TIME)
	t.tween_callback(func(): s.state = Shooter.State.IN_SLOT)


func fire_projectile(s: Shooter, cell: Vector2i) -> void:
	var target: Vector3 = grid.cell_to_world(cell)
	var bullet := MeshInstance3D.new()
	bullet.mesh = bullet_mesh
	bullet.material_override = color_material(Level.COLORS[s.color].lightened(0.3))
	add_child(bullet)
	bullet.position = s.position + Vector3.UP * 0.6

	var t := create_tween()
	t.tween_property(bullet, "position", target, 0.12)
	t.tween_callback(func():
		bullet.queue_free()
		grid.remove_block(cell)
		pop_effect(target, Level.COLORS[s.color]))


func pop_effect(pos: Vector3, color: Color) -> void:
	var piece := MeshInstance3D.new()
	piece.mesh = piece_mesh
	piece.material_override = color_material(color)
	piece.position = pos
	add_child(piece)
	var t := create_tween().set_parallel()
	t.tween_property(piece, "scale", Vector3.ZERO, 0.25)
	t.tween_property(piece, "position:y", pos.y + 1.5, 0.25)
	t.chain().tween_callback(piece.queue_free)


# ---------- Раскладка ----------

func bottom_edge() -> float:
	return conveyor.center + conveyor.road_width / 2.0


func slot_position(i: int) -> Vector3:
	return Vector3((i - (slots.size() - 1) / 2.0) * SLOT_STEP, 0, bottom_edge() + 3.0)


func column_position(c: int, tier: int) -> Vector3:
	return Vector3((c - (Level.COLUMNS - 1) / 2.0) * COLUMN_STEP.x, 0, bottom_edge() + 8.0 + tier * COLUMN_STEP.y)


func layout_columns(animated: bool) -> void:
	for c in Level.COLUMNS:
		for tier in columns[c].size():
			var s: Shooter = columns[c][tier]
			s.set_dimmed(tier > 0)
			if animated:
				move(s, column_position(c, tier))
			else:
				s.position = column_position(c, tier)


# Ожидающие въезда стоят стопкой под точкой въезда.
func layout_pending() -> void:
	for i in pending.size():
		move(pending[i], conveyor.point(0.0) + Vector3(0, 0, 2.6 * (i + 1)))


func move(s: Shooter, to: Vector3) -> Tween:
	var t := create_tween()
	t.tween_property(s, "position", to, MOVE_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	return t


func rotation_towards(dir: Vector3) -> float:
	return atan2(-dir.x, -dir.z)


# ---------- Оформление ----------

func make_board_visuals() -> void:
	var board := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(level.size + 0.4, 0.2, level.size + 0.4)
	board.mesh = box
	board.material_override = color_material(BOARD_COLOR)
	board.position.y = 0.05
	add_child(board)

	for i in slots.size():
		var slot := MeshInstance3D.new()
		var plate := BoxMesh.new()
		plate.size = Vector3(3.6, 0.1, 3.4)
		slot.mesh = plate
		slot.material_override = color_material(SLOT_COLOR)
		slot.position = slot_position(i)
		add_child(slot)


# Материалы кэшируются: выстрелов много, и создавать их каждый раз дорого (особенно в браузере).
func color_material(color: Color) -> StandardMaterial3D:
	if not materials.has(color):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		materials[color] = mat
	return materials[color]


func fit_camera() -> void:
	var view := get_viewport().get_visible_rect().size
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	# Что обязательно должно влезть: поле с лентой по ширине,
	# а по высоте — заголовок, поле, слоты и пара рядов стрелков.
	var top := -bottom_edge() - 4.0
	var bottom := column_position(0, 2).z + 2.0
	var need_width := bottom_edge() * 2.0 + 2.0
	var need_height := bottom - top
	# На широком экране (браузер, компьютер) упираемся в высоту, на телефоне — в ширину.
	camera.size = maxf(need_width, need_height * view.x / view.y)
	var visible_height := camera.size * view.y / view.x
	camera.position = Vector3(0, 60, top + visible_height / 2.0)


func screen_to_world(screen: Vector2) -> Vector3:
	var origin := camera.project_ray_origin(screen)
	var dir := camera.project_ray_normal(screen)
	return origin + dir * (-origin.y / dir.y)


# ---------- Интерфейс ----------

func make_hud() -> void:
	var hud := CanvasLayer.new()
	add_child(hud)

	var header := VBoxContainer.new()
	header.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	header.grow_horizontal = Control.GROW_DIRECTION_BOTH
	header.position.y = 14
	header.add_theme_constant_override("separation", 0)
	hud.add_child(header)
	var title := make_label("Уровень %d" % (level_index + 1), 40)
	title.add_theme_color_override("font_color", HUD_TEXT)
	header.add_child(title)
	var info := make_label("%s · сложность %d" % [level.name, level.difficulty + 1], 24)
	info.add_theme_color_override("font_color", HUD_TEXT)
	info.modulate = Color(1, 1, 1, 0.7)
	header.add_child(info)

	belt_label = make_label("", 32)
	belt_label.add_theme_color_override("font_color", HUD_TEXT)
	belt_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	belt_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	belt_label.position = Vector2(belt_label.position.x - 24, 26)
	hud.add_child(belt_label)

	result_panel = ColorRect.new()
	result_panel.color = Color(0, 0, 0, 0.65)
	result_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	result_panel.hide()
	hud.add_child(result_panel)

	# Карточка с текстом и кнопками по центру экрана.
	var card := PanelContainer.new()
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color("2a2942")
	card_style.border_color = Color("4b4778")
	card_style.set_border_width_all(4)
	card_style.set_corner_radius_all(36)
	card_style.set_content_margin_all(44)
	card.add_theme_stylebox_override("panel", card_style)
	card.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	card.grow_vertical = Control.GROW_DIRECTION_BOTH
	result_panel.add_child(card)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 20)
	card.add_child(box)

	result_title = make_label("", 56)
	box.add_child(result_title)
	result_text = make_label("", 30)
	box.add_child(result_text)
	result_buttons = VBoxContainer.new()
	result_buttons.add_theme_constant_override("separation", 14)
	box.add_child(result_buttons)


func make_label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func add_button(text: String, action: Callable, color: Color) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(380, 92)
	button.add_theme_font_size_override("font_size", 36)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_focus_color", Color.WHITE)
	button.add_theme_color_override("font_shadow_color", color.darkened(0.45))
	button.add_theme_constant_override("shadow_offset_y", 3)
	button.add_theme_stylebox_override("normal", button_style(color, false))
	button.add_theme_stylebox_override("hover", button_style(color.lightened(0.12), false))
	button.add_theme_stylebox_override("pressed", button_style(color.darkened(0.08), true))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.pressed.connect(action)
	result_buttons.add_child(button)


# Объёмная кнопка: тёмная «подошва» снизу, при нажатии кнопка опускается на неё.
func button_style(color: Color, pressed: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = color.darkened(0.35)
	style.set_corner_radius_all(26)
	style.border_width_bottom = 3 if pressed else 10
	style.content_margin_top = 14 if pressed else 8
	style.content_margin_bottom = 8
	style.content_margin_left = 32
	style.content_margin_right = 32
	return style


func show_result(won: bool) -> void:
	if finished:
		return
	finished = true

	if not won:
		result_title.text = "Упс!"
		result_text.text = "Нет места в слотах"
		add_button("Заново", restart, BUTTON_ORANGE)
	elif level_index + 1 < Level.count():
		result_title.text = "Молодец!"
		result_text.text = "Уровень %d пройден\nКартинка «%s» собрана" % [level_index + 1, level.name]
		add_button("Дальше", go_to_level.bind(level_index + 1), BUTTON_GREEN)
	else:
		result_title.text = "Поздравляем!"
		result_text.text = "Все %d уровней пройдены" % Level.count()
		add_button("Пройти заново", go_to_level.bind(0), BUTTON_GREEN)
		if not OS.has_feature("web"):  # из браузера игра закрыться не может
			add_button("Выйти", get_tree().quit, BUTTON_PURPLE)

	result_panel.show()
	result_panel.modulate.a = 0.0
	create_tween().tween_property(result_panel, "modulate:a", 1.0, 0.3)


func go_to_level(index: int) -> void:
	level_index = index
	restart()


func restart() -> void:
	get_tree().reload_current_scene()


func flash(label: Label) -> void:
	var t := create_tween()
	label.modulate = Color.RED
	t.tween_property(label, "modulate", Color.WHITE, 0.4)
