extends Node3D
## Rastro de luces en el suelo hasta la rectoría, cuando hay algo que llevar a casa.

## La guía decide cuándo toca volver.
const GUIA := preload("res://scripts/guia.gd")

## Segundos entre recálculos de ruta.
const CADA := 0.35

## Metros entre luces.
const PASO := 1.4

## Metros sin luces junto a los pies.
const CERCA := 2.6

## Metros recortados antes de la salida.
const HASTA := 0.8

## Amarillo de gas.
const LUZ := Color(0.98, 0.94, 0.80)

## Lo asigna el constructor tras _ready (en _ready es null).
var jugador: Node3D
## Salidas que son casa, en coords. del mundo.
var salidas: Array[Vector3] = []


var _luces: Array[MeshInstance3D] = []
var _malla: QuadMesh
var _halo: GradientTexture2D
var _reloj: float = 0.0
var _fase: float = 0.0
var _ruta: PackedVector3Array = PackedVector3Array()
## Salida elegida, para no cambiar a cada paso.
var _elegida: Vector3 = Vector3.INF
## Metros de ventaja que necesita otra salida para cambiar.
const VENTAJA := 8.0


func _ready() -> void:
	_malla = QuadMesh.new()
	_malla.size = Vector2(1.05, 1.05)

	# Halo radial: se lee como resplandor, no como baldosa.
	_halo = GradientTexture2D.new()
	_halo.width = 64
	_halo.height = 64
	_halo.fill = GradientTexture2D.FILL_RADIAL
	_halo.fill_from = Vector2(0.5, 0.5)
	_halo.fill_to = Vector2(1.0, 0.5)
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	# Punto medio: da un núcleo al charco.
	g.add_point(0.45, Color(1, 1, 1, 0.55))
	_halo.gradient = g

	set_process(true)


func _process(delta: float) -> void:
	# La onda indica la dirección.
	_fase = fmod(_fase + delta * 0.75, 1.0)

	_reloj -= delta
	if _reloj <= 0.0:
		_reloj = CADA
		_recalcular()

	_pintar()


func _recalcular() -> void:
	_ruta = PackedVector3Array()
	if jugador == null or salidas.is_empty():
		return
	if not _hay_algo_que_llevar():
		return
	# No durante un diálogo.
	if DialogueRunner.active:
		return

	var desde := jugador.global_position

	# Mantener la salida elegida salvo que otra esté VENTAJA m más cerca.
	var mejor := salidas[0]
	for s in salidas:
		if desde.distance_squared_to(s) < desde.distance_squared_to(mejor):
			mejor = s
	if _elegida == Vector3.INF:
		_elegida = mejor
	elif mejor != _elegida \
			and desde.distance_to(mejor) + VENTAJA < desde.distance_to(_elegida):
		_elegida = mejor
	var destino := _elegida

	var mapa := get_world_3d().navigation_map
	_ruta = NavigationServer3D.map_get_path(mapa, desde, destino, true)


## Según la etapa de la guía (clave "a_casa").
func _hay_algo_que_llevar() -> bool:
	return bool(GUIA.etapa().get("a_casa", false))


func _pintar() -> void:
	var puntos := _repartir()
	_asegurar(puntos.size())
	for i in _luces.size():
		var luz := _luces[i]
		if i >= puntos.size():
			luz.visible = false
			continue
		luz.visible = true
		luz.global_position = puntos[i] + Vector3.UP * 0.05

		# Onda: cada luz brilla a su turno.
		var t := fmod(float(i) / 9.0 - _fase + 1.0, 1.0)
		var brillo: float = pow(1.0 - t, 3.0) * 0.85 + 0.22
		var mat := luz.material_override as StandardMaterial3D
		mat.albedo_color = Color(LUZ.r, LUZ.g, LUZ.b, brillo)


## Puntos de la ruta cada PASO m, recortados por ambos extremos.
func _repartir() -> Array[Vector3]:
	var salida: Array[Vector3] = []
	if _ruta.size() < 2:
		return salida

	var largo := 0.0
	for i in range(1, _ruta.size()):
		largo += _ruta[i - 1].distance_to(_ruta[i])
	if largo <= CERCA + HASTA:
		return salida

	var recorrido := 0.0
	var siguiente := CERCA
	for i in range(1, _ruta.size()):
		var a := _ruta[i - 1]
		var b := _ruta[i]
		var tramo := a.distance_to(b)
		if tramo <= 0.0001:
			continue
		while siguiente <= recorrido + tramo:
			if siguiente > largo - HASTA:
				return salida
			salida.append(a.lerp(b, (siguiente - recorrido) / tramo))
			siguiente += PASO
		recorrido += tramo
	return salida


## Pool de luces reutilizadas.
func _asegurar(cuantos: int) -> void:
	while _luces.size() < cuantos:
		var m := MeshInstance3D.new()
		m.name = "Luz%d" % _luces.size()
		m.mesh = _malla
		# Tumbado en el suelo.
		m.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		# Aditivo: suma luz sin tapar el empedrado.
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.albedo_texture = _halo
		mat.albedo_color = LUZ
		# Sin el contorno negro de art_style.gd.
		m.set_meta(&"sin_contorno", true)
		m.material_override = mat
		add_child(m)
		_luces.append(m)
