class_name Fireworks
extends Control

# Салют на весь экран: снизу взлетают ракеты с хвостом и взрываются
# шаром разноцветных искр, которые падают и гаснут. Рисуется кодом, без частиц движка.

const COLORS := [Color("ffd84a"), Color("ff5d73"), Color("4fd1ff"), Color("7dff8a"), Color("c78bff"), Color("ff9f43")]
const GRAVITY := 420.0      # для искр
const ROCKET_DRAG := 1500.0 # торможение ракеты на взлёте: чем больше, тем быстрее взлетает и взрывается
const ROCKETS := 9          # сколько всего ракет за салют
const ROCKET_GAP := 0.28    # пауза между ракетами, секунд
const SPARKS := 34          # искр в одном взрыве

var rockets: Array[Dictionary] = []
var sparks: Array[Dictionary] = []
var launched := 0
var launch_wait := 0.0


static func make() -> Fireworks:
	var f := Fireworks.new()
	f.set_anchors_preset(PRESET_FULL_RECT)
	f.mouse_filter = MOUSE_FILTER_IGNORE
	return f


func _process(delta: float) -> void:
	launch_wait -= delta
	# size.x == 0 — раскладка ещё не дошла до нас, ракета улетела бы из угла.
	if launched < ROCKETS and launch_wait <= 0.0 and size.x > 0.0:
		launch_wait = ROCKET_GAP * randf_range(0.7, 1.3)
		launch()
		if launched == 1:
			launch()  # начинаем сразу с двух ракет

	for r in rockets.duplicate():
		r.pos += r.vel * delta
		r.vel.y += ROCKET_DRAG * delta
		r.trail.push_front(r.pos)
		if r.trail.size() > 8:
			r.trail.pop_back()
		# Ракета взрывается, когда почти остановилась на взлёте.
		if r.vel.y > -250.0:
			rockets.erase(r)
			burst(r.pos, r.color)

	for s in sparks.duplicate():
		s.vel *= 1.0 - 1.6 * delta  # сопротивление воздуха: шар расширяется и замирает
		s.vel.y += GRAVITY * 0.35 * delta
		s.pos += s.vel * delta
		s.life -= delta / s.span
		if s.life <= 0.0:
			sparks.erase(s)

	queue_redraw()
	if launched >= ROCKETS and rockets.is_empty() and sparks.is_empty():
		queue_free()


func launch() -> void:
	launched += 1
	var start := Vector2(size.x * randf_range(0.15, 0.85), size.y + 10)
	# Взрывы — в верхней половине экрана, вокруг карточки.
	var peak := size.y * randf_range(0.12, 0.42)
	var speed := sqrt(2.0 * ROCKET_DRAG * (start.y - peak))
	rockets.append({
		"pos": start,
		"vel": Vector2(randf_range(-60, 60), -speed),
		"color": COLORS.pick_random(),
		"trail": [],
	})


func burst(at: Vector2, color: Color) -> void:
	var second: Color = COLORS.pick_random()
	for k in SPARKS:
		var angle := TAU * k / SPARKS + randf_range(-0.08, 0.08)
		sparks.append({
			"pos": at,
			"vel": Vector2.from_angle(angle) * randf_range(260, 420),
			"color": color if k % 3 else second,
			"life": 1.0,
			"span": randf_range(0.9, 1.4),
		})
	# Вспышка в центре взрыва — ещё пара звёздочек в стиле игры.
	for n in 3:
		Sparkle.spawn(self, at + Vector2(randf_range(-30, 30), randf_range(-30, 30)), randf_range(18, 30))


func _draw() -> void:
	for r in rockets:
		var trail: Array = r.trail
		for i in trail.size():
			var a := 1.0 - float(i) / trail.size()
			draw_circle(trail[i], 6.0 * a, Color(r.color, a), true, -1.0, true)
		draw_circle(r.pos, 6.0, Color.WHITE, true, -1.0, true)
	for s in sparks:
		var a: float = sqrt(s.life)  # гаснет медленно, а в конце быстро
		# Искра — короткий штрих по направлению полёта, к концу жизни тускнеет и мельчает.
		var tail: Vector2 = s.vel * 0.05
		draw_line(s.pos - tail, s.pos, Color(s.color, a), 8.0 * a + 2.0, true)
		draw_circle(s.pos, 5.5 * a + 1.5, Color(Color.WHITE.lerp(s.color, 0.4), a), true, -1.0, true)
