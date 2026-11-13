class_name Game
extends Node3D

const MAX_ON_BELT := 5
const FIELD := 18.0          # сторона поля в мире — одна на всех уровнях, мельчают только блоки
const SPEED := 14.0          # единиц мира в секунду
const ENDGAME_SHOOTERS := 5  # когда стрелков осталось столько или меньше — лента ускоряется
const ENDGAME_BOOST := 1.8
const ACCELERATION := 6.0    # насколько быстро лента разгоняется (клеток/с за секунду)
const SPACING := 2.6         # расстояние между стрелками на ленте
const MOVE_TIME := 0.3
const COLUMN_STEP := Vector2(4.6, 3.6)
const SLOT_STEP := 4.0
const BIG := 1.5             # стрелки внизу крупнее, чем на ленте
const CAMERA_TILT := 62.0    # угол камеры к полу в градусах: 90 — строго сверху, меньше — видны бока блоков
const BOARD_COLOR := Color("2a2942")
const SLOT_COLOR := Color("2a2942")
const HUD_TEXT := Color.WHITE

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
var launch_sound: AudioStreamPlayer
var pop_sound: AudioStreamPlayer

var belt_label: Label
var belt_badge: Control
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
	piece_mesh = RoundedBox.make(grid.BLOCK_SIZE, grid.BLOCK_RADIUS, 1)
	slots.resize(Level.SLOTS)
	grid.build_level(level, FIELD)
	conveyor.build(FIELD, level.size)
	make_board_visuals()
	make_hud()
	make_sounds()

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
	conveyor.scroll(belt_speed * delta)
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
		flash(belt_badge)
		return
	if s.state == Shooter.State.IN_COLUMN:
		columns[s.column].erase(s)
		s.column = -1
		layout_columns(true)
	else:
		slots[s.slot] = null
		s.slot = -1
		compact_slots()
	s.state = Shooter.State.WAITING
	s.hop()
	pending.append(s)
	launch_sound.play()
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
		# false: таймер стоит, пока игра на паузе.
		get_tree().create_timer(0.8, false).timeout.connect(show_result.bind(true))

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
	bullet.position = s.muzzle_position()

	var t := create_tween()
	t.tween_property(bullet, "position", target, 0.12)
	t.tween_callback(func():
		bullet.queue_free()
		grid.remove_block(cell)
		pop_sound.play()
		pop_effect(target, Level.COLORS[s.color]))


func pop_effect(pos: Vector3, color: Color) -> void:
	var piece := MeshInstance3D.new()
	piece.mesh = piece_mesh
	piece.material_override = color_material(color)
	piece.position = pos
	piece.scale = grid.scale
	add_child(piece)
	var t := create_tween().set_parallel()
	t.tween_property(piece, "scale", Vector3.ZERO, 0.25)
	t.tween_property(piece, "position:y", pos.y + 1.5, 0.25)
	t.chain().tween_callback(piece.queue_free)


# ---------- Раскладка ----------

func bottom_edge() -> float:
	return conveyor.center + conveyor.road_width / 2.0


func slot_position(i: int) -> Vector3:
	return Vector3((i - (slots.size() - 1) / 2.0) * SLOT_STEP, 0, bottom_edge() + 4.9)


# Сдвигает стрелков в слотах влево, чтобы свободные места всегда были справа.
func compact_slots() -> void:
	var taken := slots.filter(func(s): return s != null)
	for i in slots.size():
		var s: Shooter = taken[i] if i < taken.size() else null
		slots[i] = s
		if s and s.slot != i:
			s.slot = i
			move(s, slot_position(i))


func column_position(c: int, tier: int) -> Vector3:
	return Vector3((c - (Level.COLUMNS - 1) / 2.0) * COLUMN_STEP.x, 0, bottom_edge() + 9.9 + tier * COLUMN_STEP.y)


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
		move(pending[i], conveyor.point(0.0) * Vector3(1, 0, 1) + Vector3(0, 0, 2.6 * (i + 1)))


func move(s: Shooter, to: Vector3) -> Tween:
	var t := create_tween()
	t.tween_property(s, "position", to, MOVE_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	return t


func rotation_towards(dir: Vector3) -> float:
	return atan2(-dir.x, -dir.z)


# ---------- Звуки ----------

# Звуки синтезирует tools/make_sounds.py.
func make_sounds() -> void:
	launch_sound = make_player(load("res://sounds/launch.wav"), 2)
	launch_sound.volume_db = -14.0
	# Несколько вариантов деревянного «тока» и небольшой разброс высоты, чтобы очередь не звучала механически.
	var pops := AudioStreamRandomizer.new()
	for n in 4:
		pops.add_stream(n, load("res://sounds/pop_%d.wav" % (n + 1)))
	pops.random_pitch = 1.06
	pop_sound = make_player(pops, 8)
	pop_sound.volume_db = -16.0


func make_player(stream: AudioStream, polyphony: int) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.max_polyphony = polyphony
	add_child(player)
	return player


# ---------- Оформление ----------

func make_board_visuals() -> void:
	var board := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(FIELD + 0.4, 0.2, FIELD + 0.4)
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
	var top := -bottom_edge() - 8.5
	var bottom := column_position(0, 2).z + 2.0
	var need_width := bottom_edge() * 2.0 + 2.0
	var need_height := bottom - top
	# На широком экране (браузер, компьютер) упираемся в высоту, на телефоне — в ширину.
	# Камера наклонена, поэтому глубина на экране сжимается в sin(угла) раз.
	var tilt := deg_to_rad(CAMERA_TILT)
	camera.rotation = Vector3(-tilt, 0, 0)
	camera.size = maxf(need_width, need_height * sin(tilt) * view.x / view.y)
	var visible_depth := camera.size * view.y / view.x / sin(tilt)
	var center := Vector3(0, 0, top + visible_depth / 2.0)
	camera.position = center + camera.basis.z * 60.0
	place_belt_badge()


# Значок счётчика — над слотами, по центру, в масштабе поля.
func place_belt_badge() -> void:
	var a := camera.unproject_position(Vector3(0, 0, bottom_edge() + 1.6))
	var b := camera.unproject_position(Vector3(1, 0, bottom_edge() + 1.6))
	var size := Vector2(110, 64)
	belt_badge.size = size
	belt_badge.pivot_offset = size / 2.0
	belt_badge.scale = Vector2.ONE * (b.x - a.x) * 1.9 / size.y
	belt_badge.position = a - size / 2.0


func screen_to_world(screen: Vector2) -> Vector3:
	var origin := camera.project_ray_origin(screen)
	var dir := camera.project_ray_normal(screen)
	return origin + dir * (-origin.y / dir.y)


# ---------- Интерфейс ----------

func make_hud() -> void:
	var hud := CanvasLayer.new()
	hud.process_mode = Node.PROCESS_MODE_ALWAYS  # кнопки паузы работают, пока игра стоит
	add_child(hud)

	var header := VBoxContainer.new()
	header.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	header.grow_horizontal = Control.GROW_DIRECTION_BOTH
	header.position.y = 14
	header.add_theme_constant_override("separation", 0)
	hud.add_child(header)
	var title := UI.label("Уровень %d" % (level_index + 1), 40)
	title.add_theme_color_override("font_color", HUD_TEXT)
	header.add_child(title)
	var info := UI.label("%s · сложность %d" % [level.name, level.difficulty + 1], 24)
	info.add_theme_color_override("font_color", HUD_TEXT)
	info.modulate = Color(1, 1, 1, 0.7)
	header.add_child(info)

	hud.add_child(make_pause_button())

	# Счётчик стрелков на ленте: белый значок над слотами (место задаёт fit_camera).
	belt_badge = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color.WHITE
	style.border_color = Color("2a2942")
	style.set_border_width_all(5)
	style.set_corner_radius_all(40)
	style.content_margin_left = 22
	style.content_margin_right = 22
	belt_badge.add_theme_stylebox_override("panel", style)
	belt_label = UI.label("", 40)
	belt_label.add_theme_color_override("font_color", Color("2a2942"))
	belt_badge.add_child(belt_label)
	hud.add_child(belt_badge)


	result_panel = ColorRect.new()
	result_panel.color = Color(0, 0, 0, 0.65)
	result_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	result_panel.hide()
	hud.add_child(result_panel)

	# Карточка с текстом и кнопками по центру экрана (и для итогов, и для паузы).
	var card := UI.card()
	card.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	card.grow_vertical = Control.GROW_DIRECTION_BOTH
	result_panel.add_child(card)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 20)
	card.add_child(box)

	result_title = UI.label("", 56)
	box.add_child(result_title)
	result_text = UI.label("", 30)
	box.add_child(result_text)
	result_buttons = VBoxContainer.new()
	result_buttons.add_theme_constant_override("separation", 14)
	box.add_child(result_buttons)


# Круглая кнопка паузы в левом верхнем углу: две белые полоски.
func make_pause_button() -> Button:
	var button := UI.button("", UI.PURPLE, show_pause, Vector2(88, 88), 36, 44)
	button.position = Vector2(24, 22)
	for x in [30, 50]:
		var bar := ColorRect.new()
		bar.color = Color.WHITE
		bar.size = Vector2(9, 32)
		bar.position = Vector2(x - 4.5, 24)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(bar)
	return button


func add_button(text: String, action: Callable, color: Color) -> void:
	result_buttons.add_child(UI.button(text, color, action))


# Показывает карточку поверх игры с новым набором кнопок.
func show_panel(title: String, text: String) -> void:
	result_title.text = title
	result_text.text = text
	result_text.visible = text != ""
	for b in result_buttons.get_children():
		b.queue_free()
	result_panel.show()
	result_panel.modulate.a = 0.0
	# Твин привязан к панели: она в HUD, который работает и на паузе.
	result_panel.create_tween().tween_property(result_panel, "modulate:a", 1.0, 0.3)


func show_result(won: bool) -> void:
	if finished:
		return
	finished = true

	if not won:
		show_panel("Упс!", "Нет места в слотах")
		add_button("Заново", restart, UI.ORANGE)
	elif level_index + 1 < Level.count():
		Progress.complete(level_index)
		show_panel("Молодец!", "Уровень %d пройден\nКартинка «%s» собрана" % [level_index + 1, level.name])
		add_button("Дальше", go_to_level.bind(level_index + 1), UI.GREEN)
	else:
		Progress.complete(level_index)
		show_panel("Поздравляем!", "Все уровни пройдены\nВсего %d %s" % [Level.count(), plural(Level.count(), "уровень", "уровня", "уровней")])
	add_button("В меню", go_to_menu, UI.PURPLE)


func show_pause() -> void:
	if finished:
		return
	get_tree().paused = true
	show_panel("Пауза", "")
	add_button("Продолжить", resume, UI.GREEN)
	add_button("Заново", restart, UI.ORANGE)
	add_button("В меню", go_to_menu, UI.PURPLE)


# Склонение по числу: 1 уровень, 2 уровня, 5 уровней, 21 уровень.
func plural(n: int, one: String, few: String, many: String) -> String:
	if n % 10 == 1 and n % 100 != 11:
		return one
	if n % 10 in [2, 3, 4] and not n % 100 in [12, 13, 14]:
		return few
	return many


func go_to_level(index: int) -> void:
	level_index = index
	restart()


func restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func resume() -> void:
	result_panel.hide()
	get_tree().paused = false


func go_to_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/menu.tscn")


func flash(label: CanvasItem) -> void:
	var t := create_tween()
	label.modulate = Color.RED
	t.tween_property(label, "modulate", Color.WHITE, 0.4)
