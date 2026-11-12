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
var visual: Node3D  # всё, что видно; прыгает отдельно от позиции стрелка

const NUMBERS_FONT := preload("res://fonts/nunito_numbers.tres")

# Слой стрелков: только он отбрасывает тени (см. shadow_caster_mask у солнца в game.tscn).
const SHADOW_LAYER := 2

# Ствол: где стоит и где его кончик (оттуда вылетают снаряды), в координатах стрелка.
const BARREL_POSITION := Vector3(0, 0.6, -1.1)
const MUZZLE := Vector3(0, 0.6, -1.4)

# Меши общие для всех стрелков: создаются один раз.
static var body_mesh: ArrayMesh
static var barrel_mesh: ArrayMesh


func setup(new_color: String, new_ammo: int) -> void:
	color = new_color
	ammo = new_ammo

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Level.COLORS[color]

	if body_mesh == null:
		body_mesh = RoundedBox.make(Vector3(1.9, 1.0, 1.7), 0.35, 3)
		barrel_mesh = RoundedBox.make(Vector3(0.5, 0.5, 0.6), 0.15, 2)

	visual = Node3D.new()
	add_child(visual)

	var body := MeshInstance3D.new()
	body.mesh = body_mesh
	body.layers = SHADOW_LAYER
	body.material_override = mat
	body.position.y = 0.6
	visual.add_child(body)

	var barrel := MeshInstance3D.new()
	barrel.mesh = barrel_mesh
	barrel.layers = SHADOW_LAYER
	barrel.material_override = mat
	barrel.position = BARREL_POSITION
	visual.add_child(barrel)

	label = Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font = NUMBERS_FONT
	label.font_size = 72
	# Тонкая обводка тёмным оттенком цвета стрелка — мягче, чем чёрная.
	label.outline_size = 11
	label.outline_modulate = Level.COLORS[color].darkened(0.55)
	label.pixel_size = 0.012
	# На верхней грани корпуса: камера наклонена, и метка повыше съезжала бы вверх с блока.
	label.position.y = 1.1
	visual.add_child(label)
	update_label()


# Кончик ствола в мировых координатах (учитывает поворот и масштаб стрелка).
func muzzle_position() -> Vector3:
	return to_global(MUZZLE)


# Прыжок при выборе: присел, подскочил, приземлился с лёгким сплющиванием.
func hop() -> void:
	var t := create_tween()
	t.tween_property(visual, "scale", Vector3(1.15, 0.8, 1.15), 0.06)
	t.tween_property(visual, "scale", Vector3(0.9, 1.15, 0.9), 0.1)
	t.parallel().tween_property(visual, "position:y", 1.6, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(visual, "position:y", 0.0, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(visual, "scale", Vector3.ONE, 0.14)
	t.tween_property(visual, "scale", Vector3(1.1, 0.88, 1.1), 0.05)
	t.tween_property(visual, "scale", Vector3.ONE, 0.08)


func update_label() -> void:
	label.text = str(ammo)


func set_dimmed(dimmed: bool) -> void:
	label.modulate.a = 0.45 if dimmed else 1.0
	label.outline_modulate.a = 0.45 if dimmed else 1.0
