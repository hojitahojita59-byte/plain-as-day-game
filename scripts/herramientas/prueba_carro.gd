extends Node
## Carro de los muertos: llega con lista, el sacristán la da, sube la vista y caen las marcas.
## Copia y restaura la partida guardada. Uso: --headless, o -- <carpeta> para fotos.

const CALLE := preload("res://scenes/world/calle.tscn")
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
		print("[carro] EL SACRISTAN TRAE LA LISTA Y CAE EN EL MAPA.")
	else:
		for f in _fallos:
			print("[carro] ! " + f)
	get_tree().quit(0 if _fallos.is_empty() else 1)


func _ver(cond: bool, que: String) -> void:
	if not cond:
		_fallos.append(que)


func _probar() -> void:
	GameState.reset()
	Casefile.reset()
	Cuaderno.reset()
	var calle := CALLE.instantiate()
	add_child(calle)
	var jugador := calle.get_node_or_null(^"Whitehead") as Node3D
	if jugador != null:
		jugador.global_position = Vector3(8.0, 0.0, -1.5)
	await get_tree().create_timer(1.0).timeout
	var carro := get_tree().get_first_node_in_group(&"carro_de_muertos")
	_ver(carro != null, "no hay carro")
	_ver(not (carro as Node3D).visible, "el carro está sin lista")

	# Tras el sastre llega con la lista del viernes.
	for f in ["hablado_ch1_s3_garment_woman", "hablado_ch1_s3_coal_woman", "hablado_ch1_s3_tailor"]:
		GameState.set_flag(f)
	_ver(ASIENTOS.lista_pendiente() == 1, "sin lista pendiente el viernes")
	_ver(ASIENTOS.por_asentar().is_empty(), "la lista cuenta antes de recogerla")
	await get_tree().create_timer(17.5).timeout
	_ver(int(carro.call(&"esperando")) == 1, "el carro no espera con la lista 1")
	await _foto("1_carro")

	# Hablar con el sacristán.
	DialogueRunner.start("ch1_s3_sacristan_1")
	var vueltas := 0
	while DialogueRunner.active and vueltas < 20:
		vueltas += 1
		DialogueRunner.advance()
	_ver(GameState.has_flag("lista_1"), "el sacristán no da la lista")
	await get_tree().create_timer(3.0).timeout
	var vista := get_tree().get_first_node_in_group(&"vista_pajaro")
	_ver(bool(vista.get(&"activa")), "no se abre la vista de pájaro")
	_ver(not ASIENTOS.por_asentar().is_empty(), "la lista no está por asentar")
	await _foto("2_lista_arriba")
	vista.call(&"bajar")
	await get_tree().create_timer(1.3).timeout
	GameState.reset()
	Casefile.reset()
	Cuaderno.reset()


func _foto(nombre: String) -> void:
	if _fotos.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_fotos.path_join(nombre + ".png"))
