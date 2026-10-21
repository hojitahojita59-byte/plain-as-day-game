extends Node
## Expediente: pruebas, apuntes y registro de defunciones del jugador.

signal evidence_collected(id: String)
signal note_taken(note: Dictionary)

var _collected: Array[String] = []

## Apuntes oídos {id, que, quien, donde}; distintos de las pruebas citables.
var _notes: Array[Dictionary] = []


func collect(id: String) -> bool:
	if not EvidenceDB.has(id):
		push_error("Casefile: se intentó recoger una prueba inexistente '" + id + "'")
		return false
	if id in _collected:
		return false
	_collected.append(id)
	evidence_collected.emit(id)
	return true


func has(id: String) -> bool:
	return id in _collected


## Apunta algo oído por la calle. Devuelve false si ya estaba.
func note(entry: Dictionary) -> bool:
	var id := String(entry.get("id", ""))
	if id.is_empty():
		push_error("Casefile: una anotación sin id no se puede apuntar: " + str(entry))
		return false
	for n in _notes:
		if String(n.get("id", "")) == id:
			return false
	_notes.append(entry.duplicate(true))
	note_taken.emit(entry)
	return true


func notes() -> Array[Dictionary]:
	return _notes.duplicate(true)


func note_count() -> int:
	return _notes.size()


## Registro de defunciones: lo que ha contado Whitehead (nombre, calle, día).
var _register: Array[Dictionary] = []

signal recorded(entry: Dictionary)


## Asienta una muerte. Devuelve false si ya estaba.
func record(entry: Dictionary) -> bool:
	var id := String(entry.get("id", ""))
	if id.is_empty():
		push_error("Casefile: un asiento sin id no se puede registrar: " + str(entry))
		return false
	for r in _register:
		if String(r.get("id", "")) == id:
			return false
	_register.append(entry.duplicate(true))
	recorded.emit(entry)
	return true


func records() -> Array[Dictionary]:
	return _register.duplicate(true)


func record_count() -> int:
	return _register.size()


func is_recorded(id: String) -> bool:
	for r in _register:
		if String(r.get("id", "")) == id:
			return true
	return false


## Calidad del caso (0-1): pruebas citables del capítulo actual / total.
func quality() -> float:
	var del_capitulo := EvidenceDB.by_chapter(GameState.chapter)
	if del_capitulo.is_empty():
		return 0.0
	var mias := 0
	for e in del_capitulo:
		if has(String((e as Dictionary).get("id", ""))):
			mias += 1
	return float(mias) / float(del_capitulo.size())


func collected_ids() -> Array[String]:
	return _collected.duplicate()


func count() -> int:
	return _collected.size()


## Pruebas recogidas que sirven contra un guardián concreto.
func available_against(target_id: String) -> Array:
	var out: Array = []
	for entry in EvidenceDB.refuting(target_id):
		if has(String(entry["id"])):
			out.append(entry)
	return out


func to_dict() -> Dictionary:
	return {
		"collected": _collected.duplicate(),
		"notes": _notes.duplicate(true),
		"register": _register.duplicate(true),
		# El cuaderno viaja dentro del expediente.
		"cuaderno": Cuaderno.to_dict(),
	}


func from_dict(d: Dictionary) -> void:
	_collected.clear()
	for id in Array(d.get("collected", [])):
		_collected.append(String(id))
	_notes.clear()
	for n in Array(d.get("notes", [])):
		_notes.append(Dictionary(n))
	_register.clear()
	for r in Array(d.get("register", [])):
		_register.append(Dictionary(r))
	Cuaderno.from_dict(Dictionary(d.get("cuaderno", {})))


## Vacía el expediente (nueva partida); el autoload sobrevive a las escenas.
func reset() -> void:
	_collected.clear()
	_notes.clear()
	_register.clear()
	Cuaderno.reset()
