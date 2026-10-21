extends Node
## ¿Cuenta el cronómetro solo lo que debe? Copia y restaura la partida guardada.
## Uso: --headless --quit-after 600 res://scenes/herramientas/prueba_cronometro.tscn


func _ready() -> void:
	var copia: Variant = null
	if FileAccess.file_exists(SaveSystem.SAVE_PATH):
		copia = FileAccess.get_file_as_bytes(SaveSystem.SAVE_PATH)
	await _probar()
	# El autoguardado reescribe el cronómetro: esperar y luego limpiar.
	await get_tree().process_frame
	if copia == null:
		SaveSystem.delete_save()
	else:
		FileAccess.open(SaveSystem.SAVE_PATH, FileAccess.WRITE).store_buffer(copia)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(
		Cronometro.CARPETA + "partida_%s.json" % Cronometro.inicio))
	get_tree().quit()


func _probar() -> void:
	var bien := true
	Cronometro.reset()
	print("")
	print("=== CRONÓMETRO ===")

	# 1. Cuenta mientras se juega.
	await get_tree().create_timer(1.0).timeout
	var tras_un_segundo := Cronometro.jugado
	var cuenta := tras_un_segundo > 0.8 and tras_un_segundo < 1.3
	print("  un segundo jugado -> %.2f s   %s" % [tras_un_segundo, "SI" if cuenta else "! NO"])
	bien = bien and cuenta

	# 2. La pausa no cuenta.
	get_tree().paused = true
	await get_tree().create_timer(0.6, true).timeout
	get_tree().paused = false
	var con_pausa := Cronometro.jugado - tras_un_segundo
	var pausa_bien := con_pausa < 0.15
	print("  0,6 s en pausa suman %.2f s   %s" % [con_pausa, "SI" if pausa_bien else "! NO"])
	bien = bien and pausa_bien

	# 3. Los hitos, una sola vez cada uno.
	GameState.set_flag("prueba_cronometro_bandera")
	GameState.set_flag("prueba_cronometro_bandera", false)
	GameState.set_flag("prueba_cronometro_bandera")
	Casefile.record({"id": "prueba_cronometro_asiento", "nombre": "x", "calle": "x", "dia": "x"})
	var hitos := Cronometro.hitos.map(func(h): return String(h["que"]))
	var hitos_bien := hitos.count("bandera:prueba_cronometro_bandera") == 1 \
		and hitos.has("asiento:prueba_cronometro_asiento")
	print("  hitos: %s   %s" % [str(hitos), "SI" if hitos_bien else "! NO"])
	bien = bien and hitos_bien

	# 4. Sobrevive a guardar y cargar.
	var d := Cronometro.to_dict()
	Cronometro.reset()
	Cronometro.from_dict(d)
	var vuelve := absf(Cronometro.jugado - float(d["jugado"])) < 0.01 and Cronometro.hitos.size() == hitos.size()
	print("  guardar y cargar conserva %.1f s y %d hitos   %s" % [
		Cronometro.jugado, Cronometro.hitos.size(), "SI" if vuelve else "! NO"])
	bien = bien and vuelve

	# 5. Escribe su archivo (se borra al final, en _ready).
	Cronometro.escribir()
	var ruta := Cronometro.CARPETA + "partida_%s.json" % Cronometro.inicio
	var escrito := FileAccess.file_exists(ruta)
	print("  archivo %s   %s" % [ProjectSettings.globalize_path(ruta), "SI" if escrito else "! NO"])
	bien = bien and escrito

	print("")
	print("[cronometro] %s" % ("TODO BIEN." if bien else "! ALGO FALLA."))
