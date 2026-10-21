extends Node3D
## I.6: John Snow llama a la rectoría. Final del Acto I.
## En 1ª persona: se vuelve, se levanta, va a la puerta y el jugador abre con el pomo.

const FIGURA := preload("res://scenes/world/props/figura.tscn")
const SON_GOLPES := [preload("res://audio/sfx/puerta/golpe_1.ogg"), preload("res://audio/sfx/puerta/golpe_2.ogg"),
	preload("res://audio/sfx/puerta/golpe_3.ogg")]
const SON_CRUJIDO := preload("res://audio/sfx/puerta/abrir_1.ogg")
const SON_CERRAR := preload("res://audio/sfx/puerta/cerrar_1.ogg")
const DIALOGO := "ch1_s6_snow"
const GUIA := preload("res://scripts/guia.gd")

## Snow: de oscuro, chistera, alto y algo inclinado.
const ROPA_SNOW := {"abrigo": [0.13, 0.13, 0.15], "pantalon": [0.15, 0.15, 0.16], "sombrero": [0.08, 0.08, 0.09],
	"cuello": [0.9, 0.9, 0.86], "chistera": true, "alzacuellos": false, "estatura": 1.04,
	"inclinacion": 0.08, "brazo_derecho": -0.35, "cara": "h01", "pelo": [0.14, 0.1, 0.08], "quien": "snow",
	"mira_alrededor": false}

## Ojos de pie (m) y punto de la puerta al que se vuelve.
const ALTO_DE_PIE := 1.62
const PUERTA := Vector3(2.0, 1.25, 2.0)
## De la silla a la puerta, a ras de suelo; la cámara va a ALTO_DE_PIE.
const A_LA_PUERTA: Array[Vector3] = [Vector3(0.05, 0.0, -0.05), Vector3(0.85, 0.0, 0.35), Vector3(1.72, 0.0, 0.7)]
## Mirando al pomo desde ahí.
const MIRA_POMO := Vector3(2.1, 1.32, 2.0)
## Snow en el escalón, y por dónde entra hasta el plano.
const FUERA := Vector3(2.12, 0.0, 2.78)
const ASOMADO := Vector3(2.12, 0.0, 2.48)
const HASTA_EL_PLANO: Array[Vector3] = [Vector3(2.02, 0.0, 1.45), Vector3(1.0, 0.0, 0.45),
	Vector3(-0.6, 0.0, 0.05), Vector3(-2.02, 0.0, -0.98)]
## Whitehead se aparta para dejarle pasar.
const APARTADO := Vector3(2.42, ALTO_DE_PIE, 0.3)
## Desde aquí se ven Snow y el plano juntos.
const ENCUADRE := Vector3(0.62, 1.68, 0.42)
const ENCUADRE_MIRA := Vector3(-1.62, 1.38, -1.5)
## m/s.
const PASO_WHITEHEAD := 1.05
const PASO_SNOW := 0.95
## Grados que gira la hoja hacia fuera (como en llegada_a_casa.gd).
const ABRE_GRADOS := -82.0

@export var llegada_path: NodePath = ^"../Llegada"
@export var sentado_path: NodePath = ^"../Sentado"
@export var camara_path: NodePath = ^"../Camera3D"

var _snow: Node3D
var _figura_snow: Node3D
var _luz_snow: OmniLight3D
var _camara: Camera3D
var _voz: AudioStreamPlayer
var _hoja: Node3D
var _pomo: MeshInstance3D
var _esperando_pomo: bool = false
var _encima: bool = false
var _aviso: CanvasLayer
var _al_plano: bool = false
## La cámara sigue a Snow mientras entra.
var _siguiendo: bool = false


## Cerco hecho + suficientes casas raras oídas (ver guia.gd, RARAS).
static func toca() -> bool:
	return GameState.has_flag("saw_the_cluster") \
		and GUIA.raras_oidas() >= GUIA.RARAS_PARA_SNOW \
		and not GameState.has_flag("met_snow")


func _ready() -> void:
	set_process(false)
	_camara = get_node_or_null(camara_path) as Camera3D
	var llegada := get_node_or_null(llegada_path)
	if llegada == null or _camara == null or not toca():
		return
	_voz = AudioStreamPlayer.new()
	_voz.bus = &"Efectos"
	add_child(_voz)
	llegada.connect(&"sentado", _llaman)


func _llaman() -> void:
	var sentado := get_node_or_null(sentado_path)
	if sentado != null and sentado.has_method(&"ceder"):
		sentado.call(&"ceder")
	_hoja = get_node_or_null(^"../Cuarto/HojaPuerta") as Node3D
	if _hoja != null:
		_pomo = _hoja.get_node_or_null(^"Pomo") as MeshInstance3D
	_poner_a_snow_fuera()

	await get_tree().create_timer(1.4, false).timeout
	for g in SON_GOLPES:
		_sonar(g)
		await get_tree().create_timer(0.32, false).timeout
	await get_tree().create_timer(0.5, false).timeout

	# Sentado, se vuelve hacia la puerta.
	await _girar_a(_camara.global_position, PUERTA, 1.0)
	# Se levanta.
	var de_pie := Vector3(A_LA_PUERTA[0].x, ALTO_DE_PIE, A_LA_PUERTA[0].z)
	await _girar_a(de_pie, PUERTA, 0.9)
	# Va a la puerta.
	await _caminar(A_LA_PUERTA.slice(1), MIRA_POMO, PASO_WHITEHEAD)

	_esperando_pomo = true
	set_process(true)
	_mostrar_aviso("Click the handle.")
	# Sin pantalla (pruebas) no hay quien haga clic: abre sola.
	if DisplayServer.get_name() == "headless":
		await get_tree().create_timer(0.4, false).timeout
		abrir_la_puerta()


## Snow espera en el escalón, tras la puerta, mirando a la casa.
func _poner_a_snow_fuera() -> void:
	_snow = Node3D.new()
	_snow.name = "JohnSnow"
	var f := FIGURA.instantiate() as Node3D
	Vestuario.aplicar(f, ROPA_SNOW)
	# El modelo mira a +Z; la casa queda a -Z.
	f.rotation.y = PI
	_snow.add_child(f)
	_figura_snow = f
	# Luz propia, arriba y delante, aún fuera del muro: sin ella es una mancha contra la noche.
	_luz_snow = OmniLight3D.new()
	_luz_snow.light_color = Color(1.0, 0.88, 0.7)
	# apagada hasta abrir: si no, se cuela por la pared
	_luz_snow.light_energy = 0.0
	_luz_snow.omni_range = 2.2
	_luz_snow.position = Vector3(0.0, 2.6, -0.35)
	_snow.add_child(_luz_snow)
	get_parent().add_child(_snow)
	_snow.global_position = FUERA


# --- El pomo ---

func _process(_delta: float) -> void:
	if not _esperando_pomo:
		return
	var encima := _pomo_bajo_el_raton(get_viewport().get_mouse_position())
	if encima != _encima:
		_encima = encima
		_resaltar_pomo(encima)


func _unhandled_input(event: InputEvent) -> void:
	if not _esperando_pomo or event is not InputEventMouseButton:
		return
	var mb := event as InputEventMouseButton
	if not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if _pomo_bajo_el_raton(mb.position):
		get_viewport().set_input_as_handled()
		abrir_la_puerta()


func _pomo_bajo_el_raton(donde: Vector2) -> bool:
	var desde := _camara.project_ray_origin(donde)
	var q := PhysicsRayQueryParameters3D.create(desde, desde + _camara.project_ray_normal(donde) * 4.0)
	var golpe := get_world_3d().direct_space_state.intersect_ray(q)
	var cuerpo = golpe.get("collider")
	return cuerpo != null and cuerpo.has_meta(&"accion") and String(cuerpo.get_meta(&"accion")) == "pomo"


func _resaltar_pomo(si: bool) -> void:
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if si else Input.CURSOR_ARROW)
	if _pomo == null:
		return
	var m := _pomo.material_override as StandardMaterial3D
	if m == null:
		return
	m.emission_enabled = si
	m.emission = Color(1.0, 0.8, 0.4)
	m.emission_energy_multiplier = 0.45


func _mostrar_aviso(texto: String) -> void:
	var capa := CanvasLayer.new()
	capa.layer = 12
	add_child(capa)
	var l: Label
	if HUD.has_method(&"_indicacion"):
		l = HUD.call(&"_indicacion", 24) as Label
	else:
		l = Label.new()
	l.text = texto
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	l.grow_horizontal = Control.GROW_DIRECTION_BOTH
	l.grow_vertical = Control.GROW_DIRECTION_BEGIN
	l.position.y -= 110.0
	l.modulate.a = 0.0
	capa.add_child(l)
	create_tween().tween_property(l, "modulate:a", 1.0, 0.4)
	_aviso = capa


## Clic en el pomo (o una prueba): abre, Snow se asoma y empieza la conversación.
func abrir_la_puerta() -> void:
	if not _esperando_pomo:
		return
	_esperando_pomo = false
	set_process(false)
	_resaltar_pomo(false)
	if _aviso != null:
		_aviso.queue_free()
		_aviso = null

	_sonar(SON_CRUJIDO)
	if _hoja != null:
		var t := create_tween()
		t.tween_property(_hoja, "rotation:y", deg_to_rad(ABRE_GRADOS), 1.0) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	create_tween().tween_property(_luz_snow, "light_energy", 0.65, 0.6)
	# Levanta la vista hacia él.
	_girar_a(_camara.global_position, Vector3(FUERA.x, 1.62, FUERA.z), 1.1)
	await get_tree().create_timer(0.55, false).timeout

	# Se asoma: un paso y el cuerpo hacia delante.
	_andar(_snow, ASOMADO, 0.6)
	var t2 := create_tween()
	t2.tween_property(_figura_snow, "inclinacion", 0.3, 0.5).set_trans(Tween.TRANS_SINE)
	t2.tween_interval(0.5)
	t2.tween_property(_figura_snow, "inclinacion", 0.1, 0.6).set_trans(Tween.TRANS_SINE)
	await t2.finished

	DialogueRunner.line_shown.connect(_al_hablar)
	DialogueRunner.start(DIALOGO)


# --- Al plano ---

## Nodo con camara "plano": Whitehead se aparta, Snow entra y se planta ante el plano.
func _al_hablar(nodo: Dictionary) -> void:
	if _al_plano or String(nodo.get("camara", "")) != "plano":
		return
	_al_plano = true
	var plano := get_tree().current_scene.find_child("PlanoDePared", true, false) as Node3D \
		if get_tree().current_scene != null else null
	var al_plano := plano.global_position if plano != null else Vector3(-1.52, 1.62, -1.94)

	# Whitehead se hace a un lado y le sigue con la vista.
	await _girar_a(APARTADO, _snow.global_position + Vector3(0, 1.5, 0), 0.8)
	_siguiendo = true
	_seguir_a_snow()

	await _andar(_snow, HASTA_EL_PLANO[0], PASO_SNOW)
	await _andar(_snow, HASTA_EL_PLANO[1], PASO_SNOW)
	# Ya dentro: la puerta se cierra tras él.
	if _hoja != null:
		var t := create_tween()
		t.tween_property(_hoja, "rotation:y", 0.0, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		t.tween_callback(_sonar.bind(SON_CERRAR))
	await _andar(_snow, HASTA_EL_PLANO[2], PASO_SNOW)
	await _andar(_snow, HASTA_EL_PLANO[3], PASO_SNOW)
	_siguiendo = false

	# De cara al plano, señalándolo; su luz pasa a nuestro lado.
	await get_tree().process_frame
	var d := al_plano - _snow.global_position
	var hacia := atan2(d.x, d.z)
	var t3 := create_tween().set_parallel(true)
	t3.tween_method(_encarar_a_snow.bind(_figura_snow.rotation.y), 0.0, 1.0, 0.7) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t3.tween_property(_figura_snow, "brazo_derecho", -1.15, 0.8).set_delay(0.4)
	t3.tween_property(_luz_snow, "position", Vector3(1.0, 2.0, 1.0), 0.8)
	_destino_giro = hacia
	# Y la cámara se coloca para verlos a los dos.
	await _girar_a(ENCUADRE, ENCUADRE_MIRA, 1.6)


var _destino_giro: float = 0.0


func _encarar_a_snow(u: float, desde: float) -> void:
	var a := lerp_angle(desde, _destino_giro, u)
	_figura_snow.rotation.y = a
	# figura_andante.gd vuelve cada fotograma a su giro de reposo.
	_figura_snow.set(&"_rot_reposo", a)


## La vista sigue a Snow mientras cruza el cuarto.
func _seguir_a_snow() -> void:
	while _siguiendo and is_instance_valid(_snow):
		await get_tree().process_frame
		if not is_inside_tree():
			return
		if get_tree().paused:
			continue
		var delta := get_process_delta_time()
		var quiere := _mirando_a(_camara.global_position, _snow.global_position + Vector3(0, 1.45, 0))
		_camara.quaternion = _camara.quaternion.slerp(quiere, 1.0 - exp(-4.0 * delta))


# --- Mover cámara y figuras ---

## Lleva la cámara a `donde` mirando a `mira`, suave.
func _girar_a(donde: Vector3, mira: Vector3, segundos: float) -> void:
	var t := create_tween().set_parallel(true)
	t.tween_property(_camara, "global_position", donde, segundos) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(_camara, "quaternion", _mirando_a(donde, mira), segundos) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await t.finished


## Anda en 1ª persona por `puntos` (a ras de suelo), con vaivén de cabeza; acaba mirando a `mira`.
func _caminar(puntos: Array[Vector3], mira: Vector3, velocidad: float) -> void:
	var ruta: Array[Vector3] = [Vector3(_camara.global_position.x, 0.0, _camara.global_position.z)]
	for p in puntos:
		ruta.append(Vector3(p.x, 0.0, p.z))
	var largo := 0.0
	for i in range(1, ruta.size()):
		largo += ruta[i - 1].distance_to(ruta[i])
	if largo <= 0.0:
		return
	var alto := _camara.global_position.y
	var dura := largo / velocidad
	var t := 0.0
	while t < dura:
		await get_tree().process_frame
		# En pausa no se anda.
		if not is_inside_tree():
			return
		if get_tree().paused:
			continue
		var delta := get_process_delta_time()
		t = minf(t + delta, dura)
		var u := t / dura
		# arranca y para suave
		var s := (0.5 - 0.5 * cos(PI * u)) * largo
		var p := _sobre_la_ruta(ruta, s)
		var vaiven := sin(s / 0.7 * TAU) * 0.022 * sin(PI * u)
		_camara.global_position = Vector3(p.x, alto + absf(vaiven) - 0.011, p.z)
		var delante := _sobre_la_ruta(ruta, minf(s + 1.0, largo))
		var mira_ruta := Vector3(delante.x, alto - 0.25, delante.z)
		if delante.distance_to(p) < 0.05:
			mira_ruta = mira
		var mira_ya := mira_ruta.lerp(mira, smoothstep(0.45, 1.0, u))
		var quiere := _mirando_a(_camara.global_position, mira_ya)
		_camara.quaternion = _camara.quaternion.slerp(quiere, 1.0 - exp(-6.0 * delta))
	await _girar_a(Vector3(ruta[-1].x, alto, ruta[-1].z), mira, 0.35)


func _sobre_la_ruta(ruta: Array[Vector3], s: float) -> Vector3:
	var falta := s
	for i in range(1, ruta.size()):
		var tramo := ruta[i - 1].distance_to(ruta[i])
		if falta <= tramo:
			return ruta[i - 1].lerp(ruta[i], falta / maxf(tramo, 0.0001))
		falta -= tramo
	return ruta[-1]


## Cuaternión de mirar de `desde` a `hacia`.
func _mirando_a(desde: Vector3, hacia: Vector3) -> Quaternion:
	return Basis.looking_at(hacia - desde, Vector3.UP).get_rotation_quaternion()


## Mueve el padre; los pies los anima figura_andante.gd.
func _andar(quien: Node3D, hasta: Vector3, velocidad: float) -> void:
	var d := hasta - quien.global_position
	d.y = 0.0
	var t := create_tween()
	t.tween_property(quien, "global_position", Vector3(hasta.x, quien.global_position.y, hasta.z),
		d.length() / velocidad)
	await t.finished


func _sonar(s: AudioStream) -> void:
	_voz.stream = s
	_voz.play()


func _exit_tree() -> void:
	if _encima:
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)
