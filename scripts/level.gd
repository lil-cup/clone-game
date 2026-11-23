class_name Level
extends RefCounted

# Цвета блоков и стрелков. Буква в карте уровня -> цвет.
# Должны совпадать с PALETTE в tools/make_levels.py.
# Мягкие яркие цвета: не чистые «кричащие» основные, а оттенки поприятнее
# (голубой вместо синего, малиново-бордовый вместо красного), но пары, которые встречаются
# рядом на картинках (зелёный/тёмно-зелёный, бордовый/розовый/коричневый, жёлтый/бежевый),
# по-прежнему хорошо различимы. Фиолетовый уведён в сторону пурпурного, чтобы не путать
# со скрытыми пушками (Shooter.MYSTERY).
const COLORS := {
	"R": Color("d23a55"),  # малиново-бордовый
	"W": Color("fbf7ee"),  # тёплый белый
	"Y": Color("ffd43b"),  # солнечно-жёлтый
	"G": Color("4cc66a"),  # травяной
	"B": Color("45aef5"),  # голубой
	"P": Color("a457e0"),  # виноградный
	"O": Color("ff8a3d"),  # мандариновый
	"K": Color("9a5a36"),  # шоколадный
	"N": Color("1c1b2e"),  # почти чёрный (контуры)
	"D": Color("1f8048"),  # хвойный
	"S": Color("ff8fc4"),  # розовый
	"A": Color("a7b2c6"),  # серо-голубой
	"L": Color("ffcf9e"),  # персиковый
}

# Обучение (уровни 1–4, см. INTRO_TWISTS) всегда обычное. После него уровни идут циклами
# по 9: семь обычных, потом «сложный» и сразу за ним «очень сложный» — 12 и 13, 21 и 22…
const CYCLE := 9
const HARD_AT := 7  # место сложного в цикле (с нуля), очень сложный — следующий
const DIFFICULTY_NAMES := ["Обычный", "Сложный", "Очень сложный"]
const HARD_LINKS := [0, 2, 4]       # сколько пар добавить к обычному набору (см. twist())
const HARD_HIDDEN := [0.0, 0.5, 0.8]  # не меньше такой доли скрытых

const COLUMNS := 4

# С какого уровня (с нуля) появляются связанные стрелки: пара уезжает на ленту только вместе.
const LINKS_FROM := 3

# Особенности уровня, чтобы уровни отличались не только картинкой:
# hidden — какая доля стрелков позади первого в колонке скрывает цвет (0 — никто, 1 — все),
# links  — сколько связанных пар.
# Первые уровни знакомят с особенностями по одной, дальше наборы идут по кругу,
# а пар с каждым десятком уровней становится больше.
const INTRO_TWISTS := [
	{"hidden": 0.0, "links": 0},  # 1 — обучение
	{"hidden": 1.0, "links": 0},  # 2 — новинка: скрытые
	{"hidden": 0.5, "links": 0},  # 3 — первый бустер
	{"hidden": 0.0, "links": 2},  # 4 — новинка: связанные
]
const TWISTS := [
	{"hidden": 0.5, "links": 2},
	{"hidden": 1.0, "links": 0},
	{"hidden": 0.0, "links": 4},
	{"hidden": 1.0, "links": 3},
	{"hidden": 0.3, "links": 1},
	{"hidden": 0.7, "links": 5},
]

# Мест для стрелков, вернувшихся с патронами. Одинаково на всех уровнях.
const SLOTS := 5

# Меньше стольких патронов у стрелка не бывает. Калибровка отбрасывает раскладки, где это не так,
# а в картах каждого цвета хотя бы столько блоков (tools/make_levels.py).
const MIN_AMMO := 10

# Настройки по сложности уровня: обычный, сложный, очень сложный (см. CYCLE).
# Размер поля задаётся в tools/make_levels.py.
# caps    — сколько патронов может быть у стрелка (больше = чаще возвращается в слот, сложнее)
# spread  — насколько «неоптимальные» цвета допускаются: 1.0 = всегда лучший цвет, 0.3 = почти любой
# shuffle — 0: колонки идут строго в порядке решения, 1: стрелки раскиданы по колонкам случайно
#           (порядок внутри колонки всё равно правильный, поэтому решение всегда есть)
# min_ammo — меньше скольких патронов стрелков не делаем (см. MIN_AMMO)
# target  — какую долю игр должен выигрывать бот, жмущий наугад (подбирается tools/calibrate_levels.gd)
const DIFFICULTIES := [
	{"caps": [20, 30, 40], "spread": 0.4, "shuffle": 1.0, "min_ammo": MIN_AMMO, "target": 0.15},
	{"caps": [25, 40, 50], "spread": 0.25, "shuffle": 1.0, "min_ammo": MIN_AMMO, "target": 0.03},
	{"caps": [40, 60, 80], "spread": 0.1, "shuffle": 1.0, "min_ammo": MIN_AMMO, "target": 0.01},
]

var index := 0
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


# 0 — обычный, 1 — сложный, 2 — очень сложный.
static func difficulty_of(index: int) -> int:
	if index < INTRO_TWISTS.size():
		return 0
	return clampi((index - INTRO_TWISTS.size()) % CYCLE - HARD_AT + 1, 0, 2)


static func load_map(index: int) -> Level:
	var level := Level.new()
	var data: Dictionary = Levels.LIST[index]
	var map: Array = data.map
	level.name = data.name
	level.index = index
	level.difficulty = difficulty_of(index)
	level.settings = DIFFICULTIES[level.difficulty]
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
	var twist := twist()
	add_links(list, rng, twist.links)
	var columns: Array[Array] = []
	for c in COLUMNS:
		columns.append([])
	var prev := -1  # колонка предыдущего стрелка
	for i in list.size():
		var c := i % COLUMNS
		if rng.randf() < settings.shuffle:
			# Случайная колонка, но не даём одной колонке сильно вырасти.
			var shortest: int = columns.map(func(col): return col.size()).min()
			var options := range(COLUMNS).filter(func(k): return columns[k].size() <= shortest + 1)
			c = options[rng.randi() % options.size()]
		# Второй из связанной пары — в соседнюю колонку: в той же он стоял бы за первым и пара
		# не ушла бы, а через колонку трубка тянулась бы поверх чужих стрелков.
		if linked_to_previous(list, i):
			var near := [prev - 1, prev + 1].filter(func(k): return k >= 0 and k < COLUMNS)
			c = near[rng.randi() % near.size()]
		columns[c].append(list[i])
		prev = c
	# Кто из стрелков прячет цвет — отдельным генератором, чтобы не сдвигать раскладку.
	var hide_rng := RandomNumberGenerator.new()
	hide_rng.seed = rng.seed + 7919
	for item in list:
		item.hide = hide_rng.randf() < twist.hidden
	return columns


# Связывает несколько пар соседних по решению стрелков. Соседние — значит, когда приходит
# очередь первого, второй тоже уже стоит впереди своей колонки, и пара может уехать вместе.
func add_links(list: Array[Dictionary], rng: RandomNumberGenerator, want: int) -> void:
	var pairs := 0
	var i := 1  # самого первого стрелка не связываем — пусть начало будет простым
	while i < list.size() - 1 and pairs < want:
		if rng.randf() < 0.35:
			list[i].pair = pairs
			list[i + 1].pair = pairs
			pairs += 1
			i += 2
		else:
			i += 1


func twist() -> Dictionary:
	if index < INTRO_TWISTS.size():
		return INTRO_TWISTS[index]
	var k := index - INTRO_TWISTS.size()
	var t: Dictionary = TWISTS[k % TWISTS.size()].duplicate()
	if t.links > 0:
		t.links += k / 10
	# Сложные уровни трудны прежде всего особенностями: пары сильно связывают ходы,
	# а скрытые не дают спланировать. Одни только запасы патронов почти не усложняли
	# (проверено калибровкой: бот наугад всё равно выигрывал 8–17%).
	t.links += HARD_LINKS[difficulty]
	t.hidden = maxf(t.hidden, HARD_HIDDEN[difficulty])
	return t


static func linked_to_previous(list: Array, i: int) -> bool:
	return i > 0 and list[i].has("pair") and list[i - 1].get("pair", -1) == list[i].pair
