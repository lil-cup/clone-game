class_name Progress

# Прогресс игрока. Уровни проходятся строго по порядку:
# пройденные закрыты, открыт только следующий за ними.

const PATH := "user://progress.cfg"

# Сколько монет даём за пройденный уровень.
const LEVEL_REWARD := 40


# Сколько уровней пройдено. Он же — номер (с нуля) единственного открытого уровня.
static func completed() -> int:
	return read("completed")


static func complete(index: int) -> void:
	if index != completed():
		return
	write("completed", index + 1)


static func coins() -> int:
	return read("coins")


# Монеты зачисляются сразу, а главный экран потом показывает, как они «капают» в счётчик.
static func add_coins(amount: int) -> void:
	write("coins", coins() + amount)
	write("coins_to_show", read("coins_to_show") + amount)


# Сколько недавно полученных монет ещё не показано на главном экране (и забывает о них).
static func take_coins_to_show() -> int:
	var amount := read("coins_to_show")
	write("coins_to_show", 0)
	return amount


static func reset() -> void:
	write("completed", 0)


static func read(key: String) -> int:
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	return cfg.get_value("progress", key, 0)


static func write(key: String, value: int) -> void:
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	cfg.set_value("progress", key, value)
	cfg.save(PATH)
