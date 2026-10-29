extends Node3D

@export var straight_scene: PackedScene
@export var corner_scene: PackedScene
@export var grid_size := 34
@export var cell_size := 2.0
@export var speed := 20.0
@export var grid: GridMap
@export var target_block := "Marble"

var last_cell := Vector3i(999, 999, 999)

func _ready() -> void:
	build_conveyor()


func _process(delta: float) -> void:
	var follower: PathFollow3D = $Path3D/PathFollow3D
	follower.progress += speed * delta
	
	var pos := follower.global_position
	var cell := grid.local_to_map(grid.to_local(pos))
	cell.y = 0
	
	if cell == last_cell:
		return
		
	last_cell = cell
	
	var dir: Vector3i
	if abs(pos.x) > abs(pos.z):
		dir = Vector3i(-int(signf(pos.x)), 0, 0)
	else:
		dir = Vector3i(0, 0, -int(signf(pos.z)))
		
	shoot(cell, dir)


func build_conveyor() -> void:
	var d := grid_size * cell_size / 2.0 + cell_size / 2.0
	
	for i in grid_size:
		var t := (i - grid_size / 2.0 + 0.5) * cell_size
		place(straight_scene, t, -d, 0)
		place(straight_scene, t, d, 0)
		place(straight_scene, -d, t, 90)
		place(straight_scene, d, t, 90)
		
	place(corner_scene, -d, -d, 90)
	place(corner_scene, d, -d, 0)
	place(corner_scene, d, d, -90)
	place(corner_scene, -d, d, 180)
	
	var r := cell_size / 2.0
	var centers := [
		Vector2(d - r, -d + r),
		Vector2(d - r, d - r),
		Vector2(-d + r, d - r),
		Vector2(-d + r, -d + r),
	]
	
	var c := Curve3D.new()
	for k in 4:
		var start_angle := -90.0 + 90.0 * k
		for s in 9:
			var a := deg_to_rad(start_angle + 90.0 * s / 8.0)
			var p: Vector2 = centers[k] + Vector2(cos(a), sin(a)) * r
			c.add_point(Vector3(p.x, 0, p.y))
	c.add_point(c.get_point_position(0))
	$Path3D.curve = c


func place(scene: PackedScene, x: float, z: float, angle: float) -> void:
	var piece: Node3D = scene.instantiate()
	piece.position = Vector3(x, 0, z)
	piece.rotation_degrees.y = angle
	piece.scale = Vector3.ONE * cell_size
	add_child(piece)


func shoot(from: Vector3i, dir: Vector3i) -> void:
	var cell := from
	for step in grid_size + 2:
		cell += dir
		var item := grid.get_cell_item(cell)
		if item == GridMap.INVALID_CELL_ITEM:
			continue
		if grid.mesh_library.get_item_name(item) == target_block:
			grid.set_cell_item(cell, GridMap.INVALID_CELL_ITEM)
		return
