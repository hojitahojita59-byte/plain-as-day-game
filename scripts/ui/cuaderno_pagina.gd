extends VBoxContainer
## Cuaderno abierto: casas en la página izquierda, palabras oídas en la derecha.
## Ficha llena: lo acertado pasa a tinta (fijo), lo equivocado queda subrayado en rojo.

signal presentada(ficha_id: String)

const GARAMOND := preload("res://art/fonts/EB_Garamond/static/EBGaramond-Regular.ttf")
const GARAMOND_SEMI := preload("res://art/fonts/EB_Garamond/static/EBGaramond-SemiBold.ttf")

const TINTA := Color(0.14, 0.11, 0.08)
const TINTA_SUAVE := Color(0.38, 0.31, 0.24)
const TINTA_PALIDA := Color(0.52, 0.45, 0.37)
const PAPEL_BORDE := Color(0.44, 0.37, 0.28)
const ROJO := Color(0.70, 0.12, 0.08)

const T_CUERPO := 24
const T_TITULO := 26
const T_PEQUE := 19
## Fichas por página (izquierda).
const POR_PAGINA := 3

var _fichas: VBoxContainer
var _palabras: VBoxContainer
var _indicacion: Label
var _ayudando: bool = false
var _puntero: Puntero
## Palabras gastadas ya tachadas una vez: no vuelven.
var _tachadas: Dictionary = {}
var _de_quien: Label
var _paginador: HBoxContainer
var _num_pagina: Label

## Lo cogido: un hueco [ficha, hueco] o una palabra.
var _hueco_cogido: Array = []
var _palabra_cogida: String = ""
var _presentando: bool = false
var _pagina: int = 0
## "ficha/hueco" recién pasados a tinta: se animan al pintar.
var _nuevas: Dictionary = {}
var _recien_sellada: String = ""


func _ready() -> void:
	add_theme_constant_override("separation", 12)
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	_indicacion = Label.new()
	_indicacion.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_indicacion.add_theme_font_override("font", GARAMOND)
	_indicacion.add_theme_font_size_override("font_size", 21)
	_indicacion.add_theme_color_override("font_color", Color(0.96, 0.95, 0.92))
	var gris := StyleBoxFlat.new()
	gris.bg_color = Color(0.32, 0.31, 0.30, 0.92)
	gris.set_corner_radius_all(10)
	gris.content_margin_left = 16
	gris.content_margin_right = 16
	gris.content_margin_top = 7
	gris.content_margin_bottom = 7
	_indicacion.add_theme_stylebox_override("normal", gris)
	_indicacion.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_indicacion.visible = false
	var arriba := HBoxContainer.new()
	add_child(arriba)
	arriba.add_child(_indicacion)
	var hueco := Control.new()
	hueco.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	arriba.add_child(hueco)
	var ayuda := _boton("?", 24)
	ayuda.tooltip_text = "How to fill a card"
	ayuda.add_theme_color_override("font_color", TINTA_PALIDA)
	ayuda.pressed.connect(_ayudar)
	arriba.add_child(ayuda)
	_puntero = Puntero.new()
	add_child(_puntero)

	var dos := HBoxContainer.new()
	dos.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dos.add_theme_constant_override("separation", 0)
	add_child(dos)

	var izq := _pagina_vacia(dos, "Houses")
	_fichas = VBoxContainer.new()
	_fichas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_fichas.add_theme_constant_override("separation", 20)
	izq.add_child(_fichas)
	_paginador = HBoxContainer.new()
	_paginador.alignment = BoxContainer.ALIGNMENT_CENTER
	_paginador.add_theme_constant_override("separation", 18)
	izq.add_child(_paginador)
	var atras := _boton("‹", 30)
	atras.pressed.connect(_pasar.bind(-1))
	atras.set_meta(&"pagina", "atras")
	_paginador.add_child(atras)
	_num_pagina = _linea("", TINTA_SUAVE, T_PEQUE, GARAMOND)
	_paginador.add_child(_num_pagina)
	var adelante := _boton("›", 30)
	adelante.pressed.connect(_pasar.bind(1))
	adelante.set_meta(&"pagina", "adelante")
	_paginador.add_child(adelante)

	dos.add_child(Lomo.new())

	var der := _pagina_vacia(dos, "What I have heard")
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	der.add_child(scroll)
	_palabras = VBoxContainer.new()
	_palabras.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_palabras.add_theme_constant_override("separation", 16)
	scroll.add_child(_palabras)
	_de_quien = _linea("", TINTA_PALIDA, T_PEQUE, GARAMOND)
	_de_quien.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	der.add_child(_de_quien)

	Cuaderno.cambiado.connect(rellenar)
	Cuaderno.ficha_abierta.connect(_al_cambiar_algo)
	Cuaderno.palabra_aprendida.connect(_al_cambiar_algo)


func _al_cambiar_algo(_id: String) -> void:
	rellenar()


## Una página: márgenes propios para que nada cruce el lomo.
func _pagina_vacia(padre: Control, cabecera: String) -> VBoxContainer:
	var m := MarginContainer.new()
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m.size_flags_vertical = Control.SIZE_EXPAND_FILL
	m.add_theme_constant_override("margin_left", 6)
	m.add_theme_constant_override("margin_right", 6)
	padre.add_child(m)
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 12)
	m.add_child(caja)
	caja.add_child(_linea(cabecera.to_upper(), TINTA_SUAVE, 21, GARAMOND_SEMI))
	return caja


## Modo de enseñar una ficha a alguien.
func modo_presentar(si: bool) -> void:
	_presentando = si
	_hueco_cogido = []
	_palabra_cogida = ""
	_pagina = 0
	rellenar()


func _orden() -> Array[String]:
	var abiertas := Cuaderno.abiertas()
	var orden: Array[String] = []
	if _presentando:
		for tipo in ["rareza", "muerte"]:
			for id in abiertas:
				if Cuaderno.sellada(id) and String(Cuaderno.ficha(id).get("tipo", "")) == tipo:
					orden.append(id)
		return orden
	for id in abiertas:
		if not Cuaderno.sellada(id):
			orden.append(id)
	for id in abiertas:
		if Cuaderno.sellada(id):
			orden.append(id)
	return orden


func paginas() -> int:
	return maxi(1, ceili(float(_orden().size()) / POR_PAGINA))


## Pasa a la página donde está la ficha.
func mostrar_ficha(id: String) -> void:
	var i := _orden().find(id)
	if i >= 0:
		_pagina = i / POR_PAGINA
	rellenar()


func _pasar(d: int) -> void:
	_pagina = clampi(_pagina + d, 0, paginas() - 1)
	rellenar()


func rellenar() -> void:
	if _fichas == null:
		return
	for lista in [_fichas, _palabras]:
		for h in lista.get_children():
			lista.remove_child(h)
			h.queue_free()

	var orden := _orden()
	if not _recien_sellada.is_empty() and orden.has(_recien_sellada):
		_pagina = orden.find(_recien_sellada) / POR_PAGINA
	_pagina = clampi(_pagina, 0, paginas() - 1)
	if orden.is_empty():
		_fichas.add_child(_linea("No houses yet. Ask in the street who has lost someone.", TINTA_PALIDA, T_CUERPO, GARAMOND))
	for id in orden.slice(_pagina * POR_PAGINA, (_pagina + 1) * POR_PAGINA):
		_fichas.add_child(_ficha(id))
	_paginador.visible = paginas() > 1
	_num_pagina.text = "%d / %d" % [_pagina + 1, paginas()]

	_rellenar_palabras()
	_indicacion.text = _que_hacer()
	_indicacion.visible = _presentando or _ayudando
	_nuevas.clear()
	_recien_sellada = ""


func _que_hacer() -> String:
	if _presentando:
		return "Click the card you want to show him."
	if not _hueco_cogido.is_empty():
		var tipo := Cuaderno.tipo_del_hueco(String(_hueco_cogido[0]), String(_hueco_cogido[1]))
		return "Now click a word from %s on the right." % String(Dictionary(Cuaderno.tipos().get(tipo, {})).get("nombre", "the list")).to_lower()
	if not _palabra_cogida.is_empty():
		return "Now click a blank for it on the left."
	return "Click a blank, then a word you heard. Right words turn to ink; wrong ones are underlined in red."


## El (?): explica y enseña con un puntero de hueco a palabra.
func _ayudar() -> void:
	_ayudando = not _ayudando
	rellenar()
	if not _ayudando:
		_puntero.parar()
		return
	var desde := _primero(_fichas, &"hueco")
	var hasta := _primero(_palabras, &"palabra")
	if desde != null and hasta != null:
		_puntero.ensenar(desde.get_global_rect().get_center(), hasta.get_global_rect().get_center())


func _primero(n: Node, meta: StringName) -> Control:
	for h in n.find_children("*", "Button", true, false):
		if h.has_meta(meta) and not (h as Button).disabled:
			return h as Control
	return null


# --- Ficha ---

func _ficha(id: String) -> Control:
	var f := Cuaderno.ficha(id)
	var sellada := Cuaderno.sellada(id)
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 4)

	var cabeza := HBoxContainer.new()
	cabeza.add_theme_constant_override("separation", 10)
	caja.add_child(cabeza)
	cabeza.add_child(_linea(String(f.get("titulo", id)), TINTA, T_TITULO, GARAMOND_SEMI))
	if sellada:
		var visto := Check.new()
		visto.animar = _recien_sellada == id
		visto.set_meta(&"sellada", id)
		cabeza.add_child(visto)
	if _presentando and sellada:
		var ensenar := _boton("Show this", 21)
		ensenar.add_theme_color_override("font_color", TINTA)
		ensenar.pressed.connect(func(): presentada.emit(id))
		ensenar.set_meta(&"ensenar", id)
		cabeza.add_child(ensenar)

	# Frase en un HFlowContainer, con los huecos en su sitio.
	var flujo := HFlowContainer.new()
	flujo.add_theme_constant_override("h_separation", 7)
	flujo.add_theme_constant_override("v_separation", 2)
	caja.add_child(flujo)
	var frase := String(f.get("frase", ""))
	var re := RegEx.new()
	re.compile("\\{([a-z0-9_]+)\\}([.,;:]?)|([^\\s{]+)")
	var empieza := true
	for m in re.search_all(frase):
		if not m.get_string(1).is_empty():
			flujo.add_child(_hueco(id, m.get_string(1), m.get_string(2), sellada, empieza))
			empieza = m.get_string(2) == "."
		else:
			flujo.add_child(_linea(m.get_string(3), TINTA, T_CUERPO, GARAMOND))
			empieza = m.get_string(3).ends_with(".")
	if _presentando and not sellada:
		caja.modulate.a = 0.45
	if _presentando and sellada:
		return _tarjeta(caja, id)
	return caja


## Para enseñar: la ficha entera es una tarjeta; amarilla al pasar por encima.
func _tarjeta(dentro: Control, id: String) -> Control:
	var t := PanelContainer.new()
	t.mouse_filter = Control.MOUSE_FILTER_STOP
	t.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	t.add_theme_stylebox_override("panel", _estilo_tarjeta(false))
	t.mouse_entered.connect(func(): t.add_theme_stylebox_override("panel", _estilo_tarjeta(true)))
	t.mouse_exited.connect(func(): t.add_theme_stylebox_override("panel", _estilo_tarjeta(false)))
	t.gui_input.connect(func(e: InputEvent):
		var mb := e as InputEventMouseButton
		if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			presentada.emit(id))
	t.add_child(dentro)
	return t


func _estilo_tarjeta(encima: bool) -> StyleBox:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.98, 0.86, 0.42, 0.55) if encima else Color(0.97, 0.94, 0.86, 0.75)
	sb.border_color = Color(0.80, 0.62, 0.12) if encima else Color(0.55, 0.47, 0.36, 0.6)
	sb.set_border_width_all(3 if encima else 1)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(12)
	sb.shadow_color = Color(0, 0, 0, 0.18)
	sb.shadow_size = 6 if encima else 3
	return sb


func _hueco(ficha_id: String, hueco: String, puntuacion: String, sellada: bool, mayuscula: bool = false) -> Control:
	var puesta := Cuaderno.puesta(ficha_id, hueco)
	var tipo := Cuaderno.tipo_del_hueco(ficha_id, hueco)
	var color := Cuaderno.color_de(tipo)
	var texto := "      " if puesta.is_empty() else String(Cuaderno.palabra(puesta).get("texto", "?"))
	if mayuscula and not puesta.is_empty():
		texto = texto.left(1).to_upper() + texto.substr(1)

	# En tinta: comprobado y bien. Recién pasado: con su animación.
	if sellada or Cuaderno.fija(ficha_id, hueco):
		var clave := ficha_id + "/" + hueco
		if _nuevas.has(clave):
			var t := Tinta.new()
			t.text = texto + puntuacion
			t.desde = color
			t.add_theme_font_override("font", GARAMOND_SEMI)
			t.add_theme_font_size_override("font_size", T_CUERPO)
			return t
		return _linea(texto + puntuacion, TINTA, T_CUERPO, GARAMOND_SEMI)

	var mala := not puesta.is_empty() and Cuaderno.completa(ficha_id) and not Cuaderno.correcta(ficha_id, hueco)
	var b := _boton(texto, T_CUERPO)
	b.add_theme_color_override("font_color", color if not puesta.is_empty() else TINTA_PALIDA)
	# Hueco con cara de botón: cajita de papel más oscuro.
	b.custom_minimum_size.x = 76.0 if puesta.is_empty() else 0.0
	b.add_theme_stylebox_override("normal", _cajita(color, false))
	b.add_theme_stylebox_override("hover", _cajita(color, true))
	b.add_theme_color_override("font_hover_color", color.lightened(0.2))
	b.disabled = _presentando
	var cogido: bool = _hueco_cogido.size() == 2 and _hueco_cogido[0] == ficha_id and _hueco_cogido[1] == hueco
	if cogido:
		b.add_theme_stylebox_override("normal", _subrayado(color))
		b.add_theme_stylebox_override("hover", _subrayado(color))
	elif mala:
		b.add_theme_stylebox_override("normal", _subrayado(ROJO, 0.0))
		b.add_theme_stylebox_override("hover", _subrayado(ROJO, 0.08))
		b.set_meta(&"mala", true)
	elif not _palabra_cogida.is_empty() and String(Cuaderno.palabra(_palabra_cogida).get("tipo", "")) == tipo:
		b.add_theme_stylebox_override("normal", _subrayado(color.lightened(0.3)))
	b.pressed.connect(_clic_hueco.bind(ficha_id, hueco))
	b.set_meta(&"hueco", ficha_id + "/" + hueco)
	if puntuacion.is_empty():
		return b
	# La puntuación, fuera de la caja.
	var junto := HBoxContainer.new()
	junto.add_theme_constant_override("separation", 1)
	junto.add_child(b)
	junto.add_child(_linea(puntuacion, TINTA, T_CUERPO, GARAMOND))
	return junto


func _clic_hueco(ficha_id: String, hueco: String) -> void:
	if _presentando:
		return
	if not _palabra_cogida.is_empty():
		_poner(ficha_id, hueco, _palabra_cogida)
		return
	# Clic en un hueco lleno: lo vacía y lo deja cogido.
	if not Cuaderno.puesta(ficha_id, hueco).is_empty():
		Cuaderno.poner(ficha_id, hueco, "")
	if _hueco_cogido.size() == 2 and _hueco_cogido[0] == ficha_id and _hueco_cogido[1] == hueco:
		_hueco_cogido = []
	else:
		_hueco_cogido = [ficha_id, hueco]
	rellenar()


func _poner(ficha_id: String, hueco: String, palabra_id: String) -> void:
	_hueco_cogido = []
	_palabra_cogida = ""
	if not Cuaderno.poner(ficha_id, hueco, palabra_id):
		rellenar()
		return
	if Cuaderno.completa(ficha_id):
		for h in Cuaderno.huecos_en_orden(ficha_id):
			if Cuaderno.correcta(ficha_id, h) and not Cuaderno.fija(ficha_id, h):
				_nuevas[ficha_id + "/" + h] = true
		if Cuaderno.comprobar(ficha_id) == Cuaderno.SELLADA:
			_recien_sellada = ficha_id
	rellenar()


## Huecos de una ficha subrayados en rojo (para las pruebas).
func malas(ficha_id: String) -> int:
	var n := 0
	for h in Cuaderno.huecos_en_orden(ficha_id):
		if not Cuaderno.puesta(ficha_id, h).is_empty() and Cuaderno.completa(ficha_id) \
				and not Cuaderno.correcta(ficha_id, h):
			n += 1
	return n


# --- Palabras ---

func _rellenar_palabras() -> void:
	var sabidas := Cuaderno.sabidas()
	if sabidas.is_empty():
		_palabras.add_child(_linea("Nothing yet. Names, days and numbers people tell you will appear here.", TINTA_PALIDA, T_CUERPO - 2, GARAMOND))
		return
	var tipos := Cuaderno.tipos()
	var tipo_del_hueco := ""
	if not _hueco_cogido.is_empty():
		tipo_del_hueco = Cuaderno.tipo_del_hueco(String(_hueco_cogido[0]), String(_hueco_cogido[1]))
	for tipo in tipos:
		var de_este: Array[String] = []
		for w in sabidas:
			# Vuelve a hacer falta (un papel perdido): se destacha.
			if _tachadas.has(w) and not Cuaderno.gastada(w):
				_tachadas.erase(w)
			if String(Cuaderno.palabra(w).get("tipo", "")) == tipo and not _tachadas.has(w):
				de_este.append(w)
		if de_este.is_empty():
			continue
		var grupo := VBoxContainer.new()
		grupo.add_theme_constant_override("separation", 2)
		grupo.add_child(_linea(String(Dictionary(tipos[tipo]).get("nombre", tipo)), TINTA_SUAVE, T_PEQUE + 1, GARAMOND_SEMI))
		var flujo := HFlowContainer.new()
		flujo.add_theme_constant_override("h_separation", 10)
		grupo.add_child(flujo)
		for w in de_este:
			var b := _boton(String(Cuaderno.palabra(w).get("texto", w)), T_CUERPO - 2)
			var color := Cuaderno.color_de(tipo)
			b.add_theme_color_override("font_color", color)
			b.add_theme_color_override("font_hover_color", color.lightened(0.25))
			b.tooltip_text = "Heard from %s" % Cuaderno.de_quien(w)
			b.disabled = _presentando or (not tipo_del_hueco.is_empty() and tipo_del_hueco != tipo)
			if _palabra_cogida == w:
				b.add_theme_stylebox_override("normal", _subrayado(color))
			b.pressed.connect(_clic_palabra.bind(w))
			if Cuaderno.gastada(w):
				_tachar(b, w)
			else:
				b.set_meta(&"palabra", w)
			b.mouse_entered.connect(func(): _de_quien.text = "%s: heard from %s." % [String(Cuaderno.palabra(w).get("texto", w)), Cuaderno.de_quien(w)])
			flujo.add_child(b)
		_palabras.add_child(grupo)


## Se tacha y se va: ya no hace falta.
func _tachar(b: Button, w: String) -> void:
	_tachadas[w] = true
	b.disabled = true
	var raya := Tachon.new()
	b.add_child(raya)
	var t := b.create_tween()
	t.tween_property(raya, "avance", 1.0, 0.45).set_delay(0.3)
	t.tween_property(b, "modulate:a", 0.0, 0.8).set_delay(0.5)


func _clic_palabra(w: String) -> void:
	if _presentando:
		return
	if not _hueco_cogido.is_empty():
		_poner(String(_hueco_cogido[0]), String(_hueco_cogido[1]), w)
		return
	_palabra_cogida = "" if _palabra_cogida == w else w
	rellenar()


# --- Utilidades ---

func _linea(t: String, color: Color, tam: int, f: Font) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_override("font", f)
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", color)
	return l


func _boton(t: String, tam: int) -> Button:
	var b := Button.new()
	b.text = t
	b.flat = false
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_override("font", GARAMOND_SEMI)
	b.add_theme_font_size_override("font_size", tam)
	b.add_theme_color_override("font_color", TINTA_SUAVE)
	b.add_theme_color_override("font_hover_color", TINTA)
	b.add_theme_color_override("font_disabled_color", Color(TINTA_PALIDA, 0.5))
	var vacio := StyleBoxEmpty.new()
	vacio.content_margin_left = 2
	vacio.content_margin_right = 2
	for estado in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(estado, vacio)
	return b


## Caja de hueco: fondo de papel oscuro, borde del color de su tipo.
func _cajita(c: Color, encima: bool) -> StyleBox:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.80, 0.74, 0.60, 0.55 if encima else 0.35)
	sb.border_color = Color(c, 0.85 if encima else 0.55)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 1
	sb.content_margin_bottom = 1
	return sb


## Subrayado de un color (fondo tenue opcional).
func _subrayado(c: Color, fondo: float = 0.14) -> StyleBox:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(c, fondo)
	sb.border_color = c
	sb.border_width_bottom = 3
	sb.content_margin_left = 2
	sb.content_margin_right = 2
	return sb


## Lomo del cuaderno: sombra del pliegue entre las dos páginas.
class Lomo extends Control:
	func _ready() -> void:
		custom_minimum_size = Vector2(64, 0)
		size_flags_vertical = Control.SIZE_EXPAND_FILL
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size.x * 0.5
		for i in 16:
			var d := float(i) / 16.0
			var a := 0.13 * (1.0 - d) * (1.0 - d)
			draw_rect(Rect2(c - (i + 1) * 2.0, 0, 2.0, size.y), Color(0.25, 0.18, 0.10, a))
			draw_rect(Rect2(c + i * 2.0, 0, 2.0, size.y), Color(0.25, 0.18, 0.10, a))
		draw_line(Vector2(c, 0), Vector2(c, size.y), Color(0.30, 0.22, 0.14, 0.45), 1.5)


## Palabra que pasa a tinta: brilla en oro, salpica y queda negra.
class Tinta extends Label:
	var desde: Color = Color.WHITE
	const ORO := Color(1.0, 0.80, 0.32)
	const NEGRO := Color(0.14, 0.11, 0.08)

	func _ready() -> void:
		add_theme_color_override("font_color", desde)
		add_theme_constant_override("shadow_outline_size", 7)
		add_theme_color_override("font_shadow_color", Color(ORO, 0.0))
		var t := create_tween()
		t.tween_method(_pintar, 0.0, 1.0, 1.3).set_trans(Tween.TRANS_SINE)
		_gotas()

	func _pintar(v: float) -> void:
		var c := desde.lerp(ORO, v / 0.35) if v < 0.35 else ORO.lerp(NEGRO, (v - 0.35) / 0.65)
		add_theme_color_override("font_color", c)
		var brillo := clampf(1.0 - absf(v - 0.35) / 0.5, 0.0, 1.0)
		add_theme_color_override("font_shadow_color", Color(ORO, 0.75 * brillo))

	func _gotas() -> void:
		await get_tree().process_frame
		var p := CPUParticles2D.new()
		p.one_shot = true
		p.amount = 18
		p.lifetime = 1.0
		p.explosiveness = 0.85
		p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		p.emission_rect_extents = size * 0.5
		p.position = size * 0.5
		p.direction = Vector2(0, -1)
		p.spread = 180.0
		p.gravity = Vector2(0, 40)
		p.initial_velocity_min = 18.0
		p.initial_velocity_max = 55.0
		p.scale_amount_min = 1.5
		p.scale_amount_max = 3.5
		var rampa := Gradient.new()
		rampa.set_color(0, Color(ORO, 0.9))
		rampa.set_color(1, Color(NEGRO, 0.0))
		p.color_ramp = rampa
		add_child(p)
		p.emitting = true


## Visto bueno a pluma junto al título de una ficha sellada.
class Check extends Control:
	var animar: bool = false
	var _t: float = 1.0
	const NEGRO := Color(0.14, 0.11, 0.08)

	func _ready() -> void:
		custom_minimum_size = Vector2(34, 30)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		if animar:
			_t = 0.0
			var t := create_tween()
			t.tween_interval(0.9)
			t.tween_method(_trazar, 0.0, 1.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	func _trazar(v: float) -> void:
		_t = v
		queue_redraw()

	func _draw() -> void:
		var pts := PackedVector2Array([Vector2(4, 16), Vector2(13, 26), Vector2(31, 3)])
		var l1 := pts[0].distance_to(pts[1])
		var l2 := pts[1].distance_to(pts[2])
		var hecho := (l1 + l2) * _t
		var linea := PackedVector2Array([pts[0]])
		if hecho <= l1:
			linea.append(pts[0].lerp(pts[1], hecho / l1))
		else:
			linea.append(pts[1])
			linea.append(pts[1].lerp(pts[2], (hecho - l1) / l2))
		if linea.size() >= 2:
			draw_polyline(linea, NEGRO, 3.5, true)


## Raya de tinta que tacha una palabra gastada.
class Tachon extends Control:
	var avance: float = 0.0:
		set(v):
			avance = v
			queue_redraw()

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	func _draw() -> void:
		var y := size.y * 0.55
		var a := Vector2(2, y + 2)
		var b := Vector2(size.x - 2, y - 2)
		if avance > 0.0:
			draw_line(a, a.lerp(b, avance), Color(0.14, 0.11, 0.08), 2.5, true)


## Anillo de tinta que va de un hueco a una palabra, dos veces.
class Puntero extends Control:
	var _t: Tween
	var _pulso: float = 0.0

	func _ready() -> void:
		top_level = true
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size = Vector2(40, 40)
		visible = false

	func ensenar(desde: Vector2, hasta: Vector2) -> void:
		parar()
		visible = true
		modulate.a = 0.0
		global_position = desde - size * 0.5
		_t = create_tween().set_loops(2)
		_t.tween_property(self, "modulate:a", 1.0, 0.25)
		_t.tween_method(_latir, 0.0, 1.0, 0.45)
		_t.tween_property(self, "global_position", hasta - size * 0.5, 0.9) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_t.tween_method(_latir, 0.0, 1.0, 0.45)
		_t.tween_property(self, "modulate:a", 0.0, 0.3)
		_t.tween_property(self, "global_position", desde - size * 0.5, 0.0)
		_t.finished.connect(parar)

	func parar() -> void:
		if _t != null:
			_t.kill()
		visible = false

	func _latir(v: float) -> void:
		_pulso = v
		queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var tinta := Color(0.30, 0.42, 0.62)
		draw_circle(c, 5.0, tinta)
		draw_arc(c, 9.0 + 9.0 * _pulso, 0.0, TAU, 32, Color(tinta, 1.0 - _pulso), 2.5, true)
