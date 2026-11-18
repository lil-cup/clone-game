class_name Progress

# Прогресс игрока. Уровни проходятся строго по порядку:
# пройденные закрыты, открыт только следующий за ними.

const PATH := "user://progress.cfg"

# Сколько монет даём за пройденный уровень.
const LEVEL_REWARD := 40

# Жизни: проигрыш или выход из уровня стоит одной, без жизней играть нельзя.
const MAX_LIVES := 5
const LIFE_SECONDS := 15 * 60  # за сколько восстанавливается одна жизнь
const FREE_LEVELS := 10        # на стольких первых уровнях жизни бесконечные


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


# Бустеры (id из BoosterBar.KINDS): сколько есть и выдан ли уже первый в подарок.
# У «+1 места» ключи без суффикса — так он сохранялся, когда был единственным.
static func boosters(id: String) -> int:
	return read(booster_key("boosters", id))


static func use_booster(id: String) -> void:
	write(booster_key("boosters", id), maxi(boosters(id) - 1, 0))


static func booster_gift_taken(id: String) -> bool:
	return read(booster_key("booster_gift", id)) == 1


static func take_booster_gift(id: String) -> void:
	write(booster_key("booster_gift", id), 1)
	write(booster_key("boosters", id), boosters(id) + 1)


static func booster_key(key: String, id: String) -> String:
	return key if id == "slot" else key + "_" + id


# Храним не сколько жизней есть, а сколько потеряно: у нового игрока по умолчанию 0 потерь = полные жизни.
# lives_since — когда началось восстановление следующей жизни.
static func lives() -> int:
	refill()
	return MAX_LIVES - read("lives_lost")


static func lose_life(level_index: int) -> void:
	if level_index < FREE_LEVELS:
		return
	refill()
	var lost := read("lives_lost")
	if lost == 0:
		write("lives_since", now())
	write("lives_lost", mini(lost + 1, MAX_LIVES))


# Через сколько секунд появится следующая жизнь (0 — жизни полные).
static func next_life_in() -> int:
	refill()
	if read("lives_lost") == 0:
		return 0
	return maxi(LIFE_SECONDS - (now() - read("lives_since")), 0)


# Начисляет жизни, накопившиеся с прошлого раза (в том числе пока игра была закрыта).
static func refill() -> void:
	var lost := read("lives_lost")
	if lost == 0:
		return
	var since := read("lives_since")
	var gained := (now() - since) / LIFE_SECONDS
	if gained <= 0:
		return
	write("lives_lost", maxi(lost - gained, 0))
	write("lives_since", since + gained * LIFE_SECONDS)


static func now() -> int:
	return int(Time.get_unix_time_from_system())


# Пока игрок на первых уровнях, жизни бесконечные.
static func lives_infinite() -> bool:
	return completed() < FREE_LEVELS


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
