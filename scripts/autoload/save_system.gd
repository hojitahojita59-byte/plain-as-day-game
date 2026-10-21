extends Node
## Guardado en JSON legible bajo user://.

const SAVE_PATH := "user://soho1854_save.json"

## Hay un guardado pedido y aún no escrito este fotograma.
var _pendiente: bool = false


## Autoguardado al recoger una prueba o cambiar una bandera.
func _ready() -> void:
	Casefile.evidence_collected.connect(func(_id: String): _pedir_guardado())
	GameState.flag_changed.connect(func(_f: String, _v: bool): _pedir_guardado())


## Agrupa varios cambios en un solo guardado al final del fotograma.
func _pedir_guardado() -> void:
	if _pendiente:
		return
	# No guardar desde las escenas de prueba (herramientas/).
	var escena := get_tree().current_scene
	if escena != null and escena.scene_file_path.contains("/herramientas/"):
		return
	_pendiente = true
	_guardar_al_final_del_fotograma.call_deferred()


func _guardar_al_final_del_fotograma() -> void:
	_pendiente = false
	save_game()


func save_game() -> bool:
	var payload := {
		"version": 1,
		"state": GameState.to_dict(),
		"casefile": Casefile.to_dict(),
		"barrio": Barrio.to_dict(),
		"cronometro": Cronometro.to_dict(),
	}
	var f = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("SaveSystem: no se pudo escribir " + SAVE_PATH)
		return false
	f.store_string(JSON.stringify(payload, "\t"))
	Cronometro.escribir()
	return true


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


## Lee la partida del disco sin cargarla en memoria (para el menú).
func peek() -> Dictionary:
	if not has_save():
		return {}
	var f = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed


func load_game() -> bool:
	var f = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("SaveSystem: partida corrupta")
		return false
	GameState.from_dict(Dictionary(parsed.get("state", {})))
	Casefile.from_dict(Dictionary(parsed.get("casefile", {})))
	Barrio.from_dict(Dictionary(parsed.get("barrio", {})))
	Cronometro.from_dict(Dictionary(parsed.get("cronometro", {})))
	return true


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
