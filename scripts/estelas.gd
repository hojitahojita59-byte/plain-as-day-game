extends RefCounted
## Estelas de agua: camino por las calles del plano y la cinta de luz que lo dibuja.

const PLANO := preload("res://scripts/ui/plano_parroquia.gd")
const SHADER := preload("res://materials/estela.gdshader")

const C_MUERTE := Color(0.55, 0.86, 1.0)
const C_SANOS := Color(1.0, 0.78, 0.36)


## Polilínea (plano) de desde a hasta por el centro de las calles.
static func camino(desde: Vector2, hasta: Vector2) -> PackedVector2Array:
	var nodos: Array[Vector2] = []
	var en_calle: Array = []
	for c in PLANO.CALLES:
		en_calle.append([])
	var calles: Array = PLANO.CALLES
	for i in calles.size():
		var c: Dictionary = calles[i]
		_nodo(nodos, en_calle[i], _en(c, float(c["de"])))
		_nodo(nodos, en_calle[i], _en(c, float(c["a"])))
		for j in calles.size():
			var o: Dictionary = calles[j]
			if j <= i or bool(o["h"]) == bool(c["h"]):
				continue
			var h: Dictionary = c if bool(c["h"]) else o
			var v: Dictionary = o if bool(c["h"]) else c
			var x := float(v["en"])
			var y := float(h["en"])
			if x >= float(h["de"]) and x <= float(h["a"]) and y >= float(v["de"]) and y <= float(v["a"]):
				var k := _nodo(nodos, en_calle[i], Vector2(x, y))
				if not en_calle[j].has(k):
					en_calle[j].append(k)
	var ini := _proyectar(desde)
	var fin := _proyectar(hasta)
	var a := _nodo(nodos, en_calle[ini[0]], ini[1])
	var b := _nodo(nodos, en_calle[fin[0]], fin[1])

	var astar := AStar2D.new()
	for k in nodos.size():
		astar.add_point(k, nodos[k])
	for i in calles.size():
		var c: Dictionary = calles[i]
		var lista: Array = en_calle[i]
		lista.sort_custom(func(p, q): return _a_lo_largo(c, nodos[p]) < _a_lo_largo(c, nodos[q]))
		for n in range(lista.size() - 1):
			if lista[n] != lista[n + 1]:
				astar.connect_points(lista[n], lista[n + 1])
	var tramo := astar.get_point_path(a, b)
	var out := PackedVector2Array([desde])
	for p in tramo:
		if out[out.size() - 1].distance_to(p) > 0.0005:
			out.append(p)
	if out[out.size() - 1].distance_to(hasta) > 0.0005:
		out.append(hasta)
	return out


static func _en(c: Dictionary, a: float) -> Vector2:
	return Vector2(a, float(c["en"])) if bool(c["h"]) else Vector2(float(c["en"]), a)


static func _a_lo_largo(c: Dictionary, p: Vector2) -> float:
	return p.x if bool(c["h"]) else p.y


## Índice de un nodo (lo crea si no existe) y lo apunta en la lista de su calle.
static func _nodo(nodos: Array[Vector2], lista: Array, p: Vector2) -> int:
	var k := -1
	for i in nodos.size():
		if nodos[i].distance_to(p) < 0.0005:
			k = i
	if k < 0:
		nodos.append(p)
		k = nodos.size() - 1
	if not lista.has(k):
		lista.append(k)
	return k


## [índice de calle, punto más cercano sobre su eje].
static func _proyectar(p: Vector2) -> Array:
	var mejor := [0, Vector2.ZERO]
	var dist := INF
	var calles: Array = PLANO.CALLES
	for i in calles.size():
		var c: Dictionary = calles[i]
		var a := clampf(_a_lo_largo(c, p), float(c["de"]), float(c["a"]))
		var q := _en(c, a)
		if q.distance_to(p) < dist:
			dist = q.distance_to(p)
			mejor = [i, q]
	return mejor


static func largo(puntos: PackedVector2Array) -> float:
	var t := 0.0
	for i in range(1, puntos.size()):
		t += puntos[i - 1].distance_to(puntos[i])
	return t


## Corre la polilínea d metros a un lado (con inglete), salvo el último punto:
## varias estelas por la misma calle se ven como un haz que se junta en la fuente.
static func desplazar(puntos: PackedVector3Array, d: float) -> PackedVector3Array:
	if absf(d) < 0.001 or puntos.size() < 2:
		return puntos
	var out := PackedVector3Array()
	for i in puntos.size():
		if i == puntos.size() - 1:
			out.append(puntos[i])
			continue
		var a := (puntos[i] - puntos[maxi(i - 1, 0)]).normalized() if i > 0 else Vector3.ZERO
		var b := (puntos[i + 1] - puntos[i]).normalized()
		var dir := (a + b).normalized() if (a + b).length() > 0.001 else b
		var lado := Vector3(-dir.z, 0.0, dir.x)
		var factor := 1.0 / maxf(absf(lado.dot(Vector3(-b.z, 0.0, b.x))), 0.5)
		out.append(puntos[i] + lado * d * factor)
	return out


## Cinta plana (XZ) a lo largo de una polilínea 3D; UV.x = fracción recorrida.
static func cinta(puntos: PackedVector3Array, ancho: float) -> ArrayMesh:
	var total := 0.0
	var acum: Array[float] = [0.0]
	for i in range(1, puntos.size()):
		total += puntos[i - 1].distance_to(puntos[i])
		acum.append(total)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var izq: Array[Vector3] = []
	var der: Array[Vector3] = []
	for i in puntos.size():
		var d := Vector3.ZERO
		if i > 0:
			d += (puntos[i] - puntos[i - 1]).normalized()
		if i < puntos.size() - 1:
			d += (puntos[i + 1] - puntos[i]).normalized()
		d.y = 0.0
		d = d.normalized() if d.length() > 0.0001 else Vector3.RIGHT
		var lado := Vector3(-d.z, 0.0, d.x)
		# Inglete en las esquinas para que la cinta no adelgace.
		var factor := 1.0
		if i > 0 and i < puntos.size() - 1:
			var a := (puntos[i] - puntos[i - 1]).normalized()
			factor = 1.0 / maxf(absf(lado.dot(Vector3(-a.z, 0.0, a.x))), 0.5)
		izq.append(puntos[i] + lado * ancho * 0.5 * factor)
		der.append(puntos[i] - lado * ancho * 0.5 * factor)
	for i in range(puntos.size() - 1):
		var u0 := acum[i] / maxf(total, 0.001)
		var u1 := acum[i + 1] / maxf(total, 0.001)
		var quad := [[izq[i], Vector2(u0, 0)], [der[i], Vector2(u0, 1)], [izq[i + 1], Vector2(u1, 0)],
			[der[i], Vector2(u0, 1)], [der[i + 1], Vector2(u1, 1)], [izq[i + 1], Vector2(u1, 0)]]
		for v in quad:
			st.set_uv(v[1])
			st.add_vertex(v[0])
	return st.commit()


static func material(clase: String, metros: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter(&"color", C_SANOS if clase == "sanos" else C_MUERTE)
	m.set_shader_parameter(&"largo", metros)
	m.set_shader_parameter(&"avance", 1.0)
	return m


## Dibuja la cinta de 0 a 1 en `segundos`.
static func animar(malla: MeshInstance3D, segundos: float) -> Tween:
	var m := malla.material_override as ShaderMaterial
	m.set_shader_parameter(&"avance", 0.0)
	var t := malla.create_tween()
	t.tween_method(func(v: float): m.set_shader_parameter(&"avance", v), 0.0, 1.0, segundos) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return t
