class_name Board
extends GridMap

const BLOCK_SIZE := Vector3(0.9, 0.6, 0.9)
const BLOCK_RADIUS := 0.14

var level: Level
var item_ids := {}


func build_level(new_level: Level) -> void:
	level = new_level
	clear()
	mesh_library = make_mesh_library()
	cell_size = Vector3.ONE
	# Удаление блока пересобирает меш целого куска поля, поэтому куски делаем маленькими.
	cell_octant_size = 4

	# Клетка (0, 0) в левом верхнем углу, центр поля в начале координат.
	var half := level.size / 2.0
	position = Vector3(-half, 0, -half)

	for row in level.size:
		for col in level.size:
			var color := level.get_cell(col, row)
			if color != "":
				set_cell_item(Vector3i(col, 0, row), item_ids[color])


func remove_block(cell: Vector2i) -> void:
	set_cell_item(Vector3i(cell.x, 0, cell.y), INVALID_CELL_ITEM)


func cell_to_world(cell: Vector2i) -> Vector3:
	return to_global(map_to_local(Vector3i(cell.x, 0, cell.y)))


func make_mesh_library() -> MeshLibrary:
	var lib := MeshLibrary.new()
	var id := 0
	for color in Level.COLORS:
		var mesh := RoundedBox.make(BLOCK_SIZE, BLOCK_RADIUS, 1)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Level.COLORS[color]
		mesh.surface_set_material(0, mat)
		lib.create_item(id)
		lib.set_item_name(id, color)
		lib.set_item_mesh(id, mesh)
		item_ids[color] = id
		id += 1
	return lib
