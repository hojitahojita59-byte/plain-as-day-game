extends OmniLight3D
## Luz que parpadea como fuego: dos senos lentos y uno rápido.

## Amplitud: 0.15 vela, 0.3 chimenea.
@export var viveza: float = 0.22

var _base: float = 1.0
var _t: float = 0.0


func _ready() -> void:
	_base = light_energy
	_t = randf() * 100.0


func _process(delta: float) -> void:
	_t += delta
	var v := sin(_t * 1.7) * 0.5 + sin(_t * 2.9 + 1.3) * 0.35 + sin(_t * 11.0) * 0.15
	light_energy = _base * (1.0 + v * viveza)
