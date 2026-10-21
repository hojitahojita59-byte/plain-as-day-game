extends Node3D
## Ficha de la escena (en el nodo raíz): su id y las pruebas que se sacan aquí.

## Igual que el campo `escena` de evidence.json.
@export var scene_id: String = ""

## Ids de evidence.json que se PUEDEN conseguir aquí (no solo mencionadas).
@export var expected_evidence: PackedStringArray = []


func _ready() -> void:
	add_to_group("scene_info")
	if not scene_id.is_empty():
		GameState.scene_id = scene_id
	_warn_about_typos()
	HUD.refresh_evidence()


func collected_here() -> int:
	var n := 0
	for id in expected_evidence:
		if Casefile.has(String(id)):
			n += 1
	return n


func total_here() -> int:
	return expected_evidence.size()


## Avisa al cargar si un id no existe en evidence.json.
func _warn_about_typos() -> void:
	for id in expected_evidence:
		if not EvidenceDB.has(String(id)):
			push_warning("SceneInfo(%s): la prueba '%s' no existe en evidence.json" % [scene_id, id])
