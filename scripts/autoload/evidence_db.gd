extends Node
## Pruebas de res://data/evidence.json (solo lectura; MLA, sostiene, refuta_a).

const EVIDENCE_PATH := "res://data/evidence.json"

var _by_id: Dictionary = {}


func _ready() -> void:
	_load()


func _load() -> void:
	var f = FileAccess.open(EVIDENCE_PATH, FileAccess.READ)
	if f == null:
		push_error("EvidenceDB: no se pudo abrir " + EVIDENCE_PATH)
		return
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_ARRAY:
		push_error("EvidenceDB: " + EVIDENCE_PATH + " no contiene un array JSON")
		return
	for entry in parsed:
		if typeof(entry) != TYPE_DICTIONARY or not entry.has("id"):
			push_warning("EvidenceDB: entrada sin 'id', ignorada")
			continue
		_by_id[String(entry["id"])] = entry
	print("EvidenceDB: %d pruebas cargadas" % _by_id.size())


func has(id: String) -> bool:
	return _by_id.has(id)


func get_entry(id: String) -> Dictionary:
	if not _by_id.has(id):
		push_error("EvidenceDB: prueba desconocida '" + id + "'")
		return {}
	return _by_id[id]


func all_ids() -> Array:
	return _by_id.keys()


func by_chapter(chapter: int) -> Array:
	var out: Array = []
	for id in _by_id:
		if int(_by_id[id].get("capitulo", 0)) == chapter:
			out.append(_by_id[id])
	return out


## Pruebas que refutan a un guardián.
func refuting(target_id: String) -> Array:
	var out: Array = []
	for id in _by_id:
		if String(target_id) in Array(_by_id[id].get("refuta_a", [])):
			out.append(_by_id[id])
	return out


## Ids con verificación histórica pendiente.
func unverified_ids() -> Array:
	var out: Array = []
	for id in _by_id:
		if String(_by_id[id].get("verificado", "pendiente")) != "si":
			out.append(id)
	return out
