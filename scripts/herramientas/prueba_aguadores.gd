extends Node
## Aguadores: salen los del día, llegan a la bomba y no se quedan quietos.
## Copia y restaura la partida guardada. Uso: --headless, o -- <carpeta> para fotos.

const CALLE := preload("res://scenes/world/calle.tscn")
const BOMBA := Vector3(-3.0, 0.0, 0.4)

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
		print("[aguadores] VAN Y VIENEN DE LA BOMBA, Y CADA DIA SON OTROS.")
	else:
		for f in _fallos:
			print("[aguadores] ! " + f)
	get_tree().quit(0 if _fallos.is_empty() else 1)


func _ver(cond: bool, que: String) -> void:
	if not cond:
		_fallos.append(que)


func _probar() -> void:
	GameState.reset()
	for dia in [1, 3]:
		GameState.dia = dia
		var calle := CALLE.instantiate()
		add_child(calle)
		var jugador := calle.get_node_or_null(^"Whitehead") as Node3D
		if jugador != null:
			jugador.global_position = Vector3(2.0, 0.0, -1.0)
		await get_tree().create_timer(1.0).timeout
		var grupo := get_tree().get_first_node_in_group(&"aguadores")
		var n: int = grupo.call(&"cuantos")
		_ver(n == (5 if dia == 1 else 3), "día %d: %d aguadores" % [dia, n])
		if dia == 1:
			var cerca := INF
			var juntos := 0
			for s in 130:
				await get_tree().create_timer(0.5).timeout
				var en_bomba := 0
				for a in grupo.get_children():
					if (a as Node3D).visible:
						var d := (a as Node3D).global_position.distance_to(BOMBA)
						cerca = minf(cerca, d)
						if d < 1.6:
							en_bomba += 1
				juntos = maxi(juntos, en_bomba)
				if s == 100:
					await _foto("1_aguadores")
			_ver(cerca < 2.0, "nadie llega a la bomba (más cerca: %.1f m)" % cerca)
			_ver(juntos <= 1, "%d a la vez en la bomba" % juntos)
		calle.queue_free()
		await get_tree().process_frame
	GameState.reset()


func _foto(nombre: String) -> void:
	if _fotos.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_fotos.path_join(nombre + ".png"))
