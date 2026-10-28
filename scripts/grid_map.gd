extends GridMap

@export var width := 6
@export var depth := 1

const MATERIALS := {
  #"S": preload("res://resources/materials/sand.tres"),
  #"C": preload("res://resources/materials/wet_concrete.tres"),
  #"M": preload("res://resources/materials/marble.tres"),
  "I": preload("res://resources/materials/ice.tres"),
  #"L": preload("res://resources/materials/lava.tres"),
  #"X": preload("res://resources/materials/glass.tres"),
}

func _ready() -> void:
	var mat :=  MATERIALS["I"]
	var cube := mesh_library.find_item_by_name("Cube")
	mesh_library.get_item_mesh(cube).surface_set_material(0, mat)
	clear()

	for x in range(-width / 2, width - width / 2):
		for z in range(-depth / 2, depth - depth / 2):
			set_cell_item(Vector3i(x, 0, z), cube)
