extends Node
## Vista de pájaro: subir/bajar, asentar a mano y en cascada, marcas en su casa, cerco.
## Copia y restaura la partida guardada. Uso: --headless, o -- <carpeta> para fotos.

const CALLE := preload("res://scenes/world/calle.tscn")
const MAQUETA := preload("res://scripts/world/maqueta.gd")
const PLANO := preload("res://scripts/ui/plano_parroquia.gd")
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
		print("[pajaro] SE SUBE, SE ASIENTA Y SE CERCA DESDE LA CALLE.")
	else:
		for f in _fallos:
			print("[pajaro] ! " + f)
	get_tree().quit(0 if _fallos.is_empty() else 1)


func _ver(cond: bool, que: String) -> void:
	if not cond:
		_fallos.append(que)


func _probar() -> void:
	GameState.reset()
	Casefile.reset()
	Cuaderno.reset()
	GameState.set_flag("lista_1")

	var calle := CALLE.instantiate()
	add_child(calle)
	await get_tree().create_timer(1.0).timeout
	var vista := get_tree().get_first_node_in_group(&"vista_pajaro")
	_ver(vista != null, "no hay VistaPajaro en la calle")
	if vista == null:
		return
	var maqueta: Node3D = vista.call(&"maqueta")

	# Toda dirección del libro y de las fichas cae sobre un tejado.
	var todos: Array = Array(ASIENTOS._libro().get("asientos", [])) + Array(ASIENTOS._libro().get("segunda_tanda", []))
	for a in todos:
		var p := MAQUETA.sitio(Dictionary(a))
		_ver(p != Vector2.INF, "%s sin sitio" % a.get("calle", "?"))
		if p != Vector2.INF and String(a.get("calle", "")).split(" ")[0].is_valid_int():
			_ver(maqueta.call(&"alto_en", p) > 0.0, "%s no cae sobre una casa" % a.get("calle", "?"))

	# Subir.
	vista.call(&"subir")
	await get_tree().create_timer(2.2).timeout
	_ver(bool(vista.get(&"activa")), "no subió")
	await _foto("1_a_mano")

	# A mano: un fallo de calle y luego la casa buena, tres veces.
	var pend: Array[Dictionary] = ASIENTOS.por_asentar()
	_ver(pend.size() == 4, "pendientes del libro: %d, se esperaban 4" % pend.size())
	for i in 3:
		var a: Dictionary = ASIENTOS.por_asentar()[0]
		vista.call(&"_coger", a)
		vista.call(&"clavar_en", Vector2(0.14, 0.15))
		_ver(not Casefile.is_recorded(String(a["id"])), "aceptó un clic en otra calle")
		_ver(not String(vista.get(&"_voz").text).is_empty(), "un fallo sin pista")
		vista.call(&"clavar_en", MAQUETA.sitio(a))
		await get_tree().create_timer(0.6).timeout
		_ver(Casefile.is_recorded(String(a["id"])), "no aceptó el tejado de %s" % a.get("calle", "?"))

	# El resto cae solo.
	await get_tree().create_timer(1.6).timeout
	_ver(Casefile.record_count() == 4, "en cascada: %d de 4" % Casefile.record_count())
	_ver(GameState.has_flag(ASIENTOS.YA_COPIADO), "no marcó el libro leído")
	_ver(int(maqueta.call(&"marcas")) == Casefile.record_count(), "marcas != asientos")

	# Bajar y volver con la lista del sacristán: cae sola y toca cercar.
	vista.call(&"bajar")
	await get_tree().create_timer(1.3).timeout
	_ver(not bool(vista.get(&"activa")), "no bajó")
	GameState.set_flag(ASIENTOS.ENTERRADA)
	GameState.set_flag("lista_3")
	for f in ["f_38", "f_39", "f_40", "f_12c", "f_2n", "f_5p"]:
		_sellar(f)
	vista.call(&"subir")
	await get_tree().create_timer(2.0 + 0.45 * ASIENTOS.por_asentar().size() + 1.0).timeout
	_ver(ASIENTOS.por_asentar().is_empty(), "quedan %d por asentar" % ASIENTOS.por_asentar().size())
	_ver(int(maqueta.call(&"marcas")) == Casefile.record_count(), "marcas %d != asientos %d" % [
		int(maqueta.call(&"marcas")), Casefile.record_count()])
	_ver(bool(vista.get(&"_trazando")), "no pide el cerco con %d asientos" % Casefile.record_count())
	await _foto("2_racimo")

	vista.call(&"cercar", PLANO.BOMBA, 0.4)
	_ver(not Casefile.has(ASIENTOS.PRUEBA_RACIMO), "aceptó un cerco enorme")
	vista.call(&"cercar", Vector2(0.15, 0.85), 0.05)
	_ver(not Casefile.has(ASIENTOS.PRUEBA_RACIMO), "aceptó un cerco vacío")
	vista.call(&"cercar", PLANO.BOMBA, 0.23)
	_ver(Casefile.has(ASIENTOS.PRUEBA_RACIMO), "no aceptó el cerco bueno: %s" % vista.get(&"_voz").text)
	_ver(GameState.has_flag("saw_the_cluster"), "sin saw_the_cluster")
	await get_tree().create_timer(0.5).timeout
	await _foto("3_cercado")
	print("[pajaro] %d muertes en la maqueta" % Casefile.record_count())

	vista.call(&"bajar")
	await get_tree().create_timer(1.3).timeout
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
