extends AudioStreamPlayer3D
## Goteo de la bomba: gotas sueltas con intervalo y tono al azar (no bucle).
## Va en el charco, no en el caño. goteo.wav debe ser mono para sonar en 3D.

## Espera entre gotas, en segundos.
@export var espera_min: float = 0.55
@export var espera_max: float = 1.6

@export var tono_min: float = 0.92
@export var tono_max: float = 1.08

var _reloj: Timer


func _ready() -> void:
	_reloj = Timer.new()
	_reloj.one_shot = true
	add_child(_reloj)
	_reloj.timeout.connect(_gotear)
	# 1ª espera al azar para que no goteen todas a la vez
	_reloj.start(randf_range(espera_min, espera_max))


func _gotear() -> void:
	pitch_scale = randf_range(tono_min, tono_max)
	play()
	_reloj.start(randf_range(espera_min, espera_max))
