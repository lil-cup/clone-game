class_name Sparkle
extends Control

# Четырёхлучевая искорка: вспыхивает и тут же гаснет.

const COLORS := [Color("fff3a0"), Color("ffd84a"), Color.WHITE]

var radius := 10.0
var color := Color.WHITE


static func spawn(parent: Node, pos: Vector2, size_px: float) -> Sparkle:
	var star := Sparkle.new()
	star.radius = size_px
	star.color = COLORS.pick_random()
	star.position = pos
	star.mouse_filter = MOUSE_FILTER_IGNORE
	star.scale = Vector2.ZERO
	parent.add_child(star)
	var t := star.create_tween()
	t.tween_property(star, "scale", Vector2.ONE, 0.1)
	t.tween_property(star, "scale", Vector2.ZERO, 0.35)
	t.parallel().tween_property(star, "modulate:a", 0.0, 0.35)
	t.tween_callback(star.queue_free)
	return star


func _draw() -> void:
	var points := PackedVector2Array()
	for k in 8:
		var r := radius if k % 2 == 0 else radius * 0.28
		points.append(Vector2.from_angle(TAU * k / 8 - PI / 2) * r)
	draw_colored_polygon(points, color)
