extends RefCounted
## Botón verde de las decisiones de Whitehead (salir, ir a casa), compartido.

const GARAMOND_SEMI := preload("res://art/fonts/EB_Garamond/static/EBGaramond-SemiBold.ttf")


static func crear(texto: String) -> Button:
	var b := Button.new()
	b.text = texto
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_override("font", GARAMOND_SEMI)
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_color_override("font_color", Color(0.93, 0.98, 0.92))
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	for estado in ["normal", "hover", "pressed", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.22, 0.42, 0.29) if estado == "hover" \
			else Color(0.17, 0.33, 0.23)
		sb.border_color = Color(0.62, 0.85, 0.66)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(20)
		sb.content_margin_left = 20.0
		sb.content_margin_right = 20.0
		sb.content_margin_top = 7.0
		sb.content_margin_bottom = 7.0
		b.add_theme_stylebox_override(estado, sb)
	return b


## Abajo a la derecha.
static func a_la_esquina(b: Button) -> void:
	b.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	b.offset_left = -230.0
	b.offset_top = -58.0
	b.offset_right = -22.0
	b.offset_bottom = -16.0
