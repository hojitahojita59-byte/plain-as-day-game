extends Node3D
## Menú principal 3D: orbe, título de cristal, abanico de botones y globo.

const GLASS := preload("res://materials/glass_title.gdshader")
const DEEP_SPACE := preload("res://materials/deep_space.gdshader")
const GLOBE := preload("res://materials/globe.gdshader")

## Costas (Natural Earth 110m): R = tierra, G = línea de costa.
const GLOBE_MAP := preload("res://art/ui/globo_continentes.png")

const SON_PASAR := preload("res://audio/sfx/ui/pasar.wav")
const SON_ELEGIR := preload("res://audio/sfx/ui/elegir.wav")

## Provisional: la música de la calle hasta que haya pista de menú.
const MUSICA := preload("res://audio/music/musica_calle.wav")

## Más alto que en la calle, donde compite con el ambiente.
const MUSIC_DB := -14.0

const SERIES := "res://data/series.json"

## Destino de "Begin"; la cinemática declara su propio `siguiente`.
const CINEMATICA := "res://scenes/ui/cinematica.tscn"
const DIAS := preload("res://scripts/dias.gd")

enum State { INTRO, TITLE, MENU, EVENTS, SETTINGS }

## Duración de las transiciones entre estados (s).
const MOVE := 0.45

## Colores de los óvalos del orbe.
const PASTELS: Array[Color] = [
	Color(0.98, 0.80, 0.86),
	Color(0.86, 0.92, 0.99),
	Color(0.99, 0.94, 0.78),
	Color(0.84, 0.98, 0.92),
	Color(0.91, 0.84, 0.99),
	Color(0.99, 0.87, 0.78),
	Color(0.82, 0.95, 0.99),
]

## Posición de la cámara por estado, y adónde mira.
const CAM_HOME := Vector3(0.0, 0.0, 7.2)
const CAM_EVENTS := Vector3(15.0, 0.4, 7.6)
const CAM_SETTINGS := Vector3(0.0, -5.4, 7.2)
const GLOBE_AT := Vector3(15.0, 0.0, 0.0)

var _series: Dictionary = {}
var _state: int = State.INTRO
var _t: float = 0.0
var _state_t: float = 0.0

var _cam: Camera3D
var _orb: Node3D
var _orb_petals: Array[Node3D] = []
var _halo: MeshInstance3D
var _title: MeshInstance3D
var _stars: MultiMeshInstance3D
var _globe: Node3D
var _markers: Array[Dictionary] = []
var _hovered: int = -1
var _selected: int = -1

var _ui: CanvasLayer
var _press: Label
var _fan: Control
var _buttons: Array[Button] = []
var _tab: PanelContainer
var _more: Button
var _restart: Button
var _settings: Control
var _back: Button
var _voice: AudioStreamPlayer
var _music: AudioStreamPlayer
var _music_tw: Tween

## Destino del orbe; solo _move_orb lo mueve (un único dueño).
var _orb_goal: Vector3 = Vector3(-9.0, 0.0, -0.9)


func _ready() -> void:
	HUD.hide()
	_series = _read(SERIES)

	_build_world()
	_build_stars()
	_build_orb()
	_build_title()
	_build_globe()
	_build_ui()

	_cam.position = CAM_HOME
	_enter(State.INTRO)


func _read(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("MenuSpace: cannot find " + path)
		return {}
	var d = JSON.parse_string(f.get_as_text())
	return d if typeof(d) == TYPE_DICTIONARY else {}


func _event(i: int) -> Dictionary:
	var evs := Array(_series.get("events", []))
	if i < 0 or i >= evs.size():
		return {}
	return evs[i]


# --- Mundo --------------------------------------------------------------------

func _build_world() -> void:
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = DEEP_SPACE

	var sky := Sky.new()
	sky.sky_material = sky_mat

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.35
	# El glow hace que el núcleo del orbe se lea como una luz.
	env.glow_enabled = true
	env.glow_intensity = 0.65
	env.glow_bloom = 0.08
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.tonemap_mode = Environment.TONE_MAPPER_ACES

	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	_cam = Camera3D.new()
	_cam.fov = 58.0
	_cam.current = true
	add_child(_cam)

	# Luz principal para los brillos del cristal.
	var key := DirectionalLight3D.new()
	key.light_energy = 0.55
	key.rotation_degrees = Vector3(-28.0, 34.0, 0.0)
	add_child(key)


## Estrellas cercanas (geometría) que se desplazan con la cámara.
func _build_stars() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(0.032, 0.032)

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.vertex_color_use_as_albedo = true
	mat.disable_receive_shadows = true
	quad.material = mat

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = quad
	mm.instance_count = 300

	# Semilla fija: el cielo sale siempre igual.
	var rng := RandomNumberGenerator.new()
	rng.seed = 18540831

	for i in mm.instance_count:
		var p := Vector3(
			rng.randf_range(-26.0, 34.0),
			rng.randf_range(-16.0, 16.0),
			rng.randf_range(-30.0, 2.0))
		var s := rng.randf_range(0.5, 2.0)
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(s, s, s)), p))
		var b := rng.randf_range(0.12, 0.62)
		mm.set_instance_color(i, Color(b, b * 0.96, b * 0.92, 1.0))

	_stars = MultiMeshInstance3D.new()
	_stars.multimesh = mm
	add_child(_stars)


# --- El orbe ------------------------------------------------------------------

## Óvalos pastel (esferas aplanadas) alrededor de un núcleo que brilla.
func _build_orb() -> void:
	_orb = Node3D.new()
	add_child(_orb)

	var petal := SphereMesh.new()
	petal.radius = 0.5
	petal.height = 1.0
	petal.radial_segments = 24
	petal.rings = 12

	const COUNT := 9
	for i in COUNT:
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		# Mix, no add: con add se funden en una mancha blanca.
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
		# Sin escribir profundidad, o los óvalos parpadean al girar.
		mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		var c: Color = PASTELS[i % PASTELS.size()]
		# Alfa bajo: nueve pasteles apilados suman blanco.
		mat.albedo_color = Color(c.r, c.g, c.b, 0.15)
		# Sin emisión en los pétalos; solo emite el núcleo.
		mat.emission_enabled = false

		var mi := MeshInstance3D.new()
		mi.mesh = petal
		mi.material_override = mat
		# Aplastado en Y (óvalo) y adelgazado en Z (pétalo).
		mi.scale = Vector3(1.30, 0.44, 0.50)
		# Abanico en torno a Z; las inclinaciones X/Y le dan volumen.
		mi.rotation_degrees = Vector3(
			11.0 * sin(float(i) * 1.7),
			13.0 * cos(float(i) * 0.9),
			180.0 * float(i) / float(COUNT))
		_orb.add_child(mi)
		_orb_petals.append(mi)

	var core_mesh := SphereMesh.new()
	core_mesh.radius = 0.105
	core_mesh.height = 0.21

	var core_mat := StandardMaterial3D.new()
	core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	core_mat.albedo_color = Color(1, 1, 1)
	core_mat.emission_enabled = true
	core_mat.emission = Color(1, 1, 1)
	# > 1.0 para que el glow lo convierta en luz.
	core_mat.emission_energy_multiplier = 1.5

	var core := MeshInstance3D.new()
	core.mesh = core_mesh
	core.material_override = core_mat
	_orb.add_child(core)

	# Halo aditivo: suaviza el borde y es lo que ilumina las letras de cristal.
	var halo_grad := Gradient.new()
	halo_grad.offsets = PackedFloat32Array([0.0, 0.22, 1.0])
	halo_grad.colors = PackedColorArray([
		Color(1.0, 0.97, 0.92, 0.20),
		Color(0.88, 0.90, 1.0, 0.05),
		Color(0.80, 0.85, 1.0, 0.0)])

	var halo_tex := GradientTexture2D.new()
	halo_tex.gradient = halo_grad
	halo_tex.fill = GradientTexture2D.FILL_RADIAL
	halo_tex.fill_from = Vector2(0.5, 0.5)
	halo_tex.fill_to = Vector2(1.0, 0.5)
	halo_tex.width = 256
	halo_tex.height = 256

	var halo_mat := StandardMaterial3D.new()
	halo_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	halo_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	halo_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	halo_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	halo_mat.albedo_texture = halo_tex
	halo_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	halo_mat.no_depth_test = true

	var halo_mesh := QuadMesh.new()
	halo_mesh.size = Vector2(2.7, 2.7)

	var halo := MeshInstance3D.new()
	halo.name = "Halo"
	halo.mesh = halo_mesh
	halo.material_override = halo_mat
	# Fuera del grupo que gira: un billboard con padre que gira parpadea.
	add_child(halo)
	_halo = halo

	_orb.position = _orb_goal
	_orb.scale = Vector3.ONE * 1.55


# --- El título ----------------------------------------------------------------

func _build_title() -> void:
	var tm := TextMesh.new()
	tm.text = String(_series.get("title", "UNTITLED"))
	tm.font_size = 190
	tm.pixel_size = 0.0062
	tm.depth = 0.22
	tm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var mat := ShaderMaterial.new()
	mat.shader = GLASS

	_title = MeshInstance3D.new()
	_title.mesh = tm
	_title.material_override = mat
	# Algo delante del carril del orbe, para que pase POR DETRÁS de las letras.
	_title.position = Vector3(0.0, 1.05, 0.0)
	_title.scale = Vector3.ZERO
	add_child(_title)


# --- El globo -----------------------------------------------------------------

func _build_globe() -> void:
	_globe = Node3D.new()
	_globe.position = GLOBE_AT
	add_child(_globe)

	var sphere := SphereMesh.new()
	sphere.radius = 2.1
	sphere.height = 4.2
	sphere.radial_segments = 64
	sphere.rings = 32

	var mat := ShaderMaterial.new()
	mat.shader = GLOBE
	mat.set_shader_parameter("map", GLOBE_MAP)

	var mi := MeshInstance3D.new()
	mi.mesh = sphere
	mi.material_override = mat
	_globe.add_child(mi)

	# Un marcador por evento, en su lat./lon. real.
	var evs := Array(_series.get("events", []))
	for i in evs.size():
		var e: Dictionary = evs[i]
		var lat := float(e.get("lat", 51.51))
		var lon := float(e.get("lon", -0.14))
		var pos := _on_sphere(lat, lon, 2.16)

		var pin_mesh := SphereMesh.new()
		pin_mesh.radius = 0.075
		pin_mesh.height = 0.15

		var pin_mat := StandardMaterial3D.new()
		pin_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		pin_mat.albedo_color = Color(1.0, 0.86, 0.55)
		pin_mat.emission_enabled = true
		pin_mat.emission = Color(1.0, 0.82, 0.45)
		pin_mat.emission_energy_multiplier = 4.0

		var pin := MeshInstance3D.new()
		pin.mesh = pin_mesh
		pin.material_override = pin_mat
		pin.position = pos
		_globe.add_child(pin)

		_markers.append({"index": i, "node": pin, "base": pos})


func _on_sphere(lat_deg: float, lon_deg: float, r: float) -> Vector3:
	var la := deg_to_rad(lat_deg)
	var lo := deg_to_rad(lon_deg)
	return Vector3(
		r * cos(la) * sin(lo),
		r * sin(la),
		r * cos(la) * cos(lo))


# --- Interfaz -----------------------------------------------------------------

func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 5
	add_child(_ui)

	_voice = AudioStreamPlayer.new()
	_voice.bus = &"Interfaz"
	add_child(_voice)

	# Música con fundido de entrada de 4 s.
	_music = AudioStreamPlayer.new()
	_music.stream = MUSICA
	_music.bus = &"Musica"
	_music.volume_db = -60.0
	add_child(_music)
	_music.play()
	_fade_music(MUSIC_DB, 4.0)

	_build_press()
	_build_fan()
	_build_tab()
	_build_settings()
	_build_back()


func _build_press() -> void:
	_press = Label.new()
	_press.text = _spaced("PRESS ANY KEY")
	_press.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_press.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_press.add_theme_font_size_override("font_size", 22)
	_press.add_theme_color_override("font_color", Color(0.78, 0.83, 0.95))
	_press.modulate.a = 0.0
	_ui.add_child(_press)
	_press.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_press.offset_left = -400.0
	_press.offset_right = 400.0
	_press.offset_top = 760.0
	_press.offset_bottom = 800.0
	_press.pivot_offset = Vector2(400.0, 20.0)


## Abanico: las posiciones siguen un arco; el texto queda horizontal.
func _build_fan() -> void:
	_fan = Control.new()
	_fan.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fan.modulate.a = 0.0
	_ui.add_child(_fan)
	_fan.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var labels := _fan_labels()
	var n := labels.size()
	const SPAN := 900.0
	const DROP := 58.0
	const BASE_Y := 690.0

	for i in n:
		var k: float = (float(i) / float(n - 1)) * 2.0 - 1.0  # -1 .. 1
		var b := Button.new()
		b.text = labels[i]["text"]
		b.flat = true
		b.custom_minimum_size = Vector2(300, 56)
		b.add_theme_font_size_override("font_size", 27)
		b.add_theme_color_override("font_color", Color(0.80, 0.85, 0.96))
		b.add_theme_color_override("font_hover_color", Color(1, 1, 1))
		b.add_theme_color_override("font_pressed_color", Color(0.7, 0.8, 1.0))
		_fan.add_child(b)
		b.position = Vector2(
			960.0 + k * SPAN * 0.5 - 150.0,
			BASE_Y + (1.0 - k * k) * DROP)
		b.mouse_entered.connect(func(): _sound(SON_PASAR, -16.0))
		var action: String = labels[i]["action"]
		b.pressed.connect(func(): _on_fan(action))
		_buttons.append(b)


## Primer botón: Begin o Continue según haya partida.
func _fan_labels() -> Array:
	var first := {"text": "Begin", "action": "play"}
	if SaveSystem.has_save():
		var e := _event(0)
		first = {"text": "Continue: %s, %s" % [
			String(e.get("name", "")).capitalize(), String(e.get("year", ""))],
			"action": "play"}
		# Capítulo terminado: no hay nada que continuar.
		if _terminado():
			first = {"text": "Play again: %s, %s" % [
				String(e.get("name", "")).capitalize(), String(e.get("year", ""))],
				"action": "again"}
	return [
		first,
		{"text": "Events", "action": "events"},
		{"text": "Settings", "action": "settings"},
		{"text": "Quit", "action": "quit"},
	]


## Esquina de la ficha: "···" abre "Start over" (dos clics, a propósito).
func _build_corner() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 10)

	# Antes del "···" para que se abra hacia su izquierda.
	_restart = Button.new()
	_restart.text = "Start over"
	_restart.flat = true
	_restart.visible = false
	_restart.add_theme_font_size_override("font_size", 19)
	_restart.add_theme_color_override("font_color", Color(0.80, 0.73, 0.64))
	_restart.add_theme_color_override("font_hover_color", Color(1.0, 0.87, 0.71))
	_restart.pressed.connect(_confirmar_reinicio)
	row.add_child(_restart)

	# "···" y no "⋯": ese glifo no está en todas las fuentes.
	_more = Button.new()
	_more.text = "···"
	_more.flat = true
	_more.custom_minimum_size = Vector2(46, 0)
	_more.add_theme_font_size_override("font_size", 22)
	_more.add_theme_color_override("font_color", Color(0.46, 0.53, 0.68))
	_more.add_theme_color_override("font_hover_color", Color(0.90, 0.94, 1.0))
	_more.pressed.connect(func():
		_restart.visible = not _restart.visible
		_sound(SON_PASAR, -12.0))
	row.add_child(_more)

	return row


## Primer clic pide confirmación; el segundo borra la partida y empieza.
var _confirmando: bool = false


func _confirmar_reinicio() -> void:
	if _confirmando:
		_confirmando = false
		_begin(true)
		return
	_confirmando = true
	_restart.text = "Sure? Your game will be lost. Click again"
	_restart.add_theme_color_override("font_color", Color(0.95, 0.55, 0.45))
	await get_tree().create_timer(4.0).timeout
	if is_instance_valid(_restart) and _confirmando:
		_confirmando = false
		_restart.text = "Start over"
		_restart.add_theme_color_override("font_color", Color(0.80, 0.73, 0.64))


## Ficha lateral con la información del evento.
func _build_tab() -> void:
	_tab = PanelContainer.new()
	_tab.visible = false
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.06, 0.12, 0.92)
	sb.border_color = Color(0.45, 0.55, 0.78, 0.6)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(30)
	_tab.add_theme_stylebox_override("panel", sb)
	_ui.add_child(_tab)
	_tab.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	_tab.offset_left = -700.0
	_tab.offset_right = -60.0
	_tab.offset_top = 90.0
	_tab.offset_bottom = -90.0

	# El texto hace scroll; el botón de jugar queda fijo.
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 18)
	_tab.add_child(root)

	root.add_child(_build_corner())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)

	var col := VBoxContainer.new()
	col.name = "Col"
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 14)
	scroll.add_child(col)

	var play := Button.new()
	play.name = "Play"
	play.text = "Enter this life"
	play.custom_minimum_size = Vector2(0, 62)
	play.add_theme_font_size_override("font_size", 27)
	play.add_theme_color_override("font_color", Color(0.95, 0.92, 0.78))
	play.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	root.add_child(play)
	play.pressed.connect(func(): _begin(_terminado()))


func _fill_tab(i: int) -> void:
	var e := _event(i)

	# La esquina se cierra cada vez que se abre la ficha.
	if _restart != null:
		_restart.visible = false

	var col := _tab.find_child("Col", true, false) as VBoxContainer
	for c in col.get_children():
		col.remove_child(c)
		c.queue_free()

	col.add_child(_tab_title(String(e.get("name", ""))))
	col.add_child(_tab_line("%s   ·   %s" % [
		String(e.get("place", "")), String(e.get("year", ""))],
		Color(0.66, 0.74, 0.92), 22))
	col.add_child(_rule())

	col.add_child(_tab_head("You play"))
	col.add_child(_tab_body(String(e.get("host", ""))))

	col.add_child(_tab_head("What happened"))
	col.add_child(_tab_body(String(e.get("description", ""))))

	col.add_child(_tab_head("Why it still matters"))
	col.add_child(_tab_body(String(e.get("impact", ""))))

	# Habilidades como verbos, no como asignaturas.
	col.add_child(_tab_head("What you will get good at"))
	for s in Array(e.get("skills", [])):
		col.add_child(_tab_body("·   " + String(s)))

	col.add_child(_rule())

	# Progreso como hechos, no como nota.
	col.add_child(_tab_head("Where you left it"))
	for line in _progress_lines(e):
		col.add_child(_tab_body(line))

	# La cámara va a la der. para que el globo no quede bajo el panel.
	# 2.7 m ≈ 350 px: panel de 640 px en 1920; a esta distancia 1 px ≈ 0.0069 m.
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_cam, "position:x", CAM_EVENTS.x + 2.7, MOVE)


## Progreso leído del guardado (Casefile está vacío en el menú).
func _progress_lines(_e: Dictionary) -> Array[String]:
	var save := SaveSystem.peek()
	if save.is_empty():
		return ["Not begun."] as Array[String]

	var casefile: Dictionary = save.get("casefile", {})
	var cuaderno: Dictionary = casefile.get("cuaderno", {})
	var estado: Dictionary = save.get("state", {})
	if _terminado():
		return ["Chapter I finished. Snow came to the door.",
			"Chapters II and III are not out yet."] as Array[String]
	var dia := DIAS.de(int(estado.get("dia", 1)))
	return [
		"Day: %s" % String(dia.get("titulo", "Friday, 1 September")),
		"Houses written up: %d" % Array(cuaderno.get("selladas", [])).size(),
		"Deaths on the map: %d" % Array(casefile.get("register", [])).size(),
	] as Array[String]


## El capítulo se terminó (Snow ya vino) en la partida guardada.
func _terminado() -> bool:
	var flags: Dictionary = Dictionary(SaveSystem.peek().get("state", {})).get("flags", {})
	return bool(flags.get("met_snow", false))


func _tab_title(t: String) -> Label:
	var l := Label.new()
	l.text = _spaced(t)
	l.add_theme_font_size_override("font_size", 40)
	l.add_theme_color_override("font_color", Color(0.97, 0.96, 0.92))
	return l


func _tab_head(t: String) -> Label:
	var l := Label.new()
	l.text = _spaced(t.to_upper())
	l.add_theme_font_size_override("font_size", 16)
	l.add_theme_color_override("font_color", Color(0.55, 0.66, 0.88))
	return l


func _tab_body(t: String) -> Label:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 21)
	l.add_theme_color_override("font_color", Color(0.86, 0.88, 0.94))
	return l


func _tab_line(t: String, c: Color, s: int) -> Label:
	var l := Label.new()
	l.text = _spaced(t)
	l.add_theme_font_size_override("font_size", s)
	l.add_theme_color_override("font_color", c)
	return l


func _rule() -> Control:
	var r := ColorRect.new()
	r.color = Color(0.4, 0.5, 0.7, 0.35)
	r.custom_minimum_size = Vector2(0, 1)
	return r


func _build_settings() -> void:
	_settings = VBoxContainer.new()
	_settings.visible = false
	_settings.add_theme_constant_override("separation", 22)
	_ui.add_child(_settings)
	_settings.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_settings.offset_left = -400.0
	_settings.offset_right = 400.0
	_settings.offset_top = -220.0
	_settings.offset_bottom = 260.0

	_settings.add_child(_tab_line("SETTINGS", Color(0.95, 0.95, 0.98), 34))

	for bus in ["Master", "Ambiente", "Efectos", "Voz", "Interfaz"]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 20)
		var name_label := Label.new()
		name_label.text = bus
		name_label.custom_minimum_size = Vector2(190, 0)
		name_label.add_theme_font_size_override("font_size", 22)
		name_label.add_theme_color_override("font_color", Color(0.82, 0.86, 0.95))
		row.add_child(name_label)

		var idx := AudioServer.get_bus_index(bus)
		var slider := HSlider.new()
		slider.min_value = -40.0
		slider.max_value = 6.0
		slider.value = AudioServer.get_bus_volume_db(idx) if idx >= 0 else 0.0
		slider.custom_minimum_size = Vector2(420, 0)
		slider.value_changed.connect(func(v: float):
			if idx >= 0:
				AudioServer.set_bus_volume_db(idx, v))
		row.add_child(slider)
		_settings.add_child(row)

	var lang := HBoxContainer.new()
	lang.add_theme_constant_override("separation", 20)
	var ll := Label.new()
	ll.text = "Language"
	ll.custom_minimum_size = Vector2(190, 0)
	ll.add_theme_font_size_override("font_size", 22)
	ll.add_theme_color_override("font_color", Color(0.82, 0.86, 0.95))
	lang.add_child(ll)
	var opt := OptionButton.new()
	opt.add_item("English")
	opt.disabled = true
	lang.add_child(opt)
	_settings.add_child(lang)


func _build_back() -> void:
	_back = Button.new()
	_back.text = "‹   Back"
	_back.flat = true
	_back.visible = false
	_back.add_theme_font_size_override("font_size", 24)
	_back.add_theme_color_override("font_color", Color(0.72, 0.78, 0.92))
	_back.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	_ui.add_child(_back)
	_back.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_back.offset_left = 54.0
	_back.offset_top = 46.0
	_back.offset_right = 260.0
	_back.offset_bottom = 96.0
	_back.pressed.connect(func():
		_sound(SON_PASAR, -10.0)
		_enter(State.MENU))


# --- Estados ------------------------------------------------------------------

func _enter(s: int) -> void:
	_state = s
	_state_t = 0.0
	_selected = -1
	_tab.visible = false

	var cam_to := CAM_HOME
	var title_scale := Vector3.ONE
	var title_y := 1.05

	match s:
		State.INTRO:
			title_scale = Vector3.ZERO
			_orb.position = Vector3(-9.0, 0.0, -0.9)
			_orb_goal = _orb.position
		State.TITLE:
			pass
		State.MENU:
			pass
		State.EVENTS:
			cam_to = CAM_EVENTS
			# El título no sigue: el orbe lo deja atrás.
			_orb_goal = GLOBE_AT + Vector3(0.0, 3.4, 3.0)
		State.SETTINGS:
			cam_to = CAM_SETTINGS
			# Título y orbe suben mientras baja la cámara.
			title_y = 4.4
			_orb_goal = Vector3(0.0, 4.4, -0.9)

	_fade(_press, 1.0 if s == State.TITLE else 0.0)
	_fade(_fan, 1.0 if s == State.MENU else 0.0)
	_fan.mouse_filter = Control.MOUSE_FILTER_IGNORE if s != State.MENU \
		else Control.MOUSE_FILTER_PASS
	for b in _buttons:
		b.disabled = s != State.MENU
	_settings.visible = s == State.SETTINGS
	_back.visible = s == State.EVENTS or s == State.SETTINGS

	var tw := create_tween()
	tw.set_parallel(true)
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_cam, "position", cam_to, MOVE)
	if s != State.INTRO:
		tw.tween_property(_title, "scale", title_scale, MOVE)
		tw.tween_property(_title, "position:y", title_y, MOVE)


func _on_fan(action: String) -> void:
	_sound(SON_ELEGIR, -5.0)
	match action:
		"play":
			_begin()
		"again":
			_begin(true)
		"events":
			_enter(State.EVENTS)
		"settings":
			_enter(State.SETTINGS)
		"quit":
			get_tree().quit()


## Continúa si hay guardado; si no (o con fresh), partida nueva.
func _begin(fresh: bool = false) -> void:
	var e := _event(maxi(_selected, 0))
	_hush()

	if not fresh and SaveSystem.has_save() and SaveSystem.load_game():
		var destination := String(e.get("scene", ""))
		if destination == Barrio.ESCENA_CALLE and GameState.dia >= 3 and not GameState.has_flag("buried_frances_lewis"):
			destination = Barrio.CEMENTERIO
		if not destination.is_empty():
			HUD.show()
			SceneRouter.change_scene(destination, SceneRouter.Kind.SHORT_FADE)
			return
		push_warning("MenuSpace: %s declares no scene; starting fresh." % [
			String(e.get("id", ""))])

	GameState.reset()
	Casefile.reset()
	Barrio.reset()
	Cronometro.reset()
	SceneRouter.change_scene(CINEMATICA, SceneRouter.Kind.JOURNAL)


# --- Fotograma ----------------------------------------------------------------

func _process(delta: float) -> void:
	_t += delta
	_state_t += delta

	_run_state(delta)
	_move_orb(delta)
	_spin_orb(delta)
	_drift_stars(delta)

	if _state == State.EVENTS:
		_globe.rotate_y(delta * 0.09)
		_hover_markers()

	if _press.modulate.a > 0.01:
		# Leve balanceo: es lo único en pantalla que pide algo.
		_press.rotation = deg_to_rad(2.2 * sin(_t * 1.35))
		_press.modulate.a = 0.55 + 0.45 * (0.5 + 0.5 * sin(_t * 2.1))


func _run_state(_delta: float) -> void:
	match _state:
		State.INTRO:
			# Cruce: el orbe recorre X y el título aparece al pasar por el centro.
			var k: float = clampf(_state_t / 2.1, 0.0, 1.0)
			_orb_goal = Vector3(lerpf(-9.0, 9.0, k), 0.0, -0.9)
			if k > 0.5 and _title.scale.x < 0.01:
				var tw := create_tween()
				tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				tw.tween_property(_title, "scale", Vector3.ONE, 0.7)
			if k >= 1.0:
				_enter(State.TITLE)

		State.TITLE:
			# Va y vuelve, inclinado, mientras no se pulse nada.
			var a: float = _state_t * 0.42
			_orb_goal = Vector3(
				2.9 * sin(a),
				1.5 * sin(a * 0.63) - 1.1,
				-0.9 + 0.6 * cos(a * 0.51))

		State.MENU:
			# Lemniscata (infinito) alrededor del título.
			var a: float = _state_t * 0.55
			var d: float = 1.0 + sin(a) * sin(a)
			_orb_goal = Vector3(
				4.1 * cos(a) / d,
				1.05 + 1.35 * sin(a) * cos(a) / d,
				-0.9)

		State.EVENTS, State.SETTINGS:
			pass


func _move_orb(delta: float) -> void:
	_orb.position = _orb.position.lerp(_orb_goal, 1.0 - pow(0.0012, delta))
	# El halo no es hijo del orbe para no heredar el giro.
	_halo.global_position = _orb.global_position


func _spin_orb(delta: float) -> void:
	# Giro sobre todo en Z (plano de pantalla), con algo de balanceo en X/Y.
	_orb.rotate_z(delta * 0.24)
	_orb.rotation.y = 0.14 * sin(_t * 0.37)
	_orb.rotation.x = 0.10 * cos(_t * 0.29)
	# Cada óvalo gira además por su cuenta, desfasado.
	for i in _orb_petals.size():
		_orb_petals[i].rotate_z(delta * (0.09 + 0.03 * float(i % 4)))


func _drift_stars(delta: float) -> void:
	_stars.position.x -= delta * 0.22
	if _stars.position.x < -14.0:
		_stars.position.x += 14.0


func _hover_markers() -> void:
	var mouse := get_viewport().get_mouse_position()
	var found := -1
	var best := 46.0
	for m in _markers:
		var node: Node3D = m["node"]
		if _cam.is_position_behind(node.global_position):
			continue
		var on_screen := _cam.unproject_position(node.global_position)
		var d := on_screen.distance_to(mouse)
		if d < best:
			best = d
			found = int(m["index"])

	if found != _hovered:
		_hovered = found
		if found >= 0:
			_sound(SON_PASAR, -18.0)

	for m in _markers:
		var node: Node3D = m["node"]
		var on := int(m["index"]) == _hovered or int(m["index"]) == _selected
		var want := 2.1 if on else 1.0
		node.scale = node.scale.lerp(Vector3.ONE * want, 0.18)


func _unhandled_input(event: InputEvent) -> void:
	var pressed: bool = (event is InputEventKey and event.pressed and not event.echo) \
		or (event is InputEventMouseButton and event.pressed
			and event.button_index == MOUSE_BUTTON_LEFT)
	if not pressed:
		return

	match _state:
		State.INTRO, State.TITLE:
			# Cualquier tecla salta al menú, incluso a mitad del cruce.
			_sound(SON_ELEGIR, -6.0)
			_enter(State.MENU)
			get_viewport().set_input_as_handled()

		State.EVENTS:
			if _hovered >= 0:
				_selected = _hovered
				_fill_tab(_selected)
				_tab.visible = true
				_sound(SON_ELEGIR, -6.0)
				get_viewport().set_input_as_handled()


# --- Varios -------------------------------------------------------------------

func _fade(node: CanvasItem, to: float) -> void:
	var tw := create_tween()
	tw.tween_property(node, "modulate:a", to, MOVE * 0.7)


func _sound(s: AudioStream, db: float) -> void:
	_voice.stream = s
	_voice.volume_db = db
	_voice.play()


## Baja la música antes de cambiar de escena.
func _hush() -> void:
	_fade_music(-60.0, 0.45)


## Un solo tween para el volumen; dos a la vez se pelean.
func _fade_music(db: float, seconds: float) -> void:
	if _music == null:
		return
	if _music_tw != null and _music_tw.is_valid():
		_music_tw.kill()
	_music_tw = create_tween()
	_music_tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_music_tw.tween_property(_music, "volume_db", db, seconds)


func _spaced(s: String) -> String:
	var out := ""
	for i in s.length():
		out += s[i]
		if i < s.length() - 1:
			out += " "
	return out
