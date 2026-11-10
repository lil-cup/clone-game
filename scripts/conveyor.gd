class_name Conveyor
extends Node3D

# Все размеры в клетках поля (1 клетка = 1 единица).
@export var road_width := 2.4
@export var gap := 0.5
@export var corner_radius := 1.6
@export var road_color := Color("8a95c4")
@export var rail_color := Color("d5dbf2")

var grid_size := 0
var center := 0.0     # расстояние от центра поля до средней линии ленты
var straight := 0.0   # длина прямого участка
var arc := 0.0        # длина скругления
var length := 0.0     # длина всего круга


func build(size: int) -> void:
	grid_size = size
	center = size / 2.0 + gap + road_width / 2.0
	straight = 2.0 * (center - corner_radius)
	arc = PI / 2.0 * corner_radius
	length = 4.0 * (straight + arc)

	for child in get_children():
		child.queue_free()
	add_strip(0.0, road_width, 0.05, road_color)
	add_strip(road_width / 2.0, 0.25, 0.1, rail_color)
	add_strip(-road_width / 2.0, 0.25, 0.1, rail_color)


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
	return Vector3(p.x, 0, p.y)


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
	var x := -center + corner_radius + t + grid_size / 2.0
	if x < 0.0 or x >= grid_size:
		return Vector2i(-1, -1)
	return Vector2i(side, int(x))


func add_strip(offset: float, width: float, y: float, color: Color) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	st.set_normal(Vector3.UP)
	var steps := int(length / 0.2)
	for i in steps + 1:
		var d := length * i / steps
		var n := inward(d)
		var p := point(d) - n * offset
		st.add_vertex(p + n * width / 2.0 + Vector3.UP * y)
		st.add_vertex(p - n * width / 2.0 + Vector3.UP * y)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	add_child(mi)
