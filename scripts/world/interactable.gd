extends StaticBody3D
class_name Interactable
## Algo del mundo con lo que se habla o que se examina (puerta, persona, objeto).

## Archivo en res://data/dialogue/, sin extensión.
@export var dialogue_id: String = ""

## Nombre que se muestra en el cartel.
@export var display_name: String = "A door"

## Metros a los que se para Whitehead antes de interactuar.
@export var stop_distance: float = 2.0

## Banderas necesarias, formato `GameState.conditions_met` ("!bandera" niega).
@export var requires: PackedStringArray = []

## Diálogo si no se cumplen las condiciones. Vacío = nada.
@export var locked_dialogue_id: String = ""


## Conversación que toca ahora.
func active_dialogue_id() -> String:
	if requires.is_empty():
		return DialogueRunner.resolve(dialogue_id)
	if GameState.conditions_met(Array(requires)):
		return dialogue_id
	return locked_dialogue_id


## True si hay alguien detrás, no solo la respuesta de reserva.
func hay_conversacion_de_verdad() -> bool:
	if active_dialogue_id().is_empty():
		return false
	if requires.is_empty():
		return true
	return GameState.conditions_met(Array(requires))


## Pararse delante (puertas), no en la dirección de llegada.
@export var mirar_de_frente: bool = false


## Punto del suelo donde parar viniendo de `from`, a la altura de los pies.
func approach_point(from: Vector3) -> Vector3:
	var dir: Vector3
	if mirar_de_frente:
		# Eje Z de la base = cara decorada del módulo.
		dir = global_transform.basis.z
	else:
		dir = from - global_position
	dir.y = 0.0
	if dir.length() < 0.01:
		dir = Vector3.BACK
	var point := global_position + dir.normalized() * stop_distance
	point.y = from.y
	return point
