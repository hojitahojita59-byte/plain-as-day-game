extends Node3D
## Burbuja "· · ·" sobre quien tiene algo que decir.

## Segundos por punto.
@export var ritmo: float = 0.45

## Amplitud del vaivén.
@export var flote: float = 0.05

@export var texto_path: NodePath = ^"Texto"

const PUNTOS := ["·", "· ·", "· · ·"]

var _texto: Label3D
var _reloj: float = 0.0
var _altura_base: float = 0.0


func _ready() -> void:
	_texto = get_node_or_null(texto_path) as Label3D
	_altura_base = position.y

	if DialogueRunner.line_shown.is_connected(_al_hablar):
		return
	DialogueRunner.line_shown.connect(_al_hablar)
	DialogueRunner.dialogue_finished.connect(_al_callar)


func _al_hablar(_nodo: Dictionary) -> void:
	visible = false


func _al_callar(_id: String) -> void:
	visible = true


func _process(delta: float) -> void:
	if not visible or _texto == null:
		return

	_reloj += delta
	var paso := int(_reloj / ritmo) % PUNTOS.size()
	_texto.text = PUNTOS[paso]

	position.y = _altura_base + sin(_reloj * 1.6) * flote


