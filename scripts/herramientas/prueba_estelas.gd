extends Node
## Estelas: caminos continuos por calles hasta su fuente; se dibujan en calle y maqueta.
## Copia y restaura la partida guardada. Uso: --headless, o -- <carpeta> para fotos.

const CALLE := preload("res://scenes/world/calle.tscn")
const PLANO := preload("res://scripts/ui/plano_parroquia.gd")
const ESTELAS := preload("res://scripts/estelas.gd")

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
		print("[estelas] CADA MUERTE LLEVA SU AGUA POR LA CALLE HASTA SU FUENTE.")
	else:
		for f in _fallos:
			print("[estelas] ! " + f)
	get_tree().quit(0 if _fallos.is_empty() else 1)


func _ver(cond: bool, que: String) -> void:
	if not cond:
		_fallos.append(que)


func _probar() -> void:
	GameState.reset()
	Casefile.reset()
	Cuaderno.reset()
	var con_estela := 0
	for f in Cuaderno.todas_las_fichas():
		if f.has("estela"):
			con_estela += 1
			_sellar(String(f["id"]))
	var todas := Cuaderno.estelas()
	_ver(todas.size() == con_estela, "estelas %d de %d fichas" % [todas.size(), con_estela])

	var a_broad := 0
	for e in todas:
		var c := ESTELAS.camino(e["desde"], e["hasta"])
		_ver(c.size() >= 2, "%s: camino vacío" % e["id"])
		_ver(c[c.size() - 1].distance_to(e["hasta"]) < 0.001, "%s no acaba en su fuente" % e["id"])
		# Entre el primer y el último tramo, todo va por calle y en ángulo recto.
		for i in range(1, c.size() - 2):
			var a: Vector2 = c[i]
			var b: Vector2 = c[i + 1]
			_ver(absf(a.x - b.x) < 0.0005 or absf(a.y - b.y) < 0.0005, "%s: tramo en diagonal" % e["id"])
			_ver(not PLANO.calles_en((a + b) * 0.5, 0.0).is_empty(), "%s: tramo fuera de la calle" % e["id"])
		if e["clase"] == "muerte" and e["fuente"] == "broad":
			a_broad += 1
	print("[estelas] %d estelas, %d de muerte a la bomba de Broad Street" % [todas.size(), a_broad])

	var calle := CALLE.instantiate()
	add_child(calle)
	var jugador := calle.get_node_or_null(^"Whitehead") as Node3D
	if jugador != null:
		jugador.global_position = Vector3(2.0, 0.0, -1.0)
	await get_tree().create_timer(1.5).timeout
	var en_calle := get_tree().get_first_node_in_group(&"estelas_calle")
	_ver(en_calle != null, "sin estelas en la calle")
	if en_calle != null:
		var n := int(en_calle.call(&"dibujadas"))
		_ver(n == 5, "en la calle se dibujan %d, se esperaban 5" % n)
	await _foto("1_calle")

	# Desde arriba: todas vistas menos dos, que se dibujan al llegar.
	for e in todas.slice(0, todas.size() - 2):
		Cuaderno.ver_estela(e["id"])
	var vista := get_tree().get_first_node_in_group(&"vista_pajaro")
	vista.call(&"subir")
	await get_tree().create_timer(2.0 + 2.4 * 2 + 0.5).timeout
	var maqueta: Node3D = vista.call(&"maqueta")
	var arriba: int = maqueta.call(&"estelas_dibujadas").size()
	_ver(arriba == todas.size(), "arriba %d de %d" % [arriba, todas.size()])
	for e in todas:
		_ver(Cuaderno.estela_vista(e["id"]), "%s sin marcar como vista" % e["id"])
	await _foto("2_arriba")
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
