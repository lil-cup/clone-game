class_name PointerHand
extends Control

# Рука-подсказка: указательный палец вверх, кончик пальца — в точке position.
# Сама «постукивает»: опускается, жмёт с кругом-волной и поднимается обратно.

const SKIN := Color("fff1e2")
const SKIN_SHADE := Color("f3cfae")
const OUTLINE := Color("10224d")
const TILT := -0.35  # рука слегка наклонена, палец смотрит вверх-влево

var press := 0.0   # 0 — палец поднят, 1 — нажал
var ripple := 1.0  # 0..1 — круг от нажатия расходится и гаснет


static func make() -> PointerHand:
	var hand := PointerHand.new()
	hand.mouse_filter = MOUSE_FILTER_IGNORE
	return hand


func _ready() -> void:
	var t := create_tween().set_loops()
	t.tween_property(self, "press", 1.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_callback(func(): ripple = 0.0)
	t.tween_property(self, "press", 0.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_interval(0.45)


func _process(delta: float) -> void:
	ripple = minf(ripple + delta * 1.8, 1.0)
	queue_redraw()


func _draw() -> void:
	if ripple < 1.0:
		draw_arc(Vector2.ZERO, 18 + 40 * ripple, 0, TAU, 32, Color(1, 1, 1, 0.8 * (1.0 - ripple)), 6, true)
	# Поднятая рука чуть дальше от точки и чуть крупнее — будто ближе к экрану.
	var lift := 1.0 - press
	draw_set_transform(Vector2(10, 26) * lift, TILT, Vector2.ONE * (1.0 + 0.08 * lift))
	for layer in 2:
		var grow := 5.0 if layer == 0 else 0.0
		var palm := OUTLINE if layer == 0 else SKIN_SHADE
		var skin := OUTLINE if layer == 0 else SKIN
		capsule(Vector2(-14, 72), Vector2(-26, 54), 10 + grow, palm)    # большой палец
		capsule(Vector2(4, 84), Vector2(26, 84), 26 + grow, palm)       # ладонь
		for knuckle in [Vector2(22, 56), Vector2(38, 62), Vector2(48, 76)]:
			draw_circle(knuckle, 12 + grow, skin, true, -1.0, true)                       # поджатые пальцы
		if layer == 1:
			capsule(Vector2(-2, 78), Vector2(24, 78), 21, SKIN)         # светлая ладонь, снизу тень
		capsule(Vector2(0, 10), Vector2(0, 62), 12 + grow, skin)        # указательный
	# Ноготь и складка на пальце.
	draw_circle(Vector2(0, 12), 5, Color(1, 1, 1, 0.9), true, -1.0, true)
	draw_line(Vector2(-6, 40), Vector2(6, 40), SKIN_SHADE, 3, true)
	draw_set_transform(Vector2.ZERO)


func capsule(a: Vector2, b: Vector2, r: float, color: Color) -> void:
	if r <= 0.0:
		return
	var side := (b - a).normalized().orthogonal() * r
	UI.smooth_polygon(self, PackedVector2Array([a + side, b + side, b - side, a - side]), color, 1.5)
	draw_circle(a, r, color, true, -1.0, true)
	draw_circle(b, r, color, true, -1.0, true)
