class_name Board
extends Node3D

# Поле из блоков. Все блоки одного цвета — один MultiMesh: рисуются одним вызовом,
# а сбитый блок просто сжимается в ноль. Раньше поле было GridMap, и он при каждом
# удалении пересобирал меш целого куска поля — когда стреляли несколько пушек сразу,
# игра подлагивала (особенно в браузере).

const BLOCK_SIZE := Vector3(0.9, 0.6, 0.9)
const BLOCK_RADIUS := 0.14

var level: Level
var blocks := {}  # клетка -> [MultiMesh, номер блока в нём]


# field — сторона поля в мире: она постоянная, а блоки масштабируются, чтобы влезть в неё.
func build_level(new_level: Level, field: float) -> void:
	level = new_level
	for child in get_children():
		child.queue_free()
	blocks.clear()

	scale = Vector3.ONE * field / level.size
	# Клетка (0, 0) в левом верхнем углу, центр поля в начале координат.
	position = Vector3(-field / 2.0, 0, -field / 2.0)

	var cells_by_color := {}
	for row in level.size:
		for col in level.size:
			var color := level.get_cell(col, row)
			if color != "":
				if not cells_by_color.has(color):
					cells_by_color[color] = []
				cells_by_color[color].append(Vector2i(col, row))

	var mesh := RoundedBox.make(BLOCK_SIZE, BLOCK_RADIUS, 1)
	for color in cells_by_color:
		var cells: Array = cells_by_color[color]
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = mesh
		multimesh.instance_count = cells.size()
		for i in cells.size():
			multimesh.set_instance_transform(i, Transform3D(Basis(), cell_center(cells[i])))
			blocks[cells[i]] = [multimesh, i]
		var instance := MultiMeshInstance3D.new()
		instance.multimesh = multimesh
		instance.material_override = block_material(Level.COLORS[color])
		add_child(instance)


func block_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	# Лёгкий глянец: блики на скруглённых краях (без clearcoat — на телефонах он дорогой).
	mat.roughness = 0.3
	return mat


func remove_block(cell: Vector2i) -> void:
	if not blocks.has(cell):
		return
	var entry: Array = blocks[cell]
	blocks.erase(cell)
	var multimesh: MultiMesh = entry[0]
	multimesh.set_instance_transform(entry[1], Transform3D(Basis.from_scale(Vector3.ZERO), cell_center(cell)))


func cell_to_world(cell: Vector2i) -> Vector3:
	return to_global(cell_center(cell))


# Середина клетки в координатах поля (как было у GridMap с клеткой 1×1×1).
func cell_center(cell: Vector2i) -> Vector3:
	return Vector3(cell.x + 0.5, 0.5, cell.y + 0.5)
