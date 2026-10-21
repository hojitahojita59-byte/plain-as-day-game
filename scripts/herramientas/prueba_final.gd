extends Node
## Final del acto: con racimo y dos casas raras, la imagen del mapa y luego Snow.
## Copia y restaura la partida guardada. Uso: --headless, o -- <carpeta> para fotos.

const CALLE := preload("res://scenes/world/calle.tscn")
const SNOW := preload("res://scripts/world/llaman_a_la_puerta.gd")
const ASIENTOS := preload("res://scripts/asientos.gd")

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
		print("[final] TODAS LAS ESTELAS A LA BOMBA, Y LUEGO LLAMA SNOW.")
	else:
		for f in _fallos:
			print("[final] ! " + f)
	get_tree().quit(0 if _fallos.is_empty() else 1)


func _ver(cond: bool, que: String) -> void:
	if not cond:
		_fallos.append(que)


func _probar() -> void:
	GameState.reset()
	Casefile.reset()
	Cuaderno.reset()
	GameState.dia = 3
	for f in ["dia_2", "dia_3", "lista_1", "lista_3", ASIENTOS.ENTERRADA, "apertura_vista"]:
		GameState.set_flag(f)
	for f in Cuaderno.todas_las_fichas():
		_sellar(String(f["id"]))
	for a in ASIENTOS.por_asentar():
		Casefile.record(a)
	Casefile.collect(ASIENTOS.PRUEBA_RACIMO)
	GameState.set_flag("saw_the_cluster")
	_ver(SNOW.toca(), "con todo hecho, Snow no llamaría")

	var calle := CALLE.instantiate()
	add_child(calle)
	await get_tree().create_timer(1.0).timeout
	var vista := get_tree().get_first_node_in_group(&"vista_pajaro")
	vista.call(&"final")
	await get_tree().create_timer(7.2).timeout
	await _foto("1_poster")
	await get_tree().create_timer(2.5).timeout
	_ver(GameState.has_flag("poster_visto"), "no se marca el final como visto")
	var maqueta: Node3D = vista.call(&"maqueta")
	_ver(maqueta.call(&"estelas_dibujadas").size() == Cuaderno.estelas().size(), "faltan estelas en el final")
	calle.queue_free()
	await get_tree().process_frame
	GameState.reset()
	Casefile.reset()
	Cuaderno.reset()


func _sellar(f: String) -> void:
	Cuaderno.abrir(f)
	var huecos: Dictionary = Dictionary(Cuaderno.ficha(f).get("huecos", {}))
	for h in huecos:
		Cuaderno.aprender(String(huecos[h]))
		Cuaderno.poner(f, String(h), String(huecos[h]))
	Cuaderno.comprobar(f)


func _foto(nombre: String) -> void:
	if _fotos.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_fotos.path_join(nombre + ".png"))
