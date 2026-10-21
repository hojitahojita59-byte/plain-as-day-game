extends Control
## Hoja del registro en la rectoría: asentar muertes en el plano y cercar el racimo.

## Emitida al bajar la hoja (la rectoría sigue detrás).
signal bajar

const PAPEL_SHADER := preload("res://materials/papel.gdshader")
const PLANO := preload("res://scripts/ui/plano_parroquia.gd")
const BOTON_WHITEHEAD := preload("res://scripts/ui/boton_whitehead.gd")
const ASIENTOS := preload("res://scripts/asientos.gd")

const PRUEBA_RACIMO := "broad_street_racimo"

## Se marca al clavar los 5 primeros del libro; abre el 40 y Cambridge St.
const YA_COPIADO := "parish_book_read"

const ENTERRADA := "buried_frances_lewis"

## Asientos mínimos para trazar el cerco.
const SUFICIENTES := 20

## Nivel de miasma tras cercar el racimo.
const MIASMA_TRAS_EL_RACIMO := 0.84

signal racimo_cercado(cuantos: int)

const GARAMOND := preload("res://art/fonts/EB_Garamond/static/EBGaramond-Regular.ttf")
const GARAMOND_SEMI := preload("res://art/fonts/EB_Garamond/static/EBGaramond-SemiBold.ttf")
const GARAMOND_NOTA := preload("res://art/fonts/EB_Garamond/static/EBGaramond-Regular.ttf")

const PAPEL := Color(0.87, 0.83, 0.73)
const PAPEL_BORDE := Color(0.44, 0.37, 0.28)
const TINTA := Color(0.14, 0.11, 0.08)
const TINTA_SUAVE := Color(0.38, 0.31, 0.24)
const TINTA_PALIDA := Color(0.52, 0.45, 0.37)
const T_CUERPO := 24

var _libro: VBoxContainer
var _cuaderno: VBoxContainer
var _plano: Control
var _voz: Label
## Apunte cogido, esperando sitio en el plano.
var _en_la_mano: Dictionary = {}
var _pluma: AudioStreamPlayer


func _ready() -> void:
	HUD.show()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_construir()
	_refrescar()


## Asientos del libro aún sin poner en el plano.
func _del_libro() -> Array[Dictionary]:
	return ASIENTOS.primera_tanda()


## Segunda tanda del libro (tras el entierro); se copia de golpe.
func _lista_del_sacriston() -> Array[Dictionary]:
	return ASIENTOS.segunda_tanda()


## Libro + muertes de fichas selladas aún sin asentar.
func _por_clavar() -> Array[Dictionary]:
	var out := _del_libro()
	out.append_array(ASIENTOS.de_la_calle())
	return out


func _marcar_libro_leido() -> void:
	ASIENTOS.marcar_libro_leido()


func _construir() -> void:
	var fondo := ColorRect.new()
	# Semitransparente: la rectoría se sigue viendo detrás.
	fondo.color = Color(0.05, 0.04, 0.04, 0.62)
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)

	var margen := MarginContainer.new()
	margen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margen.add_theme_constant_override("margin_left", 70)
	margen.add_theme_constant_override("margin_right", 70)
	margen.add_theme_constant_override("margin_top", 48)
	margen.add_theme_constant_override("margin_bottom", 48)
	add_child(margen)

	var hoja := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = PAPEL
	sb.border_color = PAPEL_BORDE
	sb.set_border_width_all(2)
	sb.set_content_margin_all(42)
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size = 22
	hoja.add_theme_stylebox_override("panel", sb)
	var gastado := ShaderMaterial.new()
	gastado.shader = PAPEL_SHADER
	gastado.set_shader_parameter("manchas", 0.26)
	gastado.set_shader_parameter("bordes", 0.34)
	gastado.set_shader_parameter("fibra", 0.05)
	hoja.material = gastado
	margen.add_child(hoja)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	hoja.add_child(col)

	var cabecera := HBoxContainer.new()
	var abajo := _boton("↓  Set it down", 22)
	abajo.pressed.connect(func(): bajar.emit())
	cabecera.add_child(abajo)
	var hueco := Control.new()
	hueco.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cabecera.add_child(hueco)
	cabecera.add_child(_texto("The rectory  ·  " + (
		"Saturday, after the burial" if GameState.has_flag(ENTERRADA) else "Friday, before dawn"),
		TINTA_SUAVE, 22, GARAMOND_NOTA))
	# Hueco para el maletín del HUD.
	var reserva := Control.new()
	reserva.custom_minimum_size = Vector2(140, 0)
	cabecera.add_child(reserva)
	col.add_child(cabecera)
	col.add_child(_raya())

	var dos := HBoxContainer.new()
	dos.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dos.add_theme_constant_override("separation", 40)
	col.add_child(dos)

	# Izquierda: libro y pendientes
	var izq := VBoxContainer.new()
	izq.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	izq.size_flags_stretch_ratio = 1.05
	izq.add_theme_constant_override("separation", 12)
	dos.add_child(izq)

	izq.add_child(_texto("REGISTERED", TINTA_SUAVE, 21, GARAMOND_SEMI))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	izq.add_child(scroll)
	_libro = VBoxContainer.new()
	_libro.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_libro.add_theme_constant_override("separation", 7)
	scroll.add_child(_libro)

	izq.add_child(_raya())
	izq.add_child(_texto("TO ADD", TINTA_SUAVE, 21, GARAMOND_SEMI))
	var scroll_pendientes := ScrollContainer.new()
	scroll_pendientes.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_pendientes.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	izq.add_child(scroll_pendientes)
	_cuaderno = VBoxContainer.new()
	_cuaderno.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cuaderno.add_theme_constant_override("separation", 9)
	scroll_pendientes.add_child(_cuaderno)

	# Derecha: plano
	var der := VBoxContainer.new()
	der.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	der.size_flags_stretch_ratio = 1.35
	der.add_theme_constant_override("separation", 12)
	dos.add_child(der)

	der.add_child(_texto("MAP OF THE PARISH", TINTA_SUAVE, 21, GARAMOND_SEMI))
	_plano = PLANO.new()
	_plano.fuente = GARAMOND_NOTA
	_plano.sitio_elegido.connect(_al_clavar)
	_plano.circulo_trazado.connect(_al_trazar)
	_plano.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_plano.custom_minimum_size = Vector2(0, 380)
	der.add_child(_plano)

	col.add_child(_raya())

	var pie := HBoxContainer.new()
	pie.add_theme_constant_override("separation", 24)
	_voz = _texto("", TINTA, T_CUERPO, GARAMOND_NOTA)
	_voz.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_voz.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pie.add_child(_voz)

	col.add_child(pie)

	_boton_de_salir()


func _refrescar() -> void:
	for h in _libro.get_children():
		_libro.remove_child(h)
		h.queue_free()
	for h in _cuaderno.get_children():
		_cuaderno.remove_child(h)
		h.queue_free()

	var asientos := Casefile.records()
	for a in asientos:
		_libro.add_child(_texto("%s   ·   %s   ·   %s" % [
			String(a.get("nombre", "")),
			String(a.get("calle", "")),
			String(a.get("dia", ""))], TINTA, 21, GARAMOND))

	var pendientes := _por_clavar()
	for n in pendientes:
		_cuaderno.add_child(_pendiente(n))
	var lista := _lista_del_sacriston()
	if not lista.is_empty():
		var copiar := _boton("The sexton's list: %d names. Copy them all in." % lista.size(), 21)
		copiar.add_theme_color_override("font_color", TINTA)
		copiar.pressed.connect(_copiar_la_lista)
		_cuaderno.add_child(copiar)
		if pendientes.is_empty() and _en_la_mano.is_empty():
			_palpitar(copiar)
	# Palpita el primero mientras no hay nada en la mano.
	if not pendientes.is_empty() and _en_la_mano.is_empty():
		_palpitar(_cuaderno.get_child(0) as Control)
	if pendientes.is_empty() and lista.is_empty():
		_cuaderno.add_child(_texto("Nothing waiting.", TINTA_PALIDA, 21, GARAMOND_NOTA))
		if not _en_la_mano.is_empty():
			_en_la_mano = {}
			_plano.colocar(false)

	_plano.poner(asientos)
	if Casefile.has(PRUEBA_RACIMO):
		_plano.cercar()
	_voz.text = _lo_que_piensa(asientos.size())


## Fila de un apunte pendiente; clic = cogerlo.
func _pendiente(n: Dictionary) -> Control:
	var b := Button.new()
	b.flat = true
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.text = "%s   ·   %s" % [
		String(n.get("nombre", n.get("que", ""))),
		String(n.get("calle", ""))]
	b.add_theme_font_override("font", GARAMOND)
	b.add_theme_font_size_override("font_size", 21)
	b.add_theme_color_override("font_color", TINTA)
	b.add_theme_color_override("font_hover_color", TINTA_SUAVE)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.pressed.connect(_coger.bind(n))
	if _en_la_mano.get("id", "") == n.get("id", ""):
		b.text = "→  " + b.text
		b.add_theme_color_override("font_color", TINTA)
		b.add_theme_font_override("font", GARAMOND_SEMI)
	return b


func _palpitar(c: Control) -> void:
	if c == null:
		return
	var t := c.create_tween().set_loops()
	t.tween_property(c, "modulate:a", 0.45, 0.7).set_trans(Tween.TRANS_SINE)
	t.tween_property(c, "modulate:a", 1.0, 0.7).set_trans(Tween.TRANS_SINE)


## Coge/suelta un apunte y pone el plano en modo clavar.
func _coger(n: Dictionary) -> void:
	if _en_la_mano.get("id", "") == n.get("id", ""):
		_en_la_mano = {}
	else:
		_en_la_mano = n
	_plano.colocar(not _en_la_mano.is_empty(),
		PLANO.punto_de_asiento(_en_la_mano) if not _en_la_mano.is_empty() else Vector2.INF)
	_refrescar()


## Clic en el plano: acepta si cae cerca del sitio real; fallar no penaliza.
func _al_clavar(donde: Vector2) -> void:
	if _en_la_mano.is_empty():
		return
	var verdadero := PLANO.punto_de_asiento(_en_la_mano)
	if verdadero == Vector2.INF:
		push_warning("Escritorio: el asiento '%s' no tiene sitio en el plano." % _en_la_mano.get("id", "?"))
		return
	var fallo: String = _plano.juzgar(String(_en_la_mano.get("calle", "")), donde, verdadero)
	if not fallo.is_empty():
		_voz.text = fallo
		return

	var puesto := _en_la_mano
	_en_la_mano = {}
	_plano.colocar(false)
	Casefile.record(puesto)
	_marcar_libro_leido()
	_plano.celebrar(verdadero)
	_sonar_pluma()
	_refrescar()
	_cercar_si_toca()


## Indicación de la hoja según el estado.
func _lo_que_piensa(cuantos: int) -> String:
	if not _en_la_mano.is_empty():
		return "Find %s on the map and click there. The small numbers along each street are house numbers." \
			% String(_en_la_mano.get("calle", "the house"))
	if _plano != null and _plano.trazando():
		return "%d deaths on the map. Draw a circle round the place where most of them are: press on the map and drag." % cuantos
	if Casefile.has(PRUEBA_RACIMO):
		return "%d deaths on the map." % cuantos
	if not _por_clavar().is_empty():
		if cuantos == 0:
			return "Click a name under To add."
		return "%d deaths on the map. Click the next name under To add." % cuantos
	if not _lista_del_sacriston().is_empty():
		return "%d deaths on the map. The sexton has sent his list of the dead. Copy it in." % cuantos
	return "%d deaths on the map." % cuantos


## Activa el trazado del cerco cuando ya no queda nada por asentar.
func _cercar_si_toca() -> void:
	if Casefile.has(PRUEBA_RACIMO):
		return
	if not GameState.has_flag(ENTERRADA):
		return
	if Casefile.record_count() < SUFICIENTES:
		return
	if _quedan_pendientes():
		return

	if not _plano.trazando():
		_plano.trazar(true)
		_voz.text = _lo_que_piensa(Casefile.record_count())


## Valida el círculo: no muy ancho (radio.x <= 0.24) y >= 70% de puntos dentro.
func _al_trazar(centro: Vector2, radio: Vector2) -> void:
	var total: int = _plano.puntos().size()
	var dentro: int = _plano.dentro(centro, radio)
	if radio.x > 0.24:
		_voz.text = "That circle takes in most of the parish. Draw it tighter, round the place where they crowd together."
		return
	if total == 0 or float(dentro) / float(total) < 0.7:
		_voz.text = "%d of %d deaths are inside it. Most of them are outside. Try again." % [dentro, total]
		return
	_plano.trazar(false)
	Cuaderno.poner_circulo(centro, radio)
	_sonar_pluma()
	await get_tree().create_timer(0.7).timeout
	Casefile.collect(PRUEBA_RACIMO)
	GameState.set_flag("saw_the_cluster")
	_refrescar()
	_voz.text = "%d of %d deaths inside the circle." % [dentro, total]
	await get_tree().create_timer(2.0).timeout
	GameState.set_miasma(MIASMA_TRAS_EL_RACIMO)
	racimo_cercado.emit(Casefile.record_count())


func _quedan_pendientes() -> bool:
	return not _por_clavar().is_empty() or not _lista_del_sacriston().is_empty()


## Copia la lista del sacristán punto a punto.
var _copiando: bool = false

func _copiar_la_lista() -> void:
	if _copiando:
		return
	_copiando = true
	for a in _lista_del_sacriston():
		Casefile.record(a)
		_plano.poner(Casefile.records())
		_plano.celebrar(PLANO.punto_de_asiento(a))
		_sonar_pluma()
		await get_tree().create_timer(0.16).timeout
	_copiando = false
	_marcar_libro_leido()
	_refrescar()
	_cercar_si_toca()


# --- Utilidades ---

func _texto(t: String, color: Color, tam: int, f: Font) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_override("font", f)
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", color)
	return l


func _boton(t: String, tam: int) -> Button:
	var b := Button.new()
	b.text = t
	b.flat = true
	b.add_theme_font_override("font", GARAMOND_SEMI)
	b.add_theme_font_size_override("font_size", tam)
	b.add_theme_color_override("font_color", TINTA_SUAVE)
	b.add_theme_color_override("font_hover_color", TINTA)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return b


func _raya() -> Control:
	var p := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = PAPEL_BORDE
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size = Vector2(0, 1)
	return p


## Sonido de clavar, con el tono algo variado.
func _sonar_pluma() -> void:
	if _pluma == null:
		_pluma = AudioStreamPlayer.new()
		_pluma.bus = &"Interfaz"
		_pluma.stream = load("res://audio/sfx/ui/elegir.wav")
		add_child(_pluma)
	_pluma.pitch_scale = randf_range(0.94, 1.08)
	_pluma.play()


## Botón "salir a la calle", fuera de la hoja.
func _boton_de_salir() -> void:
	var b := BOTON_WHITEHEAD.crear("Out to the street")
	b.pressed.connect(func(): Barrio.volver())
	add_child(b)
	BOTON_WHITEHEAD.a_la_esquina(b)
