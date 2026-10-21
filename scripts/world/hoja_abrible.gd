extends Node3D
## Hoja de puerta que se abre, y el vecino que aparece detrás.
## La hoja cuelga de `Pivote`, desplazado al lado de las bisagras (origen del kit = centro).

## Grados de apertura.
@export var apertura: float = 75.0

## Segundos en abrirse.
@export var tiempo: float = 0.9

## Lado de las bisagras; el pivote se desplaza media hoja (1,25 m) hacia él.
@export var bisagras_a_la_izquierda: bool = true

## Escena del vecino; se instancia escondida.
@export var ocupante: PackedScene

## Ropa del vecino (formato en `vestuario.gd`).
@export var vestimenta: Dictionary = {}

## Retraso del vecino, en fracción de `tiempo`.
@export var retraso_ocupante: float = 0.45

const VESTUARIO := preload("res://scripts/world/vestuario.gd")

const SONIDO_GOLPE := ["res://audio/sfx/puerta/golpe_1.ogg", "res://audio/sfx/puerta/golpe_2.ogg",
	"res://audio/sfx/puerta/golpe_3.ogg"]
const SONIDO_CERRAR := ["res://audio/sfx/puerta/cerrar_1.ogg", "res://audio/sfx/puerta/cerrar_2.ogg"]
const SONIDO_CRUJIDO := ["res://audio/sfx/puerta/abrir_1.ogg", "res://audio/sfx/puerta/abrir_2.ogg"]

var _pivote: Node3D
var _figura: Node3D
var _candil: Node3D
var _abierta: bool = false
var _voz: AudioStreamPlayer3D
var _ultimo_crujido: int = -1


func _ready() -> void:
	# Método y no lambda: el HUD es autoload y retendría la puerta liberada.
	HUD.retrato_visible.connect(_al_cambiar_el_retrato)
	_voz = AudioStreamPlayer3D.new()
	_voz.name = "Voz"
	# A la altura de la aldaba.
	_voz.position = Vector3(0.0, 1.1, 0.1)
	_voz.unit_size = 3.0
	_voz.max_distance = 20.0
	_voz.bus = &"Efectos"
	add_child(_voz)

	_pivote = get_node_or_null(^"Pivote") as Node3D
	_candil = get_node_or_null(^"Candil") as Node3D
	if _pivote == null:
		push_warning("HojaAbrible: me falta el nodo Pivote.")
		return

	var media := 0.625
	_pivote.position.x = -media if bisagras_a_la_izquierda else media
	var hoja := _pivote.get_node_or_null(^"Hoja") as Node3D
	if hoja != null:
		hoja.position.x = media if bisagras_a_la_izquierda else -media

	if ocupante != null:
		_figura = ocupante.instantiate() as Node3D
		# Vestir antes de add_child: la figura lee la ropa en su _ready().
		VESTUARIO.aplicar(_figura, vestimenta)
		add_child(_figura)
		# El módulo es macizo: el vecino cabe solo en el umbral (50 cm).
		_figura.position = Vector3(0.0, 0.0, -0.25)
		_figura.visible = false


## Tres golpes. Esperar con await antes de abrir.
func llamar() -> void:
	if _voz == null:
		return
	for i in SONIDO_GOLPE.size():
		_voz.stream = load(SONIDO_GOLPE[i]) as AudioStream
		_voz.pitch_scale = randf_range(0.95, 1.05)
		_voz.play()
		await get_tree().create_timer(0.32).timeout
	await get_tree().create_timer(0.3).timeout


## Abre. Admite await.
func abrir() -> void:
	if _abierta or _pivote == null:
		return
	_abierta = true

	_crujir()

	if _candil != null:
		_candil.visible = true

	var giro := deg_to_rad(apertura) * (1.0 if bisagras_a_la_izquierda else -1.0)
	var t := create_tween()
	t.tween_property(_pivote, "rotation:y", giro, tiempo) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	if _figura != null:
		# Aparece a media apertura y da un paso al umbral.
		t.parallel().tween_callback(func(): _figura.visible = true) \
			.set_delay(tiempo * retraso_ocupante)
		t.parallel().tween_property(_figura, "position:z", 0.1, tiempo * 0.7) \
			.set_delay(tiempo * retraso_ocupante) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	await t.finished


## Cierra y mete al vecino dentro.
func cerrar() -> void:
	if not _abierta or _pivote == null:
		return
	_abierta = false
	if _candil != null:
		_candil.visible = false

	if _voz != null:
		var s := load(SONIDO_CERRAR[randi() % SONIDO_CERRAR.size()]) as AudioStream
		if s != null:
			_voz.stream = s
			_voz.pitch_scale = randf_range(0.97, 1.03)
			# El golpe suena al final del giro.
			get_tree().create_timer(tiempo * 0.62).timeout.connect(_voz.play)

	var t := create_tween()
	t.tween_property(_pivote, "rotation:y", 0.0, tiempo * 0.8) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	if _figura != null:
		t.parallel().tween_property(_figura, "position:z", -0.25, tiempo * 0.5) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		t.parallel().tween_callback(func(): _figura.visible = false) \
			.set_delay(tiempo * 0.5)
	await t.finished


func esta_abierta() -> bool:
	return _abierta


## Chirrido; sin await, suena a la vez que gira.
func _crujir() -> void:
	if _voz == null or SONIDO_CRUJIDO.is_empty():
		return
	var i := randi() % SONIDO_CRUJIDO.size()
	if i == _ultimo_crujido and SONIDO_CRUJIDO.size() > 1:
		i = (i + 1) % SONIDO_CRUJIDO.size()
	_ultimo_crujido = i
	var s := load(SONIDO_CRUJIDO[i]) as AudioStream
	if s == null:
		return
	_voz.stream = s
	_voz.pitch_scale = randf_range(0.97, 1.03)
	_voz.play()


## Con un retrato en pantalla, el vecino 3D se esconde.
func _al_cambiar_el_retrato(si: bool, _quien: String) -> void:
	if _figura != null and _abierta:
		_figura.visible = not si
