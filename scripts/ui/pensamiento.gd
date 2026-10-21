extends Control
## Pensamiento de Whitehead: un renglón abajo, sin bloquear ni poder saltarse.

const GARAMOND := preload("res://art/fonts/EB_Garamond/static/EBGaramond-Medium.ttf")

## Tiempos (s): entrar, mínimo en pantalla, extra por palabra, salir.
const ENTRA := 0.45
const SE_QUEDA := 4.0
const POR_PALABRA := 0.33
const SE_VA := 0.9

var _texto: Label
var _caja: PanelContainer
var _cola: Array[String] = []
var _ocupado: bool = false
## Última frase dicha, para no repetirla.
var _ultima: String = ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var centro := CenterContainer.new()
	centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centro)
	# Más arriba que la caja de diálogo, para no confundirse con ella.
	centro.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	centro.offset_top = -250.0
	centro.offset_bottom = -150.0

	_caja = PanelContainer.new()
	_caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.06, 0.06, 0.78)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 26.0
	sb.content_margin_right = 26.0
	sb.content_margin_top = 10.0
	sb.content_margin_bottom = 12.0
	_caja.add_theme_stylebox_override("panel", sb)
	_caja.modulate.a = 0.0
	centro.add_child(_caja)

	_texto = Label.new()
	_texto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_texto.add_theme_font_override("font", GARAMOND)
	_texto.add_theme_font_size_override("font_size", 30)
	_texto.add_theme_color_override("font_color", Color(0.97, 0.96, 0.92))
	_caja.add_child(_texto)


func pensar(frase: String) -> void:
	if frase.is_empty():
		return
	# No repetir la misma frase seguida.
	if frase == _ultima:
		return
	_ultima = frase
	_cola.append(frase)
	if not _ocupado:
		_siguiente()


func _siguiente() -> void:
	if _cola.is_empty():
		_ocupado = false
		return
	# Con un diálogo abierto, espera a que se cierre.
	if DialogueRunner.active:
		_ocupado = false
		if not DialogueRunner.dialogue_finished.is_connected(_al_cerrarse_el_dialogo):
			DialogueRunner.dialogue_finished.connect(_al_cerrarse_el_dialogo,
				CONNECT_ONE_SHOT)
		return
	_ocupado = true
	var frase: String = _cola.pop_front()
	_texto.text = frase
	# Solo las frases largas se parten en dos renglones.
	var larga := frase.length() > 70
	_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if larga else TextServer.AUTOWRAP_OFF
	_texto.custom_minimum_size.x = 1000.0 if larga else 0.0
	var palabras := frase.split(" ", false).size()
	var t := create_tween()
	t.tween_property(_caja, "modulate:a", 1.0, ENTRA)
	t.tween_interval(SE_QUEDA + POR_PALABRA * float(palabras))
	t.tween_property(_caja, "modulate:a", 0.0, SE_VA)
	t.tween_callback(_siguiente)


func _al_cerrarse_el_dialogo(_id: String) -> void:
	# Pausa tras cerrar el diálogo.
	await get_tree().create_timer(0.5).timeout
	if not _ocupado:
		_siguiente()


## Permite repetir la última frase.
func olvidar() -> void:
	_ultima = ""
