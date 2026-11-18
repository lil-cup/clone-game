class_name FpsMeter
extends Label

# Счётчик кадров для проверки на телефоне: кадров в секунду и самый долгий кадр за полсекунды.
# Включается тройным нажатием на заголовок уровня. Если «худший кадр» часто больше ~33 мс,
# движение пушек выглядит рывками.

var frames := 0
var worst := 0.0
var elapsed := 0.0


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
	meter.hide()
	return meter


func _process(delta: float) -> void:
	frames += 1
	worst = maxf(worst, delta)
	elapsed += delta
	if elapsed >= 0.5:
		text = "%d FPS\nхудший кадр %d мс" % [roundi(frames / elapsed), roundi(worst * 1000.0)]
		frames = 0
		worst = 0.0
		elapsed = 0.0
