class_name Level
extends RefCounted

# Цвета блоков и стрелков. Буква в карте уровня -> цвет.
# Должны совпадать с PALETTE в tools/make_levels.py.
const COLORS := {
	"R": Color("e8202a"),
	"W": Color("ffffff"),
	"Y": Color("ffd400"),
	"G": Color("22b53a"),
	"B": Color("1f8fff"),
	"P": Color("7a3cf0"),
	"O": Color("ff7a00"),
	"K": Color("7a4520"),
	"N": Color("1b1b2b"),
	"D": Color("0f6b2c"),
	"S": Color("ff6fb5"),
	"A": Color("9aa3b8"),
	"L": Color("f7c48a"),
}

const LEVELS_PER_DIFFICULTY := 10

const COLUMNS := 4

# Мест для стрелков, вернувшихся с патронами. Одинаково на всех уровнях.
const SLOTS := 5

# Меньше стольких патронов у стрелка не бывает. Калибровка отбрасывает раскладки, где это не так,
# а в картах каждого цвета хотя бы столько блоков (tools/make_levels.py).
const MIN_AMMO := 10

# Сложность меняется каждые 10 уровней. Размер поля задаётся в tools/make_levels.py.
# caps    — сколько патронов может быть у стрелка (больше = чаще возвращается в слот, сложнее)
# spread  — насколько «неоптимальные» цвета допускаются: 1.0 = всегда лучший цвет, 0.3 = почти любой
# shuffle — 0: колонки идут строго в порядке решения, 1: стрелки раскиданы по колонкам случайно
#           (порядок внутри колонки всё равно правильный, поэтому решение всегда есть)
# min_ammo — меньше скольких патронов стрелков не делаем (см. MIN_AMMO)
# target  — какую долю игр должен выигрывать бот, жмущий наугад (подбирается tools/calibrate_levels.gd)
const DIFFICULTIES := [
	{"caps": [20, 30, 40], "spread": 0.4, "shuffle": 1.0, "min_ammo": MIN_AMMO, "target": 0.25},
	{"caps": [25, 35, 50], "spread": 0.25, "shuffle": 1.0, "min_ammo": MIN_AMMO, "target": 0.06},
	{"caps": [30, 45, 60], "spread": 0.15, "shuffle": 1.0, "min_ammo": MIN_AMMO, "target": 0.02},
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
		var ammo := tail_safe_ammo(sim, color, gains[color])
		result.append({"color": color, "ammo": sim.simulate_laps(color, ammo)})

	return merge_small(result)


# Сколько патронов дать стрелку, чтобы блоков его цвета на поле не осталось меньше min_ammo:
# из такого хвоста потом получится только мелкий стрелок. Либо добираем хвост сразу,
# либо стреляем меньше и оставляем хвост побольше.
func tail_safe_ammo(sim: Level, color: String, ammo: int) -> int:
	var min_ammo: int = settings.min_ammo
	var rest := sim.cells.count(color) - ammo
	if rest == 0 or rest >= min_ammo:
		return ammo
	var test := Level.new()
	test.size = size
	test.cells = sim.cells.duplicate()
	if test.simulate_laps(color, ammo + rest) == ammo + rest:
		return ammo + rest
	var less := ammo - (min_ammo - rest)
	return less if less >= min_ammo else ammo


# Сколько стрелков одновременно может ждать в слоте свой остаток (слотов всего SLOTS).
const MAX_WAITING := 2


# Мелкий стрелок (остаток цвета) отдаёт патроны предыдущему стрелку того же цвета.
# Тот после своих кругов ждёт в слоте и добирает остаток, когда до него дойдёт очередь.
# Если предыдущего нет — наоборот, забирает патроны следующего стрелка своего цвета и ждёт его очереди.
func merge_small(list: Array[Dictionary]) -> Array[Dictionary]:
	var waiting: Array[Vector2i] = []  # от какого до какого шага решения стрелок ждёт в слоте
	# Сначала бережём слоты для игрока, потом разрешаем занять ожидающими все слоты.
	for limit in [MAX_WAITING, SLOTS]:
		var i := 0
		while i < list.size():
			if list[i].ammo >= settings.min_ammo:
				i += 1
				continue
			var j := i - 1
			while j >= 0 and list[j].color != list[i].color:
				j -= 1
			var k := i + 1
			while k < list.size() and list[k].color != list[i].color:
				k += 1
			var from := -1
			var to := -1
			if j >= 0 and busy(waiting, j, i) < limit:
				from = j
				to = i
			elif k < list.size() and busy(waiting, i, k) < limit:
				from = i
				to = k
			if from < 0:
				i += 1
				continue
			list[from].ammo += list[to].ammo
			list.remove_at(to)
			# Номера шагов после to сдвинулись на один.
			for w in waiting.size():
				if waiting[w].y > to:
					waiting[w].y -= 1
			waiting.append(Vector2i(from, to))
			# Слитый стрелок мог остаться мелким — проверяем его ещё раз.
			i = from
	return list


# Сколько стрелков ждут в слотах между шагами from и to.
static func busy(waiting: Array[Vector2i], from: int, to: int) -> int:
	return waiting.filter(func(w): return w.x < to and w.y > from).size()


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
