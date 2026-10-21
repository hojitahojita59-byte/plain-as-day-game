extends Control
## Prototipo desechable de menú: título y campo de eventos, dibujado en código.

const GARAMOND := preload("res://art/fonts/EB_Garamond/static/EBGaramond-Regular.ttf")
const GARAMOND_SEMI := preload("res://art/fonts/EB_Garamond/static/EBGaramond-SemiBold.ttf")
const GARAMOND_NOTA := preload("res://art/fonts/EB_Garamond/static/EBGaramond-Regular.ttf")
const PINYON := preload("res://art/fonts/Pinyon_Script/PinyonScript-Regular.ttf")

const SON_PASAR := preload("res://audio/sfx/ui/pasar.wav")
const SON_ELEGIR := preload("res://audio/sfx/ui/elegir.wav")

const SERIES := "res://data/series.json"

## Frío, no negro puro.
const VOID := Color(0.035, 0.040, 0.062)

enum Screen { TITLE, FIELD }

var _series: Dictionary = {}
var _screen: int = Screen.TITLE

var _dust: Node
var _creature: Node
var _tint: ColorRect
var _title_box: Control
var _field: Control
var _caption: Label
var _hint: Label
var _voz: AudioStreamPlayer

## Hacia dónde tira la criatura (lo que se está mirando).
var _pull: Vector2 = Vector2.ZERO
var _t: float = 0.0


func _ready() -> void:
	HUD.hide()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_series = _read(SERIES)

	var bg := ColorRect.new()
	bg.color = VOID
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_dust = Dust.new()
	_dust.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dust)
	(_dust as Control).set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Tinte: sobre el polvo y bajo todo lo demás; toma el color de la época.
	_tint = ColorRect.new()
	_tint.color = Color(0, 0, 0, 0)
	_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tint)
	_tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_creature = Creature.new()
	(_creature as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	(_creature as Control).size = Vector2(360, 360)
	add_child(_creature)

	_build_field()
	_build_title()
	_build_labels()

	_voz = AudioStreamPlayer.new()
	_voz.bus = &"Interfaz"
	add_child(_voz)

	_show(Screen.TITLE)


func _read(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("MenuPrototype: cannot find " + path)
		return {}
	var d = JSON.parse_string(f.get_as_text())
	return d if typeof(d) == TYPE_DICTIONARY else {}


# --- Título -------------------------------------------------------------------

func _build_title() -> void:
	_title_box = VBoxContainer.new()
	_title_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(_title_box as VBoxContainer).alignment = BoxContainer.ALIGNMENT_CENTER
	(_title_box as VBoxContainer).add_theme_constant_override("separation", 34)
	add_child(_title_box)
	_title_box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_title_box.offset_top = -360.0
	_title_box.offset_bottom = -90.0

	# Sin fuente: Noto Sans por defecto (provisional); Pinyon no se leía.
	var title := Label.new()
	title.text = _spaced(String(_series.get("title", "UNTITLED")).to_upper())
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 78)
	title.add_theme_color_override("font_color", Color(0.90, 0.91, 0.97))
	_title_box.add_child(title)

	# Solo PRESS START en la primera pantalla.
	var start := Label.new()
	start.name = "Start"
	start.text = _spaced("PRESS START")
	start.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	start.add_theme_font_override("font", GARAMOND_SEMI)
	start.add_theme_font_size_override("font_size", 22)
	start.add_theme_color_override("font_color", Color(0.62, 0.68, 0.78))
	_title_box.add_child(start)


# --- Campo de eventos ---------------------------------------------------------

func _build_field() -> void:
	_field = Control.new()
	_field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_field)
	_field.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var events := Array(_series.get("events", []))
	var fragments := Array(_series.get("fragments", []))

	# Semilla fija: el campo sale siempre igual.
	var rng := RandomNumberGenerator.new()
	rng.seed = 18540831

	# Primero los no recordados, para que el recordado quede encima.
	for i in fragments.size():
		var p := EventPoint.new()
		p.remembered = false
		p.fragment = String(fragments[i])
		p.position = _scatter(rng)
		p.size = Vector2(34, 34)
		_field.add_child(p)
		p.entered.connect(_on_point_entered)
		p.left.connect(_on_point_left)

	for e in events:
		if typeof(e) != TYPE_DICTIONARY:
			continue
		var p := EventPoint.new()
		p.remembered = true
		p.data = e
		p.hue = Color.html(String(e.get("hue", "#8a8a6a")))
		p.size = Vector2(96, 96)
		# Algo a la izq. y arriba del centro, para no chocar con la criatura.
		p.position = Vector2(600, 360)
		_field.add_child(p)
		p.entered.connect(_on_point_entered)
		p.left.connect(_on_point_left)
		p.chosen.connect(_on_point_chosen)


## Esparce lejos de la franja central y de los bordes.
func _scatter(rng: RandomNumberGenerator) -> Vector2:
	for _try in 40:
		var v := Vector2(rng.randf_range(140.0, 1780.0), rng.randf_range(120.0, 940.0))
		if absf(v.x - 960.0) < 260.0 and absf(v.y - 540.0) < 200.0:
			continue
		return v
	return Vector2(200, 200)


func _build_labels() -> void:
	# Un solo rótulo, para que nunca se solapen dos.
	_caption = Label.new()
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.modulate.a = 0.0
	add_child(_caption)
	_caption.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_caption.offset_top = -180.0
	_caption.offset_bottom = -130.0

	_hint = Label.new()
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.add_theme_font_override("font", GARAMOND_NOTA)
	_hint.add_theme_font_size_override("font_size", 19)
	_hint.add_theme_color_override("font_color", Color(0.5, 0.54, 0.62, 0.75))
	add_child(_hint)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_hint.offset_left = -760.0
	_hint.offset_top = -62.0
	_hint.offset_right = -46.0
	_hint.offset_bottom = -28.0


# --- Pantallas ----------------------------------------------------------------

func _show(screen: int) -> void:
	_screen = screen
	var to_title := screen == Screen.TITLE

	_field.visible = not to_title
	_hint.text = "enter or click to begin" if to_title else "esc to go back"
	_pull = Vector2.ZERO
	_fade(_caption, 0.0)

	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(_title_box, "modulate:a", 1.0 if to_title else 0.0, 0.5)
	t.tween_property(_tint, "color", Color(0, 0, 0, 0), 0.6)


func _on_point_entered(p: Control) -> void:
	var point := p as EventPoint
	_pull = p.position + p.size * 0.5
	_sound(SON_PASAR, -16.0)

	if point.remembered:
		var d: Dictionary = point.data
		# Versalitas espaciadas.
		_caption.text = _spaced("%s   ·   %s   ·   %s" % [
			String(d.get("name", "")), String(d.get("place", "")), String(d.get("year", ""))])
		_dress_caption(GARAMOND_SEMI, 30, Color(0.95, 0.93, 0.86))

		# Todo el vacío toma el color de la época.
		var hue: Color = point.hue
		var t := create_tween()
		t.tween_property(_tint, "color", Color(hue.r, hue.g, hue.b, 0.16), 0.45)
	else:
		# Fragmento: cursiva, minúscula, sin espaciar.
		_caption.text = point.fragment
		_dress_caption(GARAMOND_NOTA, 27, Color(0.60, 0.64, 0.74))

	_fade(_caption, 1.0)


func _dress_caption(font: Font, size: int, colour: Color) -> void:
	_caption.add_theme_font_override("font", font)
	_caption.add_theme_font_size_override("font_size", size)
	_caption.add_theme_color_override("font_color", colour)


func _on_point_left(_p: Control) -> void:
	_pull = Vector2.ZERO
	_fade(_caption, 0.0)
	var t := create_tween()
	t.tween_property(_tint, "color", Color(0, 0, 0, 0), 0.7)


func _on_point_chosen(p: Control) -> void:
	_sound(SON_ELEGIR, -4.0)
	var d: Dictionary = (p as EventPoint).data
	# En el prototipo solo imprime.
	print("[prototype] chosen event: %s -> %s" % [
		String(d.get("id", "")), String(d.get("cinematic", ""))])


func _fade(node: CanvasItem, to: float) -> void:
	var t := create_tween()
	t.tween_property(node, "modulate:a", to, 0.3)


func _process(delta: float) -> void:
	_t += delta

	# La criatura respira en el centro y se inclina hacia lo que se mira.
	var home := Vector2(960.0, 540.0) + Vector2(sin(_t * 0.31) * 34.0, cos(_t * 0.24) * 26.0)
	var want := home if _pull == Vector2.ZERO else home.lerp(_pull, 0.35)
	var c := _creature as Control
	c.position = c.position.lerp(want - c.size * 0.5, 1.0 - pow(0.06, delta))

	if _screen == Screen.TITLE:
		var s := _title_box.get_node_or_null("Start") as Label
		if s != null:
			s.modulate.a = 0.55 + 0.45 * (0.5 + 0.5 * sin(_t * 2.0))


func _unhandled_input(event: InputEvent) -> void:
	if _screen == Screen.TITLE:
		var go: bool = event.is_action_pressed("ui_accept") \
			or (event is InputEventMouseButton and event.pressed
				and event.button_index == MOUSE_BUTTON_LEFT)
		if go:
			_sound(SON_ELEGIR, -6.0)
			_show(Screen.FIELD)
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		_show(Screen.TITLE)
		get_viewport().set_input_as_handled()


func _sound(s: AudioStream, db: float) -> void:
	_voz.stream = s
	_voz.volume_db = db
	_voz.play()


func _spaced(s: String) -> String:
	var out := ""
	for i in s.length():
		out += s[i]
		if i < s.length() - 1:
			out += " "
	return out


# --- Dibujos ------------------------------------------------------------------

## Polvo de fondo: motas irregulares que dan profundidad.
class Dust extends Control:
	var _specks: Array[Vector4] = []
	var _t: float = 0.0

	func _ready() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 1854
		for i in 420:
			_specks.append(Vector4(
				rng.randf_range(-100.0, 2020.0),
				rng.randf_range(-60.0, 1140.0),
				rng.randf_range(0.6, 2.1),
				rng.randf_range(0.06, 0.42)))
		set_process(true)

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		for s in _specks:
			# Cada mota respira a su ritmo, según su x.
			var b: float = s.w * (0.65 + 0.35 * sin(_t * 0.7 + s.x * 0.01))
			var x: float = fposmod(s.x - _t * 3.0, 2120.0) - 100.0
			draw_circle(Vector2(x, s.y), s.z, Color(0.80, 0.85, 1.0, b))


## La criatura (provisional): núcleo, halos y filamentos.
class Creature extends Control:
	var _t: float = 0.0

	func _ready() -> void:
		set_process(true)

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var c := size * 0.5

		# Halos de fuera a dentro, como anillos para que tiemblen.
		for i in range(6, 0, -1):
			var r: float = 16.0 + i * 13.0 + sin(_t * (0.8 + i * 0.11) + i) * 3.5
			var a: float = 0.045 - i * 0.005
			draw_circle(c, r, Color(0.72, 0.80, 1.0, maxf(a, 0.006)))

		# Filamentos: cinco cadenas de puntos menguantes.
		for f in 5:
			var base: float = TAU * f / 5.0 + _t * 0.16
			for j in 14:
				var k: float = float(j) / 14.0
				var ang: float = base + sin(_t * 1.1 + f * 2.0 + k * 3.4) * 0.55
				var d: float = 22.0 + k * 78.0
				var p := c + Vector2(cos(ang), sin(ang) * 0.72) * d
				draw_circle(p, 2.6 * (1.0 - k) + 0.5,
					Color(0.66, 0.76, 1.0, 0.30 * (1.0 - k)))

		var pulse: float = 0.5 + 0.5 * sin(_t * 1.6)
		draw_circle(c, 13.0 + pulse * 2.0, Color(0.86, 0.91, 1.0, 0.85))
		draw_circle(c, 6.0, Color(1, 1, 1, 0.95))


## Punto del campo: recordado (ventana) u olvidado (mota).
class EventPoint extends Control:
	signal entered(p: Control)
	signal left(p: Control)
	signal chosen(p: Control)

	var remembered: bool = false
	var fragment: String = ""
	var data: Dictionary = {}
	var hue: Color = Color(0.55, 0.58, 0.35)

	var _over: float = 0.0
	var _target: float = 0.0
	var _t: float = 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		pivot_offset = size * 0.5
		set_process(true)
		mouse_entered.connect(func():
			_target = 1.0
			entered.emit(self))
		mouse_exited.connect(func():
			_target = 0.0
			left.emit(self))

	func _gui_input(event: InputEvent) -> void:
		if remembered and event is InputEventMouseButton \
			and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			chosen.emit(self)

	func _process(delta: float) -> void:
		_t += delta
		_over = move_toward(_over, _target, delta * 3.2)
		queue_redraw()

	func _draw() -> void:
		if remembered:
			_draw_remembered()
		else:
			_draw_forgotten()

	## Olvidado: una mota que apenas responde; nunca parece pulsable.
	func _draw_forgotten() -> void:
		var c := size * 0.5
		# Anillo tenue: lo distingue del polvo sin brillar más.
		var a: float = 0.30 + 0.45 * _over + 0.06 * sin(_t * 0.9)
		draw_circle(c, 11.0 + _over * 5.0, Color(0.70, 0.78, 0.95, a * 0.14))
		draw_arc(c, 8.0 + _over * 3.0, 0.0, TAU, 24,
			Color(0.72, 0.80, 0.98, a * 0.5), 1.0, true)
		draw_circle(c, 2.6 + _over * 1.4, Color(0.84, 0.90, 1.0, a))

	## Recordado: se abre en una ventana iluminada al acercarse.
	func _draw_remembered() -> void:
		var c := size * 0.5
		var e: float = _over * _over * (3.0 - 2.0 * _over)

		var halo: float = 26.0 + 10.0 * sin(_t * 1.3)
		draw_circle(c, halo * (1.0 + e), Color(hue.r, hue.g, hue.b, 0.10 + 0.10 * e))

		if e < 0.02:
			draw_circle(c, 6.0, Color(1.0, 0.93, 0.74, 0.95))
			return

		var w := lerpf(14.0, 300.0, e)
		var h := lerpf(14.0, 210.0, e)
		var r := Rect2(c - Vector2(w, h) * 0.5, Vector2(w, h))

		draw_rect(r.grow(7.0), Color(0.07, 0.06, 0.05, 0.85 * e))
		draw_rect(r, Color(1.0, 0.84, 0.52, 0.10 + 0.80 * e))

		# Bandas oscuras abajo: se lee como una habitación.
		draw_rect(Rect2(r.position + Vector2(0, h * 0.62), Vector2(w, h * 0.38)),
			Color(0.35, 0.24, 0.12, 0.35 * e))

		# Travesaños.
		var bar := Color(0.10, 0.09, 0.08, 0.9 * e)
		draw_rect(Rect2(r.position.x + w * 0.5 - 2.0, r.position.y, 4.0, h), bar)
		draw_rect(Rect2(r.position.x, r.position.y + h * 0.46 - 2.0, w, 4.0), bar)
		draw_rect(r, bar, false, 5.0)

		# Lluvia en el cristal, en bucle.
		for i in 16:
			var x: float = r.position.x + fmod(float(i) * 37.0, w)
			var y: float = r.position.y + fposmod(_t * 90.0 + i * 53.0, h)
			draw_line(Vector2(x, y), Vector2(x - 2.0, y + 13.0),
				Color(0.95, 0.95, 1.0, 0.22 * e), 1.5)
