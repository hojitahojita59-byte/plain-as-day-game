extends Node
## Fotos de Snow en la rectoría: llamada, pomo, puerta abierta y ante el plano.
## Copia y restaura la partida guardada. Uso: -- <carpeta>. Sin pantalla, la puerta se abre sola.

const RECTORIA := "res://scenes/world/rectoria.tscn"
const LLEGADA := preload("res://scripts/world/llegada_a_casa.gd")
const SNOW := preload("res://scripts/world/llaman_a_la_puerta.gd")
const ASIENTOS := preload("res://scripts/asientos.gd")

var _dir: String = ""
var _t0: float = 0.0


func _ready() -> void:
	_dir = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(_dir)
	var copia: Variant = null
	if FileAccess.file_exists(SaveSystem.SAVE_PATH):
		copia = FileAccess.get_file_as_bytes(SaveSystem.SAVE_PATH)
	SaveSystem.set(&"_pendiente", true)
	await _probar()
	if copia == null:
		SaveSystem.delete_save()
	else:
		FileAccess.open(SaveSystem.SAVE_PATH, FileAccess.WRITE).store_buffer(copia)
	GameState.reset()
	Casefile.reset()
	Cuaderno.reset()
	get_tree().quit()


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
	print("[snow] toca: ", SNOW.toca())
	LLEGADA.ya_llegamos = true
	var escena := (load(RECTORIA) as PackedScene).instantiate()
	add_child(escena)
	_t0 = _ahora()
	var snow := escena.get_node(^"Snow")
	for s in [2.4, 3.6, 4.6, 5.6]:
		await _hasta(s)
		await _foto("a%.1f" % s)
	while not bool(snow.get("_esperando_pomo")) and _ahora() - _t0 < 20.0:
		await get_tree().process_frame
	await get_tree().create_timer(0.5).timeout
	await _foto("b_pomo")
	var pomo := escena.find_child("Pomo", true, false) as Node3D
	var cam := get_viewport().get_camera_3d()
	var en_pantalla := cam.unproject_position(pomo.global_position)
	print("[snow] pomo en pantalla: ", en_pantalla, " clicable: ", snow.call(&"_pomo_bajo_el_raton", en_pantalla))
	snow.call(&"_resaltar_pomo", true)
	await _foto("b_pomo_encima")
	snow.call(&"_resaltar_pomo", false)
	if DisplayServer.get_name() != "headless":
		snow.call(&"abrir_la_puerta")
	await get_tree().create_timer(0.7).timeout
	await _foto("c_abre")
	while not DialogueRunner.active:
		await get_tree().process_frame
	await get_tree().create_timer(0.3).timeout
	await _foto("d_habla")
	# hasta el nodo del plano
	var vueltas := 0
	while DialogueRunner.active and String(_nodo().get("camara", "")) != "plano" and vueltas < 10:
		DialogueRunner.advance()
		vueltas += 1
		await get_tree().process_frame
	print("[snow] en el nodo del plano: ", String(_nodo().get("camara", "")) == "plano")
	var t := _ahora()
	for s in [1.0, 3.0, 5.0, 7.5, 10.0]:
		while _ahora() - t < s:
			await get_tree().process_frame
		await _foto("e_plano_%.1f" % s)
	var snow_n := escena.find_child("JohnSnow", true, false) as Node3D
	print("[snow] Snow en ", snow_n.global_position, " giro ", snow_n.get_child(0).rotation.y)


func _nodo() -> Dictionary:
	var nodos: Dictionary = DialogueRunner._current.get("nodos", {})
	return nodos.get(DialogueRunner._node_id, {})


func _ahora() -> float:
	return Time.get_ticks_msec() / 1000.0


func _hasta(s: float) -> void:
	while _ahora() - _t0 < s:
		await get_tree().process_frame


func _foto(nombre: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_dir.path_join(nombre + ".png"))
	print("[snow] foto ", nombre)


func _sellar(f: String) -> void:
	Cuaderno.abrir(f)
	var huecos: Dictionary = Dictionary(Cuaderno.ficha(f).get("huecos", {}))
	for h in huecos:
		Cuaderno.aprender(String(huecos[h]))
		Cuaderno.poner(f, String(h), String(huecos[h]))
	Cuaderno.comprobar(f)
