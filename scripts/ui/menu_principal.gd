extends Control
## Menú principal de la serie. Textos en series.json; aspecto en tema_soho.tres.

const TEMA := preload("res://art/ui/tema_soho.tres")
const PINYON := preload("res://art/fonts/Pinyon_Script/PinyonScript-Regular.ttf")
const GARAMOND := preload("res://art/fonts/EB_Garamond/static/EBGaramond-Regular.ttf")
const GARAMOND_SEMI := preload("res://art/fonts/EB_Garamond/static/EBGaramond-SemiBold.ttf")
const GARAMOND_NOTA := preload("res://art/fonts/EB_Garamond/static/EBGaramond-Regular.ttf")

const SON_PASAR := preload("res://audio/sfx/ui/pasar.wav")
const SON_ELEGIR := preload("res://audio/sfx/ui/elegir.wav")
const SON_ABRIR := preload("res://audio/sfx/ui/maletin_abrir.wav")
const SON_CERRAR := preload("res://audio/sfx/ui/maletin_cerrar.wav")
const AMBIENTE := preload("res://audio/music/amb_calle.wav")

const SERIE := "res://data/series.json"
const CINEMATICA := "res://scenes/ui/cinematica.tscn"

## Paleta: nada de negro ni blanco puros.
const NOCHE := Color(0.055, 0.062, 0.058)
const GAS := Color(0.93, 0.87, 0.72)
const TINTA_CLARA := Color(0.78, 0.76, 0.70)
const VERDIGRIS := Color(0.36, 0.40, 0.24)

var _serie: Dictionary = {}
var _titulo: Label
var _hoja: PanelContainer
var _nieblas: Array[TextureRect] = []
var _voz: AudioStreamPlayer
var _ambiente: AudioStreamPlayer
var _t: float = 0.0


func _ready() -> void:
	# El HUD es autoload: ocultarlo en el menú.
	HUD.hide()

	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = TEMA
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

	_serie = _leer_serie()
	_construir_voces()
	_construir_fondo()
	_construir_titulo()
	_construir_botones()
	_construir_pie()
	_construir_hoja()


func _leer_serie() -> Dictionary:
	var f := FileAccess.open(SERIE, FileAccess.READ)
	if f == null:
		push_error("MenuPrincipal: no encuentro " + SERIE)
		return {}
	var d = JSON.parse_string(f.get_as_text())
	return d if typeof(d) == TYPE_DICTIONARY else {}


## El episodio que se juega ahora mismo: el primero que no esté cerrado.
func _episodio_activo() -> Dictionary:
	for e in Array(_serie.get("events", [])):
		if typeof(e) == TYPE_DICTIONARY and bool(e.get("remembered", false)):
			return e
	return {}


# --- Fondo --------------------------------------------------------------------

## Fondo procedural: dos capas de niebla y una viñeta.
func _construir_fondo() -> void:
	var base := ColorRect.new()
	base.color = NOCHE
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(base)
	base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_nieblas.append(_capa_de_niebla(0.5, Color(VERDIGRIS.r, VERDIGRIS.g, VERDIGRIS.b, 0.15), 3.4))
	_nieblas.append(_capa_de_niebla(1.7, Color(0.55, 0.58, 0.52, 0.10), 1.9))

	# Viñeta: degradado radial que oscurece los bordes.
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.35, 1.0])
	g.colors = PackedColorArray([Color(0, 0, 0, 0.0), Color(0.02, 0.02, 0.02, 0.85)])

	var vg := GradientTexture2D.new()
	vg.gradient = g
	vg.fill = GradientTexture2D.FILL_RADIAL
	vg.fill_from = Vector2(0.5, 0.45)
	vg.fill_to = Vector2(1.05, 1.0)
	vg.width = 256
	vg.height = 256

	var vineta := TextureRect.new()
	vineta.texture = vg
	vineta.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vineta.stretch_mode = TextureRect.STRETCH_SCALE
	vineta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vineta)
	vineta.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _capa_de_niebla(frecuencia: float, tinte: Color, escala: float) -> TextureRect:
	var ruido := FastNoiseLite.new()
	ruido.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	ruido.frequency = 0.004 * frecuencia
	ruido.fractal_octaves = 3

	var tex := NoiseTexture2D.new()
	tex.noise = ruido
	# Sin costura para repetirse sin saltos.
	tex.seamless = true
	tex.width = 512
	tex.height = 512

	var capa := TextureRect.new()
	capa.texture = tex
	capa.stretch_mode = TextureRect.STRETCH_TILE
	capa.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	capa.modulate = tinte
	capa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capa.scale = Vector2(escala, escala)
	add_child(capa)
	# Más grande que la pantalla para que al desplazarla no asome el borde.
	capa.size = Vector2(4200, 2600)
	capa.position = Vector2(-600, -400)
	capa.set_meta("deriva", 7.0 / escala)
	return capa


func _process(delta: float) -> void:
	_t += delta
	for capa in _nieblas:
		if is_instance_valid(capa):
			capa.position.x -= float(capa.get_meta("deriva", 6.0)) * delta
			if capa.position.x < -1400.0:
				capa.position.x += 800.0

	# Parpadeo del gas: 3 senos de periodos no múltiplos (no randf).
	if _titulo != null:
		var l := 0.90 \
			+ 0.055 * sin(_t * 1.7) \
			+ 0.035 * sin(_t * 4.3 + 1.1) \
			+ 0.020 * sin(_t * 9.1 + 2.7)
		_titulo.modulate = Color(l, l * 0.985, l * 0.94)


# --- Título -------------------------------------------------------------------

func _construir_titulo() -> void:
	var caja := VBoxContainer.new()
	caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caja.alignment = BoxContainer.ALIGNMENT_CENTER
	caja.add_theme_constant_override("separation", 6)
	add_child(caja)
	caja.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	caja.offset_top = 140.0
	caja.offset_bottom = 470.0

	# Pinyon Script solo en rótulos cortos.
	_titulo = Label.new()
	_titulo.text = String(_serie.get("title", "UNTITLED"))
	_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_titulo.add_theme_font_override("font", PINYON)
	_titulo.add_theme_font_size_override("font_size", 150)
	_titulo.add_theme_color_override("font_color", GAS)
	_titulo.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	_titulo.add_theme_constant_override("shadow_offset_x", 0)
	_titulo.add_theme_constant_override("shadow_offset_y", 6)
	_titulo.add_theme_constant_override("shadow_outline_size", 14)
	caja.add_child(_titulo)

	var lema := Label.new()
	lema.text = String(_serie.get("tagline", ""))
	lema.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lema.add_theme_font_override("font", GARAMOND_NOTA)
	lema.add_theme_font_size_override("font_size", 27)
	lema.add_theme_color_override("font_color", Color(TINTA_CLARA.r, TINTA_CLARA.g, TINTA_CLARA.b, 0.72))
	caja.add_child(lema)

	var ep := _episodio_activo()
	var linea := Label.new()
	linea.text = _espaciado("%s   ·   %s" % [
		String(ep.get("name", "")), String(ep.get("year", ""))])
	linea.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	linea.add_theme_font_override("font", GARAMOND_SEMI)
	linea.add_theme_font_size_override("font_size", 22)
	linea.add_theme_color_override("font_color", Color(0.62, 0.66, 0.58))
	caja.add_child(linea)


## Versalitas falsas: letras separadas por espacios.
func _espaciado(s: String) -> String:
	var out := ""
	for i in s.length():
		out += s[i]
		if i < s.length() - 1:
			out += " "
	return out


# --- Botones ------------------------------------------------------------------

func _construir_botones() -> void:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	add_child(col)
	col.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	col.offset_left = -230.0
	col.offset_right = 230.0
	col.offset_top = 560.0
	col.offset_bottom = 1000.0

	_boton(col, "Comenzar una vida", _comenzar)

	# Continuar solo si hay partida.
	if SaveSystem.has_save():
		_boton(col, "Continuar", _continuar)

	_boton(col, "Events", _abrir_episodios)

	_boton(col, "Fuentes", _abrir_fuentes)

	# En web quit() no hace nada.
	if not OS.has_feature("web"):
		_boton(col, "Salir", func(): get_tree().quit())


func _boton(padre: Node, texto: String, accion: Callable) -> Button:
	var b := Button.new()
	b.text = texto
	b.custom_minimum_size = Vector2(0, 62)
	b.add_theme_font_override("font", GARAMOND)
	b.add_theme_font_size_override("font_size", 30)
	b.add_theme_color_override("font_color", Color(0.20, 0.15, 0.10))
	b.add_theme_color_override("font_hover_color", Color(0.97, 0.94, 0.86))
	b.add_theme_color_override("font_pressed_color", Color(0.20, 0.15, 0.10))
	padre.add_child(b)
	b.mouse_entered.connect(func(): _sonar(SON_PASAR, -13.0))
	b.pressed.connect(func():
		_sonar(SON_ELEGIR, -5.0)
		accion.call())
	return b


# --- Acciones -----------------------------------------------------------------

func _comenzar() -> void:
	# Partida nueva: limpiar el estado de la anterior.
	GameState.reset()
	Casefile.reset()
	Barrio.reset()
	Cronometro.reset()
	_apagar_ambiente()
	SceneRouter.change_scene(CINEMATICA, SceneRouter.Kind.JOURNAL)


func _continuar() -> void:
	if not SaveSystem.load_game():
		push_warning("MenuPrincipal: la partida no se pudo cargar.")
		return
	var ep := _episodio_activo()
	var destino := String(ep.get("scene", ""))
	if destino.is_empty():
		push_error("MenuPrincipal: el episodio activo no declara escena.")
		return
	_apagar_ambiente()
	HUD.show()
	SceneRouter.change_scene(destino, SceneRouter.Kind.SHORT_FADE)


## Lista los episodios ya recordados.
func _abrir_episodios() -> void:
	var lineas: Array[String] = []
	for e in Array(_serie.get("events", [])):
		if typeof(e) != TYPE_DICTIONARY:
			continue
		if not bool(e.get("remembered", false)):
			continue
		lineas.append("%s · %s · %s\n        %s\n" % [
			String(e.get("name", "")),
			String(e.get("place", "")),
			String(e.get("year", "")),
			String(e.get("host", "")),
		])
	_mostrar_hoja("Events", "\n".join(lineas))


func _abrir_fuentes() -> void:
	var citas: Array[String] = []
	for id in EvidenceDB.all_ids():
		var e: Dictionary = EvidenceDB.get_entry(String(id))
		var cita := String(e.get("cita_mla", "")).strip_edges()
		if cita.is_empty():
			continue
		if String(e.get("verificado", "pendiente")) != "si":
			cita += "     [sin verificar]"
		if not cita in citas:
			citas.append(cita)
	citas.sort()

	var cabecera := "Todo lo que se afirma en este juego sale de uno de estos documentos. "
	cabecera += "Los principales son de dominio público y se pueden leer enteros.\n\n"
	_mostrar_hoja("Fuentes", cabecera + "\n\n".join(citas))


# --- La hoja (Episodios y Fuentes usan la misma) ------------------------------

## Una sola hoja para Episodios y Fuentes.
func _construir_hoja() -> void:
	_hoja = PanelContainer.new()
	_hoja.visible = false
	add_child(_hoja)
	_hoja.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hoja.offset_left = 250.0
	_hoja.offset_right = -250.0
	_hoja.offset_top = 80.0
	_hoja.offset_bottom = -80.0

	var margen := MarginContainer.new()
	for lado in ["left", "right", "top", "bottom"]:
		margen.add_theme_constant_override("margin_" + lado, 44)
	_hoja.add_child(margen)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	margen.add_child(col)

	var titulo := Label.new()
	titulo.name = "Titulo"
	titulo.add_theme_font_override("font", GARAMOND_SEMI)
	titulo.add_theme_font_size_override("font_size", 38)
	titulo.add_theme_color_override("font_color", Color(0.16, 0.12, 0.09))
	col.add_child(titulo)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(scroll)

	var cuerpo := Label.new()
	cuerpo.name = "Cuerpo"
	cuerpo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cuerpo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cuerpo.custom_minimum_size = Vector2(900, 0)
	cuerpo.add_theme_font_override("font", GARAMOND)
	cuerpo.add_theme_font_size_override("font_size", 24)
	cuerpo.add_theme_color_override("font_color", Color(0.16, 0.12, 0.09))
	cuerpo.add_theme_constant_override("line_spacing", 8)
	scroll.add_child(cuerpo)

	var cerrar := Button.new()
	cerrar.text = "Cerrar"
	cerrar.custom_minimum_size = Vector2(0, 56)
	cerrar.add_theme_font_override("font", GARAMOND)
	cerrar.add_theme_font_size_override("font_size", 26)
	cerrar.add_theme_color_override("font_color", Color(0.20, 0.15, 0.10))
	col.add_child(cerrar)
	cerrar.pressed.connect(_cerrar_hoja)


func _mostrar_hoja(titulo: String, cuerpo: String) -> void:
	var t := _hoja.find_child("Titulo", true, false) as Label
	var c := _hoja.find_child("Cuerpo", true, false) as Label
	if t != null:
		t.text = titulo
	if c != null:
		c.text = cuerpo
	_hoja.show()
	_sonar(SON_ABRIR, -7.0)


func _cerrar_hoja() -> void:
	_hoja.hide()
	_sonar(SON_CERRAR, -7.0)


func _unhandled_input(event: InputEvent) -> void:
	if _hoja != null and _hoja.visible and event.is_action_pressed("ui_cancel"):
		_cerrar_hoja()
		get_viewport().set_input_as_handled()


# --- Pie y sonido -------------------------------------------------------------

func _construir_pie() -> void:
	var pie := Label.new()
	pie.text = "Un juego de %s" % String(_serie.get("studio", ""))
	pie.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pie.add_theme_font_override("font", GARAMOND_NOTA)
	pie.add_theme_font_size_override("font_size", 21)
	pie.add_theme_color_override("font_color", Color(TINTA_CLARA.r, TINTA_CLARA.g, TINTA_CLARA.b, 0.45))
	add_child(pie)
	pie.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	pie.offset_left = 48.0
	pie.offset_top = -72.0
	pie.offset_right = 700.0
	pie.offset_bottom = -32.0


func _construir_voces() -> void:
	_voz = AudioStreamPlayer.new()
	_voz.bus = &"Interfaz"
	add_child(_voz)

	# Ambiente de calle bajo el menú.
	_ambiente = AudioStreamPlayer.new()
	_ambiente.bus = &"Ambiente"
	_ambiente.stream = AMBIENTE
	_ambiente.volume_db = -17.0
	if _ambiente.stream is AudioStreamWAV:
		(_ambiente.stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	add_child(_ambiente)
	_ambiente.play()


func _apagar_ambiente() -> void:
	if _ambiente == null:
		return
	var t := create_tween()
	t.tween_property(_ambiente, "volume_db", -40.0, 0.4)


func _sonar(s: AudioStream, db: float) -> void:
	if _voz == null:
		return
	_voz.stream = s
	_voz.volume_db = db
	_voz.play()
