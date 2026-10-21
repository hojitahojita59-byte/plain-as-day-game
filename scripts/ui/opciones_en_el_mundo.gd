extends Control
## Burbujas de decisión pegadas a un objeto 3D (puerta, esquina...).
## Uso: `var cual := await HUD.preguntar_en(ancla, ["Go in", "Not yet"])`; -1 = no.

signal elegida(cual: int)

const GARAMOND_SEMI := preload("res://art/fonts/EB_Garamond/static/EBGaramond-SemiBold.ttf")

## Mismo verde que la caja de Whitehead.
const AZUL := Color(0.17, 0.33, 0.23)
const AZUL_ENCIMA := Color(0.24, 0.45, 0.31)
const BORDE := Color(0.62, 0.85, 0.66)
const LETRA := Color(0.95, 0.99, 0.94)

## Distancia (m) al ancla a la que se recogen solas.
const LEJOS := 7.0
## Duración (s) de abrir/recoger.
const ABRE := 0.22
## Altura sobre el ancla, en px de pantalla.
const ALTO := 54.0
const SEPARACION := 8.0

var _ancla: Node3D
var _jugador: Node3D
var _burbujas: Array[Button] = []
var _abierto: bool = false
var _cerrando: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	set_process(false)


## Pregunta y espera; llamar con `await`.
func preguntar(ancla: Node3D, opciones: Array) -> int:
	if _abierto or ancla == null or opciones.is_empty():
		return -1
	_ancla = ancla
	_jugador = get_tree().get_first_node_in_group(&"jugador") as Node3D
	_abierto = true
	_cerrando = false
	visible = true
	set_process(true)

	for i in opciones.size():
		var b := _burbuja(String(opciones[i]))
		add_child(b)
		b.pressed.connect(_escoger.bind(i))
		_burbujas.append(b)

	_colocar()
	# Brotan desde el punto del ancla.
	for b in _burbujas:
		b.pivot_offset = b.size * 0.5
		b.scale = Vector2(0.2, 0.2)
		b.modulate.a = 0.0
		var t := create_tween()
		t.set_parallel(true)
		t.tween_property(b, "scale", Vector2.ONE, ABRE) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(b, "modulate:a", 1.0, ABRE)

	var cual: int = await elegida
	return cual


func _process(_delta: float) -> void:
	if not _abierto or _cerrando:
		return
	# Alejarse = "no".
	if _jugador != null and _ancla != null \
			and _jugador.global_position.distance_to(_ancla.global_position) > LEJOS:
		_escoger(-1)
		return
	_colocar()


## Las coloca sobre el ancla proyectada a pantalla.
func _colocar() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or _ancla == null:
		return
	var p := _ancla.global_position
	# Detrás de la cámara: se recogen.
	if cam.is_position_behind(p):
		_escoger(-1)
		return
	var centro := cam.unproject_position(p)

	var alto_total := 0.0
	for b in _burbujas:
		alto_total += b.size.y + SEPARACION
	var y := centro.y - ALTO - alto_total
	for b in _burbujas:
		b.position = Vector2(centro.x - b.size.x * 0.5, y)
		b.pivot_offset = b.size * 0.5
		y += b.size.y + SEPARACION


func _escoger(cual: int) -> void:
	if _cerrando:
		return
	_cerrando = true
	set_process(false)
	# Misma animación de recogerse sea cual sea la respuesta.
	for b in _burbujas:
		var t := create_tween()
		t.set_parallel(true)
		t.tween_property(b, "scale", Vector2(0.2, 0.2), ABRE) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		t.tween_property(b, "modulate:a", 0.0, ABRE)
	await get_tree().create_timer(ABRE).timeout

	for b in _burbujas:
		b.queue_free()
	_burbujas.clear()
	_abierto = false
	_cerrando = false
	visible = false
	_ancla = null
	elegida.emit(cual)


func _burbuja(t: String) -> Button:
	var b := Button.new()
	b.text = t
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_override("font", GARAMOND_SEMI)
	b.add_theme_font_size_override("font_size", 24)
	b.add_theme_color_override("font_color", LETRA)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_stylebox_override("normal", _fondo(AZUL))
	b.add_theme_stylebox_override("hover", _fondo(AZUL_ENCIMA))
	b.add_theme_stylebox_override("pressed", _fondo(AZUL_ENCIMA))
	b.add_theme_stylebox_override("focus", _fondo(AZUL))
	b.size = Vector2(230.0, 48.0)
	b.custom_minimum_size = b.size
	return b


func _fondo(c: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.border_color = BORDE
	sb.set_border_width_all(2)
	# Radio = mitad del alto: cápsula.
	sb.set_corner_radius_all(24)
	sb.content_margin_left = 20.0
	sb.content_margin_right = 20.0
	sb.content_margin_top = 8.0
	sb.content_margin_bottom = 8.0
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 6
	return sb


func _unhandled_input(event: InputEvent) -> void:
	if not _abierto or _cerrando:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_escoger(-1)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		# Clic fuera de las burbujas = "no".
		if mb.pressed:
			get_viewport().set_input_as_handled()
			_escoger(-1)
