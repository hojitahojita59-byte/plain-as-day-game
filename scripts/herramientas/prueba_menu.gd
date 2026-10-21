extends Node
## Del menú al juego: Begin, cinemática, calle. Fotos por el camino.
## Copia y restaura la partida guardada. Uso: -- <carpeta> [continue]

const MENU := "res://scenes/ui/menu_space.tscn"

var _fotos: String = ""
var _n: int = 0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	_fotos = args[0] if not args.is_empty() else ""
	if not _fotos.is_empty():
		DirAccess.make_dir_recursive_absolute(_fotos)
	var continuar := args.size() > 1 and args[1] == "continue"
	var copia: Variant = null
	if FileAccess.file_exists(SaveSystem.SAVE_PATH):
		copia = FileAccess.get_file_as_bytes(SaveSystem.SAVE_PATH)
	SaveSystem.set(&"_pendiente", true)
	if not continuar:
		DirAccess.remove_absolute(SaveSystem.SAVE_PATH)

	var menu := (load(MENU) as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(menu)
	await get_tree().process_frame
	get_tree().current_scene = menu
	await _esperar(4.0, "menu")
	menu.call(&"_begin", false)
	for s in [1.5, 6.0, 12.0, 20.0, 28.0, 34.0, 38.0, 44.0]:
		await _esperar(s - (0.0 if _n < 2 else 0.0), "tras_begin_%02d" % int(s))
	print("[menu] escena final: %s  dia=%d  hud=%s  esquina=%s" % [
		get_tree().current_scene.scene_file_path if get_tree().current_scene else "?",
		GameState.dia, str(HUD.visible), str((HUD.get(&"_esquina") as CanvasItem).visible)])

	if copia == null:
		SaveSystem.delete_save()
	else:
		FileAccess.open(SaveSystem.SAVE_PATH, FileAccess.WRITE).store_buffer(copia)
	get_tree().quit()


var _t0 := 0.0

func _esperar(hasta: float, nombre: String) -> void:
	if _t0 == 0.0:
		_t0 = Time.get_ticks_msec() / 1000.0
	while Time.get_ticks_msec() / 1000.0 - _t0 < hasta:
		await get_tree().process_frame
	_n += 1
	if _fotos.is_empty():
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_fotos.path_join("%02d_%s.png" % [_n, nombre]))
	print("[menu] t=", Time.get_ticks_msec()); print("[menu] %s  escena=%s" % [nombre, get_tree().current_scene.scene_file_path if get_tree().current_scene else "?"])
