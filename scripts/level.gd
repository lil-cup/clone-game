class_name Level
extends RefCounted

# Цвета блоков и стрелков. Буква в карте уровня -> цвет.
# Должны совпадать с PALETTE в tools/make_levels.py.
const COLORS := {
	"R": Color("e8434b"),
	"W": Color("f4f1ea"),
	"Y": Color("f2c94c"),
	"G": Color("4cb860"),
	"B": Color("4aa3e8"),
	"P": Color("7b55d9"),
	"O": Color("f2913d"),
	"K": Color("8b5a3c"),
	"N": Color("3a3a4a"),
	"D": Color("2e7d4f"),
	"S": Color("f29bb8"),
	"A": Color("9aa3b5"),
	"L": Color("e0b483"),
}

const LEVELS_PER_DIFFICULTY := 10

const COLUMNS := 4

# Сложность меняется каждые 10 уровней. Размер поля задаётся в tools/make_levels.py.
# caps    — сколько патронов может быть у стрелка (меньше = больше стрелков, больше решений)
# spread  — насколько «неоптимальные» цвета допускаются: 1.0 = всегда лучший цвет, 0.3 = почти любой
# shuffle — 0: колонки идут строго в порядке решения, 1: стрелки раскиданы по колонкам случайно
#           (порядок внутри колонки всё равно правильный, поэтому решение всегда есть)
# slots   — сколько мест для стрелков, вернувшихся с патронами
# target  — какую долю игр должен выигрывать бот, жмущий наугад (подбирается tools/calibrate_levels.gd)
const DIFFICULTIES := [
	{"caps": [20, 30, 40], "spread": 1.0, "shuffle": 0.0, "slots": 5, "target": 0.9},
	{"caps": [10, 20, 30], "spread": 0.3, "shuffle": 1.0, "slots": 3, "target": 0.15},
]

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
			var n := test.simulate_lap(color, cap)
			if n > 0:
				gains[color] = n
				best = maxi(best, n)

		# Случайный цвет из тех, что дают хороший выстрел, чтобы уровни были разными.
		var limit := ceili(best * settings.spread)
		var options: Array = gains.keys().filter(func(c): return gains[c] >= limit)
		var color: String = options[rng.randi() % options.size()]
		result.append({"color": color, "ammo": sim.simulate_lap(color, cap)})

	return result


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
