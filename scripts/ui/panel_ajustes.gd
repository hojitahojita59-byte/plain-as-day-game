extends VBoxContainer
## Panel de ajustes (volumen y controles); lo usan la pausa y el menú.

const GARAMOND := preload("res://art/fonts/EB_Garamond/static/EBGaramond-Regular.ttf")
const GARAMOND_SEMI := preload("res://art/fonts/EB_Garamond/static/EBGaramond-SemiBold.ttf")

@export var tinta: Color = Color(0.14, 0.11, 0.08)
@export var tinta_suave: Color = Color(0.38, 0.31, 0.24)

func _ready() -> void:
	add_theme_constant_override("separation", 14)
	_construir()


func _construir() -> void:
	_fila_volumen("Master", "maestro")
	_fila_volumen("Music", "musica")
	_fila_volumen("Sound", "efectos")

	var aire := Control.new()
	aire.custom_minimum_size = Vector2(0, 10)
	add_child(aire)

	# Solo informativo: las dos maneras de andar valen siempre.
	var nota := _etiqueta("Walk with the mouse, WASD or the arrow keys.")
	nota.add_theme_font_override("font", GARAMOND)
	nota.add_theme_font_size_override("font_size", 18)
	nota.custom_minimum_size = Vector2.ZERO
	add_child(nota)


func _fila_volumen(rotulo: String, grupo: String) -> void:
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 16)
	add_child(fila)
	fila.add_child(_etiqueta(rotulo))

	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.01
	s.value = float(Ajustes.volumen.get(grupo, 1.0))
	s.custom_minimum_size = Vector2(300, 26)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.value_changed.connect(func(v: float): Ajustes.poner_volumen(grupo, v))
	fila.add_child(s)


func _etiqueta(t: String) -> Label:
	var l := Label.new()
	l.text = t
	l.custom_minimum_size = Vector2(130, 0)
	l.add_theme_font_override("font", GARAMOND_SEMI)
	l.add_theme_font_size_override("font_size", 23)
	l.add_theme_color_override("font_color", tinta_suave)
	return l
