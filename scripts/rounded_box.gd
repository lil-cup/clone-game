class_name RoundedBox

# Куб со скруглёнными рёбрами и углами.
# Каждая грань разбивается на сетку (частую у краёв), затем каждая точка
# «притягивается» к скруглённой поверхности: берём ближайшую точку внутреннего
# куба (меньше на радиус) и отступаем от неё на радиус наружу.
# segments — сколько шагов на скругление: больше = глаже, но больше треугольников.
static func make(size: Vector3, radius: float, segments := 3) -> ArrayMesh:
	var half := size / 2.0
	radius = minf(radius, minf(half.x, minf(half.y, half.z)))
	var inner := half - Vector3.ONE * radius

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Грани: нормаль и две оси вдоль грани (порядок осей задаёт направление обхода).
	var faces := [
		[Vector3.RIGHT, Vector3.BACK, Vector3.UP],
		[Vector3.LEFT, Vector3.UP, Vector3.BACK],
		[Vector3.UP, Vector3.RIGHT, Vector3.BACK],
		[Vector3.DOWN, Vector3.BACK, Vector3.RIGHT],
		[Vector3.BACK, Vector3.UP, Vector3.RIGHT],
		[Vector3.FORWARD, Vector3.RIGHT, Vector3.UP],
	]
	for face in faces:
		var n: Vector3 = face[0]
		var a: Vector3 = face[1]
		var b: Vector3 = face[2]
		var us := axis_steps(absf(a.dot(half)), radius, segments)
		var vs := axis_steps(absf(b.dot(half)), radius, segments)
		var depth := absf(n.dot(half))
		var grid := []
		for u in us:
			var row := []
			for v in vs:
				var p: Vector3 = n * depth + a * u + b * v
				var core := p.clamp(-inner, inner)
				var normal := (p - core).normalized()
				if normal == Vector3.ZERO:
					normal = n
				row.append([core + normal * radius, normal])
			grid.append(row)
		for i in us.size() - 1:
			for j in vs.size() - 1:
				var q := [grid[i][j], grid[i + 1][j], grid[i + 1][j + 1], grid[i][j + 1]]
				for k in [0, 1, 2, 0, 2, 3]:
					st.set_normal(q[k][1])
					st.add_vertex(q[k][0])

	st.index()
	return st.commit()


# Координаты вдоль одной оси грани: частые шаги на скруглениях, один большой шаг посередине.
static func axis_steps(half: float, radius: float, segments: int) -> Array[float]:
	var steps: Array[float] = []
	for i in segments + 1:
		steps.append(-(half - radius) - radius * cos(PI / 2.0 * i / segments))
	for i in segments + 1:
		steps.append((half - radius) + radius * sin(PI / 2.0 * i / segments))
	return steps
