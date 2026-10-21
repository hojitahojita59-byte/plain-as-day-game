extends Node
## Vista de puerta: 1ª persona ante una casa, con barrido a las puertas vecinas.
## API: entrar(puerta), mover(+1/-1), salir(). Puertas en el grupo "puertas".

signal entrado(puerta)
signal cambiada(puerta)
signal salido()

const GRUPO := "puertas"

## Metros de la cámara a la puerta.
const DISTANCIA := 3.3
## Altura de los ojos, en m.
const ALTURA := 1.62
## Segundos de bajada desde la vista de arriba.
const BAJADA := 0.75
## Segundos de barrido entre puertas.
const BARRIDO := 0.55

var activo: bool = false
## True mientras la cámara sube de vuelta; el punto y clic no escucha.
var volviendo: bool = false

var _camara: Camera3D = null
var _camara_previa: Camera3D = null
var _puertas: Array[Node3D] = []
var _indice: int = -1
var _moviendo: bool = false
var _jugador: Node3D = null
var _figura: Node3D = null


## Entra en la vista de puerta delante de `puerta`.
func entrar(puerta: Node3D) -> void:
	if activo or puerta == null:
		return

	_recoger_puertas(puerta)
	_indice = _puertas.find(puerta)
	if _indice < 0:
		push_warning("DoorMode: esa puerta no está en el grupo '%s'." % GRUPO)
		return

	_camara_previa = get_viewport().get_camera_3d()
	if _camara_previa == null:
		push_warning("DoorMode: no hay cámara de la que partir.")
		return

	_preparar_camara()
	activo = true
	_esconder_al_jugador(true)

	# Viaja desde la cámara de arriba (sin corte seco).
	_camara.global_transform = _camara_previa.global_transform
	_camara.fov = _camara_previa.fov
	_camara.current = true
	await _viajar_a(_sitio(_indice), BAJADA, Tween.EASE_IN_OUT, 58.0)

	entrado.emit(_puertas[_indice])


## Barrido lateral: +1 der., -1 izq. False si no hay puerta ahí.
func mover(paso: int) -> bool:
	if not activo or _moviendo:
		return false
	var destino := _indice + paso
	if destino < 0 or destino >= _puertas.size():
		return false

	_indice = destino
	_moviendo = true
	await _viajar_a(_sitio(_indice), BARRIDO, Tween.EASE_IN_OUT, 58.0)
	_moviendo = false
	cambiada.emit(_puertas[_indice])
	return true


## Vuelve a la vista de arriba.
func salir() -> void:
	if not activo:
		return

	var aqui := puerta_actual()
	if aqui != null:
		var hoja := aqui.get_node_or_null(^"Hoja")
		if hoja != null and hoja.has_method("cerrar"):
			hoja.cerrar()

	# Leer la posición ANTES del viaje de vuelta.
	var sitio := Vector3.ZERO
	var tengo_sitio := false
	if _camara != null and is_instance_valid(_camara):
		sitio = _camara.global_position
		tengo_sitio = true

	activo = false
	if _camara_previa != null:
		volviendo = true
		await _viajar_a(_camara_previa.global_transform, BAJADA,
			Tween.EASE_IN_OUT, _camara_previa.fov)
		_camara_previa.current = true
		volviendo = false
	_esconder_al_jugador(false)
	if tengo_sitio:
		_dejar_al_jugador_en(sitio)
	salido.emit()


## Puerta actual, o null.
func puerta_actual() -> Node3D:
	if not activo or _indice < 0 or _indice >= _puertas.size():
		return null
	return _puertas[_indice]


## Si hay puerta hacia ese lado.
## Rehace la fila (una charla puede abrir otra puerta).
func refrescar_fila() -> void:
	var actual := puerta_actual()
	if not activo or actual == null:
		return
	_recoger_puertas(actual)
	_indice = _puertas.find(actual)


func hay_puerta(paso: int) -> bool:
	var i := _indice + paso
	return activo and i >= 0 and i < _puertas.size()


# --- Internos ---

## Fila de barrido: misma fachada y plano, con conversación real; orden a lo largo.
func _recoger_puertas(desde: Node3D) -> void:
	_puertas.clear()
	if desde == null:
		return

	var base := desde.global_transform.basis.orthonormalized()
	var normal := base.z
	normal.y = 0.0
	if normal.length() < 0.01:
		normal = Vector3.BACK
	normal = normal.normalized()
	var tangente := base.x
	var origen := desde.global_position

	for n in get_tree().get_nodes_in_group(GRUPO):
		var d := n as Node3D
		if d == null:
			continue
		if d != desde:
			var suya := d.global_transform.basis.orthonormalized().z
			suya.y = 0.0
			# Casi paralelas: misma fachada.
			if suya.length() < 0.01 or suya.normalized().dot(normal) < 0.9:
				continue
			# Mismo plano, 1 m de holgura por retranqueos.
			if absf((d.global_position - origen).dot(normal)) > 1.0:
				continue
			# Con alguien detrás, no solo la frase de reserva.
			if d.has_method("hay_conversacion_de_verdad") \
					and not bool(d.call("hay_conversacion_de_verdad")):
				continue
		_puertas.append(d)

	_puertas.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return a.global_position.dot(tangente) < b.global_position.dot(tangente))


## Sitio de la cámara, según la orientación de la puerta (no un eje fijo).
func _sitio(i: int) -> Transform3D:
	var puerta := _puertas[i]
	var p := puerta.global_position
	var normal := puerta.global_transform.basis.orthonormalized().z
	normal.y = 0.0
	if normal.length() < 0.01:
		normal = Vector3.BACK
	normal = normal.normalized()
	return Transform3D(Basis.looking_at(-normal, Vector3.UP),
		Vector3(p.x, ALTURA, p.z) + normal * DISTANCIA)


func _preparar_camara() -> void:
	if _camara != null and is_instance_valid(_camara):
		return
	_camara = Camera3D.new()
	_camara.name = "CamaraPuerta"
	get_tree().current_scene.add_child(_camara)


func _viajar_a(destino: Transform3D, tiempo: float, curva: int, fov: float) -> void:
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(_camara, "global_transform", destino, tiempo) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(curva)
	t.tween_property(_camara, "fov", fov, tiempo) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(curva)
	await t.finished


## Oculta la figura (no el nodo) en 1ª persona.
func _esconder_al_jugador(esconder: bool) -> void:
	if _jugador == null or not is_instance_valid(_jugador):
		_jugador = get_tree().get_first_node_in_group("jugador") as Node3D
		if _jugador == null:
			for n in get_tree().current_scene.get_children():
				if n is CharacterBody3D:
					_jugador = n
					break
		if _jugador != null:
			_figura = _jugador.get_node_or_null("Figura") as Node3D

	if _figura != null:
		_figura.visible = not esconder


## Pone al jugador en X/Z de `punto` (conserva su Y) y lo ajusta a la navmesh.
func _dejar_al_jugador_en(punto: Vector3) -> void:
	if _jugador == null or not is_instance_valid(_jugador):
		return

	var destino := Vector3(punto.x, _jugador.global_position.y, punto.z)

	var agente := _jugador.get_node_or_null("NavigationAgent3D") as NavigationAgent3D
	if agente != null:
		var mapa := agente.get_navigation_map()
		if mapa.is_valid():
			var cerca := NavigationServer3D.map_get_closest_point(mapa, destino)
			# Sin sincronizar devuelve (0,0,0): aceptar solo si está cerca.
			if cerca.distance_to(destino) < 3.0:
				destino.x = cerca.x
				destino.z = cerca.z

	_jugador.global_position = destino
