extends SceneTree

# Рисует картинку загрузки: наша панда в прыжке на фоне неба, сбоку вторая со снарядом,
# внизу гора блоков поля. Сцена собирается из тех же моделей, что в игре, и снимается.
# Запуск (не headless — нужен рендер; Forward+ — ради размытия и мягких теней,
# на игру это не влияет):
#   Godot --path . --rendering-method forward_plus -s tools/make_splash.gd
# → splash.png в корне проекта (исходник) и web/shell.html — страница загрузки
# для веб-экспорта, в неё картинка встроена в WebP: так она весит в разы меньше PNG.
#
# Картинка широкая (под экран компьютера), а загрузка растягивает её на весь экран
# с обрезкой краёв (stretch_mode Cover, в вебе — object-fit: cover из head_include).
# На телефоне остаётся середина шириной ~0.46 высоты: там главная панда и место
# под название, по бокам — небо и блоки для широкого экрана.

const SIZE := Vector2i(2600, 1400)
const OUT := "res://splash.png"
const SHELL_TEMPLATE := "res://web/shell_template.html"
const SHELL := "res://web/shell.html"
const WEBP_QUALITY := 0.8
const PANDA := preload("res://models/panda.glb")

const SKY_TOP := Color("1f63e8")
const SKY_HORIZON := Color("7fe0ff")
const HILL := Color("63d46a")
const HILL_FAR := Color("4cbf86")
# Блоки — несколько сочных цветов, которые дружат между собой: пёстрая палитра
# со всеми цветами поля смотрелась кашей.
const BLOCKS := [Color("ff7eb9"), Color("b36bff"), Color("ffc83d"), Color("4fa3ff"), Color("ff9fd0"), Color("8f5cf7")]

var rng := RandomNumberGenerator.new()


func _initialize() -> void:
	rng.seed = 3
	# Снимаем через SubViewport: окно такого размера система может и не дать.
	var viewport := SubViewport.new()
	viewport.size = SIZE
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var scene := Node3D.new()
	viewport.add_child(scene)
	build(scene)
	viewport.add_child(make_title())
	# Несколько кадров: тени и затенение (SSAO) набираются не с первого.
	for i in 8:
		await process_frame
	var img := viewport.get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(OUT))
	print("written ", OUT, " ", img.get_size())
	var webp := img.save_webp_to_buffer(true, WEBP_QUALITY)
	var shell := FileAccess.get_file_as_string(SHELL_TEMPLATE).replace("$SPLASH_WEBP", Marshalls.raw_to_base64(webp))
	FileAccess.open(SHELL, FileAccess.WRITE).store_string(shell)
	print("written ", SHELL, ", splash webp ", webp.size() / 1024, " KB")
	quit()


func build(scene: Node3D) -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = SKY_TOP
	sky_mat.sky_horizon_color = SKY_HORIZON
	sky_mat.sky_curve = 0.12
	sky_mat.ground_horizon_color = SKY_HORIZON
	sky_mat.ground_bottom_color = HILL
	sky_mat.sun_angle_max = 0.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	# Заполняющий свет нейтральный: голубой от неба смешивался с жёлтым в салатовый.
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("f4f6ff")
	env.ambient_light_energy = 0.55
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.ssao_enabled = true
	env.ssao_intensity = 1.5
	var world := WorldEnvironment.new()
	world.environment = env
	scene.add_child(world)

	# Тёплый основной свет спереди-слева и холодный контровой сзади — объём, как у игрушек.
	var sun := DirectionalLight3D.new()
	sun.light_color = Color("fff3e0")
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-40, -30, 0)
	scene.add_child(sun)
	var rim := DirectionalLight3D.new()
	rim.light_color = Color("fff8ec")
	rim.light_energy = 0.7
	rim.rotation_degrees = Vector3(-25, 160, 0)
	scene.add_child(rim)

	var camera := Camera3D.new()
	camera.fov = 50
	# Камера ниже сцены и смотрит вверх на её середину: горизонт неба (он на уровне
	# глаз камеры) уходит вниз — неба больше.
	camera.position = Vector3(0, -3.5, 14)
	camera.rotation_degrees.x = 14
	# Ближние блоки и дальний холм размыты, резкие только панды.
	var focus := CameraAttributesPractical.new()
	focus.dof_blur_near_enabled = true
	focus.dof_blur_near_distance = 9.5
	focus.dof_blur_near_transition = 3.0
	focus.dof_blur_far_enabled = true
	focus.dof_blur_far_distance = 24.0
	focus.dof_blur_far_transition = 20.0
	focus.dof_blur_amount = 0.12
	camera.attributes = focus
	scene.add_child(camera)
	camera.make_current()

	add_rays(scene)

	# Круглые холмы: ближний светлый, за ним дальний.
	add_hill(scene, Vector3(-9, -38, -40), 34.0, HILL_FAR)
	add_hill(scene, Vector3(8, -40, -30), 34.0, HILL)

	# Главная панда (фиолетовая) — в прыжке, повёрнута к нам и чуть вбок.
	add_panda(scene, Color("8b4df2"), Vector3(-0.3, -2.3, 2), Vector3(-18, 196, 14), 1.75)
	# Вторая слева сверху (на телефоне наполовину за краем), её снаряд летит вправо вверх.
	add_panda(scene, Color("ffae1f"), Vector3(-4.4, 0.2, -1), Vector3(-12, 228, 10), 1.15)
	add_shot(scene, Vector3(-1.7, 1.1, 0.5), Vector3(-1, -0.42, 0), Color("ff8cc6"))
	# Для широкого экрана — ещё одна, маленькая и дальняя, справа.
	add_panda(scene, Color("ff8cc6"), Vector3(8.5, 2.6, -5), Vector3(-10, 140, -12), 1.0)

	# Кубики-конфетти вокруг места под название.
	for p in [Vector3(-2.1, 6.4, 0), Vector3(2.2, 6.9, -1), Vector3(-0.4, 7.4, -2), Vector3(2.8, 4.6, 0),
			Vector3(-6.5, 5.5, -2), Vector3(7.0, 6.2, -2), Vector3(-10.5, 3.0, -4)]:
		add_block(scene, p, rng.randf_range(0.4, 0.6), pick())

	# Куча блоков снизу во всю ширину: ближние ряды крупные и размытые, дальние резкие.
	# К краям куча выше — обрамляет сцену; посередине ниже, чтобы не закрывать панду.
	for row in 3:
		var z := 6.5 - row * 2.6
		var size := 2.4 - row * 0.4
		var x := -17.0 + rng.randf() * size
		while x < 17.0:
			var s := size * rng.randf_range(0.85, 1.15)
			var y := -6.7 + row * 0.45 + maxf(absf(x) - 3.0, 0.0) * 0.12 + rng.randf_range(-0.35, 0.35)
			add_block(scene, Vector3(x, y, z), s, pick())
			x += s * rng.randf_range(0.8, 1.0)


func pick() -> Color:
	return BLOCKS[rng.randi() % BLOCKS.size()]


func add_panda(scene: Node3D, color: Color, pos: Vector3, rot: Vector3, size: float) -> void:
	var model := PANDA.instantiate()
	scene.add_child(model)
	var body: MeshInstance3D = model.find_children("*", "MeshInstance3D", true, false)[0]
	body.mesh = smooth_mesh(body.mesh)
	var mat := Shooter.material_for(color).duplicate()
	mat.roughness = 0.35
	mat.rim_enabled = true
	mat.rim = 0.15
	body.material_override = mat
	model.position = pos
	model.rotation_degrees = rot
	model.scale = Vector3.ONE * size


# ---------- Название ----------

const TITLE_FONT := preload("res://fonts/nunito_numbers.tres")  # Nunito Black
const TITLE_OUTLINE := Color("1d1b4f")
const TITLE_WIDTH := 560.0  # не шире середины, которая остаётся на телефоне


# «ПАНДА / БОЛЛ» сверху по центру: толстая тёмная обводка, «подошва» снизу и светлый
# блик сверху — как кнопки в игре. Чуть наклонено, чтобы не было скучно.
func make_title() -> Node2D:
	var title := Node2D.new()
	title.position = Vector2(SIZE.x / 2.0, 230)
	title.rotation = deg_to_rad(-4)
	title.draw.connect(func():
		draw_word(title, "ПАНДА", Vector2(0, 0), Color("ffffff"), Color("bfe6ff"))
		draw_word(title, "БОЛЛ", Vector2(0, 175), Color("ffc93a"), Color("ff9a1f")))
	return title


func draw_word(c: CanvasItem, text: String, at: Vector2, fill: Color, bottom: Color) -> void:
	var size := 200
	while TITLE_FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > TITLE_WIDTH:
		size -= 4
	var w := TITLE_FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var pos := at + Vector2(-w / 2.0, size * 0.35)
	var outline := 44
	# Подошва — та же обводка, сдвинутая вниз.
	c.draw_string_outline(TITLE_FONT, pos + Vector2(0, 16), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline, TITLE_OUTLINE)
	c.draw_string_outline(TITLE_FONT, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline, TITLE_OUTLINE)
	# Объём буквы: тёмный низ, поверх основной цвет чуть выше — снизу остаётся тень.
	c.draw_string(TITLE_FONT, pos + Vector2(0, 7), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, bottom)
	c.draw_string(TITLE_FONT, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, fill)


# ---------- Сглаживание панды ----------
# Модель низкополигональная: в игре панды мелкие и это незаметно, а на заставке грани
# на скруглениях бросались в глаза. Два шага подразделения Loop (как Subdivision Surface
# в Blender) делают поверхность гладкой. Только для заставки — в игре модель прежняя.

var smoothed: ArrayMesh  # одна сглаженная модель на всех панд


func smooth_mesh(source: Mesh) -> ArrayMesh:
	if smoothed:
		return smoothed
	var arrays := source.surface_get_arrays(0)
	var pos: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var col: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for step in 2:
		var result := loop_subdivide(pos, col, idx)
		pos = result[0]
		col = result[1]
		idx = result[2]

	# Нормали — по сваренным точкам: вершины на границах цветов разделены,
	# и без этого по ним шёл бы шов в освещении.
	var weld := weld_positions(pos)
	var normals := PackedVector3Array()
	normals.resize(weld.count)
	for t in range(0, idx.size(), 3):
		var a := pos[idx[t]]
		var n := (pos[idx[t + 1]] - a).cross(pos[idx[t + 2]] - a)
		for k in 3:
			normals[weld.map[idx[t + k]]] += n
	var out_normals := PackedVector3Array()
	out_normals.resize(pos.size())
	for i in pos.size():
		out_normals[i] = normals[weld.map[i]].normalized()

	var out := []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = pos
	out[Mesh.ARRAY_NORMAL] = out_normals
	out[Mesh.ARRAY_COLOR] = col
	out[Mesh.ARRAY_INDEX] = idx
	smoothed = ArrayMesh.new()
	smoothed.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out)
	return smoothed


# Вершины с одинаковым положением (разрезанные по цвету) — одна точка: map[i] -> номер точки.
func weld_positions(pos: PackedVector3Array) -> Dictionary:
	var ids := {}
	var map := PackedInt32Array()
	map.resize(pos.size())
	for i in pos.size():
		var key := pos[i].snapped(Vector3.ONE * 0.00001)
		if not ids.has(key):
			ids[key] = ids.size()
		map[i] = ids[key]
	return {"map": map, "count": ids.size()}


# Один шаг Loop. Положения считаются по сваренным точкам (чтобы разрезы по цвету не рвали
# поверхность), а цвета — по исходным вершинам, поэтому границы частей остаются чёткими.
func loop_subdivide(pos: PackedVector3Array, col: PackedColorArray, idx: PackedInt32Array) -> Array:
	var weld := weld_positions(pos)
	var map: PackedInt32Array = weld.map
	var point := PackedVector3Array()
	point.resize(weld.count)
	for i in pos.size():
		point[map[i]] = pos[i]

	# Рёбра по сваренным точкам: кто противолежит ребру в каждом треугольнике.
	var opposite := {}   # Vector2i(min, max) -> [точки напротив]
	var neighbours := []  # точка -> {соседняя точка: true}
	neighbours.resize(weld.count)
	for i in weld.count:
		neighbours[i] = {}
	for t in range(0, idx.size(), 3):
		for k in 3:
			var a := map[idx[t + k]]
			var b := map[idx[t + (k + 1) % 3]]
			var c := map[idx[t + (k + 2) % 3]]
			var key := Vector2i(mini(a, b), maxi(a, b))
			if not opposite.has(key):
				opposite[key] = []
			opposite[key].append(c)
			neighbours[a][b] = true
			neighbours[b][a] = true

	# Новые положения старых точек.
	var moved := PackedVector3Array()
	moved.resize(weld.count)
	for v in weld.count:
		var near: Array = neighbours[v].keys()
		var n := near.size()
		var on_edge := false
		for u in near:
			if opposite[Vector2i(mini(u, v), maxi(u, v))].size() != 2:
				on_edge = true
		if on_edge or n < 3:
			moved[v] = point[v]
			continue
		var beta := 3.0 / 16.0 if n == 3 else 3.0 / (8.0 * n)
		var sum := Vector3.ZERO
		for u in near:
			sum += point[u]
		moved[v] = point[v] * (1.0 - n * beta) + sum * beta

	# Точки на серединах рёбер.
	var edge_point := {}
	for key: Vector2i in opposite:
		var a := point[key.x]
		var b := point[key.y]
		var opp: Array = opposite[key]
		if opp.size() == 2:
			edge_point[key] = (a + b) * 0.375 + (point[opp[0]] + point[opp[1]]) * 0.125
		else:
			edge_point[key] = (a + b) * 0.5

	# Новая сетка: у старых вершин свои цвета, у середин — среднее двух концов ребра
	# (внутри треугольника — по его вершинам, так разрезы по цвету сохраняются).
	var out_pos := PackedVector3Array()
	var out_col := PackedColorArray()
	var out_idx := PackedInt32Array()
	for i in pos.size():
		out_pos.append(moved[map[i]])
		out_col.append(col[i])
	var mids := {}  # Vector2i(исходная i, исходная j) -> новая вершина
	for t in range(0, idx.size(), 3):
		var corner := [idx[t], idx[t + 1], idx[t + 2]]
		var mid := []
		for k in 3:
			var i: int = corner[k]
			var j: int = corner[(k + 1) % 3]
			var key := Vector2i(mini(i, j), maxi(i, j))
			if not mids.has(key):
				var a := map[i]
				var b := map[j]
				mids[key] = out_pos.size()
				out_pos.append(edge_point[Vector2i(mini(a, b), maxi(a, b))])
				out_col.append(col[i].lerp(col[j], 0.5))
			mid.append(mids[key])
		out_idx.append_array([corner[0], mid[0], mid[2], mid[0], corner[1], mid[1],
				mid[2], mid[1], corner[2], mid[0], mid[1], mid[2]])
	return [out_pos, out_col, out_idx]


func add_block(scene: Node3D, pos: Vector3, size: float, color: Color) -> void:
	var block := MeshInstance3D.new()
	block.mesh = RoundedBox.make(Vector3.ONE, 0.2)
	block.material_override = glossy(color)
	block.position = pos
	block.scale = Vector3.ONE * size
	block.rotation = Vector3(rng.randf_range(-0.5, 0.5), rng.randf_range(-0.8, 0.8), rng.randf_range(-0.4, 0.4))
	scene.add_child(block)


func add_hill(scene: Node3D, pos: Vector3, radius: float, color: Color) -> void:
	var hill := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 96
	mesh.rings = 48
	hill.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	hill.material_override = mat
	hill.position = pos
	scene.add_child(hill)


# Мягкие косые лучи света в небе: полупрозрачные полосы далеко за сценой.
func add_rays(scene: Node3D) -> void:
	for i in 5:
		var ray := MeshInstance3D.new()
		var mesh := QuadMesh.new()
		mesh.size = Vector2(rng.randf_range(2.5, 12.0), 120)
		ray.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.albedo_color = Color(1, 1, 1, rng.randf_range(0.025, 0.06))
		ray.material_override = mat
		ray.position = Vector3(-34 + i * 15 + rng.randf_range(-6, 6), 10, -60)
		ray.rotation_degrees.z = -35
		scene.add_child(ray)


# Снаряд и шлейф за ним: светлая полоса, сужающаяся и тающая к хвосту.
func add_shot(scene: Node3D, pos: Vector3, back: Vector3, color: Color) -> void:
	var ball := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.45
	mesh.height = 0.9
	ball.mesh = mesh
	ball.material_override = glossy(color.lightened(0.15))
	ball.position = pos
	scene.add_child(ball)
	var dir := back.normalized()
	for i in 10:
		var puff := MeshInstance3D.new()
		var puff_mesh := SphereMesh.new()
		var r := 0.42 * (1.0 - i / 11.0)
		puff_mesh.radius = r
		puff_mesh.height = r * 2.0
		puff.mesh = puff_mesh
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(1, 1, 1, 0.45 * (1.0 - i / 10.0))
		puff.material_override = mat
		puff.position = pos + dir * (0.35 + i * 0.25)
		scene.add_child(puff)


func glossy(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.25
	mat.rim_enabled = true
	mat.rim = 0.3
	return mat
