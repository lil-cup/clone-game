class_name Game
extends Node3D

const MAX_ON_BELT := 5
const FIELD := 18.0          # сторона поля в мире — одна на всех уровнях, мельчают только блоки
const SPEED := 14.0          # единиц мира в секунду
const ENDGAME_SHOOTERS := 5  # колонки и слоты пусты, а на ленте столько или меньше — лента ускоряется
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
const HIDDEN_FROM := 1       # уровень (с нуля), где впервые появляются скрытые стрелки
const BOOSTERS_FROM := 2     # с какого уровня (с нуля) видна панель бустеров

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
var reward_claimed := false
var belt_speed := SPEED
var link_cylinder: CylinderMesh
var link_sphere: SphereMesh
var links: Array[Dictionary] = []  # {a, b, tube} — связанные пары в колонках
var materials := {}
var bullet_mesh := SphereMesh.new()
var piece_mesh: ArrayMesh
var launch_sound: AudioStreamPlayer
var pop_sound: AudioStreamPlayer
var win_sound: AudioStreamPlayer
var fail_sound: AudioStreamPlayer

var hud: CanvasLayer
var tutorial: Tutorial  # только на первом уровне, пока он не пройден
var booster_bar: BoosterBar
var picking := false  # включён бустер «любой стрелок»: ждём, кого выберут
var belt_limit := MAX_ON_BELT  # бустер добавляет к нему место
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
	var pairs := {}  # номер пары -> первый из пары
	for c in Level.COLUMNS:
		for item in data[c]:
			var s := Shooter.new()
			add_child(s)
			s.scale = Vector3.ONE * BIG
			s.setup(item.color, item.ammo)
			s.rotation.y = PI  # мордой к игроку
			s.face_player(true, false)
			s.hideable = item.hide
			s.column = c
			columns[c].append(s)
			if item.has("pair"):
				if pairs.has(item.pair):
					link(pairs[item.pair], s)
				else:
					pairs[item.pair] = s
	layout_columns(false)
	update_links()

	get_viewport().size_changed.connect(fit_camera)
	fit_camera()
	update_belt_label()

	if level_index == 0 and Progress.completed() == 0:
		tutorial = Tutorial.make(self, hud)
		hud.add_child(tutorial)
		tutorial.start()
	# Уровень, где впервые появляются скрытые стрелки: сначала объясняем, игра ждёт.
	if level_index == HIDDEN_FROM and Progress.completed() <= HIDDEN_FROM:
		get_tree().paused = true
		hud.add_child(NoveltyScreen.make("Эта пушка скрывает свой цвет!\nОна откроется, когда выйдет вперёд",
				NoveltyScreen.HIDDEN, func(): get_tree().paused = false))
	if level_index == Level.LINKS_FROM and Progress.completed() <= Level.LINKS_FROM:
		get_tree().paused = true
		hud.add_child(NoveltyScreen.make("Связанные пушки едут на ленту вместе!\nОбе должны стоять впереди",
				NoveltyScreen.LINKED, func(): get_tree().paused = false))
	# Новый бустер дарим один раз, а потом показываем, как им пользоваться (игра ждёт).
	var gift := booster_bar.next_gift() if booster_bar else ""
	if gift != "":
		get_tree().paused = true
		hud.add_child(CardScreen.booster_gift(gift, func():
			Progress.take_booster_gift(gift)
			booster_bar.refresh()
			if not tutorial:
				tutorial = Tutorial.make(self, hud)
				hud.add_child(tutorial)
			tutorial.booster_hint(booster_bar, gift)))


func _process(delta: float) -> void:
	update_links()
	if finished:
		return
	var target := SPEED * ENDGAME_BOOST if endgame() else SPEED
	belt_speed = move_toward(belt_speed, target, ACCELERATION * delta)
	conveyor.scroll(belt_speed * delta)
	try_enter()
	for s in belt.duplicate():
		move_on_belt(s, delta)
	update_belt_label()


func _unhandled_input(event: InputEvent) -> void:
	if finished:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var point := screen_to_world(event.position)
		if picking:
			var any := pick_in_columns(point)
			if any:
				UI.play_click(self)
				pick_any(any)
			return
		var s := pick(point)
		if s:
			UI.play_click(self)
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


# Любой стрелок в колонках, не только передний (для бустера).
func pick_in_columns(point: Vector3) -> Shooter:
	for col in columns:
		for s: Shooter in col:
			if absf(s.position.x - point.x) < 1.8 and absf(s.position.z - point.z) < 1.8:
				return s
	return null


func send_to_belt(s: Shooter) -> void:
	var group: Array[Shooter] = [s]
	if s.partner:
		# Пара уезжает только вместе, и напарник тоже должен быть под рукой:
		# впереди своей колонки или в слоте.
		if not can_go(s.partner):
			s.wiggle()
			s.partner.wiggle()
			return
		group.append(s.partner)
	if on_belt_count() + group.size() > belt_limit:
		flash(belt_badge)
		return
	for one in group:
		launch(one)
	if tutorial:
		tutorial.shooter_sent(s)
		if on_belt_count() >= belt_limit:
			tutorial.belt_full()


func can_go(s: Shooter) -> bool:
	if s.state == Shooter.State.IN_SLOT:
		return true
	return s.state == Shooter.State.IN_COLUMN and columns[s.column].front() == s


func launch(s: Shooter) -> void:
	if s.state == Shooter.State.IN_COLUMN:
		# Бустером можно взять и скрытого из глубины колонки — он сразу открывается.
		s.set_hidden(false, false)
		s.set_dimmed(false)
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
	t.parallel().tween_property(s, "rotation:y", nearest_turn(s.rotation.y, rotation_towards(conveyor.inward(0.0))), MOVE_TIME)
	s.face_player(false)
	t.parallel().tween_property(s, "scale", Vector3.ONE, MOVE_TIME)
	t.tween_callback(func():
		entering -= 1
		s.state = Shooter.State.ON_BELT
		s.distance = 0.0
		s.last_lane = Vector2i(-1, -1)
		belt.append(s))


# Передний стрелок первой непустой колонки.
func first_in_columns() -> Shooter:
	for col in columns:
		if not col.is_empty():
			return col[0]
	return null


func columns_empty() -> bool:
	return columns.all(func(col): return col.is_empty())


# Последние стрелки: в колонках и в запасных слотах никого, на ленте ENDGAME_SHOOTERS или меньше.
func endgame() -> bool:
	return columns_empty() and slots.all(func(s): return s == null) and on_belt_count() <= ENDGAME_SHOOTERS


# Обновляется и в _process, и отдельно: на паузе (подарок, обучение) _process стоит.
func update_belt_label() -> void:
	belt_label.text = "%d/%d" % [on_belt_count(), belt_limit]


func on_belt_count() -> int:
	return pending.size() + entering + belt.size()


# ---------- Лента и стрельба ----------

func move_on_belt(s: Shooter, delta: float) -> void:
	# Мог исчезнуть в этом же кадре вместе с напарником.
	if s.state != Shooter.State.ON_BELT:
		return
	# Двигаемся маленькими шагами, чтобы не пропустить полосу при подлагивании.
	var left := belt_speed * delta
	while left > 0.0:
		var step := minf(left, 0.5)
		left -= step
		s.distance += step
		if s.distance >= conveyor.length:
			if columns_empty() or endgame():
				s.distance -= conveyor.length  # последние стрелки — едет ещё круг, а не в слот
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


# Возвращает true, если стрелок исчез с ленты.
func shoot(s: Shooter, lane: Vector2i) -> bool:
	if s.ammo <= 0:
		return false  # пустой из пары просто едет за напарником
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
	# Из пары пустой не пропадает, пока у напарника есть заряды — исчезают они только вдвоём.
	var partner := s.partner
	if partner and partner.ammo > 0:
		return false
	unlink(s)
	vanish(s)
	if partner:
		vanish(partner)
	return true


# Стрелок отстрелялся: убираем его отовсюду, где он мог быть, и он сжимается в точку.
func vanish(s: Shooter) -> void:
	belt.erase(s)
	pending.erase(s)
	if s.slot >= 0:
		slots[s.slot] = null
		s.slot = -1
		compact_slots()
	s.state = Shooter.State.MOVING
	var t := create_tween()
	t.tween_property(s, "scale", Vector3.ZERO, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.tween_callback(s.queue_free)


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
	t.parallel().tween_property(s, "rotation:y", nearest_turn(s.rotation.y, PI), MOVE_TIME)
	s.face_player(true)
	t.parallel().tween_property(s, "scale", Vector3.ONE * BIG, MOVE_TIME)
	t.tween_callback(func():
		s.state = Shooter.State.IN_SLOT
		if tutorial:
			tutorial.landed_in_slot(s))


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


# ---------- Связанные стрелки ----------

const LINK_SEGMENTS := 4  # из скольких кусков собрана дуга (половина — цвета одного стрелка)


# Пара связана дугой-ручкой от макушки до макушки. Связь живёт, пока живы оба:
# на ленте и в слотах пара тоже ездит вместе.
func link(a: Shooter, b: Shooter) -> void:
	a.partner = b
	b.partner = a
	# Куски дуги — цилиндры, на стыках шарики, чтобы изгиб был гладким. Меши общие на всех,
	# каждый кадр меняется только масштаб: пересобирать меш на каждом шаге ленты дорого
	# (раньше из-за этого на уровнях с парами подлагивало).
	if not link_cylinder:
		link_cylinder = CylinderMesh.new()
		link_cylinder.top_radius = 1.0
		link_cylinder.bottom_radius = 1.0
		link_cylinder.height = 1.0
		link_cylinder.radial_segments = 16
		link_cylinder.rings = 1
		link_cylinder.cap_top = false
		link_cylinder.cap_bottom = false
		link_sphere = SphereMesh.new()
		link_sphere.radius = 1.0
		link_sphere.height = 2.0
		link_sphere.radial_segments = 16
		link_sphere.rings = 8
	var parts: Array[MeshInstance3D] = []
	var joints: Array[MeshInstance3D] = []
	for i in LINK_SEGMENTS:
		var owner := a if i < LINK_SEGMENTS / 2 else b
		parts.append(link_piece(link_cylinder, owner))
	# Шарики только на внутренних стыках: концы дуги и так спрятаны в пандах.
	for i in range(1, LINK_SEGMENTS):
		var owner := a if i <= LINK_SEGMENTS / 2 else b
		joints.append(link_piece(link_sphere, owner))
	links.append({"a": a, "b": b, "parts": parts, "joints": joints})


func link_piece(mesh: Mesh, owner: Shooter) -> MeshInstance3D:
	var piece := MeshInstance3D.new()
	piece.mesh = mesh
	piece.material_override = tube_material(owner.color)
	add_child(piece)
	return piece


# Немного светлее стрелка и с бликом, чтобы дуга читалась поверх корпуса.
func tube_material(color: String) -> StandardMaterial3D:
	var key := "tube_" + color
	if not materials.has(key):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Level.COLORS[color].lightened(0.15)
		mat.roughness = 0.3
		materials[key] = mat
	return materials[key]


func unlink(s: Shooter) -> void:
	for l in links:
		if l.a == s or l.b == s:
			links.erase(l)
			l.a.partner = null
			l.b.partner = null
			for part: MeshInstance3D in l.parts + l.joints:
				var t := part.create_tween()
				t.tween_property(part, "scale", Vector3.ZERO, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
				t.tween_callback(part.queue_free)
			return


# Дуга — кривая Безье от макушки одного стрелка через точку повыше к макушке другого.
# Стрелки двигаются (и меняют размер: на ленте они мельче) — дуга следует за ними.
func update_links() -> void:
	for l in links:
		var a: Shooter = l.a
		var b: Shooter = l.b
		var size := (a.scale.x + b.scale.x) / 2.0
		var from := a.position + Vector3(0, 1.05 * a.scale.x, 0)
		var to := b.position + Vector3(0, 1.05 * b.scale.x, 0)
		var top := (from + to) / 2.0 + Vector3(0, 0.45 * size, 0)
		var radius := 0.18 * size
		var points: Array[Vector3] = []
		for i in LINK_SEGMENTS + 1:
			var t := float(i) / LINK_SEGMENTS
			points.append(from.lerp(top, t).lerp(top.lerp(to, t), t))
		for i in LINK_SEGMENTS:
			place_tube(l.parts[i], points[i], points[i + 1], radius)
		for i in range(1, LINK_SEGMENTS):
			l.joints[i - 1].transform = Transform3D(Basis.from_scale(Vector3.ONE * radius), points[i])


# Цилиндр от p до q: единичный меш, растянутый по длине и толщине.
func place_tube(part: MeshInstance3D, p: Vector3, q: Vector3, radius: float) -> void:
	var dir := q - p
	var length := dir.length()
	if length < 0.001:
		return
	var y := dir / length
	var x := y.cross(Vector3.UP)
	if x.length() < 0.01:
		x = y.cross(Vector3.RIGHT)
	x = x.normalized()
	part.transform = Transform3D(Basis(x * radius, y * length, x.cross(y) * radius), (p + q) / 2.0)


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
			# Связанных не прячем: игрок должен видеть, кого тянет за собой пара.
			s.set_hidden(s.hideable and tier > 0 and not s.partner, animated)
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


# Тот же угол, что target, но ближайший к from — чтобы поворот шёл коротким путём, а не через полкруга.
func nearest_turn(from: float, target: float) -> float:
	return from + wrapf(target - from, -PI, PI)


func rotation_towards(dir: Vector3) -> float:
	return atan2(-dir.x, -dir.z)


# ---------- Звуки ----------

# Звуки синтезирует tools/make_sounds.py.
func make_sounds() -> void:
	launch_sound = make_player(load("res://sounds/launch.wav"), 2)
	launch_sound.volume_db = -14.0
	# Несколько вариантов сухого «тика» и небольшой разброс высоты, чтобы очередь не звучала механически.
	var pops := AudioStreamRandomizer.new()
	for n in 4:
		pops.add_stream(n, load("res://sounds/pop_%d.wav" % (n + 1)))
	pops.random_pitch = 1.06
	pop_sound = make_player(pops, 8)
	pop_sound.volume_db = -12.0
	win_sound = make_player(load("res://sounds/win.wav"), 1)
	win_sound.volume_db = -10.0
	fail_sound = make_player(load("res://sounds/fail.wav"), 1)
	fail_sound.volume_db = -10.0


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
	var bottom := column_position(0, 2).z + (5.5 if booster_bar else 2.0)
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
	hud = CanvasLayer.new()
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

	if level_index >= BOOSTERS_FROM:
		booster_bar = BoosterBar.make(self)
		hud.add_child(booster_bar)


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
	if tutorial:
		tutorial.hide()

	if not won:
		fail_sound.play()
		UI.vibrate(250)
		Progress.lose_life(level_index)
		result_panel.get_parent().add_child(ResultScreen.fail("Уровень %d" % (level_index + 1), retry, go_to_menu))
		return
	Progress.complete(level_index)
	win_sound.play()
	UI.vibrate(120)
	var all_done := level_index + 1 >= Level.count()
	var title := "Все уровни" if all_done else "Уровень %d" % (level_index + 1)
	var subtitle := "пройдены!" if all_done else "пройден!"
	result_panel.get_parent().add_child(ResultScreen.win(title, subtitle, Progress.LEVEL_REWARD, claim_reward))


# Монеты зачисляются, а «капают» в счётчик уже на главном экране.
func claim_reward() -> void:
	if reward_claimed:
		return
	reward_claimed = true
	Progress.add_coins(Progress.LEVEL_REWARD)
	go_to_menu()


func show_pause() -> void:
	if finished:
		return
	get_tree().paused = true
	show_panel("Пауза", "")
	add_button("Продолжить", resume, UI.GREEN)
	add_button("Заново", leave.bind("Заново", retry), UI.ORANGE)
	add_button("В меню", leave.bind("Выход", go_to_menu), UI.PURPLE)


# Бросить уровень посреди игры стоит жизни — сначала спрашиваем (на обучении жизни не тратятся).
func leave(action: String, then: Callable) -> void:
	if level_index < Progress.FREE_LEVELS:
		then.call()
		return
	hud.add_child(CardScreen.lose_life(action, func():
		Progress.lose_life(level_index)
		then.call(), func(): pass))


# Ещё попытка — если остались жизни, иначе на главный экран ждать новую.
func retry() -> void:
	if Progress.lives() > 0 or level_index < Progress.FREE_LEVELS:
		restart()
	else:
		go_to_menu()


func restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func resume() -> void:
	result_panel.hide()
	get_tree().paused = false


func go_to_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/menu.tscn")


# Бустер: на ленте становится на одно место больше до конца уровня.
func add_belt_slot() -> void:
	belt_limit += 1
	update_belt_label()
	var base := belt_badge.scale
	var t := belt_badge.create_tween()
	t.tween_property(belt_badge, "scale", base * 1.3, 0.15)
	t.tween_property(belt_badge, "scale", base, 0.2)
	if tutorial:
		tutorial.booster_used("slot")


# Бустер «перемешать»: стрелки в колонках меняются местами, высота колонок та же.
# Связанные пары остаются где стояли — иначе пара могла бы встать в одну колонку
# друг за другом и уже никогда не уехать.
func shuffle_columns() -> void:
	var free: Array[Shooter] = []
	for col in columns:
		for s: Shooter in col:
			if not s.partner:
				free.append(s)
	free.shuffle()
	var k := 0
	for c in columns.size():
		for tier in columns[c].size():
			if not columns[c][tier].partner:
				var s := free[k]
				k += 1
				columns[c][tier] = s
				s.column = c
				s.hop()
	layout_columns(true)
	if tutorial:
		tutorial.booster_used("shuffle")


# Бустер «любой стрелок»: следующее нажатие выбирает стрелка в любом месте колонки.
func start_picking() -> void:
	picking = true
	booster_bar.set_active("pick", true)
	if tutorial:
		tutorial.booster_used("pick")


func stop_picking() -> void:
	picking = false
	booster_bar.set_active("pick", false)


func pick_any(s: Shooter) -> void:
	if on_belt_count() >= belt_limit:
		flash(belt_badge)
		return
	stop_picking()
	booster_bar.spend("pick")
	unlink(s)
	launch(s)
	if tutorial:
		tutorial.picked()


func flash(label: CanvasItem) -> void:
	var t := create_tween()
	label.modulate = Color.RED
	t.tween_property(label, "modulate", Color.WHITE, 0.4)
