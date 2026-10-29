extends GridMap

const BLOCKS := {
  "S": "Sand",
  "C": "Concrete",
  "M": "Marble",
  "I": "Ice",
  "L": "Lava",
  "G": "Glass",
}

const LEVEL := [
	"MM",
 ]

func _ready() -> void:
	clear()
	build_level(LEVEL)

func build_level(map_level):
	var rows: int = map_level.size()  
	
	for row in rows: 
		var line: String = map_level[row]
		var columns: int = line.length()
		for column in  columns:
			if line[column] != ".":
				place_block(Vector3i(column - columns / 2, 0, row - rows / 2), line[column])
				
		position.x = -cell_size.x / 2 if columns % 2 == 1 else 0.0
		position.z = -cell_size.z / 2 if rows % 2 == 1 else 0.0

func place_block(cell: Vector3i, symbol: String) -> void:
	set_cell_item(cell, mesh_library.find_item_by_name(BLOCKS[symbol]))
