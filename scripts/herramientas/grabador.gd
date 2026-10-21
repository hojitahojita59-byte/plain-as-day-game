extends Node
## Clips para el tráiler con Movie Maker. Copia y devuelve la partida guardada.
## Uso: --write-movie <salida.avi> --fixed-fps 30 grabador.tscn -- <modo> [rotulos.json]
## rotulos.json: [{"de": s, "a": s, "texto": "...", "tipo": "titulo" | "pie", "pos": "arriba" | "abajo"}]

const ASIENTOS := preload("res://scripts/asientos.gd")
const LLEGADA := preload("res://scripts/world/llegada_a_casa.gd")
const PLANO := preload("res://scripts/ui/plano_parroquia.gd")
const CALLE := "res://scenes/world/calle.tscn"
const GARAMOND := preload("res://art/fonts/EB_Garamond/static/EBGaramond-Regular.ttf")
const GARAMOND_SEMI := preload("res://art/fonts/EB_Garamond/static/EBGaramond-SemiBold.ttf")

var _t: float = 0.0
var _copia: Variant = null
var _escena: Node
var _cam: Camera3D


func _ready() -> void:
	if FileAccess.file_exists(SaveSystem.SAVE_PATH):
		_copia = FileAccess.get_file_as_bytes(SaveSystem.SAVE_PATH)
	SaveSystem.set(&"_pendiente", true)
	GameState.reset()
	Casefile.reset()
	Cuaderno.reset()
	# La raíz aún monta sus hijos: la escena va un fotograma después.
	await get_tree().process_frame
	var args := OS.get_cmdline_user_args()
	if args.size() > 1:
		_rotulos(String(args[1]))
	await call("_" + args[0])
	get_tree().quit()


func _exit_tree() -> void:
	if _copia != null:
		FileAccess.open(SaveSystem.SAVE_PATH, FileAccess.WRITE).store_buffer(_copia)


func _process(delta: float) -> void:
	_t += delta


func _esperar(s: float) -> void:
	var fin := _t + s
	while _t < fin:
		await get_tree().process_frame


## La escena pasa a ser la actual; el grabador sigue en la raíz aunque cambie.
func _montar(ruta: String) -> Node:
	_escena = (load(ruta) as PackedScene).instantiate()
	get_tree().root.add_child(_escena)
	get_tree().current_scene = _escena
	return _escena


func _sin_interfaz() -> void:
	HUD.hide()
	for c in get_tree().root.find_children("*", "CanvasLayer", true, false):
		if c != HUD and not c.get_parent() == HUD and not c.has_meta(&"rotulos"):
			(c as CanvasLayer).visible = false


func _camara_propia() -> void:
	_cam = Camera3D.new()
	_cam.fov = 55.0
	get_tree().root.add_child(_cam)
	_cam.current = true


## Mueve la cámara de A a B mirando de M1 a M2 en s segundos.
func _plano(a: Vector3, b: Vector3, m1: Vector3, m2: Vector3, s: float) -> void:
	var t0 := _t
	while _t - t0 < s:
		var k := smoothstep(0.0, 1.0, (_t - t0) / s)
		_cam.global_position = a.lerp(b, k)
		_cam.look_at(m1.lerp(m2, k))
		await get_tree().process_frame


func _banderas(dia: int, extra: Array = []) -> void:
	GameState.dia = dia
	for f in ["apertura_vista"] + extra:
		GameState.set_flag(f)
	if dia >= 2:
		GameState.set_flag("dia_2")
	if dia >= 3:
		GameState.set_flag("dia_3")


func _sellar_todo() -> void:
	for f in Cuaderno.todas_las_fichas():
		var id := String(f["id"])
		Cuaderno.abrir(id)
		var huecos: Dictionary = Dictionary(Cuaderno.ficha(id).get("huecos", {}))
		for h in huecos:
			Cuaderno.aprender(String(huecos[h]))
			Cuaderno.poner(id, String(h), String(huecos[h]))
		Cuaderno.comprobar(id)


## Pasa el diálogo cada `cada` segundos; en un nodo que vuelve, la opción siguiente.
func _conversar(cada: float, hasta: float) -> void:
	var vistas := {}
	var t0 := _t
	while DialogueRunner.active and _t - t0 < hasta:
		await _esperar(cada)
		if not DialogueRunner.active:
			return
		var nodo := DialogueRunner.nodo_actual()
		var opciones: Array = DialogueRunner._visible_choices(nodo)
		if nodo.has("pide"):
			for f in Dictionary(nodo["pide"].get("fichas", {})):
				if Cuaderno.sellada(String(f)):
					DialogueRunner.presentar(String(f))
					break
		elif opciones.is_empty():
			DialogueRunner.advance()
		else:
			var k := int(vistas.get(DialogueRunner._node_id, 0))
			vistas[DialogueRunner._node_id] = k + 1
			DialogueRunner.choose(k % opciones.size())


# --- Modos ---

func _menu() -> void:
	_montar("res://scenes/ui/menu_space.tscn")
	await _esperar(20.0)


## El ataúd sale del 38 y la mujer solloza.
func _apertura() -> void:
	# Las herramientas solo ven la apertura si la piden.
	GameState.set_flag("probar_apertura")
	_montar(CALLE)
	await _esperar(30.0)


## Planos de cine por Broad Street de noche, sin interfaz.
func _calle_cine() -> void:
	_banderas(2)
	_montar(CALLE)
	await _esperar(1.0)
	_sin_interfaz()
	_camara_propia()
	# travelling a la altura de los ojos por Broad Street
	await _plano(Vector3(-46, 1.7, 1.8), Vector3(-12, 1.7, 1.8), Vector3(-36, 1.6, -2.5), Vector3(-2, 1.6, -2.5), 10.0)
	# vuelta lenta a la bomba
	var t0 := _t
	while _t - t0 < 10.0:
		var a := 0.6 + (_t - t0) * 0.16
		_cam.global_position = Vector3(-3.0, 0.0, 0.6) + Vector3(sin(a) * 5.5, 1.6 + (_t - t0) * 0.15, cos(a) * 5.5)
		_cam.look_at(Vector3(-3.0, 1.4, 0.6))
		await get_tree().process_frame
	# contrapicado junto a las farolas, hacia el 38 y el 40
	await _plano(Vector3(-6, 0.4, 3.2), Vector3(6, 0.5, 3.2), Vector3(-6, 3.5, -4), Vector3(6, 3.5, -4), 8.0)
	# grúa que sube sobre Cambridge Street
	await _plano(Vector3(-15, 1.4, -6), Vector3(-15, 11, 2), Vector3(-15, 1.2, -26), Vector3(-15, 0, -30), 9.0)
	# grúa alta sobre los tejados de Broad Street
	await _plano(Vector3(-30, 16, 14), Vector3(25, 16, 14), Vector3(-25, 0, -4), Vector3(30, 0, -4), 10.0)


## Jugando: Whitehead anda al 38, llama y habla.
func _calle_juego() -> void:
	_banderas(1)
	_montar(CALLE)
	await _esperar(2.0)
	var yo := get_tree().get_first_node_in_group(&"jugador")
	var puerta: Node = null
	for n in _escena.find_children("*", "StaticBody3D", true, false):
		if str(n.get("dialogue_id")) == "ch1_s3_garment_woman":
			puerta = n
	if yo != null and puerta != null:
		yo.call(&"ir_a", puerta)
	while not (DoorMode.activo and not bool(DoorMode.get(&"_moviendo"))):
		await get_tree().process_frame
	await _esperar(1.5)
	# Llamar: un clic en la vista de puerta.
	await _clic(get_viewport().get_visible_rect().size * 0.5)
	while not DialogueRunner.active:
		await get_tree().process_frame
	await _conversar(3.0, 40.0)
	await _esperar(3.0)


func _clic(pos: Vector2) -> void:
	var m := InputEventMouseMotion.new()
	m.position = pos
	m.global_position = pos
	get_tree().root.push_input(m, true)
	await _esperar(0.25)
	for apretado in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = apretado
		ev.position = pos
		ev.global_position = pos
		get_tree().root.push_input(ev, true)
		await get_tree().process_frame


## La taberna de la cervecería: la sala, la barra y la charla.
func _cerveceria() -> void:
	_banderas(2)
	_montar("res://scenes/world/cerveceria.tscn")
	await _esperar(9.5)
	await _conversar(3.5, 30.0)


## Plano general de la taberna sin interfaz, con cámara propia.
func _cerveceria_cine() -> void:
	_banderas(2)
	_montar("res://scenes/world/cerveceria.tscn")
	await _esperar(0.5)
	_sin_interfaz()
	_camara_propia()
	await _plano(Vector3(-6.0, 1.3, 5.5), Vector3(-1.0, 1.5, 5.0), Vector3(2.5, 1.6, -4.5), Vector3(3.0, 1.8, -5.0), 9.0)
	await _plano(Vector3(6.6, 3.6, 3.6), Vector3(4.0, 2.6, -1.0), Vector3(-4.0, 1.0, -2.0), Vector3(-5.5, 1.6, -3.5), 9.0)
	await _plano(Vector3(0.8, 0.5, 2.4), Vector3(-1.2, 0.5, 2.6), Vector3(-2.7, 1.9, 0.7), Vector3(-2.7, 2.1, 0.7), 7.0)


## El entierro de Frances Lewis.
func _cementerio() -> void:
	_banderas(3)
	_montar("res://scenes/world/cementerio.tscn")
	await _esperar(37.0)


## El carro a Hampstead: esquiva solo y llega; luego la hija.
func _carroza() -> void:
	_banderas(3, ["sabe_de_hampstead"])
	_sellar_todo()
	_montar("res://scenes/world/camino.tscn")
	var t0 := _t
	while _t - t0 < 44.0:
		_piloto()
		await get_tree().process_frame
	Input.action_release(&"ui_left")
	Input.action_release(&"ui_right")
	while get_tree().current_scene == null or not String(get_tree().current_scene.scene_file_path).ends_with("hampstead.tscn"):
		await get_tree().process_frame
	await _esperar(9.0)
	await _conversar(3.5, 40.0)
	await _esperar(5.0)


## Esquiva lo que viene por su carril.
func _piloto() -> void:
	var camino := get_tree().current_scene
	if camino == null or not camino.has_method(&"_poner_obstaculo"):
		return
	var carro := camino.get(&"_carro") as Node3D
	var meta := 0.0
	var cerca := INF
	for o in camino.get(&"_obstaculos"):
		var n := o as Node3D
		if n.position.x > -22.0 and n.position.x < -1.0 and -n.position.x < cerca \
				and absf(n.position.z - carro.position.z) < 1.4:
			cerca = -n.position.x
			meta = clampf(n.position.z + (1.7 if carro.position.z >= n.position.z else -1.7), -2.0, 2.0)
	if cerca == INF:
		meta = carro.position.z
	var izquierda := meta > carro.position.z + 0.15
	var derecha := meta < carro.position.z - 0.15
	if izquierda: Input.action_press(&"ui_left")
	else: Input.action_release(&"ui_left")
	if derecha: Input.action_press(&"ui_right")
	else: Input.action_release(&"ui_right")


## La casa de Whitehead: la llegada y el recorrido de la cámara.
func _rectoria() -> void:
	_banderas(2)
	_montar("res://scenes/world/rectoria.tscn")
	await _esperar(16.0)


## Llama Snow: la puerta, el pomo y Snow ante el plano.
func _snow() -> void:
	_banderas(3, ["lista_1", "lista_3", ASIENTOS.ENTERRADA])
	_sellar_todo()
	for a in ASIENTOS.por_asentar():
		Casefile.record(a)
	Casefile.collect(ASIENTOS.PRUEBA_RACIMO)
	GameState.set_flag("saw_the_cluster")
	LLEGADA.ya_llegamos = true
	_montar("res://scenes/world/rectoria.tscn")
	var snow := _escena.get_node(^"Snow")
	while not bool(snow.get("_esperando_pomo")):
		await get_tree().process_frame
	await _esperar(1.0)
	snow.call(&"_resaltar_pomo", true)
	await _esperar(1.2)
	snow.call(&"abrir_la_puerta")
	while not DialogueRunner.active:
		await get_tree().process_frame
	await _conversar(3.6, 70.0)


## El mapa: las muertes caen, el círculo dorado y las líneas a la bomba.
func _mapa() -> void:
	_banderas(3, ["lista_1", "lista_3", ASIENTOS.ENTERRADA])
	_sellar_todo()
	var pend := ASIENTOS.por_asentar()
	for i in 3:
		Casefile.record(pend[i])
	_montar(CALLE)
	await _esperar(2.0)
	var vista := get_tree().get_first_node_in_group(&"vista_pajaro")
	vista.call(&"subir")
	await _esperar(14.0)
	vista.call(&"cercar", PLANO.BOMBA + Vector2(0.01, 0.0), 0.17)
	await _esperar(5.0)
	await vista.call(&"final")
	await _esperar(2.0)


# --- Rótulos del vídeo ---

## Título a pantalla llena sobre la imagen oscurecida, o pie de una línea.
func _rotulos(ruta: String) -> void:
	var lista: Variant = JSON.parse_string(FileAccess.get_file_as_string(ruta))
	if not (lista is Array):
		push_error("Grabador: no puedo leer " + ruta)
		return
	var capa := CanvasLayer.new()
	capa.layer = 120
	capa.set_meta(&"rotulos", true)
	add_child(capa)
	for r in lista:
		_rotulo(capa, Dictionary(r))


func _rotulo(capa: CanvasLayer, r: Dictionary) -> void:
	var de := float(r.get("de", 0.0))
	var a := float(r.get("a", de + 4.0))
	await _esperar(de - _t)
	var tipo := String(r.get("tipo", "pie"))
	# Velo y fundidos: solo un rectángulo que entra o sale.
	if tipo in ["velo", "negro_entra", "negro_sale"]:
		var c := ColorRect.new()
		c.color = Color(0.02, 0.03, 0.02, 0.62) if tipo == "velo" else Color.BLACK
		c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.modulate.a = 1.0 if tipo == "negro_entra" else 0.0
		capa.add_child(c)
		capa.move_child(c, 0)
		var f := c.create_tween()
		f.tween_property(c, "modulate:a", 0.0 if tipo == "negro_entra" else 1.0, float(r.get("dura", 0.6)))
		if tipo == "velo":
			await _esperar(a - de - 0.6)
			c.create_tween().tween_property(c, "modulate:a", 0.0, 0.6)
		return
	var titulo := tipo == "titulo"
	var raiz := Control.new()
	raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.modulate.a = 0.0
	capa.add_child(raiz)
	var l := Label.new()
	l.text = String(r.get("texto", ""))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_color_override("font_color", Color(0.97, 0.94, 0.86))
	l.add_theme_color_override("font_outline_color", Color(0.03, 0.03, 0.03))
	if titulo and bool(r.get("velo", true)):
		var velo := ColorRect.new()
		velo.color = Color(0.02, 0.03, 0.02, 0.72)
		velo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		velo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		raiz.add_child(velo)
	if titulo:
		l.add_theme_font_override("font", GARAMOND_SEMI if bool(r.get("grande", false)) else GARAMOND)
		l.add_theme_font_size_override("font_size", int(r.get("tam", 64)))
		l.add_theme_constant_override("line_spacing", 10)
		l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		l.offset_left = 220
		l.offset_right = -220
		raiz.add_child(l)
	else:
		var caja := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.03, 0.04, 0.03, 0.78)
		sb.set_corner_radius_all(10)
		sb.content_margin_left = 34
		sb.content_margin_right = 34
		sb.content_margin_top = 14
		sb.content_margin_bottom = 18
		caja.add_theme_stylebox_override("panel", sb)
		caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.add_theme_font_override("font", GARAMOND_SEMI)
		l.add_theme_font_size_override("font_size", int(r.get("tam", 44)))
		l.add_theme_constant_override("outline_size", 6)
		caja.add_child(l)
		raiz.add_child(caja)
		caja.anchor_left = 0.14
		caja.anchor_right = 0.86
		if String(r.get("pos", "abajo")) == "arriba":
			caja.anchor_top = 0.06
			caja.anchor_bottom = 0.06
			caja.grow_vertical = Control.GROW_DIRECTION_END
		else:
			caja.anchor_top = 0.9
			caja.anchor_bottom = 0.9
			caja.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var t := raiz.create_tween()
	t.tween_property(raiz, "modulate:a", 1.0, 0.45)
	await _esperar(maxf(0.5, a - de - 0.9))
	var fuera := raiz.create_tween()
	fuera.tween_property(raiz, "modulate:a", 0.0, 0.45)
	await fuera.finished
	raiz.queue_free()


## El cuaderno: rellenar la ficha del 39, una palabra mal en rojo, se corrige y se sella.
func _cuaderno() -> void:
	_banderas(1, ["hablado_ch1_s3_garment_woman", "hablado_ch1_s3_coal_woman", "hablado_ch1_s3_tailor"])
	for f in ["f_38", "f_39"]:
		Cuaderno.abrir(f)
		for w in Dictionary(Cuaderno.ficha(f).get("huecos", {})).values():
			Cuaderno.aprender(String(w), "a neighbour")
	for w in ["elizabeth_dunn", "jueves"]:
		Cuaderno.aprender(w, "the tailor")
	_montar(CALLE)
	await _esperar(2.0)
	HUD.alternar_expediente()
	await _esperar(1.0)
	var exp: Control = HUD.get("_expediente")
	var pagina: Control = exp.get("_pag_cuaderno")
	pagina.call(&"mostrar_ficha", "f_39")
	await _esperar(1.2)
	var huecos: Dictionary = Cuaderno.ficha("f_39").get("huecos", {})
	for h in Cuaderno.huecos_en_orden("f_39"):
		var w := String(huecos[h])
		if w == "viernes":
			w = "jueves"
		await _clic_meta(pagina, &"hueco", "f_39/" + h)
		await _esperar(0.5)
		await _clic_meta(pagina, &"palabra", w)
		await _esperar(0.9)
	await _esperar(2.5)
	for h in Cuaderno.huecos_en_orden("f_39"):
		if String(huecos[h]) == "viernes":
			await _clic_meta(pagina, &"hueco", "f_39/" + h)
			await _esperar(0.5)
			await _clic_meta(pagina, &"palabra", "viernes")
	await _esperar(4.0)


func _clic_meta(raiz: Node, clave: StringName, valor: String) -> void:
	for n in raiz.find_children("*", "Button", true, false):
		var b := n as Button
		if b.has_meta(clave) and String(b.get_meta(clave)) == valor and b.is_visible_in_tree():
			await _clic(b.get_global_rect().get_center())
			return
	push_warning("Grabador: no encuentro %s %s" % [clave, valor])
