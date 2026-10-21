extends Control
## Cinemática: pasa cartas de texto de un JSON, con fundidos por reloj.

const PINYON := preload("res://art/fonts/Pinyon_Script/PinyonScript-Regular.ttf")
const GARAMOND_NOTA := preload("res://art/fonts/EB_Garamond/static/EBGaramond-Regular.ttf")
const GARAMOND_SEMI := preload("res://art/fonts/EB_Garamond/static/EBGaramond-SemiBold.ttf")

const SON_PASAR := preload("res://audio/sfx/ui/pasar.wav")

const SERIE := "res://data/series.json"

## JSON de la cinemática; el menú lo fija antes de cargar la escena.
@export var cinematica: String = "res://data/cinematicas/soho_1854.json"

## Fundidos máximos (s); se acortan en cartas cortas (ver _pasar_a).
const ENTRADA := 1.0
const SALIDA := 0.8
const MINIMO_EN_PANTALLA := 0.5

## Qué parte de la carta puede ocupar cada fundido cuando la carta es corta.
const FRACCION_ENTRADA := 0.28
const FRACCION_SALIDA := 0.24

var _entrada: float = ENTRADA
var _salida: float = SALIDA

const GAS := Color(0.93, 0.87, 0.72)
const TINTA_CLARA := Color(0.86, 0.84, 0.78)

var _datos: Dictionary = {}
var _cartas: Array = []
var _serie: Dictionary = {}

var _i: int = -1
var _tiempo: float = 0.0
var _duracion: float = 0.0
var _terminada: bool = false

var _fondo: ColorRect
var _texto: Label
var _lema: Label
var _pista: Label
var _voz: AudioStreamPlayer
var _ambiente: AudioStreamPlayer


func _ready() -> void:
	HUD.hide()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_datos = _leer(cinematica)
	_serie = _leer(SERIE)
	_cartas = Array(_datos.get("cartas", []))

	_construir()
	_sonar_ambiente()
	if bool(_datos.get("campana", false)):
		var campana := AudioStreamPlayer.new()
		campana.stream = preload("res://scripts/campana.gd").sonido()
		campana.volume_db = -6.0
		add_child(campana)
		campana.play()
	if bool(_datos.get("bomba", false)):
		_bombear_de_fondo()

	if _cartas.is_empty():
		push_error("Cinematica: %s no tiene cartas." % cinematica)
		_terminar()
		return
	_pasar_a(0)


## Al fondo, alguien saca agua: cubo, tres golpes de palanca y el chorro.
func _bombear_de_fondo() -> void:
	const SONIDOS := preload("res://scripts/sonidos_bomba.gd")
	var p := AudioStreamPlayer.new()
	p.bus = &"Ambiente"
	p.volume_db = -16.0
	add_child(p)
	var agua := AudioStreamPlayer.new()
	agua.bus = &"Ambiente"
	agua.volume_db = -18.0
	add_child(agua)
	await get_tree().create_timer(4.0).timeout
	for s in [SONIDOS.cubo(), null, SONIDOS.palanca(), SONIDOS.palanca(), SONIDOS.palanca()]:
		if not is_inside_tree():
			return
		if s != null:
			p.stream = s
			p.play()
			if s == SONIDOS.palanca():
				agua.stream = SONIDOS.chorro()
				agua.play()
		await get_tree().create_timer(1.1).timeout


func _leer(ruta: String) -> Dictionary:
	var f := FileAccess.open(ruta, FileAccess.READ)
	if f == null:
		push_error("Cinematica: no encuentro " + ruta)
		return {}
	var d = JSON.parse_string(f.get_as_text())
	return d if typeof(d) == TYPE_DICTIONARY else {}


# --- Montaje ------------------------------------------------------------------

func _construir() -> void:
	_fondo = ColorRect.new()
	_fondo.color = Color(0.03, 0.035, 0.03)
	_fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fondo)
	_fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var caja := VBoxContainer.new()
	caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caja.alignment = BoxContainer.ALIGNMENT_CENTER
	caja.add_theme_constant_override("separation", 22)
	add_child(caja)
	caja.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Márgenes anchos para que las líneas se lean bien.
	caja.offset_left = 340.0
	caja.offset_right = -340.0

	_texto = Label.new()
	_texto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_texto.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_texto.add_theme_constant_override("line_spacing", 14)
	caja.add_child(_texto)

	_lema = Label.new()
	_lema.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lema.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lema.add_theme_font_override("font", GARAMOND_NOTA)
	_lema.add_theme_font_size_override("font_size", 27)
	_lema.add_theme_color_override("font_color", Color(TINTA_CLARA.r, TINTA_CLARA.g, TINTA_CLARA.b, 0.7))
	_lema.visible = false
	caja.add_child(_lema)

	# La pista se retira sola a los 6 s.
	_pista = Label.new()
	_pista.text = "space to continue   ·   esc to skip"
	_pista.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pista.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_pista.add_theme_font_override("font", GARAMOND_NOTA)
	_pista.add_theme_font_size_override("font_size", 20)
	_pista.add_theme_color_override("font_color", Color(0.7, 0.7, 0.66, 0.5))
	add_child(_pista)
	_pista.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_pista.offset_left = -700.0
	_pista.offset_top = -70.0
	_pista.offset_right = -60.0
	_pista.offset_bottom = -34.0
	var t := create_tween()
	t.tween_interval(6.0)
	t.tween_property(_pista, "modulate:a", 0.0, 1.5)

	_voz = AudioStreamPlayer.new()
	_voz.bus = &"Interfaz"
	add_child(_voz)


func _sonar_ambiente() -> void:
	var ruta := String(_datos.get("sonido_ambiente", ""))
	if ruta.is_empty() or not ResourceLoader.exists(ruta):
		return
	_ambiente = AudioStreamPlayer.new()
	_ambiente.bus = &"Ambiente"
	_ambiente.stream = load(ruta)
	_ambiente.volume_db = -14.0
	if _ambiente.stream is AudioStreamWAV:
		(_ambiente.stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	add_child(_ambiente)
	_ambiente.play()


# --- Las cartas ---------------------------------------------------------------

func _pasar_a(i: int) -> void:
	if i >= _cartas.size():
		_terminar()
		return

	_i = i
	_tiempo = 0.0
	var carta: Dictionary = _cartas[i]
	_duracion = maxf(MINIMO_EN_PANTALLA, float(carta.get("segundos", 5.0)))
	_entrada = minf(ENTRADA, _duracion * FRACCION_ENTRADA)
	_salida = minf(SALIDA, _duracion * FRACCION_SALIDA)

	var voz := String(carta.get("voz", "memoria"))
	var texto := String(carta.get("texto", ""))

	# El título sale de series.json.
	if voz == "titulo":
		texto = String(_serie.get("title", ""))
		_lema.text = String(_serie.get("tagline", ""))
		_lema.visible = true
		_lema.modulate.a = 0.0
	else:
		_lema.visible = false

	_texto.text = _espaciado(texto) if voz == "rotulo" else texto
	_vestir(voz)
	_texto.modulate.a = 0.0

	var color := _color(String(carta.get("color", "")))
	# El fondo se funde durante la carta, más lento que el texto.
	var t := create_tween()
	t.tween_property(_fondo, "color", color, _duracion * 0.8)

	_sonar(SON_PASAR, -20.0)


func _vestir(voz: String) -> void:
	match voz:
		"titulo":
			# Fuente por defecto (provisional), igual que en la pantalla de título.
			_texto.remove_theme_font_override("font")
			_texto.add_theme_font_size_override("font_size", 78)
			_texto.add_theme_color_override("font_color", GAS)
			_texto.text = _espaciado(_texto.text.to_upper())
		"rotulo":
			_texto.add_theme_font_override("font", GARAMOND_SEMI)
			_texto.add_theme_font_size_override("font_size", 30)
			_texto.add_theme_color_override("font_color", Color(0.62, 0.66, 0.58))
		_:
			# Memoria: cursiva, la misma de los pensamientos de Whitehead.
			_texto.add_theme_font_override("font", GARAMOND_NOTA)
			_texto.add_theme_font_size_override("font_size", 46)
			_texto.add_theme_color_override("font_color", TINTA_CLARA)


func _process(delta: float) -> void:
	if _terminada or _i < 0:
		return
	_tiempo += delta

	var a := 0.0
	if _tiempo < _entrada:
		a = _tiempo / _entrada
	elif _tiempo < _duracion - _salida:
		a = 1.0
	elif _tiempo < _duracion:
		a = (_duracion - _tiempo) / _salida
	else:
		_pasar_a(_i + 1)
		return

	# smoothstep en vez de lineal: una entrada lineal se nota arrancar y frenar.
	var suave := a * a * (3.0 - 2.0 * a)
	_texto.modulate.a = suave
	if _lema.visible:
		# El lema entra después del título.
		_lema.modulate.a = clampf((_tiempo - _entrada * 1.8) / _entrada, 0.0, 1.0) * suave


func _unhandled_input(event: InputEvent) -> void:
	if _terminada:
		return

	if event.is_action_pressed("ui_cancel"):
		_terminar()
		get_viewport().set_input_as_handled()
		return

	# Tipo explícito: event.pressed es Variant y `:=` no lo deduce.
	var pasar: bool = event.is_action_pressed("ui_accept") \
		or (event is InputEventMouseButton and event.pressed
			and event.button_index == MOUSE_BUTTON_LEFT)
	if not pasar:
		return
	get_viewport().set_input_as_handled()

	# 1er toque: salta al fundido de salida; 2º: siguiente carta.
	if _tiempo < _duracion - _salida:
		_tiempo = _duracion - _salida
	else:
		_pasar_a(_i + 1)


# --- Salida -------------------------------------------------------------------

func _terminar() -> void:
	if _terminada:
		return
	_terminada = true

	if _ambiente != null:
		var t := create_tween()
		t.tween_property(_ambiente, "volume_db", -40.0, 0.5)

	var destino := String(_datos.get("siguiente", ""))
	if destino.is_empty():
		push_error("Cinematica: %s no declara 'siguiente'." % cinematica)
		return

	# El HUD se enciende aquí, no en cada escena de destino.
	HUD.show()
	SceneRouter.change_scene(destino, SceneRouter.Kind.SHORT_FADE)


# --- Herramientas -------------------------------------------------------------

func _color(hex: String) -> Color:
	if hex.is_empty() or not hex.begins_with("#"):
		return Color(0.03, 0.035, 0.03)
	return Color.html(hex)


func _espaciado(s: String) -> String:
	var out := ""
	for i in s.length():
		out += s[i]
		if i < s.length() - 1:
			out += " "
	return out


func _sonar(s: AudioStream, db: float) -> void:
	if _voz == null:
		return
	_voz.stream = s
	_voz.volume_db = db
	_voz.play()
