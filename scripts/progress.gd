class_name Progress

# Прогресс игрока. Уровни проходятся строго по порядку:
# пройденные закрыты, открыт только следующий за ними.

const PATH := "user://progress.cfg"


# Сколько уровней пройдено. Он же — номер (с нуля) единственного открытого уровня.
static func completed() -> int:
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	return cfg.get_value("progress", "completed", 0)


static func complete(index: int) -> void:
	if index != completed():
		return
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	cfg.set_value("progress", "completed", index + 1)
	cfg.save(PATH)


static func reset() -> void:
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	cfg.set_value("progress", "completed", 0)
	cfg.save(PATH)
