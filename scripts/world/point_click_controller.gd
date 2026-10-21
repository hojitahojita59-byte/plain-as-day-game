extends CharacterBody3D
## Movimiento punto-y-clic (rayo + NavigationAgent3D), teclado e interacción.

const SNOW := preload("res://scripts/world/llaman_a_la_puerta.gd")

## m/s. Si cambia, cambiar también `velocidad_normal` en figura_andante.gd.
@export var speed: float = 4.2

## Distancia de llegada sin navegación, en m.
@export var arrive_distance: float = 0.2

## Muestra mensajes de depuración en pantalla.
@export var debug: bool = false

var _target: Vector3 = Vector3.ZERO
var _has_target: bool = false
var _pending: Interactable = null
var _clicks: int = 0
var _debug_label: Label = null
var _agent: NavigationAgent3D = null

# Si no avanza en ~0,5 s, se da el viaje por terminado.
var _stuck_frames: int = 0
var _last_position: Vector3 = Vector3.ZERO

# Esquiva tras un choque: lado y duración.
var _avoid_dir: Vector3 = Vector3.ZERO
var _avoid_timer: float = 0.0


func _ready() -> void:
	_target = global_position
	_debug_label = get_tree().get_first_node_in_group("debug_label") as Label
	if _debug_label != null:
		_debug_label.visible = debug
	_agent = get_node_or_null("NavigationAgent3D") as NavigationAgent3D

	# La navegación no está lista hasta el primer frame de física.
	await get_tree().physics_frame
	await get_tree().physics_frame

	if _agent == null:
		_say("No navigation map: I will walk in a straight line.")
		return

	await _ajustar_altura_de_ruta()
	_say("Ready. Click the ground to walk, a door to speak.")


## Ajusta path_height_offset (origen en el centro de la cápsula, navmesh en el suelo).
## Reintenta hasta que el mapa sincronice (antes devuelve (0,0,0)).
func _ajustar_altura_de_ruta() -> void:
	var mapa := _agent.get_navigation_map()
	if not mapa.is_valid():
		push_warning("PointClick: el agente no tiene mapa; no puedo cuadrar la altura.")
		return

	for intento in 120:
		# Esperar antes de preguntar evita errores en consola.
		await get_tree().physics_frame

		var punto := NavigationServer3D.map_get_closest_point(mapa, global_position)
		var desvio := Vector2(punto.x - global_position.x, punto.z - global_position.z)
		if desvio.length() < 1.0:
			_agent.path_height_offset = punto.y - global_position.y
			return

	push_warning("PointClick: el mapa de navegación no respondió; el personaje no andará.")


## Log a consola y al cartel de depuración.
func _say(message: String) -> void:
	if not debug:
		return
	print("[PointClick] ", message)
	if _debug_label != null:
		_debug_label.text = "clicks: %d\n%s" % [_clicks, message]


## _unhandled_input: los clics que acepta la interfaz no mueven al personaje.
func _unhandled_input(event: InputEvent) -> void:
	if DialogueRunner.active:
		return  # no se camina en un diálogo
	if DoorMode.activo or DoorMode.volviendo:
		return  # manda DoorMode
	if event is not InputEventMouseButton:
		return

	var mb := event as InputEventMouseButton
	if not mb.pressed:
		return

	_clicks += 1
	if mb.button_index != MOUSE_BUTTON_LEFT:
		_say("Button %d. Use the left button." % mb.button_index)
		return

	_pick_target(mb.position)


func _pick_target(screen_pos: Vector2) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		_say("There is no active camera in this scene.")
		return

	var from := cam.project_ray_origin(screen_pos)
	var dir := cam.project_ray_normal(screen_pos)

	var query := PhysicsRayQueryParameters3D.create(from, from + dir * 1000.0)
	query.exclude = [get_rid()]

	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		_say("There is nothing to go to there.")
		return

	var collider = hit.get("collider")
	if collider is not Interactable:
		var puerta := _zona_de_puerta(from, dir)
		if puerta != null:
			collider = puerta
	if collider is Interactable:
		_pending = collider as Interactable
		_go_to(_pending.approach_point(global_position))
		_say("Going to " + _pending.display_name)
		return

	_pending = null

	var point: Vector3 = hit["position"]
	var normal: Vector3 = hit.get("normal", Vector3.UP)
	if debug and collider is Node:
		_say("Hit %s at %s (normal %s)" % [(collider as Node).name, str(point.round()), str(normal.round())])

	# Clic en una pared: sacar el punto 1 m hacia fuera.
	if normal.y < 0.7:
		point += normal * 1.0

	point.y = global_position.y  # a la altura de los pies
	_go_to(point)
	_say("Heading for " + str(_target.round()))


## Ir a algo como si se hubiera clicado (lo usa burbujas_de_puerta.gd).
func ir_a(objeto: Interactable) -> void:
	if objeto == null or DialogueRunner.active or DoorMode.activo:
		return
	_pending = objeto
	_go_to(objeto.approach_point(global_position))


## Zonas Area3D de clic delante de puertas laterales (ver constructor_calle.gd).
func _zona_de_puerta(from: Vector3, dir: Vector3) -> Interactable:
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 1000.0)
	q.collide_with_areas = true
	q.collide_with_bodies = false
	var golpe := get_world_3d().direct_space_state.intersect_ray(q)
	var zona = golpe.get("collider")
	if zona is Area3D and (zona as Area3D).has_meta(&"puerta"):
		return (zona as Area3D).get_parent() as Interactable
	return null


## Va al punto caminable más cercano a `point`.
func _go_to(point: Vector3) -> void:
	var goal := point

	if _agent != null:
		var map := _agent.get_navigation_map()
		if map.is_valid():
			goal = NavigationServer3D.map_get_closest_point(map, point)

	_target = goal
	_has_target = true
	_stuck_frames = 0
	_last_position = global_position

	if _agent != null:
		_agent.target_position = goal


func _physics_process(delta: float) -> void:
	# El teclado tiene prioridad y cancela el destino.
	if _andar_con_teclas():
		return

	# Al soltar la tecla, parar (si no, la figura sigue animando).
	if not _has_target:
		velocity = Vector3.ZERO
		return

	# Con navegación.
	if _agent != null:
		if _agent.is_navigation_finished():
			_stop()
			return

		var next_point := _agent.get_next_path_position()
		var step := next_point - global_position
		step.y = 0.0
		if step.length() > 0.01:
			velocity = step.normalized() * speed
			move_and_slide()

		if _is_stuck():
			_say("I cannot get any closer. I will stop here.")
			_stop()
		return

	# Sin navegación: línea recta con esquiva.
	var to_target := _target - global_position
	to_target.y = 0.0

	if to_target.length() < arrive_distance:
		_stop()
		return

	var direction := to_target.normalized()

	# Tras un choque, desviarse un momento hacia el lado.
	if _avoid_timer > 0.0:
		_avoid_timer -= delta
		direction = (direction + _avoid_dir * 1.6).normalized()

	velocity = direction * speed
	move_and_slide()

	_update_avoidance(to_target)

	if _is_stuck():
		_say("I cannot get any closer. I will stop here.")
		_stop()


## Tras un choque, elige la tangente que acerca al destino.
func _update_avoidance(to_target: Vector3) -> void:
	if get_slide_collision_count() == 0:
		return

	var normal := get_slide_collision(0).get_normal()
	normal.y = 0.0
	if normal.length() < 0.01:
		return
	normal = normal.normalized()

	var tangent := Vector3(-normal.z, 0.0, normal.x)
	if tangent.dot(to_target) < 0.0:
		tangent = -tangent

	_avoid_dir = tangent
	_avoid_timer = 0.4


## True si lleva ~0,5 s (45 frames) sin avanzar.
func _is_stuck() -> bool:
	if global_position.distance_to(_last_position) > 0.005:
		_stuck_frames = 0
		_last_position = global_position
		return false
	_stuck_frames += 1
	return _stuck_frames > 45


func _stop() -> void:
	# Guardar la posición aquí: un diálogo puede cambiar de escena antes.
	Barrio.anotar_posicion(Barrio.actual, global_position.x, global_position.z)
	_has_target = false
	velocity = Vector3.ZERO
	move_and_slide()
	_arrive()


func _arrive() -> void:
	if _pending == null:
		_say("Arrived at " + str(global_position.round()))
		return

	var target := _pending
	_pending = null

	# Esquinas de salida: burbujas de decisión (ver opciones_en_el_mundo.gd).
	if target.has_meta(&"decision"):
		await _decidir(target, Dictionary(target.get_meta(&"decision")))
		return

	var id := target.active_dialogue_id()
	if id.is_empty():
		_say(target.display_name + " has nothing to say yet.")
		if target.is_in_group(DoorMode.GRUPO):
			HUD.pensar(String(target.get_meta(&"cerrada",
				Barrio.datos(Barrio.actual).get("puerta_sin_nombre", ""))))
		return

	# Puertas: vista de puerta solo si hay alguien; si no, un pensamiento.
	if target.is_in_group(DoorMode.GRUPO):
		if target.hay_conversacion_de_verdad():
			_say("Going up to " + target.display_name)
			DoorMode.entrar(target)
		else:
			HUD.pensar(String(Barrio.datos(Barrio.actual).get("puerta_sin_nombre", "")))
		return

	_say("Speaking with " + target.display_name)
	DialogueRunner.start(id)


## Decisión de una esquina: dos burbujas, sin texto. Opción 0 = ir.
func _decidir(objeto: Node3D, decision: Dictionary) -> void:
	var cual: int = await HUD.preguntar_en(objeto, Array(decision.get("opciones", [])))
	if cual != 0:
		return
	var escena := String(decision.get("escena", ""))
	# La última vuelta a casa (llamará Snow): antes, la imagen del mapa entero.
	if escena.ends_with("rectoria.tscn") and SNOW.toca() and not GameState.has_flag("poster_visto"):
		var vista := get_tree().get_first_node_in_group(&"vista_pajaro")
		if vista != null:
			await vista.call(&"final")
	if not escena.is_empty():
		SceneRouter.change_scene(escena, SceneRouter.Kind.SHORT_FADE)


## WASD/flechas, relativas a la cámara. True si el teclado manda este frame.
func _andar_con_teclas() -> bool:
	if DialogueRunner.active or DoorMode.activo or get_tree().paused:
		return false

	var d := Input.get_vector("andar_izquierda", "andar_derecha",
		"andar_arriba", "andar_abajo")
	if d.length() < 0.01:
		return false

	# Cancela cualquier viaje o interacción pendiente.
	_has_target = false
	_pending = null

	velocity = Vector3(d.x, 0.0, d.y).normalized() * speed
	move_and_slide()
	return true
