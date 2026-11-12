class_name Level
extends RefCounted

# Цвета блоков и стрелков. Буква в карте уровня -> цвет.
# Должны совпадать с PALETTE в tools/make_levels.py.
const COLORS := {
	"R": Color("ff6b6b"),
	"W": Color("fdfbf5"),
	"Y": Color("ffd166"),
	"G": Color("6bcb77"),
	"B": Color("5ab8f0"),
	"P": Color("9b7ede"),
	"O": Color("ff9f43"),
	"K": Color("a47551"),
	"N": Color("4a4e69"),
	"D": Color("3a9d6b"),
	"S": Color("ff9ecd"),
	"A": Color("b8c0d6"),
	"L": Color("f3c995"),
}

const LEVELS_PER_DIFFICULTY := 10

const COLUMNS := 4

# Мест для стрелков, вернувшихся с патронами. Одинаково на всех уровнях.
const SLOTS := 5

# Сложность меняется каждые 10 уровней. Размер поля задаётся в tools/make_levels.py.
# caps    — сколько патронов может быть у стрелка (меньше = больше стрелков, больше решений)
# spread  — насколько «неоптимальные» цвета допускаются: 1.0 = всегда лучший цвет, 0.3 = почти любой
# shuffle — 0: колонки идут строго в порядке решения, 1: стрелки раскиданы по колонкам случайно
#           (порядок внутри колонки всё равно правильный, поэтому решение всегда есть)
# min_ammo — меньше скольких блоков за круг стрелок не делаем (кроме самого конца уровня)
# target  — какую долю игр должен выигрывать бот, жмущий наугад (подбирается tools/calibrate_levels.gd)
const DIFFICULTIES := [
	{"caps": [20, 30], "spread": 0.6, "shuffle": 0.5, "min_ammo": 8, "target": 0.5},
	{"caps": [20, 30, 40], "spread": 0.3, "shuffle": 1.0, "min_ammo": 10, "target": 0.15},
	{"caps": [20, 30, 40], "spread": 0.2, "shuffle": 1.0, "min_ammo": 10, "target": 0.08},
]

# Уровни-фигуры (без фона) мелкие, поэтому патронов у стрелков чуть меньше — иначе слишком просто.
const FIGURE_CAPS := [15, 25]
const FIGURE_MIN_AMMO := 6

var size := 0
var cells: Array[String] = []  # "" = пусто, иначе буква цвета
var name := ""
var difficulty := 0
var settings: Dictionary


static func count() -> int:
	return Levels.LIST.size()


# Сид раскладки стрелков, подобранный калибровкой под нужную сложность.
static func seed_for(index: int) -> int:
	if index < LevelSeeds.SEEDS.size():
		return LevelSeeds.SEEDS[index]
	return 1000 + index


static func load_map(index: int) -> Level:
	var level := Level.new()
	var data: Dictionary = Levels.LIST[index]
	var map: Array = data.map
	level.name = data.name
	level.difficulty = index / LEVELS_PER_DIFFICULTY
	level.settings = DIFFICULTIES[mini(level.difficulty, DIFFICULTIES.size() - 1)]
	if data.get("figure", false):
		level.settings = level.settings.duplicate()
		level.settings.caps = FIGURE_CAPS
		level.settings.min_ammo = FIGURE_MIN_AMMO
	level.size = map.size()
	for row in level.size:
		var line: String = map[row]
		for col in level.size:
			level.cells.append("" if line[col] == "." else line[col])
	return level


func get_cell(col: int, row: int) -> String:
	return cells[row * size + col]


func remove(cell: Vector2i) -> void:
	cells[cell.y * size + cell.x] = ""


func blocks_left() -> int:
	return cells.size() - cells.count("")


# Первый блок, в который попадёт выстрел с дорожки.
# side: 0 низ, 1 право, 2 верх, 3 лево (по ходу ленты), lane: номер полосы на этой стороне.
func first_block(side: int, lane: int) -> Vector2i:
	var cell: Vector2i
	var dir: Vector2i
	match side:
		0:
			cell = Vector2i(lane, size - 1)
			dir = Vector2i.UP
		1:
			cell = Vector2i(size - 1, size - 1 - lane)
			dir = Vector2i.LEFT
		2:
			cell = Vector2i(size - 1 - lane, 0)
			dir = Vector2i.DOWN
		_:
			cell = Vector2i(0, lane)
			dir = Vector2i.RIGHT
	for step in size:
		if get_cell(cell.x, cell.y) != "":
			return cell
		cell += dir
	return Vector2i(-1, -1)


# Один круг стрелка по ленте. Возвращает сколько блоков он выбил.
func simulate_lap(color: String, ammo: int) -> int:
	var shots := 0
	for side in 4:
		for lane in size:
			if shots == ammo:
				return shots
			var cell := first_block(side, lane)
			if cell.x >= 0 and get_cell(cell.x, cell.y) == color:
				remove(cell)
				shots += 1
	return shots


# Несколько кругов одного стрелка подряд (между кругами он ждёт в слоте), пока не кончатся
# патроны или круг не пройдёт впустую. Возвращает, сколько блоков он выбил за все круги.
func simulate_laps(color: String, ammo: int) -> int:
	var shots := 0
	while shots < ammo:
		var n := simulate_lap(color, ammo - shots)
		if n == 0:
			break
		shots += n
	return shots


# Подбирает стрелков так, чтобы, запуская их по очереди, уровень проходился полностью.
# Сумма патронов каждого цвета точно равна числу блоков этого цвета.
func generate_shooters(rng: RandomNumberGenerator) -> Array[Dictionary]:
	var sim := Level.new()
	sim.size = size
	sim.cells = cells.duplicate()
	var result: Array[Dictionary] = []
	var caps: Array = settings.caps

	while sim.blocks_left() > 0:
		var cap: int = caps[rng.randi() % caps.size()]
		var gains := {}
		var best := 0
		for color in COLORS:
			if not sim.cells.has(color):
				continue
			var test := Level.new()
			test.size = size
			test.cells = sim.cells.duplicate()
			var n := test.simulate_laps(color, cap)
			if n > 0:
				gains[color] = n
				best = maxi(best, n)

		# Случайный цвет из тех, что дают хороший выстрел, чтобы уровни были разными.
		# Но не слишком мелкий: стрелки с 1–2 патронами только раздражают.
		var limit := mini(maxi(ceili(best * settings.spread), settings.min_ammo), best)
		var options: Array = gains.keys().filter(func(c): return gains[c] >= limit)
		var color: String = options[rng.randi() % options.size()]
		result.append({"color": color, "ammo": sim.simulate_laps(color, cap)})

	return merge_small(result)


# Сколько стрелков одновременно может ждать в слоте свой остаток (слотов всего SLOTS).
const MAX_WAITING := 2


# Мелкий стрелок (остаток цвета) отдаёт патроны предыдущему стрелку того же цвета.
# Тот после своих кругов ждёт в слоте и добирает остаток, когда до него дойдёт очередь.
func merge_small(list: Array[Dictionary]) -> Array[Dictionary]:
	var waiting: Array[Vector2i] = []  # от какого до какого шага решения стрелок ждёт в слоте
	var i := 0
	while i < list.size():
		if list[i].ammo >= settings.min_ammo:
			i += 1
			continue
		var j := i - 1
		while j >= 0 and list[j].color != list[i].color:
			j -= 1
		var busy := waiting.filter(func(w): return w.x < i and w.y > j).size()
		if j < 0 or busy >= MAX_WAITING:
			i += 1
			continue
		list[j].ammo += list[i].ammo
		list.remove_at(i)
		# Номера шагов после i сдвинулись на один.
		for k in waiting.size():
			if waiting[k].y > i:
				waiting[k].y -= 1
		waiting.append(Vector2i(j, i))
	return list


# Раскладывает стрелков по колонкам. Порядок внутри каждой колонки совпадает с порядком решения,
# поэтому, беря стрелков в этом порядке, уровень проходится без слотов.
func make_columns(rng: RandomNumberGenerator) -> Array[Array]:
	var list := generate_shooters(rng)
	var columns: Array[Array] = []
	for c in COLUMNS:
		columns.append([])
	for i in list.size():
		var c := i % COLUMNS
		if rng.randf() < settings.shuffle:
			# Случайная колонка, но не даём одной колонке сильно вырасти.
			var shortest: int = columns.map(func(col): return col.size()).min()
			var options := range(COLUMNS).filter(func(k): return columns[k].size() <= shortest + 1)
			c = options[rng.randi() % options.size()]
		columns[c].append(list[i])
	return columns
