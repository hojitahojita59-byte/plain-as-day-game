extends AudioStreamPlayer3D
## Pasos por distancia recorrida (no por tiempo): un paso cada zancada.

## Cargados por patrón, no lista exportada: el editor a veces borra exports.
@export var carpeta: String = "res://audio/sfx/pasos/"
@export var patron: String = "paso_%02d.wav"
@export var cuantos: int = 9

var pasos: Array[AudioStream] = []

## Metros entre pie y pie.
@export var zancada: float = 0.9

@export var tono_min: float = 0.94
@export var tono_max: float = 1.06

## Variación de volumen entre pasos, en dB.
@export var variacion_db: float = 2.0

var _recorrido: float = 0.0
var _anterior: Vector3
var _ultimo: int = -1
var _base_db: float = 0.0


func _ready() -> void:
	for i in cuantos:
		var ruta := carpeta + patron % (i + 1)
		# exists() antes de load(): aviso en vez de error por cada paso
		if not ResourceLoader.exists(ruta):
			push_warning("Pasos: no encuentro " + ruta)
			continue
		var s := load(ruta) as AudioStream
		if s != null:
			pasos.append(s)
	if pasos.is_empty():
		push_warning("Pasos: no he cargado ningún archivo; me quedo callado.")

	_anterior = global_position
	_base_db = volume_db
	# medio paso de ventaja para que el 1º no suene tarde
	_recorrido = zancada * 0.5


func _physics_process(_delta: float) -> void:
	if pasos.is_empty():
		return

	var ahora := global_position
	# solo plano XZ
	var avance := Vector2(ahora.x - _anterior.x, ahora.z - _anterior.z).length()
	_anterior = ahora

	# salto grande = teletransporte, no andar
	if avance > zancada * 2.0:
		return

	_recorrido += avance
	if _recorrido < zancada:
		return
	_recorrido = 0.0
	_sonar()


func _sonar() -> void:
	var i := randi() % pasos.size()
	# nunca el mismo dos veces seguidas
	if i == _ultimo and pasos.size() > 1:
		i = (i + 1) % pasos.size()
	_ultimo = i

	stream = pasos[i]
	pitch_scale = randf_range(tono_min, tono_max)
	volume_db = _base_db + randf_range(-variacion_db, variacion_db)
	play()
