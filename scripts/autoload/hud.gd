extends CanvasLayer
## HUD (autoload): caja de diálogo, expediente, esquina, pausa y retratos.
## Garamond para leer; Pinyon Script solo en rótulos cortos.

const TEMA := preload("res://art/ui/tema_soho.tres")
const GARAMOND_NOTA := preload("res://art/fonts/EB_Garamond/static/EBGaramond-Regular.ttf")
const GARAMOND_SEMI := preload("res://art/fonts/EB_Garamond/static/EBGaramond-SemiBold.ttf")
const GARAMOND := preload("res://art/fonts/EB_Garamond/static/EBGaramond-Regular.ttf")
const PINYON := preload("res://art/fonts/Pinyon_Script/PinyonScript-Regular.ttf")
const PAPEL := preload("res://materials/papel.gdshader")
const MALETIN := preload("res://scripts/ui/maletin.gd")
const EXPEDIENTE := preload("res://scripts/ui/expediente.gd")
const BARRA := preload("res://scripts/ui/barra_miasma.gd")
const PAUSA := preload("res://scripts/ui/pausa.gd")
const GUIA := preload("res://scripts/guia.gd")
const PENSAMIENTO := preload("res://scripts/ui/pensamiento.gd")
const OPCIONES := preload("res://scripts/ui/opciones_en_el_mundo.gd")

## Sonidos de UI analógicos (sello, hoja, maletín); pasar/elegir = mismo sello.
const SON_ELEGIR := preload("res://audio/sfx/ui/elegir.wav")
const SON_PASAR := preload("res://audio/sfx/ui/pasar.wav")
const SON_GUARDAR := preload("res://audio/sfx/ui/guardar.ogg")
const SON_CIERRE := preload("res://audio/sfx/ui/maletin_cerrar.wav")

## Tinta sobre papel; nada de negro puro.
const TINTA := Color(0.16, 0.12, 0.09)
const TINTA_SUAVE := Color(0.36, 0.29, 0.22)

## Caja de objeto (Whitehead mira una cosa): gris, translúcida, sin nombre.
const TINTA_COSA := Color(0.88, 0.88, 0.86)

## Cuando habla Whitehead: caja azul marino, letra blanca, nombre a la der.
const TINTA_WHITEHEAD := Color(0.96, 0.99, 0.95)
const NOMBRE_WHITEHEAD := Color(0.66, 0.88, 0.7)
const QUIEN_ES_EL_JUGADOR := "whitehead"

var _estilo_persona: StyleBox
var _estilo_cosa: StyleBox
var _estilo_whitehead: StyleBox

var _panel: PanelContainer
var _speaker: Label
## Rich: resalta las palabras que van al cuaderno.
var _text: RichTextLabel
var _tinta_texto: Color = Color(0.16, 0.12, 0.09)
var _choices: VBoxContainer
var _hint: Label
var _evidence: Label
var _maletin: Control
var _expediente: Control
var _ultimo_apunte: String = ""
## Lo apuntado en este fotograma; se avisa una vez por lote.
var _recien_apuntado: Array[Dictionary] = []
var _esquina: Control
## Raíz del HUD; no coloca a sus hijos (para animaciones sueltas).
var _lienzo: Control
var _barra: Control
var _hallado: Label
var _citado: Label
## Lo que toca ahora, escrito por Whitehead. Ver guia.gd.
var _objetivo: Label
var _etapa_vista: String = ""
var _pausa: Control
var _boton_pausa: Button
var _pensamiento: Control
var _opciones: Control

## Tres reproductores en rueda: play() en uno que ya suena lo corta.
var _voces: Array[AudioStreamPlayer] = []
var _voz: int = 0

## id de personaje -> nombre para mostrar, sacado de data/characters.json.
var _nombres: Dictionary = {}


func _ready() -> void:
	layer = 20
	_cargar_nombres()
	_construir_voces()
	_build()

	DialogueRunner.line_shown.connect(_on_line_shown)
	DialogueRunner.choices_offered.connect(_on_choices_offered)
	DialogueRunner.dialogue_finished.connect(_on_dialogue_finished)
	Casefile.evidence_collected.connect(_on_evidence_collected)
	# Los apuntes también refrescan la esquina.
	Casefile.note_taken.connect(func(n: Dictionary):
		refresh_evidence()
		_apuntado(n))
	GameState.miasma_changed.connect(_on_miasma_changed)
	Cuaderno.palabra_aprendida.connect(_oir)
	Cuaderno.ficha_abierta.connect(_ficha_nueva)
	Cuaderno.ficha_sellada.connect(func(_id: String): refresh_evidence())
	DialogueRunner.ficha_pedida.connect(_al_pedir_ficha)

	# La esquina vuelve al cerrarse el expediente, lo cierre quien lo cierre.
	_expediente.cerrado.connect(func(): _esquina.visible = true)
	_expediente.presentada.connect(_al_presentar)

	_panel.hide()
	refresh_evidence()
	_on_miasma_changed(GameState.get_miasma())


func _construir_voces() -> void:
	for i in 3:
		var v := AudioStreamPlayer.new()
		# No 3D: la interfaz no tiene sitio en el mundo.
		v.bus = &"Interfaz"
		add_child(v)
		_voces.append(v)


func _sonar(s: AudioStream, db: float = 0.0) -> void:
	if s == null or _voces.is_empty():
		return
	var v := _voces[_voz]
	_voz = (_voz + 1) % _voces.size()
	v.stream = s
	v.volume_db = db
	v.play()


func _build() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = TEMA

	# El proyecto filtra en Nearest (pixel art); el HUD necesita Linear.
	root.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

	add_child(root)
	_lienzo = root

	_build_evidence(root)
	_build_dialogue(root)

	# Fuera de `root` (que es IGNORE): va encima y se come los clics.
	_expediente = EXPEDIENTE.new()
	_expediente.theme = TEMA
	add_child(_expediente)

	# Fuera de `root`: las burbujas tienen que recibir clics.
	_pensamiento = PENSAMIENTO.new()
	add_child(_pensamiento)
	_opciones = OPCIONES.new()
	add_child(_opciones)

	# La pausa, por encima de todo.
	_pausa = PAUSA.new()
	_pausa.theme = TEMA
	add_child(_pausa)

	_construir_boton_de_pausa(root)


## Esquina: maletín, cifras (Cards/Cited) e indicación de la guía.
func _build_evidence(root: Control) -> void:
	# Todo en un bloque, para ocultarlo entero al abrir el expediente.
	_esquina = VBoxContainer.new()
	_esquina.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_esquina.alignment = BoxContainer.ALIGNMENT_END
	_esquina.add_theme_constant_override("separation", 6)
	root.add_child(_esquina)
	_esquina.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_esquina.offset_left = -900.0
	_esquina.offset_top = 24.0
	_esquina.offset_right = -34.0
	_esquina.offset_bottom = 210.0

	var fila := HBoxContainer.new()
	fila.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fila.alignment = BoxContainer.ALIGNMENT_END
	fila.add_theme_constant_override("separation", 14)
	_esquina.add_child(fila)

	# Sin barra de miasma: la creencia de Whitehead solo se ve en la niebla.

	_maletin = MALETIN.new()
	_maletin.fuente = GARAMOND_SEMI
	_maletin.pulsado.connect(alternar_expediente)
	fila.add_child(_maletin)

	var cuentas := HBoxContainer.new()
	cuentas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cuentas.alignment = BoxContainer.ALIGNMENT_END
	cuentas.add_theme_constant_override("separation", 30)
	_esquina.add_child(cuentas)

	_hallado = _cifra("Found 0", 24)
	cuentas.add_child(_hallado)
	_citado = _cifra("Cited 0", 24)
	cuentas.add_child(_citado)

	# Lo que toca ahora (ver guia.gd), en recuadro gris.
	_objetivo = _indicacion(26)
	_objetivo.size_flags_horizontal = Control.SIZE_SHRINK_END
	# Las líneas largas parten en dos en vez de salirse de la pantalla.
	_objetivo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_esquina.add_child(_objetivo)

	# Aviso de lo apuntado, bajo la guía; crece hacia la izq.
	_evidence = _indicacion(22)
	_evidence.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_evidence.modulate.a = 0.0
	root.add_child(_evidence)
	_evidence.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_evidence.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_evidence.offset_top = 250.0
	_evidence.offset_right = -34.0
	_evidence.offset_left = -34.0


## Cifra de la esquina, con contorno para leerse de día y de noche.
func _cifra(t: String, tam: int) -> Label:
	var l := Label.new()
	l.text = t
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", GARAMOND_SEMI)
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", Color(0.95, 0.93, 0.86))
	l.add_theme_color_override("font_outline_color", Color(0.09, 0.08, 0.07))
	l.add_theme_constant_override("outline_size", 7)
	return l


## Enseña una nota al lado del maletín y la retira sola.
func _apunte(texto: String) -> void:
	if _evidence == null or texto.is_empty() or texto == _ultimo_apunte:
		return
	_ultimo_apunte = texto
	_evidence.text = texto
	var t := create_tween()
	t.tween_property(_evidence, "modulate:a", 1.0, 0.35)
	t.tween_interval(clampf(float(texto.length()) / 20.0, 4.5, 10.0))
	t.tween_property(_evidence, "modulate:a", 0.0, 0.8)


## Cada apunte vuela al maletín y avisa qué se apuntó y para qué.
func _apuntado(n: Dictionary) -> void:
	_recien_apuntado.append(n)
	if _recien_apuntado.size() == 1:
		_avisar_lo_apuntado.call_deferred()


func _avisar_lo_apuntado() -> void:
	var lote := _recien_apuntado.duplicate()
	_recien_apuntado.clear()
	if lote.is_empty():
		return
	_animar_guardado()
	var muertes := 0
	for n in lote:
		if bool(n.get("muerte", false)):
			muertes += 1
	var texto := ""
	if lote.size() == 1:
		texto = "Noted: " + String(lote[0].get("que", "something said in the street"))
	else:
		texto = "Noted: %d things." % lote.size()
	if not GUIA.aprendiendo():
		pass
	elif muertes == 1:
		texto += "\n1 death. Plot it on the map at home."
	elif muertes > 1:
		texto += "\n%d deaths. Plot them on the map at home." % muertes
	if not GameState.has_flag("vio_la_diferencia"):
		GameState.set_flag("vio_la_diferencia")
		texto += "\nFound: what people told you. Cited: what you can prove."
	_apunte(texto)


## Una hoja vuela de la caja de diálogo al maletín (acuse de recibo).
func _animar_guardado() -> void:
	if _maletin == null:
		return

	var papelito := Panel.new()
	papelito.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.95, 0.92, 0.84)
	estilo.border_color = Color(0.35, 0.28, 0.2)
	estilo.set_border_width_all(2)
	estilo.set_corner_radius_all(3)
	papelito.add_theme_stylebox_override("panel", estilo)
	papelito.size = Vector2(74, 96)
	papelito.pivot_offset = papelito.size * 0.5
	# Al lienzo: el maletín está en un contenedor que recolocaría la hoja.
	_lienzo.add_child(papelito)

	# Sale de la caja de diálogo si está abierta; si no, del centro.
	var pantalla: Vector2 = _lienzo.size
	var desde := Vector2(pantalla.x * 0.5, pantalla.y * 0.72)
	if _panel != null and _panel.visible:
		desde = _panel.global_position + Vector2(_panel.size.x * 0.5, 30.0)
	papelito.global_position = desde - papelito.size * 0.5

	var hasta := _maletin.global_position + _maletin.size * 0.5 - papelito.size * 0.5

	# Hoja al salir; cierre del maletín al llegar.
	_sonar(SON_GUARDAR, -3.0)

	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(papelito, "global_position", hasta, 0.62) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	t.tween_property(papelito, "scale", Vector2(0.25, 0.25), 0.62) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	t.tween_property(papelito, "rotation", 0.5, 0.62)
	t.tween_property(papelito, "modulate:a", 0.0, 0.2).set_delay(0.44)
	await t.finished
	papelito.queue_free()
	_sonar(SON_CIERRE, -4.0)
	_maletin.destacar()


## Abre o cierra el expediente. Lo llaman TAB y el maletín.
func alternar_expediente() -> void:
	if _expediente == null:
		return
	# No se abre en mitad de una conversación.
	if not _expediente.visible and DialogueRunner.active:
		return
	_sonar(SON_CIERRE if _expediente.visible else SON_GUARDAR, -7.0)
	_expediente.alternar()
	_esquina.visible = not _expediente.visible


func _build_dialogue(root: Control) -> void:
	_build_retrato(root)
	var margen := MarginContainer.new()
	margen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margen.add_theme_constant_override("margin_left", 60)
	margen.add_theme_constant_override("margin_right", 60)
	margen.add_theme_constant_override("margin_top", 40)
	margen.add_theme_constant_override("margin_bottom", 44)
	root.add_child(margen)

	var pila := VBoxContainer.new()
	pila.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pila.alignment = BoxContainer.ALIGNMENT_END
	margen.add_child(pila)

	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Ancho fijo (~70 caracteres por línea) y centrada.
	_panel.custom_minimum_size = Vector2(1220, 0)
	_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pila.add_child(_panel)

	# Caja de objeto: el mismo recorte de Kenney, teñido.
	_estilo_persona = TEMA.get_stylebox("panel", "PanelContainer")
	_estilo_cosa = _estilo_persona.duplicate()
	(_estilo_cosa as StyleBoxTexture).modulate_color = Color(0.42, 0.44, 0.46, 0.78)
	# Verde de Whitehead: el mismo recorte, teñido.
	_estilo_whitehead = _estilo_persona.duplicate()
	(_estilo_whitehead as StyleBoxTexture).modulate_color = Color(0.17, 0.33, 0.23, 1)

	# Fibra y grano de papel sobre el panel, sea del color que sea.
	var hoja := ShaderMaterial.new()
	hoja.shader = PAPEL
	_panel.material = hoja

	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 12)
	_panel.add_child(column)

	# Nombre en seminegrita espaciada, no en cursiva.
	_speaker = Label.new()
	_speaker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_speaker.add_theme_font_override("font", GARAMOND_SEMI)
	_speaker.add_theme_font_size_override("font_size", 25)
	_speaker.add_theme_color_override("font_color", TINTA_SUAVE)
	_speaker.add_theme_constant_override("line_spacing", 0)
	column.add_child(_speaker)

	_text = RichTextLabel.new()
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.scroll_active = false
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(0, 96)
	_text.add_theme_font_override("normal_font", GARAMOND)
	_text.add_theme_font_override("bold_font", GARAMOND_SEMI)
	_text.add_theme_font_size_override("normal_font_size", 32)
	_text.add_theme_font_size_override("bold_font_size", 32)
	_text.add_theme_color_override("default_color", TINTA)
	# Garamond tiene la x pequeña: necesita interlineado.
	_text.add_theme_constant_override("line_separation", 8)
	column.add_child(_text)

	_choices = VBoxContainer.new()
	_choices.add_theme_constant_override("separation", 8)
	column.add_child(_choices)

	_hint = Label.new()
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.text = "click or press space to continue"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.add_theme_font_override("font", GARAMOND_NOTA)
	_hint.add_theme_font_size_override("font_size", 21)
	_hint.add_theme_color_override("font_color", TINTA_SUAVE)
	column.add_child(_hint)


# --- Reacciones a las señales -------------------------------------------------

func _on_line_shown(node: Dictionary) -> void:
	_panel.show()
	_clear_choices()
	_vestir_caja(String(node.get("estilo", "persona")),
		String(node.get("hablante", "")) == QUIEN_ES_EL_JUGADOR)
	# Versalitas falsas (Garamond no trae small caps).
	var quien := String(node.get("hablante", ""))
	_speaker.text = _spaced(_nombre_de(quien))
	_text.text = _resaltar(String(node.get("texto", "")), Array(node.get("palabras", [])))
	_hint.show()
	_poner_retrato(quien, String(node.get("retrato", "")), String(node.get("estilo", "persona")))


## Pone la caja de conversación o la de objeto.
func _vestir_caja(estilo: String, soy_yo: bool) -> void:
	var es_cosa := estilo == "objeto"

	var fondo := _estilo_persona
	var tinta := TINTA
	var tinta_nombre := TINTA_SUAVE
	var tinta_pie := TINTA_SUAVE
	if es_cosa:
		fondo = _estilo_cosa
		tinta = TINTA_COSA
		tinta_pie = Color(0.82, 0.83, 0.82)
	elif soy_yo:
		fondo = _estilo_whitehead
		tinta = TINTA_WHITEHEAD
		tinta_nombre = NOMBRE_WHITEHEAD
		tinta_pie = Color(0.62, 0.82, 0.66)

	_panel.add_theme_stylebox_override("panel", fondo)
	# Una cosa no tiene nombre: el rótulo estorbaría.
	_speaker.visible = not es_cosa
	_speaker.horizontal_alignment = (HORIZONTAL_ALIGNMENT_RIGHT if soy_yo
		else HORIZONTAL_ALIGNMENT_LEFT)
	_speaker.add_theme_color_override("font_color", tinta_nombre)
	_text.add_theme_color_override("default_color", tinta)
	_tinta_texto = tinta
	_hint.add_theme_color_override("font_color", tinta_pie)


## Resalta palabras del cuaderno con el color de su tipo; escapa corchetes.
func _resaltar(texto: String, palabras: Array) -> String:
	var t := texto.replace("[", "[lb]")
	for id in palabras:
		var w := Cuaderno.palabra(String(id))
		if w.is_empty():
			continue
		var formas: Array = Array(w.get("formas", [w.get("texto", "")]))
		var color := Cuaderno.color_de(String(w.get("tipo", "")))
		if _caja_es_oscura():
			color = color.lightened(0.55)
		for f in formas:
			var forma := String(f)
			var re := RegEx.new()
			re.compile("\\b" + _escapar_regex(forma) + "\\b")
			var m := re.search(t)
			if m != null:
				t = t.substr(0, m.get_start()) + "[b][color=#%s]%s[/color][/b]" % [color.to_html(false), forma] + t.substr(m.get_end())
				break
	return t


func _caja_es_oscura() -> bool:
	return _tinta_texto.get_luminance() > 0.5


func _escapar_regex(s: String) -> String:
	var out := ""
	for c in s:
		out += ("\\" + c) if "\\.^$|?*+()[]{}".contains(c) else c
	return out


## Aviso del cuaderno: una línea con la última ficha nueva.
var _ficha_por_avisar: String = ""


func _oir(_id: String) -> void:
	if _maletin != null:
		_maletin.destacar()


func _ficha_nueva(id: String) -> void:
	var habia := not _ficha_por_avisar.is_empty()
	_ficha_por_avisar = id
	if not habia:
		_avisar_del_cuaderno.call_deferred()


func _avisar_del_cuaderno() -> void:
	var id := _ficha_por_avisar
	_ficha_por_avisar = ""
	if id.is_empty():
		return
	var texto := "New card in your notebook: %s." % String(Cuaderno.ficha(id).get("titulo", id))
	if not GameState.has_flag("vio_el_cuaderno"):
		GameState.set_flag("vio_el_cuaderno")
		texto += "\nPress TAB to fill it in."
	_animar_guardado()
	# Tras el primer día lo dicen los papeles del maletín.
	if GUIA.aprendiendo():
		_apunte(texto)
	refresh_evidence()


## Snow pide que se le enseñe algo: se abre el cuaderno para elegir.
func _al_pedir_ficha(pide: Dictionary) -> void:
	if _expediente == null:
		return
	_clear_choices()
	_expediente.presentar(String(pide.get("boton", "")))
	_esquina.visible = false


func _al_presentar(ficha_id: String) -> void:
	_esquina.visible = true
	if ficha_id.is_empty():
		DialogueRunner.reofrecer()
	else:
		DialogueRunner.presentar(ficha_id)


## Nombres de personaje (id -> nombre) desde characters.json.
func _cargar_nombres() -> void:
	var f := FileAccess.open("res://data/characters.json", FileAccess.READ)
	if f == null:
		push_warning("HUD: no encuentro characters.json; mostraré los ids tal cual.")
		return
	var datos = JSON.parse_string(f.get_as_text())
	if typeof(datos) != TYPE_DICTIONARY:
		return
	for id in datos:
		_nombres[id] = String(datos[id].get("nombre", id))


## Si el id no está en la lista, se muestra tal cual.
func _nombre_de(id: String) -> String:
	return String(_nombres.get(id, id))


## Letras espaciadas y en mayúsculas: el nombre como rótulo.
func _spaced(texto: String) -> String:
	if texto.is_empty():
		return ""
	var salida := ""
	for i in texto.length():
		salida += texto[i]
		if i < texto.length() - 1:
			salida += " "  # espacio fino
	return salida.to_upper()


func _on_choices_offered(choices: Array) -> void:
	_hint.hide()
	# Limpiar antes, o se reconectan señales a botones viejos.
	_clear_choices()
	for i in choices.size():
		var button := Button.new()
		button.text = String(choices[i].get("texto", "..."))
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(_on_choice_pressed.bind(i))
		_choices.add_child(button)
	if _choices.get_child_count() > 0:
		(_choices.get_child(0) as Button).grab_focus()

	# Sonido conectado tras dar el foco, para que no suene solo al abrir.
	for hijo in _choices.get_children():
		var b := hijo as Button
		if b == null or b.is_queued_for_deletion():
			continue
		b.focus_entered.connect(_sonar.bind(SON_PASAR, -6.0))
		b.mouse_entered.connect(_sonar.bind(SON_PASAR, -6.0))


func _on_choice_pressed(index: int) -> void:
	_sonar(SON_ELEGIR, -3.0)
	_clear_choices()
	DialogueRunner.choose(index)


func _on_dialogue_finished(_dialogue_id: String) -> void:
	_clear_choices()
	_panel.hide()
	_quitar_retrato()


# --- El retrato ---------------------------------------------------------------
# Estilo Ace Attorney: art/portraits/<quien>/<gesto>.png, o neutro.png.

signal retrato_visible(si: bool, quien: String)

const RETRATOS := "res://art/portraits/"
const RETRATO_ENTRA := 0.28

var _velo: ColorRect
var _retrato: TextureRect
var _retrato_de: String = ""


func _build_retrato(root: Control) -> void:
	_velo = ColorRect.new()
	_velo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_velo.color = Color(0.03, 0.03, 0.04, 0.0)
	_velo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(_velo)

	_retrato = TextureRect.new()
	_retrato.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_retrato.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_retrato.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# Abajo y al centro; la caja de diálogo le tapa el pecho.
	_retrato.anchor_left = 0.2
	_retrato.anchor_right = 0.8
	_retrato.anchor_top = 0.12
	_retrato.anchor_bottom = 1.0
	_retrato.modulate.a = 0.0
	root.add_child(_retrato)


## La ruta del dibujo de alguien con un gesto, o vacío si no hay.
func _ruta_retrato(quien: String, gesto: String) -> String:
	for nombre in [gesto, "neutro"]:
		if String(nombre).is_empty():
			continue
		for ext in ["png", "webp", "svg"]:
			var ruta := "%s%s/%s.%s" % [RETRATOS, quien, nombre, ext]
			if ResourceLoader.exists(ruta):
				return ruta
	return ""


func _poner_retrato(quien: String, gesto: String, estilo: String) -> void:
	if _retrato == null:
		return
	# Mientras habla Whitehead se queda el otro; un objeto no lleva retrato.
	if quien == QUIEN_ES_EL_JUGADOR:
		return
	if estilo == "objeto":
		_quitar_retrato()
		return
	var ruta := _ruta_retrato(quien, gesto)
	if ruta.is_empty():
		_quitar_retrato()
		return
	var nuevo := quien != _retrato_de
	_retrato.texture = load(ruta) as Texture2D
	_retrato_de = quien
	if nuevo:
		# Entra desde un poco más abajo, como quien se asoma.
		_retrato.position.y = 40.0
		var t := create_tween().set_parallel(true)
		t.tween_property(_retrato, "modulate:a", 1.0, RETRATO_ENTRA)
		t.tween_property(_retrato, "position:y", 0.0, RETRATO_ENTRA) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		t.tween_property(_velo, "color:a", 0.38, RETRATO_ENTRA)
		retrato_visible.emit(true, quien)


func _quitar_retrato() -> void:
	if _retrato == null or _retrato_de.is_empty():
		return
	var quien := _retrato_de
	_retrato_de = ""
	var t := create_tween().set_parallel(true)
	t.tween_property(_retrato, "modulate:a", 0.0, RETRATO_ENTRA * 0.8)
	t.tween_property(_velo, "color:a", 0.0, RETRATO_ENTRA * 0.8)
	retrato_visible.emit(false, quien)


func _hay_expediente_abierto() -> bool:
	return _expediente != null and _expediente.visible


## Escenas sin pausa (por trozo de ruta): menú, cinemática, fin de capítulo.
const SIN_PAUSA: PackedStringArray = ["menu_", "cinematica", "main.tscn", "fin_capitulo"]


## Botón de pausa visible, arriba a la izq. (la der. es del maletín).
func _construir_boton_de_pausa(padre: Control) -> void:
	_boton_pausa = Button.new()
	_boton_pausa.tooltip_text = "Pause (Esc)"
	_boton_pausa.custom_minimum_size = Vector2(46, 42)
	_boton_pausa.focus_mode = Control.FOCUS_NONE
	_boton_pausa.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for estado in ["normal", "hover", "pressed", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.90, 0.86, 0.76, 0.92) if estado == "hover" \
			else Color(0.84, 0.80, 0.70, 0.82)
		sb.border_color = Color(0.44, 0.37, 0.28)
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(3)
		sb.content_margin_left = 14.0
		sb.content_margin_right = 14.0
		sb.content_margin_top = 4.0
		sb.content_margin_bottom = 4.0
		_boton_pausa.add_theme_stylebox_override(estado, sb)
	# Dos barras: el símbolo de pausa.
	var barras := Control.new()
	barras.mouse_filter = Control.MOUSE_FILTER_IGNORE
	barras.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	barras.draw.connect(func():
		var c := barras.size * 0.5
		for dx in [-6.0, 6.0]:
			barras.draw_rect(Rect2(c + Vector2(dx - 3.0, -10.0), Vector2(6.0, 20.0)), Color(0.22, 0.18, 0.13)))
	_boton_pausa.add_child(barras)
	_boton_pausa.pressed.connect(func():
		if _se_puede_parar() and not _hay_expediente_abierto():
			_pausa.abrir())
	padre.add_child(_boton_pausa)
	_boton_pausa.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_boton_pausa.position = Vector2(24.0, 24.0)
	# Sondeo cada 0.2 s: depende de escena, expediente y diálogo.
	var reloj := Timer.new()
	reloj.wait_time = 0.2
	reloj.autostart = true
	reloj.timeout.connect(_refrescar_boton_de_pausa)
	reloj.timeout.connect(_vigilar_la_guia)
	add_child(reloj)
	_refrescar_boton_de_pausa()


## Solo donde se puede parar, sin expediente ni conversación.
func _refrescar_boton_de_pausa() -> void:
	if _boton_pausa == null:
		return
	_boton_pausa.visible = _se_puede_parar() and not _hay_expediente_abierto() \
		and not DialogueRunner.active


## Recuadro gris de indicación (habla el juego, no Whitehead).
func _indicacion(tam: int) -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", GARAMOND_SEMI)
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", Color(0.97, 0.96, 0.93))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.30, 0.30, 0.31, 0.90)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 18.0
	sb.content_margin_right = 18.0
	sb.content_margin_top = 7.0
	sb.content_margin_bottom = 9.0
	l.add_theme_stylebox_override("normal", sb)
	return l


## Actualiza la guía (guia.gd); destella al cambiar de etapa.
func _vigilar_la_guia() -> void:
	if _objetivo == null or get_tree().paused:
		return
	var e := GUIA.etapa()
	var linea := String(e.get("linea", ""))
	if _maletin != null:
		_maletin.poner_papeles(_fichas_por_rellenar())
	if _objetivo.text != linea:
		_objetivo.text = linea
		var ancho := GARAMOND_SEMI.get_string_size(linea, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x + 40.0
		_objetivo.custom_minimum_size.x = minf(ancho, 820.0)
	_objetivo.visible = not linea.is_empty() and _se_puede_parar()
	var id := String(e.get("id", ""))
	if id != _etapa_vista:
		_etapa_vista = id
		if _objetivo.visible:
			_objetivo.modulate = Color(1.5, 1.5, 1.4)
			create_tween().tween_property(_objetivo, "modulate", Color.WHITE, 2.0)


## Fichas sin sellar que ya se pueden rellenar (o llenas y mal).
func _fichas_por_rellenar() -> int:
	var n := 0
	for id in Cuaderno.abiertas():
		if not Cuaderno.sellada(id) and (Cuaderno.completa(id) or Cuaderno.se_puede_completar(id)):
			n += 1
	return n


## Muestra u oculta la esquina (p.ej. en el entierro).
func esquina(si: bool) -> void:
	if _esquina != null:
		_esquina.visible = si


func _se_puede_parar() -> bool:
	if get_tree().paused:
		return false
	var escena := get_tree().current_scene
	if escena == null:
		return false
	var ruta := escena.scene_file_path
	for trozo in SIN_PAUSA:
		if ruta.contains(trozo):
			return false
	return true


## La niebla (art_style.gd) escucha esta misma señal.
func _on_miasma_changed(valor: float) -> void:
	if _barra != null:
		_barra.poner(valor)


func _on_evidence_collected(id: String) -> void:
	refresh_evidence()
	_animar_guardado()
	var entry := EvidenceDB.get_entry(id)
	print("[Expediente] Nueva prueba: ", entry.get("hecho", id))


# --- Auxiliares ---------------------------------------------------------------

func _clear_choices() -> void:
	for child in _choices.get_children():
		# remove_child ya, o el foco nuevo puede caer en un botón viejo.
		_choices.remove_child(child)
		child.queue_free()


## Actualiza las cifras de la esquina y el estado del argumento de la escena.
func refresh_evidence() -> void:
	# Cifra del maletín.
	if _maletin != null:
		_maletin.poner_cuenta(Casefile.count())
	if _hallado != null:
		# Fichas selladas de las abiertas.
		var abiertas := Cuaderno.abiertas().size()
		_hallado.text = ("Cards %d of %d" % [Cuaderno.selladas().size(), abiertas]) if abiertas > 0 else "Cards 0"
	if _citado != null:
		_citado.text = "Cited %d" % Casefile.count()

	var scene_info := get_tree().get_first_node_in_group("scene_info")
	if scene_info == null:
		return

	var here: int = scene_info.collected_here()
	var goal: int = scene_info.total_here()
	if goal <= 0:
		return

	_apunte(_argument_state(here, goal))


## Estado del argumento en palabras, en vez de "1 de 2".
func _argument_state(here: int, goal: int) -> String:
	if here <= 0:
		return "nothing written down yet; only what people say"
	if here < goal:
		return "one case is not a pattern; keep asking"
	return "there is nothing left to ask here"


## Toda la entrada del HUD, en una sola función: pausa, expediente, diálogo.
func _unhandled_input(event: InputEvent) -> void:
	# Pausa primero, salvo con el expediente abierto (Escape lo cierra).
	# También ui_cancel: un editor abierto antes de añadir `pausa` no la conoce.
	if (event.is_action_pressed("pausa") or event.is_action_pressed("ui_cancel")) \
			and not _hay_expediente_abierto() and _se_puede_parar():
		get_viewport().set_input_as_handled()
		_pausa.abrir()
		return

	if _expediente != null:
		if event.is_action_pressed("casefile"):
			alternar_expediente()
			get_viewport().set_input_as_handled()
			return
		if _expediente.visible:
			if event.is_action_pressed("ui_cancel"):
				alternar_expediente()
				get_viewport().set_input_as_handled()
			return

	if not DialogueRunner.active:
		return
	if _choices.get_child_count() > 0:
		return  # hay que elegir; no se puede avanzar sin más

	var advance := false
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		advance = mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT
	elif event.is_action_pressed("ui_accept"):
		advance = true

	if advance:
		get_viewport().set_input_as_handled()
		DialogueRunner.advance()


# --- Pensamientos y preguntas en el mundo -------------------------------------

## Pensamiento de Whitehead: un renglón sin caja que no bloquea.
func pensar(frase: String) -> void:
	if _pensamiento != null:
		_pensamiento.pensar(frase)


## Pregunta pegada a un objeto; devuelve el índice, o -1 si se cancela.
##     var cual := await HUD.preguntar_en(la_esquina, ["Go home", "Not yet"])
func preguntar_en(ancla: Node3D, opciones: Array) -> int:
	if _opciones == null:
		return -1
	return await _opciones.preguntar(ancla, opciones)
