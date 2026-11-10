class_name Shooter
extends Node3D

enum State { IN_COLUMN, WAITING, MOVING, ON_BELT, IN_SLOT }

var color := ""
var ammo := 0
var state := State.IN_COLUMN
var distance := 0.0           # сколько проехал по ленте за этот круг
var last_lane := Vector2i(-1, -1)
var column := -1
var slot := -1

var label: Label3D


func setup(new_color: String, new_ammo: int) -> void:
	color = new_color
	ammo = new_ammo

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Level.COLORS[color]

	var body := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.9, 1.0, 1.7)
	body.mesh = box
	body.material_override = mat
	body.position.y = 0.6
	add_child(body)

	var barrel := MeshInstance3D.new()
	var tube := BoxMesh.new()
	tube.size = Vector3(0.5, 0.5, 0.6)
	barrel.mesh = tube
	barrel.material_override = mat
	barrel.position = Vector3(0, 0.6, -1.1)
	add_child(barrel)

	label = Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 96
	label.outline_size = 24
	label.pixel_size = 0.012
	label.position.y = 1.5
	add_child(label)
	update_label()


func update_label() -> void:
	label.text = str(ammo)


func set_dimmed(dimmed: bool) -> void:
	label.modulate.a = 0.45 if dimmed else 1.0
	label.outline_modulate.a = 0.45 if dimmed else 1.0
