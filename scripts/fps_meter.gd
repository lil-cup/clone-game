class_name FpsMeter
extends Label

# Счётчик кадров для проверки на телефоне: кадров в секунду и самый долгий кадр за полсекунды.
# Включается тройным нажатием на заголовок уровня. Если «худший кадр» часто больше ~33 мс,
# движение пушек выглядит рывками.
# Под цифрами — график времени последних кадров: средний FPS прячет неровность,
# а по графику видно, идут ли кадры ровно (гладкая линия) или вразнобой (пила).

const HISTORY := 120          # сколько последних кадров на графике (~2 с)
const GRAPH_SIZE := Vector2(240, 90)
const GRAPH_MAX_MS := 50.0    # верх графика

var frames := 0
var worst := 0.0
var best := 1.0
var elapsed := 0.0
var history := PackedFloat32Array()
var head := 0  # куда писать следующий кадр в history (кольцевой буфер)


static func make() -> FpsMeter:
	var meter := FpsMeter.new()
	meter.add_theme_font_size_override("font_size", 26)
	meter.add_theme_color_override("font_color", Color.WHITE)
	meter.add_theme_color_override("font_outline_color", Color.BLACK)
	meter.add_theme_constant_override("outline_size", 8)
	meter.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	meter.set_anchors_and_offsets_preset(PRESET_TOP_RIGHT)
	meter.grow_horizontal = GROW_DIRECTION_BEGIN
	meter.position += Vector2(-20, 120)
	meter.process_mode = PROCESS_MODE_ALWAYS
	meter.mouse_filter = MOUSE_FILTER_IGNORE
	meter.history.resize(HISTORY)
	meter.hide()
	return meter


func _process(delta: float) -> void:
	history[head] = delta
	head = (head + 1) % HISTORY
	frames += 1
	worst = maxf(worst, delta)
	best = minf(best, delta)
	elapsed += delta
	if elapsed >= 0.5:
		text = "%d FPS\nкадр %d–%d мс" % [roundi(frames / elapsed), roundi(best * 1000.0), roundi(worst * 1000.0)]
		frames = 0
		worst = 0.0
		best = 1.0
		elapsed = 0.0
	if visible:
		queue_redraw()


func _draw() -> void:
	var origin := Vector2(size.x - GRAPH_SIZE.x, size.y + 10)
	draw_rect(Rect2(origin, GRAPH_SIZE), Color(0, 0, 0, 0.6))
	# Линии 60 и 30 FPS.
	for ms: float in [1000.0 / 60.0, 1000.0 / 30.0]:
		var y := origin.y + GRAPH_SIZE.y * (1.0 - ms / GRAPH_MAX_MS)
		draw_line(Vector2(origin.x, y), Vector2(origin.x + GRAPH_SIZE.x, y), Color(1, 1, 1, 0.35), 1.0)
	var bar := GRAPH_SIZE.x / HISTORY
	for i in HISTORY:
		var ms := history[(head + i) % HISTORY] * 1000.0
		var h := GRAPH_SIZE.y * minf(ms / GRAPH_MAX_MS, 1.0)
		var color := Color("6ee7a0") if ms < 20.0 else (Color("ffd166") if ms < 36.0 else Color("ff5d73"))
		draw_rect(Rect2(origin.x + i * bar, origin.y + GRAPH_SIZE.y - h, maxf(bar - 0.5, 1.0), h), color)
