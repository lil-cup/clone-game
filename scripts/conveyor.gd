class_name Conveyor
extends Node3D

# Все размеры в единицах мира. Поле — квадрат со стороной field, блоки масштабируются под него.
@export var road_width := 2.4
@export var gap := 1.1
# Не больше gap + road_width / 2: иначе крайние ряды пазла окажутся напротив поворота и по ним не выстрелить.
@export var corner_radius := 2.3
@export var road_color := Color("2f2d4a")
@export var rail_color := Color("d5dbf2")
@export var stripe_color := Color("4d527e")

# «Ёлочки» на ленте показывают, что она едет: острие смотрит по ходу движения.
# Каждая — отдельная плоская фигурка, поэтому на поворотах не гнётся.
const CHEVRON_STEP := 7.2         # расстояние между ёлочками
const CHEVRON_HALF_WIDTH := 0.42  # половина ширины (поперёк ленты)
const CHEVRON_LENGTH := 0.4       # насколько крылья отходят назад от острия
const CHEVRON_THICKNESS := 0.2
const CHEVRON_SPEED := 0.5        # ёлочки едут медленнее стрелков, чтобы не рябило

const ROAD_HEIGHT := 0.2  # стрелки на ленте едут по её верху

var field := 0.0     # сторона поля
var cells := 0       # клеток поля по стороне
var center := 0.0     # расстояние от центра поля до средней линии ленты
var straight := 0.0   # длина прямого участка
var arc := 0.0        # длина скругления
var length := 0.0     # длина всего круга
var scroll_offset := 0.0
var chevrons: Array[MeshInstance3D] = []


func build(field_size: float, cell_count: int) -> void:
	field = field_size
	cells = cell_count
	center = field / 2.0 + gap + road_width / 2.0
	straight = 2.0 * (center - corner_radius)
	arc = PI / 2.0 * corner_radius
	length = 4.0 * (straight + arc)

	for child in get_children():
		child.queue_free()
	# Объёмная лента: полотно чуть приподнято, по краям бортики повыше.
	add_strip(0.0, road_width, ROAD_HEIGHT, plain_material(road_color))
	var rail := plain_material(rail_color)
	# Подсветка, чтобы стенки бортиков в тени не темнели: тёмная стенка читается как часть
	# дороги, и ёлочки кажутся не по центру.
	rail.emission_enabled = true
	rail.emission = rail_color * 0.25
	add_strip(road_width / 2.0, 0.35, 0.45, rail)
	add_strip(-road_width / 2.0, 0.35, 0.45, rail)


	chevrons.clear()
	var mesh := make_chevron_mesh()
	var mat := plain_material(stripe_color)
	# Целое число ёлочек на круг: шаг чуть подгоняется под длину ленты.
	for i in roundi(length / CHEVRON_STEP):
		var chevron := MeshInstance3D.new()
		chevron.mesh = mesh
		chevron.material_override = mat
		chevron.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(chevron)
		chevrons.append(chevron)
	scroll(0.0)


# Двигает ёлочки вслед за стрелками.
func scroll(distance: float) -> void:
	scroll_offset = fmod(scroll_offset + distance * CHEVRON_SPEED, length)
	var step := length / chevrons.size()
	for i in chevrons.size():
		var d := scroll_offset + i * step
		var forward := (point(d + 0.05) - point(d - 0.05)).normalized()
		var chevron := chevrons[i]
		chevron.basis = Basis(forward, Vector3.UP, forward.cross(Vector3.UP))
		chevron.position = point(d) + Vector3.UP * 0.01


# Плоская «галочка» острием вдоль оси X: два крыла, расходящихся назад.
# Крылья — полоски со скруглёнными концами.
func make_chevron_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [1.0, -1.0]:
		add_capsule(st, Vector2.ZERO, Vector2(-CHEVRON_LENGTH, CHEVRON_HALF_WIDTH * side), CHEVRON_THICKNESS / 2.0)
	return st.commit()


# Плоская полоска от a до b (в плоскости XZ) с круглыми концами радиуса r.
func add_capsule(st: SurfaceTool, a: Vector2, b: Vector2, r: float) -> void:
	var dir := (b - a).normalized()
	var side := dir.orthogonal() * r
	add_flat_triangle(st, a + side, b + side, b - side)
	add_flat_triangle(st, a + side, b - side, a - side)
	for c in [a, b]:
		var segments := 10
		for i in segments:
			var p0: Vector2 = c + Vector2.from_angle(TAU * i / segments) * r
			var p1: Vector2 = c + Vector2.from_angle(TAU * (i + 1) / segments) * r
			add_flat_triangle(st, c, p0, p1)


# Треугольник на полу, всегда лицом вверх (иначе освещение делает его тёмным).
func add_flat_triangle(st: SurfaceTool, p0: Vector2, p1: Vector2, p2: Vector2) -> void:
	var points := [p0, p1, p2]
	if (p1 - p0).cross(p2 - p0) < 0.0:
		points = [p0, p2, p1]
	for p: Vector2 in points:
		st.set_normal(Vector3.UP)
		st.add_vertex(Vector3(p.x, 0, p.y))


# Позиция на ленте. Путь начинается слева снизу и идёт: низ вправо, право вверх, верх влево, лево вниз.
func point(d: float) -> Vector3:
	d = fposmod(d, length)
	var side := int(d / (straight + arc))
	var t := d - side * (straight + arc)
	var p: Vector2
	if t < straight:
		p = Vector2(-center + corner_radius + t, center)
	else:
		var a := PI / 2.0 - (t - straight) / corner_radius
		p = Vector2(center - corner_radius, center - corner_radius) + Vector2(cos(a), sin(a)) * corner_radius
	for i in side:
		p = Vector2(p.y, -p.x)
	return Vector3(p.x, ROAD_HEIGHT, p.y)


# Направление внутрь поля (куда смотрит стрелок).
func inward(d: float) -> Vector3:
	var t := (point(d + 0.05) - point(d - 0.05)).normalized()
	return Vector3(t.z, 0, -t.x)


# Сторона и полоса напротив точки d, либо (-1, -1) на углах.
func lane_at(d: float) -> Vector2i:
	d = fposmod(d, length)
	var side := int(d / (straight + arc))
	var t := d - side * (straight + arc)
	if t >= straight:
		return Vector2i(-1, -1)
	var x := -center + corner_radius + t + field / 2.0
	if x < 0.0 or x >= field:
		return Vector2i(-1, -1)
	return Vector2i(side, mini(int(x / field * cells), cells - 1))


func plain_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


# Полоса вдоль ленты высотой height: верх и две боковые стенки до пола.
func add_strip(offset: float, width: float, height: float, mat: Material) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := int(length / 0.2)
	for i in steps:
		var d0 := length * i / steps
		var d1 := length * (i + 1) / steps
		var n0 := inward(d0)
		var n1 := inward(d1)
		var p0 := point(d0) * Vector3(1, 0, 1) - n0 * offset
		var p1 := point(d1) * Vector3(1, 0, 1) - n1 * offset
		var up := Vector3.UP * height
		# Края полосы: a — внутренний (к полю), b — внешний.
		var a0 := p0 + n0 * width / 2.0
		var a1 := p1 + n1 * width / 2.0
		var b0 := p0 - n0 * width / 2.0
		var b1 := p1 - n1 * width / 2.0
		add_quad(st, [a0 + up, a1 + up, b1 + up, b0 + up], Vector3.UP)
		add_quad(st, [a0, a1, a1 + up, a0 + up], n0)
		add_quad(st, [b0 + up, b1 + up, b1, b0], -n0)

	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	# Тени бортиков на полотне ложатся рваной «пилой» — без них чище.
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func add_quad(st: SurfaceTool, corners: Array, normal: Vector3) -> void:
	for k in [0, 1, 2, 0, 2, 3]:
		st.set_normal(normal)
		st.add_vertex(corners[k])
