extends Node
## Recorre «Continue» del menú: dónde acaba y si vuelve a la posición guardada.

const SERIES := "res://data/series.json"


## Copia la partida guardada y la restaura al terminar.
func _ready() -> void:
	var copia: Variant = null
	if FileAccess.file_exists(SaveSystem.SAVE_PATH):
		copia = FileAccess.get_file_as_bytes(SaveSystem.SAVE_PATH)
	await _probar()
	await get_tree().process_frame
	if copia == null:
		SaveSystem.delete_save()
	else:
		FileAccess.open(SaveSystem.SAVE_PATH, FileAccess.WRITE).store_buffer(copia)
	get_tree().quit()


func _probar() -> void:
	print("")
	print("=== 1. LA PARTIDA QUE HAY EN EL DISCO ===")
	if not SaveSystem.has_save():
		print("  no hay ninguna: el menú diría «Begin», no «Continue».")
	else:
		var save := SaveSystem.peek()
		var cf: Dictionary = save.get("casefile", {})
		print("  se lee sin cargarla (lo que enseña el menú):")
		print("    muertes asentadas:  %d" % Array(cf.get("register", [])).size())
		print("    cosas apuntadas:    %d" % Array(cf.get("notes", [])).size())
		print("    pruebas citables:   %d" % Array(cf.get("collected", [])).size())
		print("    calle:              %s" % String(
			Dictionary(save.get("barrio", {})).get("actual", "?")))
		var pos := Dictionary(Dictionary(save.get("barrio", {})).get("posiciones", {}))
		print("    posición guardada:  %s" % (str(pos) if not pos.is_empty()
			else "NINGUNA (partida vieja: volverá al principio de la calle)"))

	print("")
	print("=== 2. ADÓNDE MANDA EL MENÚ ===")
	var f := FileAccess.open(SERIES, FileAccess.READ)
	var series = JSON.parse_string(f.get_as_text()) if f != null else null
	var evs := Array(Dictionary(series).get("events", [])) if typeof(series) == TYPE_DICTIONARY else []
	var destino := String(Dictionary(evs[0]).get("scene", "")) if not evs.is_empty() else ""
	print("  escena declarada: '%s'  existe: %s" % [
		destino, "sí" if (not destino.is_empty() and ResourceLoader.exists(destino)) else "NO"])
	if destino.is_empty() or not ResourceLoader.exists(destino):
		print("  ! sin escena, Continue se rendiría y empezaría de cero. ESE sería el fallo.")
		return

	print("")
	print("=== 3. ¿VUELVE DONDE LO DEJÓ? ===")
	# Partida de prueba: parado delante del 41.
	Barrio.actual = "soho"
	Barrio.anotar_posicion("soho", 12.4, -2.6)
	GameState.set_flag("knows_the_coal_womans_house")
	SaveSystem.save_game()
	print("  guardado de pie en x=12.4, z=-2.6 (delante del 41)")

	# Olvida todo, como al arrancar.
	GameState.reset()
	Casefile.reset()
	Barrio.reset()
	print("  todo olvidado. Barrio.actual=%s posición=%s" % [
		Barrio.actual, str(Barrio.posicion("soho"))])

	SaveSystem.load_game()
	print("  cargado. entrada_por=%s posición=%s" % [
		Barrio.entrada_por, str(Barrio.posicion("soho"))])

	var escena := (load(destino) as PackedScene).instantiate()
	add_child(escena)
	for i in 25:
		await get_tree().process_frame

	var jugador := escena.get_node_or_null(^"Whitehead") as Node3D
	var x := jugador.global_position.x
	var z := jugador.global_position.z
	var bien: bool = absf(x - 12.4) < 0.6 and absf(z + 2.6) < 0.6
	print("  aparece en x=%.1f z=%.1f  -> %s" % [x, z,
		"VUELVE DONDE LO DEJÓ" if bien else "! SE FUE AL PRINCIPIO DE LA CALLE"])

	pass
