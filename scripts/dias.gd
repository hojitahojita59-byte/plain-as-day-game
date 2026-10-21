extends RefCounted
## Días del Acto I: lazos negros, qué cierra cada día y el paso de la noche.

const DATOS := "res://data/barrio/dias.json"

static var _dias: Array = []


static func _todos() -> Array:
	if _dias.is_empty():
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATOS))
		if d is Dictionary:
			_dias = Array((d as Dictionary).get("dias", []))
	return _dias


static func cuantos() -> int:
	return _todos().size()


## Datos del día n (1..), o {}.
static func de(n: int) -> Dictionary:
	var t := _todos()
	return Dictionary(t[n - 1]) if n >= 1 and n <= t.size() else {}


static func hoy() -> Dictionary:
	return de(GameState.dia)


## Nº de puerta de todas las casas con lazo hasta hoy.
static func lazos() -> PackedStringArray:
	var out: PackedStringArray = []
	for n in range(1, GameState.dia + 1):
		for l in Array(de(n).get("lazos", [])):
			out.append(String(l))
	return out


## El día está cerrado: hecho lo que pide y queda otro día.
static func toca_dormir() -> bool:
	var termina: Array = hoy().get("termina", [])
	if termina.is_empty() or GameState.dia >= cuantos():
		return false
	return GameState.conditions_met(termina)


static func dormir() -> void:
	GameState.dia += 1
	GameState.set_flag("dia_%d" % GameState.dia)
