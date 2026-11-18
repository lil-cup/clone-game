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

var partner: Shooter  # связанный стрелок: уезжают на ленту только вместе
var hideable := false  # уровень разрешает ему прятать цвет, пока он не впереди
var hidden := false  # цвет и заряды скрыты, пока стрелок не выйдет вперёд в колонке
var body: MeshInstance3D
var label: Label3D
var visual: Node3D  # всё, что видно; прыгает отдельно от позиции стрелка

const MYSTERY := Color("8a6cf0")  # цвет скрытого стрелка

const NUMBERS_FONT := preload("res://fonts/nunito_numbers.tres")

# Общие на всех: материалы по цвету и мягкое пятно-тень под ногами
# (настоящие тени от солнца на телефонах дорогие — каждая панда рисовалась бы дважды).
static var materials := {}
static var blob_mesh: PlaneMesh
static var blob_material: StandardMaterial3D

# Модель-панда из Blender — один меш, оттенки частей в цветах вершин: тело белое,
# пятна у глаз серые, глаза и нос чёрные. Материал умножает их на цвет пушки, поэтому
# панда однотонная, а один материал на цвет годится для всех панд этого цвета.
const MODEL := preload("res://models/panda.glb")

# Откуда вылетают снаряды (мордочка), в координатах пушки. Морда смотрит в −Z.
const MUZZLE := Vector3(0, 0.74, -0.92)

# В колонках и слотах панда стоит мордой к игроку и чуть откинута назад:
# камера смотрит почти сверху, и без наклона от морды видна только полоска.
const LEAN := 0.45


func setup(new_color: String, new_ammo: int) -> void:
	color = new_color
	ammo = new_ammo

	var blob := MeshInstance3D.new()
	blob.mesh = shadow_blob()
	blob.material_override = blob_material
	blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	blob.position.y = 0.03
	add_child(blob)

	visual = Node3D.new()
	add_child(visual)

	var model := MODEL.instantiate()
	visual.add_child(model)
	body = model.find_children("*", "MeshInstance3D", true, false)[0]
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	label = Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font = NUMBERS_FONT
	label.font_size = 72
	label.outline_size = 11
	label.pixel_size = 0.012
	# На макушке: камера наклонена, и метка повыше съезжала бы вверх с пушки.
	label.position.y = 1.6
	visual.add_child(label)
	paint()


# Кончик ствола в мировых координатах (учитывает поворот и масштаб стрелка).
func muzzle_position() -> Vector3:
	return to_global(MUZZLE)


# Повернуться мордой к игроку (в колонке, слоте) или обратно, к полю (на ленте).
func face_player(on: bool, animated := true) -> void:
	var lean := LEAN if on else 0.0
	if not animated:
		visual.rotation.x = lean
		return
	create_tween().tween_property(visual, "rotation:x", lean, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


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


# «Нельзя»: стрелок мотает корпусом из стороны в сторону.
func wiggle() -> void:
	var t := create_tween()
	for angle in [0.3, -0.3, 0.15, 0.0]:
		t.tween_property(visual, "rotation:y", angle, 0.06)


func update_label() -> void:
	label.text = "?" if hidden else str(ammo)


# Скрыть или открыть цвет. Открытие — с прыжком, чтобы было заметно.
func set_hidden(value: bool, animated: bool) -> void:
	if value == hidden:
		return
	hidden = value
	paint()
	if animated and not hidden:
		hop()


func paint() -> void:
	var c: Color = MYSTERY if hidden else Level.COLORS[color]
	body.material_override = material_for(c)
	# Тонкая обводка тёмным оттенком цвета стрелка — мягче, чем чёрная.
	var alpha := label.outline_modulate.a
	label.outline_modulate = Color(c.darkened(0.55), alpha)
	update_label()


static func material_for(c: Color) -> StandardMaterial3D:
	if not materials.has(c):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = c
		mat.vertex_color_use_as_albedo = true
		mat.roughness = 0.35
		materials[c] = mat
	return materials[c]


# Пятно-тень: квадрат с круглым мягким градиентом, общий на всех панд.
static func shadow_blob() -> PlaneMesh:
	if not blob_mesh:
		blob_mesh = PlaneMesh.new()
		blob_mesh.size = Vector2(2.1, 2.0)
		var gradient := Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
		gradient.colors = PackedColorArray([Color(0, 0, 0, 0.45), Color(0, 0, 0, 0.3), Color(0, 0, 0, 0)])
		var texture := GradientTexture2D.new()
		texture.gradient = gradient
		texture.fill = GradientTexture2D.FILL_RADIAL
		texture.fill_from = Vector2(0.5, 0.5)
		texture.fill_to = Vector2(1.0, 0.5)
		texture.width = 64
		texture.height = 64
		blob_material = StandardMaterial3D.new()
		blob_material.albedo_texture = texture
		blob_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		blob_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return blob_mesh


func set_dimmed(dimmed: bool) -> void:
	label.modulate.a = 0.45 if dimmed else 1.0
	label.outline_modulate.a = 0.45 if dimmed else 1.0
