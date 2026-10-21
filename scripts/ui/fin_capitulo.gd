extends Control
## Fin del capítulo I y nota de autor (qué es histórico y qué inventado).

const MENU := "res://scenes/ui/menu_space.tscn"
const GARAMOND := preload("res://art/fonts/EB_Garamond/static/EBGaramond-Regular.ttf")
const GARAMOND_SEMI := preload("res://art/fonts/EB_Garamond/static/EBGaramond-SemiBold.ttf")
const GARAMOND_NOTA := preload("res://art/fonts/EB_Garamond/static/EBGaramond-Regular.ttf")

const NOTA := [
	"Henry Whitehead and John Snow were real. The brewery, the workhouse and the widow at Hampstead come from Snow's own account of the outbreak, published in 1855.",
	"They did not meet this early. In history, Whitehead first set out to prove Snow wrong, and came round to him through the parish's own inquiry.",
	"The neighbours at the doors are invented. The streets and the days of the outbreak are real.",
]

var _puede_salir: bool = false


func _ready() -> void:
	HUD.esquina(false)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var negro := ColorRect.new()
	negro.color = Color(0.02, 0.02, 0.02)
	negro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	negro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(negro)

	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	col.custom_minimum_size = Vector2(980, 0)
	col.position = Vector2(-490, -320)
	col.add_theme_constant_override("separation", 26)
	add_child(col)

	var rotulo := _texto("END OF CHAPTER I", GARAMOND_SEMI, 52, Color(0.9, 0.87, 0.8))
	rotulo.modulate.a = 0.0
	col.add_child(rotulo)
	var hueco := Control.new()
	hueco.custom_minimum_size = Vector2(0, 30)
	col.add_child(hueco)

	var parrafos: Array[Label] = []
	for linea in NOTA:
		var l := _texto(linea, GARAMOND_NOTA, 26, Color(0.72, 0.69, 0.62))
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.modulate.a = 0.0
		col.add_child(l)
		parrafos.append(l)

	var desarrollo := _texto("Game in development. Keep in touch for more.", GARAMOND_SEMI, 28, Color(0.9, 0.87, 0.8))
	desarrollo.modulate.a = 0.0
	col.add_child(desarrollo)
	var tiempo := _texto("You played for %d minutes." % maxi(1, roundi(Cronometro.jugado / 60.0)), GARAMOND, 20, Color(0.6, 0.57, 0.52))
	desarrollo.add_child(tiempo)
	tiempo.position.y = 44
	tiempo.size.x = 980
	var aire := Control.new()
	aire.custom_minimum_size = Vector2(0, 30)
	col.add_child(aire)
	var seguir := _texto("(Click & return to the menu)", GARAMOND, 20, Color(0.5, 0.48, 0.44))
	seguir.modulate.a = 0.0
	col.add_child(seguir)

	var t := create_tween()
	t.tween_interval(0.8)
	t.tween_property(rotulo, "modulate:a", 1.0, 1.6)
	t.tween_interval(2.2)
	for l in parrafos:
		t.tween_property(l, "modulate:a", 1.0, 1.2)
		t.tween_interval(1.4)
	t.tween_property(desarrollo, "modulate:a", 1.0, 1.2)
	t.tween_interval(1.0)
	t.tween_property(seguir, "modulate:a", 1.0, 0.8)
	t.tween_callback(func(): _puede_salir = true)


## _input: el fondo negro (Control) se come los clics antes de _unhandled_input.
func _input(event: InputEvent) -> void:
	if not _puede_salir:
		return
	var clic := event is InputEventMouseButton and (event as InputEventMouseButton).pressed
	if clic or event.is_action_pressed(&"ui_accept"):
		_puede_salir = false
		HUD.esquina(true)
		SceneRouter.change_scene(MENU, SceneRouter.Kind.SHORT_FADE)


func _texto(t: String, f: Font, tam: int, c: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", f)
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", c)
	return l
