extends Node
## ¿Pausa Escape el juego? Pulsa la tecla de verdad en calle, rectoría y mesa.
## Uso: prueba_pausa.tscn [-- foto.png]

const ESCENAS := {
	"calle": "res://scenes/world/calle.tscn",
	"rectoría": "res://scenes/world/rectoria.tscn",
}

## Tiempo hasta que Whitehead se sienta en la rectoría.
const ESPERA_SENTADO := 9.0


func _ready() -> void:
	# Copia la partida guardada y la restaura al terminar.
	var copia: Variant = null
	if FileAccess.file_exists(SaveSystem.SAVE_PATH):
		copia = FileAccess.get_file_as_bytes(SaveSystem.SAVE_PATH)

	var fallos := 0
	print("")
	print("=== PAUSA ===")
	for nombre in ESCENAS:
		var escena := (load(ESCENAS[nombre]) as PackedScene).instantiate()
		get_tree().root.add_child.call_deferred(escena)
		await get_tree().process_frame
		get_tree().current_scene = escena
		await get_tree().create_timer(1.5).timeout
		fallos += 0 if await _escape(nombre) else 1
		if nombre == "calle":
			fallos += 0 if await _boton() else 1
		if nombre == "rectoría":
			await get_tree().create_timer(ESPERA_SENTADO).timeout
			fallos += 0 if await _escape("rectoría, sentado") else 1
			# Foto opcional: sentado con la hoja levantada.
			var extra := OS.get_cmdline_user_args()
			var sentado := escena.find_child("Sentado", true, false)
			if extra.size() > 1 and sentado != null:
				sentado.call("_levantar_la_hoja")
				await get_tree().create_timer(1.0).timeout
				# Con un nombre en la mano, para ver su hueco en el plano.
				var marco = sentado.get("_hoja")
				if marco != null and marco.get_child_count() > 0:
					var hoja: Node = marco.get_child(0)
					var esperan: Array = hoja.call("_por_clavar")
					if not esperan.is_empty():
						hoja.call("_coger", esperan[0])
				await get_tree().create_timer(0.4).timeout
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(extra[1])
		escena.queue_free()
		await get_tree().process_frame

	print("[pausa] %s" % ("ESCAPE PARA EL JUEGO EN TODAS." if fallos == 0
		else "%d SITIOS DONDE ESCAPE NO PARA." % fallos))
	await get_tree().process_frame
	if copia == null:
		SaveSystem.delete_save()
	else:
		FileAccess.open(SaveSystem.SAVE_PATH, FileAccess.WRITE).store_buffer(copia)
	get_tree().quit(0 if fallos == 0 else 1)


func _escape(donde: String) -> bool:
	_pulsar(KEY_ESCAPE)
	await get_tree().process_frame
	await get_tree().process_frame
	var hoja := HUD.get("_pausa") as Control
	var abierta := hoja != null and hoja.visible and get_tree().paused
	print("  %-22s %s" % [donde, "para" if abierta else "! NO PARA"])
	if abierta:
		hoja.call("cerrar")
		await get_tree().process_frame
	return abierta


## El botón de pausa: que se vea y que pare. Foto con `-- ruta.png`.
func _boton() -> bool:
	var b := HUD.get("_boton_pausa") as Button
	await get_tree().create_timer(0.3).timeout
	var se_ve := b != null and b.is_visible_in_tree()
	var extra := OS.get_cmdline_user_args()
	if extra.size() > 0:
		# Apunte reciente, para ver el aviso "Noted".
		Casefile.note({"id": "prueba_foto", "muerte": true,
			"que": "Brother-in-law at 38 Broad Street. Well at noon; dead Friday night."})
		# Y un pensamiento.
		HUD.pensar("Most of the deaths are around the corner of Broad Street.")
		await get_tree().create_timer(0.9).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(extra[0])
	if se_ve:
		b.pressed.emit()
		await get_tree().process_frame
	var hoja := HUD.get("_pausa") as Control
	var para := se_ve and hoja != null and hoja.visible and get_tree().paused
	print("  %-22s %s" % ["botón en la calle", "se ve y para" if para
		else ("! NO SE VE" if not se_ve else "! NO PARA")])
	if para:
		hoja.call("cerrar")
		await get_tree().process_frame
	return para


func _pulsar(tecla: Key) -> void:
	for apretada in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = tecla
		ev.physical_keycode = tecla
		ev.pressed = apretada
		Input.parse_input_event(ev)
