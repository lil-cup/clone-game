class_name CoinIcon
extends Control

# Золотая монетка, нарисованная кодом: тёмный ободок, светлое кольцо внутри и блик.
# Может вращаться вокруг вертикальной оси: тогда сжимается по ширине и показывает ребро.

const RIM := Color("c97a12")
const GOLD := Color("ffc21f")
const LIGHT := Color("ffe36b")
const EDGE := Color("e0960f")

var phase := 0.0       # угол поворота: 0 — монетка смотрит на нас лицом
var spin_speed := 0.0  # радиан в секунду; 0 — монетка не крутится


static func make(diameter: float) -> CoinIcon:
	var coin := CoinIcon.new()
	coin.custom_minimum_size = Vector2.ONE * diameter
	coin.size = coin.custom_minimum_size
	coin.pivot_offset = coin.size / 2.0
	coin.mouse_filter = MOUSE_FILTER_IGNORE
	return coin


func spin(speed: float) -> void:
	spin_speed = speed
	phase = randf() * TAU
	set_process(true)


func _ready() -> void:
	set_process(spin_speed != 0.0)


func _process(delta: float) -> void:
	phase += spin_speed * delta
	queue_redraw()


func _draw() -> void:
	var r := minf(size.x, size.y) / 2.0
	var c := size / 2.0
	var width := maxf(absf(cos(phase)), 0.1)
	# Ребро: стопка овалов, сдвинутых вбок тем сильнее, чем больше монетка повёрнута.
	var side := r * 0.22 * sin(phase)
	for k in range(4, 0, -1):
		draw_set_transform(c + Vector2(side * k / 4.0, 0), 0, Vector2(width, 1))
		draw_circle(Vector2(0, r * 0.08), r, RIM.darkened(0.3), true, -1.0, true)
		draw_circle(Vector2.ZERO, r, EDGE, true, -1.0, true)
	draw_set_transform(c, 0, Vector2(width, 1))
	draw_circle(Vector2(0, r * 0.08), r, RIM.darkened(0.3), true, -1.0, true)
	draw_circle(Vector2.ZERO, r, RIM, true, -1.0, true)
	draw_circle(Vector2.ZERO, r * 0.84, GOLD, true, -1.0, true)
	draw_arc(Vector2.ZERO, r * 0.58, 0, TAU, 32, LIGHT, r * 0.12, true)
	draw_arc(Vector2.ZERO, r * 0.68, PI * 1.1, PI * 1.45, 8, Color(1, 1, 1, 0.8), r * 0.12, true)
	draw_set_transform(Vector2.ZERO)
