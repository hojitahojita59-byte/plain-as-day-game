extends Node
## Apertura: sale una vez, sin control mientras dura, y devuelve el control al acabar.
## Copia y restaura la partida guardada. Uso: --headless, o -- <carpeta> para fotos.

const CALLE := preload("res://scenes/world/calle.tscn")

var _fallos: PackedStringArray = []
var _fotos: String = ""


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		_fotos = args[0]
		DirAccess.make_dir_recursive_absolute(_fotos)
	var copia: Variant = null
	if FileAccess.file_exists(SaveSystem.SAVE_PATH):
		copia = FileAccess.get_file_as_bytes(SaveSystem.SAVE_PATH)
	SaveSystem.set(&"_pendiente", true)
	await _probar()
	await get_tree().process_frame
	if copia == null:
		SaveSystem.delete_save()
	else:
		FileAccess.open(SaveSystem.SAVE_PATH, FileAccess.WRITE).store_buffer(copia)
	if _fallos.is_empty():
		print("[apertura] SACAN UN CUERPO DEL 38 Y LUEGO SE JUEGA.")
	else:
		for f in _fallos:
			print("[apertura] ! " + f)
	get_tree().quit(0 if _fallos.is_empty() else 1)


func _ver(cond: bool, que: String) -> void:
	if not cond:
		_fallos.append(que)


func _probar() -> void:
	GameState.reset()
	Casefile.reset()
	GameState.set_flag("probar_apertura")
	var calle := CALLE.instantiate()
	add_child(calle)
	await get_tree().create_timer(0.5).timeout
	var ap := get_tree().get_first_node_in_group(&"apertura")
	_ver(ap != null, "no hay apertura en la primera visita")
	var jugador := get_tree().get_first_node_in_group(&"jugador") as Node
	await get_tree().create_timer(3.4).timeout
	_ver(jugador != null and is_zero_approx(float(jugador.get(&"speed"))), "se puede andar durante la apertura")
	await _foto("1_apertura")
	await get_tree().create_timer(3.0).timeout
	await _foto("2_apertura")
	await get_tree().create_timer(7.0).timeout
	_ver(GameState.has_flag("apertura_vista"), "no se marca como vista")
	_ver(jugador != null and float(jugador.get(&"speed")) > 1.0, "no devuelve el control")
	# Tras la apertura se anda: hasta Sarah Lewis, junto al 40.
	var sarah := calle.find_child("BroadSarahLewis", true, false) as Node3D
	if sarah != null and jugador != null:
		jugador.call(&"ir_a", sarah)
		var llega := false
		for i in 60:
			await get_tree().create_timer(0.25).timeout
			if not bool(jugador.get(&"_has_target")):
				llega = true
				break
		var p := (jugador as Node3D).global_position
		_ver(llega, "tras la apertura no llega a Sarah Lewis (se queda en %.1f, %.1f; v=%s)" % [
			p.x, p.z, str(jugador.get(&"velocity"))])
	calle.queue_free()
	await get_tree().process_frame

	# Segunda visita: ya no sale.
	calle = CALLE.instantiate()
	add_child(calle)
	await get_tree().create_timer(0.5).timeout
	_ver(get_tree().get_first_node_in_group(&"apertura") == null, "sale dos veces")
	calle.queue_free()
	await get_tree().process_frame
	GameState.reset()


func _foto(nombre: String) -> void:
	if _fotos.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_fotos.path_join(nombre + ".png"))
