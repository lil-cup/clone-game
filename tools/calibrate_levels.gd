# Подбирает для каждого уровня раскладку стрелков под нужную сложность.
# Бот жмёт случайных доступных стрелков; ищем сид, при котором он выигрывает
# примерно в DIFFICULTIES[...].target доле игр.
# Запуск: Godot --headless --path . -s tools/calibrate_levels.gd [-- 5 10 ...]
# С номерами уровней пересчитывает только их, остальным оставляет прежние сиды.
extends SceneTree

const SEEDS_TO_TRY := 40
const GAMES := 80


func _initialize() -> void:
	var only := Array(OS.get_cmdline_user_args()).map(func(a): return int(a) - 1)
	var seeds := []
	for index in Level.count():
		if not only.is_empty() and not index in only:
			seeds.append(Level.seed_for(index))
			continue
		var level := Level.load_map(index)
		var best_seed := 0
		var best_rate := -1.0
		for k in SEEDS_TO_TRY:
			var level_seed := 1000 + index * 100 + k
			var rate := win_rate(level, level_seed)
			if best_rate < 0 or absf(rate - level.settings.target) < absf(best_rate - level.settings.target):
				best_seed = level_seed
				best_rate = rate
		seeds.append(best_seed)
		print("%2d %-10s seed=%d  random bot wins %d%% (target %d%%)" % [
			index + 1, level.name, best_seed, best_rate * 100, level.settings.target * 100])

	var file := FileAccess.open("res://scripts/level_seeds.gd", FileAccess.WRITE)
	file.store_string("# Сгенерировано tools/calibrate_levels.gd — не редактируй руками.\n")
	file.store_string("class_name LevelSeeds\n\nconst SEEDS := %s\n" % str(seeds))
	quit()


func win_rate(level: Level, level_seed: int) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = level_seed
	var columns := level.make_columns(rng)
	var bot := RandomNumberGenerator.new()
	bot.seed = 1
	var wins := 0
	for g in GAMES:
		wins += int(play(level, columns, bot))
	return float(wins) / GAMES


# Упрощённая игра: стрелки едут по одному, каждый делает один круг.
func play(source: Level, source_columns: Array, rng: RandomNumberGenerator) -> bool:
	var level := Level.new()
	level.size = source.size
	level.cells = source.cells.duplicate()
	var columns := source_columns.map(func(c): return c.duplicate())
	var slots := []
	while level.blocks_left() > 0:
		var options := []
		for c in columns.size():
			if not columns[c].is_empty():
				options.append(c)
		for i in slots.size():
			options.append(-1 - i)
		if options.is_empty():
			return false
		var pick: int = options[rng.randi() % options.size()]
		var s: Dictionary
		if pick >= 0:
			s = columns[pick].pop_front().duplicate()
		else:
			s = slots.pop_at(-1 - pick)
		s.ammo -= level.simulate_lap(s.color, s.ammo)
		if s.ammo > 0:
			if slots.size() >= Level.SLOTS:
				return false
			slots.append(s)
	return true
