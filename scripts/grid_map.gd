extends GridMap

@export var width := 10
@export var depth := 10

func _ready() -> void:
	var cube := mesh_library.find_item_by_name("Cube")
	print(mesh_library.get_item_list())
	clear()
	for x in range(-width / 2, width - width / 2):
		for z in range(-depth / 2, depth - depth / 2):
			set_cell_item(Vector3i(x, 0, z), cube)
