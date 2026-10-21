extends Node
## Días: lazos por día, puertas por día, la noche en la rectoría pasa al día siguiente.
## Copia y restaura la partida guardada. Uso: --headless, o -- <carpeta> para fotos.

const CALLE := preload("res://scenes/world/calle.tscn")
const RECTORIA := preload("res://scenes/world/rectoria.tscn")
const DIAS := preload("res://scripts/dias.gd")

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
		print("[dias] TRES DIAS, CON SUS LAZOS, SUS PUERTAS Y SUS NOCHES.")
	else:
		for f in _fallos:
			print("[dias] ! " + f)
	get_tree().quit(0 if _fallos.is_empty() else 1)


func _ver(cond: bool, que: String) -> void:
	if not cond:
		_fallos.append(que)


func _probar() -> void:
	GameState.reset()
	Casefile.reset()
	Cuaderno.reset()
	_ver(DIAS.cuantos() == 3, "no hay tres días")

	# Día 1 en la calle.
	var calle := CALLE.instantiate()
	add_child(calle)
	var jugador := calle.get_node_or_null(^"Whitehead") as Node3D
	if jugador != null:
		jugador.global_position = Vector3(-8.0, 0.0, -2.0)
	await get_tree().create_timer(1.2).timeout
	var lazos := get_tree().get_first_node_in_group(&"lazos")
	_ver(lazos != null, "sin lazos en la calle")
	var hay: PackedStringArray = lazos.call(&"numeros") if lazos != null else PackedStringArray()
	_ver(Array(hay) == ["38", "39"] or Array(hay) == ["39", "38"], "lazos del viernes: %s" % str(hay))
	_ver(_abierta("38") and _abierta("41"), "el viernes no abren 38 y 41")
	_ver(not _abierta("39"), "el 39 abre antes de hablar con el 41")
	GameState.set_flag("spoke_to_the_coal_woman")
	_ver(_abierta("39"), "el 39 no abre después del 41")
	_ver(not _abierta("40") and not _abierta("12") and not _abierta("5"), "el viernes abre una puerta de otro día")
	var niebla_1 := _niebla(calle)
	await _foto("1_lazo_38")

	# Día cerrado: la noche en la rectoría.
	for f in Array(DIAS.hoy()["termina"]):
		GameState.set_flag(String(f))
	_ver(DIAS.toca_dormir(), "el viernes cerrado no pide dormir")
	calle.queue_free()
	await get_tree().process_frame
	var casa := RECTORIA.instantiate()
	add_child(casa)
	var noche := get_tree().get_first_node_in_group(&"noche")
	_ver(noche != null, "la rectoría no tiene noche")
	await get_tree().create_timer(5.5).timeout
	await _foto("2_noche")
	await noche.amanecido
	_ver(GameState.dia == 2, "tras la noche, día %d" % GameState.dia)
	_ver(GameState.has_flag("dia_2"), "sin bandera dia_2")
	casa.queue_free()
	await get_tree().process_frame

	# Día 2: lazos nuevos, puertas nuevas, más niebla.
	calle = CALLE.instantiate()
	add_child(calle)
	await get_tree().create_timer(1.2).timeout
	lazos = get_tree().get_first_node_in_group(&"lazos")
	hay = lazos.call(&"numeros")
	_ver(hay.size() == 3 and "12" in hay and not "40" in hay, "lazos del sábado: %s" % str(hay))
	_ver(_abierta("40") and _abierta("12") and _abierta("16"), "el sábado no abren 40 y Cambridge")
	_ver(not _abierta("5"), "el sábado abre Peter Street")
	_ver(_niebla(calle) > niebla_1, "la niebla no espesa (%.4f -> %.4f)" % [niebla_1, _niebla(calle)])
	calle.queue_free()
	await get_tree().process_frame
	GameState.reset()
	Casefile.reset()
	Cuaderno.reset()


func _abierta(numero: String) -> bool:
	for p in get_tree().get_nodes_in_group(&"puertas"):
		if String((p as Node).get_meta(&"numero", "")) == numero:
			return GameState.conditions_met(Array(p.get("requires")))
	return false


func _niebla(raiz: Node) -> float:
	var w := raiz.find_child("WorldEnvironment", true, false) as WorldEnvironment
	return w.environment.fog_density if w != null and w.environment != null else 0.0


func _foto(nombre: String) -> void:
	if _fotos.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_fotos.path_join(nombre + ".png"))
