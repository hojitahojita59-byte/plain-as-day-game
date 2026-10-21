extends AudioStreamPlayer
## Música de fondo: entra con fundido y baja mientras alguien habla.

## dB en bus Musica; ~10 dB sobre el ambiente de calle (que llega a ~-48).
@export var volumen: float = -18.0

## dB que baja durante el diálogo.
@export var apartarse: float = 7.0

## Segundos del fundido de entrada.
@export var entrada: float = 8.0

var _tween: Tween


func _ready() -> void:
	if stream == null:
		push_warning("MusicaAmbiente: no tengo ninguna pieza que sonar.")
		return

	volume_db = -60.0
	play()
	_llevar_a(volumen, entrada)

	DialogueRunner.line_shown.connect(_al_hablar)
	DialogueRunner.dialogue_finished.connect(_al_callar)


func _al_hablar(_nodo: Dictionary) -> void:
	_llevar_a(volumen - apartarse, 0.6)


func _al_callar(_id: String) -> void:
	_llevar_a(volumen, 1.8)


## Mata el tween anterior para que no se solapen dos fundidos.
func _llevar_a(db: float, segundos: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "volume_db", db, segundos) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
