extends CanvasLayer
## Vista de pájaro (M): la cámara sube de la calle a la maqueta.
## Allí se asientan las muertes (las A_MANO primeras a mano) y se cerca el racimo.

const MAQUETA := preload("res://scripts/world/maqueta.gd")
const PLANO := preload("res://scripts/ui/plano_parroquia.gd")
const ASIENTOS := preload("res://scripts/asientos.gd")
const GARAMOND := preload("res://art/fonts/EB_Garamond/static/EBGaramond-Regular.ttf")
const GARAMOND_SEMI := preload("res://art/fonts/EB_Garamond/static/EBGaramond-SemiBold.ttf")
const SON_MARCA := preload("res://audio/sfx/ui/elegir.wav")
const SON_SUBIR := preload("res://audio/sfx/ui/pasar.wav")
const SON_AGUA := preload("res://audio/sfx/goteo.wav")

const A_MANO := 3
## Cerco válido: radio máx. (plano) y fracción mínima de muertes dentro.
const RADIO_MAX := 0.24
const DENTRO_MIN := 0.7

## Encuadre por defecto de la maqueta.
const FOCO := Vector3(0.0, 0.0, -14.0)
const DESDE := Vector3(0.0, 168.0, 70.0)

signal subida
signal bajada
signal racimo_cercado(cuantos: int)

var activa: bool = false
var _ocupada: bool = false

var _contenedor: SubViewportContainer
var _vista: SubViewport
var _maqueta: Node3D
var _cam: Camera3D
var _niebla: ColorRect
var _ui: Control
var _indicacion: Label
var _voz: Label
var _tira: HFlowContainer
var _boton_mapa: Button
var _boton_bajar: Button
var _punto: Control
var _son: AudioStreamPlayer

var _cam_calle: Camera3D
var _cam_calle_xf: Transform3D
var _foco: Vector3 = FOCO
var _zoom: float = 1.0
var _arrastrando_vista: bool = false

var _en_la_mano: Dictionary = {}
var _cayendo: bool = false
var _trazando: bool = false
var _arrastre: bool = false
var _centro: Vector2 = Vector2.ZERO
var _radio: float = 0.0


func _ready() -> void:
	layer = 13
	_construir()


# --- Construcción ---

func _construir() -> void:
	_contenedor = SubViewportContainer.new()
	_contenedor.stretch = true
	_contenedor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_contenedor.mouse_filter = Control.MOUSE_FILTER_STOP
	_contenedor.visible = false
	_contenedor.gui_input.connect(_al_clicar_mapa)
	add_child(_contenedor)

	_vista = SubViewport.new()
	_vista.own_world_3d = true
	_vista.msaa_3d = Viewport.MSAA_2X
	_vista.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_contenedor.add_child(_vista)

	var entorno := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = MAQUETA.C_SUELO
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.58, 0.66)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	entorno.environment = env
	_vista.add_child(entorno)

	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-52.0, -38.0, 0.0)
	sol.light_color = Color(1.0, 0.92, 0.80)
	sol.light_energy = 1.15
	sol.shadow_enabled = true
	# El renderizador de la web (Compatibility) quema el blanco: menos luz.
	if RenderingServer.get_current_rendering_method() == "gl_compatibility":
		sol.light_energy = 0.62
		env.ambient_light_energy = 0.28
	_vista.add_child(sol)

	_maqueta = Node3D.new()
	_maqueta.name = "Maqueta"
	_maqueta.set_script(MAQUETA)
	_vista.add_child(_maqueta)

	_cam = Camera3D.new()
	_cam.fov = 45.0
	_cam.far = 900.0
	_vista.add_child(_cam)
	_encuadrar()

	_ui = Control.new()
	_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.visible = false
	add_child(_ui)

	_indicacion = _caja_gris()
	_ui.add_child(_indicacion)

	_voz = Label.new()
	_voz.add_theme_font_override("font", GARAMOND_SEMI)
	_voz.add_theme_font_size_override("font_size", 26)
	_voz.add_theme_color_override("font_color", Color.WHITE)
	_voz.add_theme_color_override("font_outline_color", Color.BLACK)
	_voz.add_theme_constant_override("outline_size", 8)
	_voz.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_voz.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_voz.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_voz.anchor_left = 0.15
	_voz.anchor_right = 0.85
	_voz.offset_left = 0
	_voz.offset_right = 0
	_voz.offset_top = -190
	_voz.offset_bottom = -120
	_voz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_voz)

	_tira = HFlowContainer.new()
	_tira.alignment = FlowContainer.ALIGNMENT_CENTER
	_tira.add_theme_constant_override("h_separation", 10)
	_tira.add_theme_constant_override("v_separation", 8)
	_tira.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_tira.anchor_left = 0.0
	_tira.anchor_right = 1.0
	_tira.anchor_top = 1.0
	_tira.anchor_bottom = 1.0
	_tira.offset_left = 30
	_tira.offset_right = -260
	_tira.offset_top = -96
	_tira.offset_bottom = -36
	_tira.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_tira)

	_boton_bajar = _boton("Back down  (M)")
	_boton_bajar.anchor_left = 1.0
	_boton_bajar.anchor_right = 1.0
	_boton_bajar.anchor_top = 1.0
	_boton_bajar.anchor_bottom = 1.0
	_boton_bajar.offset_left = -230
	_boton_bajar.offset_right = -30
	_boton_bajar.offset_top = -86
	_boton_bajar.offset_bottom = -36
	_boton_bajar.pressed.connect(bajar)
	_ui.add_child(_boton_bajar)

	_niebla = ColorRect.new()
	_niebla.color = Color(0.72, 0.74, 0.70, 0.0)
	_niebla.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_niebla.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_niebla)

	_boton_mapa = _boton("Map  (M)")
	_boton_mapa.anchor_top = 1.0
	_boton_mapa.anchor_bottom = 1.0
	_boton_mapa.offset_left = 30
	_boton_mapa.offset_right = 190
	_boton_mapa.offset_top = -86
	_boton_mapa.offset_bottom = -36
	_boton_mapa.pressed.connect(subir)
	add_child(_boton_mapa)
	# Punto verde: hay muertes por poner o toca el cerco.
	_punto = Control.new()
	_punto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_punto.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_punto.position = Vector2(-8, -10)
	_punto.size = Vector2(22, 22)
	_punto.pivot_offset = Vector2(11, 11)
	_punto.draw.connect(func():
		_punto.draw_circle(Vector2(11, 11), 10.0, Color(0.10, 0.30, 0.12))
		_punto.draw_circle(Vector2(11, 11), 8.0, Color(0.30, 0.80, 0.34)))
	_boton_mapa.add_child(_punto)

	_son = AudioStreamPlayer.new()
	_son.bus = &"Interfaz"
	add_child(_son)


func _boton(texto: String) -> Button:
	var b := Button.new()
	b.text = texto
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_override("font", GARAMOND_SEMI)
	b.add_theme_font_size_override("font_size", 21)
	for estado in ["normal", "hover", "pressed"]:
		var s := StyleBoxFlat.new()
		s.bg_color = Color(0.87, 0.83, 0.73) if estado != "hover" else Color(0.93, 0.89, 0.79)
		s.border_color = Color(0.44, 0.37, 0.28)
		s.set_border_width_all(2)
		s.set_corner_radius_all(4)
		s.content_margin_left = 16
		s.content_margin_right = 16
		b.add_theme_stylebox_override(estado, s)
	for c in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(c, Color(0.14, 0.11, 0.08))
	return b


## Recuadro gris de indicaciones, arriba al centro.
func _caja_gris() -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", GARAMOND)
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_color_override("font_color", Color(0.95, 0.95, 0.93))
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.22, 0.22, 0.23, 0.88)
	s.set_corner_radius_all(6)
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	l.add_theme_stylebox_override("normal", s)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.anchor_left = 0.2
	l.anchor_right = 0.8
	l.offset_top = 24
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


# --- Subir y bajar ---

func _se_puede() -> bool:
	return not activa and not _ocupada and not DoorMode.activo and not DoorMode.volviendo \
		and not DialogueRunner.active and not get_tree().paused and not _expediente_abierto()


func _expediente_abierto() -> bool:
	return HUD.has_method(&"_hay_expediente_abierto") and bool(HUD.call(&"_hay_expediente_abierto"))


func _process(_delta: float) -> void:
	_boton_mapa.visible = _se_puede()
	if _boton_mapa.visible:
		_punto.visible = not ASIENTOS.por_asentar().is_empty() or ASIENTOS.toca_cercar()
		if _punto.visible:
			_punto.scale = Vector2.ONE * (1.0 + 0.12 * sin(Time.get_ticks_msec() * 0.006))
	if activa and not _ocupada:
		_cam.global_position = _cam.global_position.lerp(_posicion_cam(), 0.18)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("vista_pajaro"):
		if activa:
			bajar()
		elif _se_puede():
			subir()
		else:
			return
		get_viewport().set_input_as_handled()
	elif activa and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pausa")):
		if _trazando and _arrastre:
			_arrastre = false
			_maqueta.anillo(Vector2.ZERO, 0.0)
		else:
			bajar()
		get_viewport().set_input_as_handled()


func subir() -> void:
	if not _se_puede():
		return
	activa = true
	_ocupada = true
	_niebla.mouse_filter = Control.MOUSE_FILTER_STOP
	_sonar(SON_SUBIR, -4.0)
	_cam_calle = get_viewport().get_camera_3d()
	var t := create_tween().set_parallel()
	if _cam_calle != null:
		_cam_calle_xf = _cam_calle.global_transform
		_cam_calle.set_physics_process(false)
		t.tween_property(_cam_calle, "global_position", _cam_calle.global_position + Vector3(0, 16, -3), 0.6) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		t.tween_property(_cam_calle, "rotation:x", deg_to_rad(-82.0), 0.6).set_trans(Tween.TRANS_SINE)
	t.tween_property(_niebla, "color:a", 1.0, 0.55).set_ease(Tween.EASE_IN)
	await t.finished

	_pintar_marcas()
	var yo := get_tree().get_first_node_in_group(&"jugador") as Node3D
	# En la rectoría no hay "You": sus coordenadas no son las de la calle.
	if yo != null and String(get_tree().current_scene.scene_file_path).contains("calle"):
		_maqueta.call(&"poner_jugador", yo.global_position)
	# Las líneas a las fuentes no se ven hasta el final del capítulo.
	var nuevas: Array[Dictionary] = []
	_maqueta.limpiar_estelas()
	if GameState.has_flag(POSTER):
		nuevas = _pintar_estelas()
	_maqueta.anillo(Vector2.ZERO, 0.0)
	_dibujar_cerco_guardado()
	_vista.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_contenedor.visible = true
	_ui.visible = true
	_foco = FOCO
	_zoom = 1.0
	# Sale de cerca y se aleja por la misma línea: no gira.
	_cam.global_position = _foco + (DESDE - FOCO) * 0.18
	_cam.look_at(_foco)
	var t2 := create_tween().set_parallel()
	t2.tween_property(_cam, "global_position", _posicion_cam(), 1.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t2.tween_property(_niebla, "color:a", 0.0, 0.7)
	await t2.finished
	# Arriba el ratón es de la maqueta; la niebla solo tapaba la subida.
	_niebla.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ocupada = false
	_esquina(false)
	subida.emit()
	_al_llegar()
	_dibujar_nuevas(nuevas)


func bajar() -> void:
	if not activa or _ocupada:
		return
	_ocupada = true
	_en_la_mano = {}
	_trazando = false
	_arrastre = false
	_niebla.mouse_filter = Control.MOUSE_FILTER_STOP
	var t := create_tween()
	t.tween_property(_niebla, "color:a", 1.0, 0.4)
	await t.finished
	_contenedor.visible = false
	_ui.visible = false
	_vista.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if is_instance_valid(_cam_calle):
		_cam_calle.global_transform = _cam_calle_xf
		_cam_calle.set_physics_process(true)
	var t2 := create_tween()
	t2.tween_property(_niebla, "color:a", 0.0, 0.5)
	await t2.finished
	_niebla.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_esquina(true)
	activa = false
	_ocupada = false
	bajada.emit()


func _posicion_cam() -> Vector3:
	return _foco + (DESDE - FOCO) * _zoom


func _encuadrar() -> void:
	_cam.position = _posicion_cam()
	_cam.look_at(_foco)


# --- Lo que hay que hacer arriba ---

func _pintar_marcas() -> void:
	_maqueta.limpiar_marcas()
	for a in Casefile.records():
		_maqueta.marcar(a, false)


## Pinta las estelas ya vistas; devuelve las nuevas (se dibujan al llegar).
func _pintar_estelas() -> Array[Dictionary]:
	_maqueta.limpiar_estelas()
	var nuevas: Array[Dictionary] = []
	for e in Cuaderno.estelas():
		if Cuaderno.estela_vista(e["id"]):
			_maqueta.estela(e, false)
		else:
			nuevas.append(e)
	_maqueta.contar_en_fuentes(_ya_vistas())
	return nuevas


func _ya_vistas() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e in Cuaderno.estelas():
		if Cuaderno.estela_vista(e["id"]):
			out.append(e)
	return out


func _dibujar_nuevas(nuevas: Array[Dictionary]) -> void:
	for e in nuevas:
		if not activa or _en_final:
			return
		Cuaderno.ver_estela(e["id"])
		_maqueta.estela(e, true)
		_sonar(SON_AGUA, -8.0, randf_range(0.9, 1.05))
		await get_tree().create_timer(2.3).timeout
		_maqueta.contar_en_fuentes(_ya_vistas())


func _dibujar_cerco_guardado() -> void:
	var c := Cuaderno.circulo()
	if c.size() == 4 and Casefile.has(ASIENTOS.PRUEBA_RACIMO):
		_maqueta.anillo(Vector2(float(c[0]), float(c[1])), float(c[2]))


func _al_llegar() -> void:
	_rehacer_tira()
	var pend := ASIENTOS.por_asentar()
	if not pend.is_empty():
		if Casefile.record_count() >= A_MANO:
			_caer_solas(pend)
		else:
			_indicar("Click a name at the bottom, then click that house on the map.")
		return
	if ASIENTOS.toca_cercar():
		_empezar_cerco()
		return
	var n := Casefile.record_count()
	if n == 0:
		_indicar("No deaths on the map yet. Find out who has died, and fill in their card.")
	elif Casefile.has(ASIENTOS.PRUEBA_RACIMO):
		_indicar("%d deaths on the map." % n)
	else:
		_indicar("%d deaths on the map." % n)


func _indicar(texto: String) -> void:
	_indicacion.text = texto


func _decir(texto: String) -> void:
	_voz.text = texto
	_voz.modulate.a = 1.0
	var t := _voz.create_tween()
	t.tween_interval(3.5)
	t.tween_property(_voz, "modulate:a", 0.0, 0.8)


func _rehacer_tira() -> void:
	for n in _tira.get_children():
		n.queue_free()
	if Casefile.record_count() >= A_MANO:
		return
	for a in ASIENTOS.por_asentar():
		var b := _boton("%s  ·  %s" % [String(a.get("nombre", "?")), String(a.get("calle", "?"))])
		# Nombres del libro: más grandes y con más contraste, se leen mal pequeños.
		b.add_theme_font_size_override("font_size", 25)
		b.toggle_mode = true
		b.button_pressed = String(_en_la_mano.get("id", "")) == String(a.get("id", ""))
		b.set_meta(&"asiento", String(a.get("id", "")))
		b.pressed.connect(_coger.bind(a))
		b.mouse_filter = Control.MOUSE_FILTER_STOP
		_tira.add_child(b)


func _coger(a: Dictionary) -> void:
	if String(_en_la_mano.get("id", "")) == String(a.get("id", "")):
		_en_la_mano = {}
		_indicar("Click a name at the bottom, then click that house on the map.")
	else:
		_en_la_mano = a
		_indicar("Find %s and click the house. The small numbers along each street are house numbers." \
			% String(a.get("calle", "the house")))
	_contenedor.mouse_default_cursor_shape = Control.CURSOR_CROSS if not _en_la_mano.is_empty() \
		else Control.CURSOR_ARROW
	_maqueta.cursor(Vector2.INF)
	_rehacer_tira()


## Las que quedan caen solas, una tras otra.
func _caer_solas(lista: Array[Dictionary]) -> void:
	if _cayendo:
		return
	_cayendo = true
	var hay := Casefile.record_count()
	_indicar("%d deaths on the map." % hay)
	for a in lista:
		if not activa:
			break
		Casefile.record(a)
		_maqueta.marcar(a, true)
		hay += 1
		_indicar("%d deaths on the map." % hay)
		await get_tree().create_timer(0.3).timeout
		_sonar(SON_MARCA, -6.0, randf_range(0.9, 1.1))
		await get_tree().create_timer(0.12).timeout
	ASIENTOS.marcar_libro_leido()
	_cayendo = false
	if activa:
		_al_llegar()


func _asentar(a: Dictionary) -> void:
	Casefile.record(a)
	ASIENTOS.marcar_libro_leido()
	_maqueta.marcar(a, true)
	_en_la_mano = {}
	_contenedor.mouse_default_cursor_shape = Control.CURSOR_ARROW
	_maqueta.cursor(Vector2.INF)
	await get_tree().create_timer(0.3).timeout
	_sonar(SON_MARCA, -5.0)
	_al_llegar()


# --- Ratón sobre la maqueta ---

## Punto del plano bajo el ratón (suelo y = 0), o INF.
func plano_bajo(pos: Vector2) -> Vector2:
	var o := _cam.project_ray_origin(pos)
	var d := _cam.project_ray_normal(pos)
	if absf(d.y) < 0.0001:
		return Vector2.INF
	var t := -o.y / d.y
	if t < 0.0:
		return Vector2.INF
	return MAQUETA.a_plano(o + d * t)


## Píxel de pantalla de un punto del plano (para pruebas).
func pantalla_de(p: Vector2, alto: float = 0.0) -> Vector2:
	return _cam.unproject_position(MAQUETA.a_mundo(p, alto))


func _al_clicar_mapa(event: InputEvent) -> void:
	if not activa or _ocupada:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if mb.pressed:
				_acercar(mb.position, 0.88 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 0.88)
			return
		if mb.button_index == MOUSE_BUTTON_RIGHT or mb.button_index == MOUSE_BUTTON_MIDDLE:
			_arrastrando_vista = mb.pressed
			return
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		var p := plano_bajo(mb.position)
		if p == Vector2.INF:
			return
		if _trazando:
			if mb.pressed:
				_arrastre = true
				_centro = p
				_radio = 0.0
			elif _arrastre:
				_arrastre = false
				_radio = p.distance_to(_centro)
				_juzgar_cerco()
			return
		if mb.pressed and not _en_la_mano.is_empty():
			_clavar(p)
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _arrastrando_vista:
			var escala := _posicion_cam().distance_to(_foco) * 0.0012
			_foco -= Vector3(mm.relative.x, 0.0, mm.relative.y) * escala
			_foco.x = clampf(_foco.x, -75.0, 75.0)
			_foco.z = clampf(_foco.z, -65.0, 35.0)
		elif not _en_la_mano.is_empty():
			_maqueta.cursor(plano_bajo(mm.position))
		elif _trazando and _arrastre:
			var p := plano_bajo(mm.position)
			if p != Vector2.INF:
				_radio = p.distance_to(_centro)
				_maqueta.anillo(_centro, _radio)


func _acercar(pos: Vector2, factor: float) -> void:
	var antes := _zoom
	_zoom = clampf(_zoom * factor, 0.3, 1.0)
	var p := plano_bajo(pos)
	if p != Vector2.INF and not is_equal_approx(antes, _zoom):
		var bajo := MAQUETA.a_mundo(p)
		_foco += (bajo - _foco) * (1.0 - _zoom / antes)
	if is_equal_approx(_zoom, 1.0):
		_foco = FOCO


## Clic con un nombre en la mano: vale si cae en su casa; si no, una pista.
func clavar_en(p: Vector2) -> void:
	_clavar(p)


func _clavar(p: Vector2) -> void:
	var verdadero := PLANO.punto_de_asiento(_en_la_mano)
	if verdadero == Vector2.INF:
		return
	var fallo := PLANO.juzgar(String(_en_la_mano.get("calle", "")), p, verdadero, MAQUETA.margen_de_clic())
	if not fallo.is_empty():
		_decir(fallo)
		return
	_asentar(_en_la_mano)


# --- El cerco ---

func _empezar_cerco() -> void:
	_trazando = true
	_contenedor.mouse_default_cursor_shape = Control.CURSOR_CROSS
	_indicar("%d deaths on the map. Press on the map and drag a circle round the place where most of them are." \
		% Casefile.record_count())


func cercar(centro: Vector2, radio: float) -> void:
	_centro = centro
	_radio = radio
	_juzgar_cerco()


func _juzgar_cerco() -> void:
	_maqueta.anillo(_centro, _radio)
	var total := 0
	var dentro := 0
	for a in Casefile.records():
		var p := PLANO.punto_de_asiento(a)
		if p == Vector2.INF:
			continue
		total += 1
		if p.distance_to(_centro) <= _radio:
			dentro += 1
	if _radio > RADIO_MAX:
		_decir("That circle takes in most of the parish. Draw it tighter, round the place where they crowd together.")
		return
	if total == 0 or float(dentro) / float(total) < DENTRO_MIN:
		_decir("%d of %d deaths are inside it. Most of them are outside. Try again." % [dentro, total])
		return
	_trazando = false
	_contenedor.mouse_default_cursor_shape = Control.CURSOR_ARROW
	Cuaderno.poner_circulo(_centro, Vector2(_radio, _radio))
	_sonar(SON_MARCA, -4.0, 0.8)
	Casefile.collect(ASIENTOS.PRUEBA_RACIMO)
	GameState.set_flag("saw_the_cluster")
	_maqueta.anillo_dorado()
	_decir("%d of %d deaths inside the circle." % [dentro, total])
	_indicar("%d deaths on the map." % total)
	racimo_cercado.emit(total)
	await get_tree().create_timer(2.0).timeout
	GameState.set_miasma(ASIENTOS.MIASMA_TRAS_EL_RACIMO)


# --- El final del acto ---

const POSTER := "poster_visto"
var _en_final: bool = false

## Sube sola, todas las estelas laten hacia sus fuentes y la cámara se acerca a la bomba.
func final() -> void:
	if not activa:
		await subir()
	_ocupada = true
	_en_final = true
	_indicacion.visible = false
	_tira.visible = false
	_boton_bajar.visible = false
	for e in Cuaderno.estelas():
		Cuaderno.ver_estela(e["id"])
	_maqueta.limpiar_estelas()
	var mallas: Array[MeshInstance3D] = []
	for e in Cuaderno.estelas():
		mallas.append(_maqueta.estela(e, true, 3.2))
	_maqueta.contar_en_fuentes(Cuaderno.estelas())
	var campana := AudioStreamPlayer.new()
	campana.stream = preload("res://scripts/campana.gd").sonido()
	campana.volume_db = -8.0
	add_child(campana)
	campana.play()
	var bomba := MAQUETA.a_mundo(PLANO.BOMBA)
	var t := create_tween().set_parallel()
	t.tween_property(self, "_zoom", 0.8, 6.0).set_trans(Tween.TRANS_SINE)
	t.tween_property(self, "_foco", bomba, 6.0).set_trans(Tween.TRANS_SINE)
	t.tween_method(func(v: float):
		_cam.global_position = _posicion_cam(), 0.0, 1.0, 6.0)
	await get_tree().create_timer(3.4).timeout
	for m in mallas:
		var mat := m.material_override as ShaderMaterial
		var latido := m.create_tween().set_loops(3)
		latido.tween_method(func(v: float): mat.set_shader_parameter(&"energia", v), 1.4, 3.2, 0.45)
		latido.tween_method(func(v: float): mat.set_shader_parameter(&"energia", v), 3.2, 1.4, 0.45)
	await t.finished
	GameState.set_flag(POSTER)
	var negro := create_tween()
	negro.tween_property(_niebla, "color", Color(0, 0, 0, 1), 1.4)
	await negro.finished


# --- Utilidades ---

## La línea de la esquina del HUD repite el recuadro gris: arriba se oculta.
func _esquina(si: bool) -> void:
	var e: Variant = HUD.get(&"_esquina")
	if e is CanvasItem:
		(e as CanvasItem).visible = si


func _sonar(stream: AudioStream, db: float, tono: float = 1.0) -> void:
	_son.stream = stream
	_son.volume_db = db
	_son.pitch_scale = tono
	_son.play()


static func _muertes(n: int) -> String:
	return "1 death" if n == 1 else "%d deaths" % n


func maqueta() -> Node3D:
	return _maqueta
