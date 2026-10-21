extends Control
## Expediente (TAB o maletín): cuaderno de fichas + fuentes con barras aire/caso.

const PAPEL_SHADER := preload("res://materials/papel.gdshader")
const CIERRE := preload("res://scripts/ui/cierre_libro.gd")
const CUADERNO := preload("res://scripts/ui/cuaderno_pagina.gd")
const HOJA_QUE_PASA := preload("res://scripts/ui/hoja_que_pasa.gd")

const GARAMOND := preload("res://art/fonts/EB_Garamond/static/EBGaramond-Regular.ttf")
const GARAMOND_SEMI := preload("res://art/fonts/EB_Garamond/static/EBGaramond-SemiBold.ttf")
const GARAMOND_NOTA := preload("res://art/fonts/EB_Garamond/static/EBGaramond-Regular.ttf")

const PAPEL := Color(0.87, 0.83, 0.73)
const PAPEL_BORDE := Color(0.44, 0.37, 0.28)
const TINTA := Color(0.14, 0.11, 0.08)
const TINTA_SUAVE := Color(0.38, 0.31, 0.24)
const TINTA_PALIDA := Color(0.52, 0.45, 0.37)
const SOMBRA := Color(0.03, 0.03, 0.04, 0.78)

## Verde = mismo que la niebla de miasma (art_style.gd).
const VERDE_MIASMA := Color(0.36, 0.44, 0.22)
const AZUL_CASO := Color(0.24, 0.38, 0.62)

## Tamaños de letra; 26 se lee en una tele a 2 m.
const T_TITULO := 44
const T_CABECERA := 24
const T_CUERPO := 26
const T_FIRMA := 21
const T_FUENTE := 20
const T_BARRA := 20

signal cerrado
## Ficha enseñada a quien la pidió ("" si se volvió sin enseñar).
signal presentada(ficha_id: String)

## Dos páginas: cuaderno (por defecto) y fuentes.
var _pag_cuaderno: Control
var _pag_fuentes: Control
var _pestanas: HBoxContainer
var _btn_cuaderno: Button
var _btn_fuentes: Button
var _btn_volver: Button
var _titulo_pagina: Label
var _a_fuentes: Button
var _a_cuaderno: Button
var _volteo: Control
var _presentando: bool = false

var _izquierda: VBoxContainer
var _derecha: VBoxContainer
var _barra_aire: ProgressBar
var _barra_caso: ProgressBar
var _cierre: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	# IGNORE cerrado, STOP abierto (ver abrir()): ocupa toda la pantalla.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_construir()


func _construir() -> void:
	var fondo := ColorRect.new()
	fondo.color = SOMBRA
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fondo)

	var centro := MarginContainer.new()
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centro.add_theme_constant_override("margin_left", 190)
	centro.add_theme_constant_override("margin_right", 110)
	centro.add_theme_constant_override("margin_top", 64)
	centro.add_theme_constant_override("margin_bottom", 64)
	centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centro)

	var hoja := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = PAPEL
	sb.border_color = PAPEL_BORDE
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(1)
	sb.set_content_margin_all(48)
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size = 22
	hoja.add_theme_stylebox_override("panel", sb)

	# Papel más gastado que el de la caja de diálogo.
	var gastado := ShaderMaterial.new()
	gastado.shader = PAPEL_SHADER
	gastado.set_shader_parameter("manchas", 0.34)
	gastado.set_shader_parameter("bordes", 0.40)
	# Sin pliegue del shader: el lomo lo dibuja el cuaderno, centrado.
	gastado.set_shader_parameter("pliegues", 0.0)
	gastado.set_shader_parameter("fibra", 0.055)
	gastado.set_shader_parameter("grano", 0.030)
	hoja.material = gastado
	centro.add_child(hoja)
	_volteo = HOJA_QUE_PASA.new()
	centro.add_child(_volteo)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 20)
	hoja.add_child(col)

	var cabeza := HBoxContainer.new()
	cabeza.add_theme_constant_override("separation", 28)
	col.add_child(cabeza)
	_titulo_pagina = _linea("Houses and words", TINTA, T_TITULO, GARAMOND_SEMI)
	cabeza.add_child(_titulo_pagina)
	var hueco := Control.new()
	hueco.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cabeza.add_child(hueco)
	_pestanas = HBoxContainer.new()
	_pestanas.visible = false
	_pestanas.add_theme_constant_override("separation", 22)
	cabeza.add_child(_pestanas)
	_btn_cuaderno = _pestana("Houses and words")
	_btn_cuaderno.pressed.connect(_mostrar.bind(true))
	_pestanas.add_child(_btn_cuaderno)
	_btn_fuentes = _pestana("Sources")
	_btn_fuentes.pressed.connect(_mostrar.bind(false))
	_pestanas.add_child(_btn_fuentes)
	_btn_volver = _pestana("Back")
	_btn_volver.pressed.connect(cerrar)
	_btn_volver.visible = false
	cabeza.add_child(_btn_volver)
	col.add_child(_raya())

	_pag_cuaderno = CUADERNO.new()
	_pag_cuaderno.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_pag_cuaderno.presentada.connect(_presentado)
	col.add_child(_pag_cuaderno)

	_pag_fuentes = VBoxContainer.new()
	_pag_fuentes.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_pag_fuentes.add_theme_constant_override("separation", 20)
	col.add_child(_pag_fuentes)
	_pag_fuentes.add_child(_barras())
	_pag_fuentes.add_child(_raya())

	var dos := HBoxContainer.new()
	dos.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dos.add_theme_constant_override("separation", 0)
	_pag_fuentes.add_child(dos)

	_izquierda = _columna(dos, "What I have found")

	dos.add_child(CUADERNO.Lomo.new())

	_derecha = _columna(dos, "What I can cite")

	# Esquinas para pasar de página: adelante a la derecha, atrás a la izquierda.
	var esquinas := HBoxContainer.new()
	col.add_child(esquinas)
	_a_cuaderno = _pestana("‹  Houses and words")
	_a_cuaderno.pressed.connect(_voltear.bind(true))
	_a_cuaderno.mouse_entered.connect(func(): _volteo.doblar(-1, true))
	_a_cuaderno.mouse_exited.connect(func(): _volteo.doblar(-1, false))
	esquinas.add_child(_a_cuaderno)
	var medio := Control.new()
	medio.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	esquinas.add_child(medio)
	_a_fuentes = _pestana("Sources  ›")
	_a_fuentes.pressed.connect(_voltear.bind(false))
	_a_fuentes.mouse_entered.connect(func(): _volteo.doblar(1, true))
	_a_fuentes.mouse_exited.connect(func(): _volteo.doblar(1, false))
	esquinas.add_child(_a_fuentes)

	# Botón de cierre, pegado a la esquina de la pantalla.
	_cierre = CIERRE.new()
	_cierre.fuente = GARAMOND_SEMI
	_cierre.pulsado.connect(cerrar)
	add_child(_cierre)
	_cierre.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_cierre.offset_left = 34.0
	_cierre.offset_top = 30.0
	_cierre.offset_right = 166.0
	_cierre.offset_bottom = 134.0


## Barras aire y caso juntas, para compararlas.
func _barras() -> Control:
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 54)

	var izq := VBoxContainer.new()
	izq.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	izq.add_theme_constant_override("separation", 5)
	izq.add_child(_linea("THE AIR", TINTA_SUAVE, T_BARRA, GARAMOND_SEMI))
	_barra_aire = _barra(VERDE_MIASMA)
	izq.add_child(_barra_aire)
	fila.add_child(izq)

	var der := VBoxContainer.new()
	der.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	der.add_theme_constant_override("separation", 5)
	der.add_child(_linea("THE CASE", TINTA_SUAVE, T_BARRA, GARAMOND_SEMI))
	_barra_caso = _barra(AZUL_CASO)
	der.add_child(_barra_caso)
	fila.add_child(der)

	return fila


func _barra(color: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.min_value = 0.0
	b.max_value = 1.0
	b.custom_minimum_size = Vector2(0, 13)

	var fondo := StyleBoxFlat.new()
	fondo.bg_color = Color(0.68, 0.63, 0.53)
	fondo.border_color = PAPEL_BORDE
	fondo.set_border_width_all(1)
	b.add_theme_stylebox_override("background", fondo)

	var relleno := StyleBoxFlat.new()
	relleno.bg_color = color
	b.add_theme_stylebox_override("fill", relleno)
	return b


func _columna(padre: Control, cabecera: String) -> VBoxContainer:
	var caja := VBoxContainer.new()
	caja.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caja.size_flags_vertical = Control.SIZE_EXPAND_FILL
	caja.add_theme_constant_override("separation", 16)
	padre.add_child(caja)

	caja.add_child(_linea(cabecera.to_upper(), TINTA_SUAVE, T_CABECERA, GARAMOND_SEMI))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	caja.add_child(scroll)

	var lista := VBoxContainer.new()
	lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lista.add_theme_constant_override("separation", 26)
	scroll.add_child(lista)
	return lista


func abrir() -> void:
	_rellenar()
	# Siempre en la primera página.
	_pag_cuaderno.set(&"_pagina", 0)
	_mostrar(true)
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP


func cerrar() -> void:
	if _presentando:
		# Con algo que enseñar, hay que elegir: no vale cerrar.
		if _hay_que_ensenar():
			return
		_presentado("")
		return
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	cerrado.emit()


## Abre el cuaderno para enseñar una ficha (a Snow), con botón "Back".
func presentar(_boton: String = "") -> void:
	_presentando = true
	_mostrar(true)
	_pag_cuaderno.modo_presentar(true)
	_a_fuentes.visible = false
	_a_cuaderno.visible = false
	_btn_volver.visible = not _hay_que_ensenar()
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP


func _hay_que_ensenar() -> bool:
	return _pag_cuaderno.call(&"paginas") > 0 and not _pag_cuaderno.call(&"_orden").is_empty()


func _presentado(ficha_id: String) -> void:
	if not _presentando:
		return
	_presentando = false
	_pag_cuaderno.modo_presentar(false)
	_btn_volver.visible = false
	_mostrar(true)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	presentada.emit(ficha_id)


func _mostrar(cuaderno: bool) -> void:
	_pag_cuaderno.visible = cuaderno
	_pag_fuentes.visible = not cuaderno
	_titulo_pagina.text = "Houses and words" if cuaderno else "Sources"
	_a_fuentes.visible = cuaderno and not _presentando
	_a_cuaderno.visible = not cuaderno and not _presentando
	if cuaderno:
		_pag_cuaderno.rellenar()


## Pasa la hoja y cambia de página a media vuelta.
func _voltear(cuaderno: bool) -> void:
	_volteo.a_medias.connect(_mostrar.bind(cuaderno), CONNECT_ONE_SHOT)
	_volteo.pasar(-1 if cuaderno else 1)


func _pestana(t: String) -> Button:
	var b := Button.new()
	b.text = t
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_override("font", GARAMOND_SEMI)
	b.add_theme_font_size_override("font_size", T_CABECERA)
	b.add_theme_color_override("font_color", TINTA_PALIDA)
	b.add_theme_color_override("font_hover_color", TINTA)
	return b


func alternar() -> void:
	if visible:
		cerrar()
	else:
		abrir()


func _rellenar() -> void:
	for lista in [_izquierda, _derecha]:
		for h in lista.get_children():
			lista.remove_child(h)
			h.queue_free()

	var notas := Casefile.notes()
	if notas.is_empty():
		_izquierda.add_child(_vacio("Nothing written down yet."))
	for n in notas:
		_izquierda.add_child(_apunte(n))

	var ids := Casefile.collected_ids()
	if ids.is_empty():
		_derecha.add_child(_vacio("Nothing I could put in front of anyone yet."))
	for id in ids:
		_derecha.add_child(_prueba(EvidenceDB.get_entry(id)))

	_barra_aire.value = GameState.get_miasma()
	_barra_caso.value = Casefile.quality()


## Apunte: lo dicho y de quién se oyó.
func _apunte(n: Dictionary) -> Control:
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 4)
	caja.add_child(_parrafo(String(n.get("que", "")), TINTA, T_CUERPO, GARAMOND))

	var pie := String(n.get("quien", ""))
	var donde := String(n.get("donde", ""))
	if not donde.is_empty():
		pie = "%s, %s" % [pie, donde] if not pie.is_empty() else donde
	if not pie.is_empty():
		caja.add_child(_parrafo(pie, TINTA_PALIDA, T_FIRMA, GARAMOND_NOTA))
	return caja


## Prueba: imagen y "resumen" opcionales, cita textual y referencia MLA.
func _prueba(e: Dictionary) -> Control:
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 7)

	var ruta := String(e.get("imagen", ""))
	if not ruta.is_empty() and ResourceLoader.exists(ruta):
		var lamina := TextureRect.new()
		lamina.texture = load(ruta) as Texture2D
		lamina.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		lamina.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		lamina.custom_minimum_size = Vector2(0, 150)
		caja.add_child(lamina)

	var resumen := String(e.get("resumen", ""))
	if not resumen.is_empty():
		caja.add_child(_parrafo(resumen, TINTA, T_CUERPO, GARAMOND))

	var texto := String(e.get("cita_textual", ""))
	if texto.is_empty():
		texto = String(e.get("hecho", ""))
	else:
		texto = "“" + texto + "”"
	caja.add_child(_parrafo(texto, TINTA, T_CUERPO - 3, GARAMOND))

	var mla := String(e.get("cita_mla", ""))
	if not mla.is_empty():
		caja.add_child(_parrafo(mla, TINTA_SUAVE, T_FUENTE, GARAMOND_NOTA))
	return caja


func _vacio(texto: String) -> Control:
	return _parrafo(texto, TINTA_PALIDA, T_CUERPO - 2, GARAMOND_NOTA)


func _titulo(t: String) -> Label:
	var l := _linea(t, TINTA, T_TITULO, GARAMOND_SEMI)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _linea(t: String, color: Color, tam: int, f: Font) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_override("font", f)
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", color)
	return l


func _parrafo(t: String, color: Color, tam: int, f: Font) -> Label:
	var l := _linea(t, color, tam, f)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


func _raya() -> Control:
	var p := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = PAPEL_BORDE
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size = Vector2(0, 1)
	return p
