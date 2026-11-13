class_name CoinIcon
extends Control

# Золотая монетка, нарисованная кодом: тёмный ободок, светлое кольцо внутри и блик.

const RIM := Color("c97a12")
const GOLD := Color("ffc21f")
const LIGHT := Color("ffe36b")


static func make(diameter: float) -> CoinIcon:
	var coin := CoinIcon.new()
	coin.custom_minimum_size = Vector2.ONE * diameter
	coin.size = coin.custom_minimum_size
	coin.pivot_offset = coin.size / 2.0
	coin.mouse_filter = MOUSE_FILTER_IGNORE
	return coin


func _draw() -> void:
	var r := minf(size.x, size.y) / 2.0
	var c := size / 2.0
	draw_circle(c + Vector2(0, r * 0.08), r, RIM.darkened(0.3))
	draw_circle(c, r, RIM)
	draw_circle(c, r * 0.84, GOLD)
	draw_arc(c, r * 0.58, 0, TAU, 32, LIGHT, r * 0.12, true)
	draw_arc(c, r * 0.68, PI * 1.1, PI * 1.45, 8, Color(1, 1, 1, 0.8), r * 0.12, true)
