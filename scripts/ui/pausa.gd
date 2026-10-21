extends Control
## Pausa (Escape), como Minecraft: seguir, ajustes, o guardar y volver al menú.

signal reanudar

const GARAMOND := preload("res://art/fonts/EB_Garamond/static/EBGaramond-Regular.ttf")
const GARAMOND_SEMI := preload("res://art/fonts/EB_Garamond/static/EBGaramond-SemiBold.ttf")
const PINYON := preload("res://art/fonts/Pinyon_Script/PinyonScript-Regular.ttf")
const MENU := "res://scenes/ui/menu_space.tscn"
const AJUSTES := preload("res://scripts/ui/panel_ajustes.gd")

const PAPEL := Color(0.87, 0.83, 0.73)
const PAPEL_BORDE := Color(0.44, 0.37, 0.28)
const TINTA := Color(0.14, 0.11, 0.08)
const TINTA_SUAVE := Color(0.38, 0.31, 0.24)

var _primero: Button
var _menu: VBoxContainer
var _ajustes: Control
var _atras: Button
var _hoja_ajustes: Control


func _ready() -> void:
	# Debe correr con el árbol pausado para oír la tecla que la cierra.
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_construir()


func _construir() -> void:
	# Velo pardo, no negro, para no apagar el color de la escena.
	var velo := ColorRect.new()
	velo.color = Color(0.07, 0.06, 0.05, 0.72)
	velo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	velo.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(velo)

	var col := VBoxContainer.new()
	col.anchor_left = 0.1
	col.anchor_right = 0.1
	col.anchor_top = 0.5
	col.anchor_bottom = 0.5
	col.offset_top = -190
	col.offset_right = 470
	col.add_theme_constant_override("separation", 14)
	add_child(col)

	var titulo := Label.new()
	titulo.text = "Plain As Day"
	titulo.add_theme_font_override("font", PINYON)
	titulo.add_theme_font_size_override("font_size", 64)
	titulo.add_theme_color_override("font_color", PAPEL)
	col.add_child(titulo)

	# El evento en curso, bajo el título.
	var evento := Label.new()
	evento.text = "Soho, 1854"
	evento.add_theme_font_override("font", GARAMOND_SEMI)
	evento.add_theme_font_size_override("font_size", 30)
	evento.add_theme_color_override("font_color", PAPEL.darkened(0.12))
	evento.add_theme_constant_override("line_spacing", 0)
	col.add_child(evento)

	_menu = VBoxContainer.new()
	_menu.add_theme_constant_override("separation", 12)
	col.add_child(_menu)

	_primero = _boton("Resume Game", true)
	_primero.pressed.connect(_reanudar)
	_menu.add_child(_primero)

	var config := _boton("Settings")
	config.pressed.connect(func(): _ver_ajustes(true))
	_menu.add_child(config)

	var salir := _boton("Save & Quit")
	salir.pressed.connect(_al_menu)
	_menu.add_child(salir)

	var parado := Label.new()
	parado.text = "  Game is paused  "
	parado.add_theme_font_override("font", GARAMOND_SEMI)
	parado.add_theme_font_size_override("font_size", 22)
	parado.add_theme_color_override("font_color", PAPEL)
	var caja := StyleBoxFlat.new()
	caja.bg_color = Color(0.20, 0.30, 0.20, 0.9)
	caja.set_content_margin_all(6)
	parado.add_theme_stylebox_override("normal", caja)
	parado.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_menu.add_child(parado)

	# Mismo panel que el menú principal, con los colores del papel.
	_ajustes = AJUSTES.new()
	_ajustes.tinta = TINTA
	_ajustes.tinta_suave = TINTA_SUAVE
	_ajustes.visible = false
	var hoja := PanelContainer.new()
	var fondo := StyleBoxFlat.new()
	fondo.bg_color = PAPEL
	fondo.border_color = PAPEL_BORDE
	fondo.set_border_width_all(2)
	fondo.set_content_margin_all(28)
	hoja.add_theme_stylebox_override("panel", fondo)
	hoja.add_child(_ajustes)
	col.add_child(hoja)
	_hoja_ajustes = hoja

	_atras = _boton("Back")
	_atras.visible = false
	_atras.pressed.connect(func(): _ver_ajustes(false))
	col.add_child(_atras)


func _ver_ajustes(si: bool) -> void:
	_menu.visible = not si
	_ajustes.visible = si
	_hoja_ajustes.visible = si
	_atras.visible = si


func abrir() -> void:
	visible = true
	_ver_ajustes(false)
	get_tree().paused = true
	if _primero != null:
		_primero.grab_focus()


func cerrar() -> void:
	visible = false
	get_tree().paused = false


func _reanudar() -> void:
	cerrar()
	reanudar.emit()


## Guardar ANTES de cambiar de escena, o el guardado queda a medias.
func _al_menu() -> void:
	SaveSystem.save_game()
	cerrar()
	SceneRouter.change_scene(MENU)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("pausa") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		# En ajustes, Escape vuelve al menú de la pausa.
		if _ajustes != null and _ajustes.visible:
			_ver_ajustes(false)
		else:
			_reanudar()


## Botón ancho con caja, como los de Minecraft; el primero, destacado.
func _boton(t: String, destacado: bool = false) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(470, 62)
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_override("font", GARAMOND_SEMI)
	b.add_theme_font_size_override("font_size", 27)
	var fondo := Color(0.23, 0.35, 0.22) if destacado else PAPEL
	var letra := PAPEL if destacado else TINTA
	for k in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
		b.add_theme_color_override(k, letra)
	for estado in ["normal", "hover", "pressed", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = fondo.lightened(0.08) if estado == "hover" else fondo
		sb.border_color = Color(0.96, 0.93, 0.86) if estado in ["hover", "focus"] else PAPEL_BORDE
		sb.set_border_width_all(3)
		b.add_theme_stylebox_override(estado, sb)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return b
