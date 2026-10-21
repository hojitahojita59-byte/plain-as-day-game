extends Node3D
## Llegada a la rectoría: entra, se sienta y la cámara pasa a 1ª persona. Clic = saltar.

signal sentado()

## Ya se llegó en esta sesión (no se guarda): al volver no se repite la caminata.
static var ya_llegamos: bool = false

const ESCRITORIO := "res://scenes/ui/escritorio.tscn"

## Recorrido desde el umbral; lo de fuera solo se oye.
const RUTA: Array[Vector3] = [
	Vector3(2.0, 0.0, 1.75),
	Vector3(2.0, 0.0, 1.05),
	Vector3(0.75, 0.0, -0.05),
	Vector3(0.05, 0.0, -0.5),
]

## Segundos de casa vacía con pasos fuera (la cámara recorre la casa).
const ESPERA_FUERA := 3.0
## Segundos en abrir/cerrar la hoja.
const GIRO_PUERTA := 0.75
## Grados de apertura.
const ABRE_GRADOS := -82.0
## m/s.
const PASO := 1.55

## Silla, ojos y punto al que mira sentado.
const SILLA := Vector3(0.02, 0.0, -0.62)
const OJOS := Vector3(0.0, 1.34, -0.28)
const MIRA := Vector3(0.0, 0.76, -1.78)

## Plano general: empieza mirando a la cocina y gira hacia la puerta. Dentro de la casa (z de -2 a 2).
const CAMARA_INICIO := Vector3(-2.7, 1.72, 0.7)
const CAMARA_INICIO_MIRA := Vector3(-7.6, 0.95, -0.4)
const CAMARA_LEJOS := Vector3(-2.45, 1.72, 1.2)
const CAMARA_MIRA := Vector3(0.60, 0.80, -0.85)

## Segundos del paso de plano general a 1ª persona.
const ENTRADA := 1.45

@export var figura_path: NodePath = ^"../Whitehead"
@export var camara_path: NodePath = ^"../Camera3D"

var _figura: Node3D
var _camara: Camera3D
var _andando: bool = false
var _tramo: int = 0
var _listo: bool = false
var _paseo: Tween


func _ready() -> void:
	_figura = get_node_or_null(figura_path) as Node3D
	_camara = get_node_or_null(camara_path) as Camera3D
	if _figura == null or _camara == null:
		push_error("LlegadaACasa: falta la figura o la cámara.")
		return

	if ya_llegamos:
		# Diferido: los nodos que escuchan «sentado» aún no se han conectado.
		_sentarse_ya.call_deferred()
		return

	_camara.global_position = CAMARA_INICIO
	_camara.look_at(CAMARA_INICIO_MIRA, Vector3.UP)
	_figura.global_position = RUTA[0]
	_figura.visible = false
	_llegar_de_la_calle()


## Cuarto vacío, pasos, puerta, él, puerta.
func _llegar_de_la_calle() -> void:
	_pasos_fuera()
	_paseo = create_tween().set_parallel(true)
	_paseo.tween_property(_camara, "global_position", CAMARA_LEJOS, ESPERA_FUERA - 0.1) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_paseo.tween_property(_camara, "quaternion", _mirando_a(CAMARA_LEJOS, CAMARA_MIRA), ESPERA_FUERA - 0.1) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await get_tree().create_timer(ESPERA_FUERA).timeout
	if _listo:
		return

	_girar_puerta(deg_to_rad(ABRE_GRADOS))
	_sonar(SON_CRUJIDO, -4.0)
	await get_tree().create_timer(GIRO_PUERTA * 0.55).timeout
	if _listo:
		return

	_figura.visible = true
	_andando = true
	_tramo = 1

	# La puerta se cierra tras él al cruzar el umbral.
	await get_tree().create_timer(1.1).timeout
	if _listo:
		return
	_girar_puerta(0.0)
	_sonar(SON_CERRAR, -5.0)


func _process(delta: float) -> void:
	if not _andando:
		return
	var meta := RUTA[_tramo]
	var d := meta - _figura.global_position
	d.y = 0.0
	if d.length() <= PASO * delta:
		_figura.global_position = Vector3(meta.x, _figura.global_position.y, meta.z)
		_tramo += 1
		if _tramo >= RUTA.size():
			_andando = false
			_sentarse()
		return
	# figura_andante.gd anima las piernas a partir del desplazamiento.
	_figura.global_position += d.normalized() * PASO * delta


## Sentarse y pasar a 1ª persona.
func _sentarse() -> void:
	_posar_sentado()
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(_camara, "global_position", OJOS, ENTRADA) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(_camara, "quaternion", _mirando_a(OJOS, MIRA), ENTRADA) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Ocultar a mitad: si no, la cámara atraviesa la cabeza.
	t.tween_callback(func(): _figura.visible = false).set_delay(ENTRADA * 0.4)
	await t.finished
	_terminar()


## Sin caminata: directamente sentado.
func _sentarse_ya() -> void:
	if _paseo != null:
		_paseo.kill()
	_posar_sentado()
	_camara.global_position = OJOS
	_camara.look_at(MIRA, Vector3.UP)
	_terminar()


func _terminar() -> void:
	ya_llegamos = true
	_listo = true
	# En 1ª persona la cámara está dentro del torso.
	_figura.visible = false
	set_process(false)
	sentado.emit()


## Postura de sentado a mano: bajar el cuerpo y girar caderas y hombros.
func _posar_sentado() -> void:
	_figura.global_position = SILLA
	# El modelo mira a +Z.
	_figura.rotation.y = PI

	var andante := _figura.get_node_or_null(^"Figura")
	if andante == null:
		return
	# Apagar el ciclo de andar.
	andante.set_process(false)
	# La figura interior conserva el giro del último tramo: enderezarla.
	(andante as Node3D).rotation.y = 0.0

	var cuerpo := andante.get_node_or_null(^"Cuerpo") as Node3D
	if cuerpo != null:
		cuerpo.position.y -= 0.40
	_angulo(andante, ^"Cuerpo/CaderaIzq", -1.35)
	_angulo(andante, ^"Cuerpo/CaderaDer", -1.35)
	_angulo(andante, ^"Cuerpo/HombroIzq", -0.55)
	_angulo(andante, ^"Cuerpo/HombroDer", -0.5)


func _angulo(raiz: Node, ruta: NodePath, x: float) -> void:
	var n := raiz.get_node_or_null(ruta) as Node3D
	if n != null:
		n.rotation.x = x


## Cuaternión de mirar de `desde` a `hacia` (interpola sin voltear).
func _mirando_a(desde: Vector3, hacia: Vector3) -> Quaternion:
	return Basis.looking_at(hacia - desde, Vector3.UP).get_rotation_quaternion()


## Clic durante la llegada: saltarla.
func _unhandled_input(event: InputEvent) -> void:
	if _listo or not _andando:
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		get_viewport().set_input_as_handled()
		_andando = false
		_sentarse_ya()


# --- Puerta y sonido ---

const SON_CRUJIDO := "res://audio/sfx/puerta/abrir_1.ogg"
const SON_CERRAR := "res://audio/sfx/puerta/cerrar_1.ogg"
const PASO_PATRON := "res://audio/sfx/pasos/paso_%02d.wav"
const CUANTOS_PASOS := 9

var _voz: AudioStreamPlayer


## Pasos que se acercan por fuera.
func _pasos_fuera() -> void:
	var huecos := [0.0, 0.52, 1.02, 1.5, 1.94, 2.42, 2.9]
	for i in huecos.size():
		_dar_un_paso.call_deferred()
		await get_tree().create_timer(float(huecos[i])).timeout
		if _listo:
			return


func _dar_un_paso() -> void:
	var n := 1 + (randi() % CUANTOS_PASOS)
	# Amortiguados, tras la puerta.
	_sonar(PASO_PATRON % n, -14.0)


func _sonar(ruta: String, db: float) -> void:
	if _voz == null:
		_voz = AudioStreamPlayer.new()
		_voz.bus = &"Efectos"
		add_child(_voz)
	var s := load(ruta) as AudioStream
	if s == null:
		return
	_voz.stream = s
	_voz.volume_db = db
	_voz.pitch_scale = randf_range(0.95, 1.06)
	_voz.play()


## Abre/cierra la hoja; si no existe, no pasa nada.
func _girar_puerta(radianes: float) -> void:
	var pivote := get_node_or_null(^"../Cuarto/HojaPuerta") as Node3D
	if pivote == null:
		return
	var t := create_tween()
	t.tween_property(pivote, "rotation:y", radianes, GIRO_PUERTA) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
