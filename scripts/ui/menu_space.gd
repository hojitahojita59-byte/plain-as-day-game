extends Node3D
## Menú principal 3D: orbe, título de hielo, abanico de botones y globo.

const GLASS := preload("res://materials/glass_title.gdshader")
const DEEP_SPACE := preload("res://materials/deep_space.gdshader")
const GLOBE := preload("res://materials/globe.gdshader")
const GLOBE_BACK := preload("res://materials/globe_back.gdshader")
const ATMOS := preload("res://materials/globe_atmosphere.gdshader")
const PIN := preload("res://materials/globe_pin.gdshader")
const BADGE := preload("res://materials/globe_badge.gdshader")

## Costas (Natural Earth 110m): R = tierra, G = línea de costa.
const GLOBE_MAP := preload("res://art/ui/globo_continentes.png")

const F_TITULO := preload("res://art/fonts/Cinzel/Cinzel-VariableFont_wght.ttf")
const F_SERIF := preload("res://art/fonts/EB_Garamond/static/EBGaramond-Regular.ttf")
const F_SERIF_MEDIA := preload("res://art/fonts/EB_Garamond/static/EBGaramond-Medium.ttf")
const F_SERIF_FUERTE := preload("res://art/fonts/EB_Garamond/static/EBGaramond-SemiBold.ttf")
const F_SANS := preload("res://art/fonts/Source_Sans_3/SourceSans3-VariableFont_wght.ttf")

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
const GLOBE_R := 2.1

## Marcas "?" de vidas futuras (lat., lon.): sin nombre ni año, no se eligen.
const PISTAS: Array[Vector2] = [
	Vector2(40.7, -74.0),    # Norteamérica
	Vector2(-12.0, -77.0),   # Sudamérica
	Vector2(48.2, 16.4),     # Europa central
	Vector2(6.5, 3.4),       # África occidental
	Vector2(-33.9, 18.4),    # África austral
	Vector2(30.0, 31.2),     # Oriente Próximo
	Vector2(22.6, 88.4),     # Asia del Sur
	Vector2(31.2, 121.5),    # Asia oriental
	Vector2(-33.9, 151.2),   # Oceanía
]

## Paleta de la interfaz.
const C_TEXTO := Color(0.87, 0.89, 0.94)
const C_CLARO := Color(0.98, 0.97, 0.94)
const C_TENUE := Color(0.62, 0.68, 0.80)
const C_HIELO := Color(0.70, 0.84, 1.0)
const C_ORO := Color(0.95, 0.79, 0.50)
const C_PANEL := Color(0.028, 0.038, 0.075, 0.93)
const C_PIN_ORO := Color(1.0, 0.78, 0.40)
const C_PIN_HIELO := Color(0.62, 0.80, 1.0)

## Nombre del bus y cómo se ve en pantalla.
const BUSES := [["Master", "Master"], ["Ambiente", "Ambience"], ["Efectos", "Effects"],
	["Voz", "Voices"], ["Interfaz", "Interface"]]

var _series: Dictionary = {}
var _state: int = State.INTRO
var _t: float = 0.0
var _state_t: float = 0.0

var _cam: Camera3D
var _cam_tw: Tween
var _orb: Node3D
var _orb_petals: Array[Node3D] = []
var _halo: MeshInstance3D
var _title: MeshInstance3D
var _stars: MultiMeshInstance3D
var _globe: Node3D
## Marcas de evento (Soho): se eligen.
var _markers: Array[Dictionary] = []
## Marcas "?": solo se ven.
var _pistas: Array[Dictionary] = []
var _hovered: int = -1
var _selected: int = -1

## Modo cine: sin interfaz; el grabador mueve el globo.
var _cine: bool = false
var _giro: float = 0.0

var _ui: CanvasLayer
var _raiz: Control
var _press: Control
var _fan: Control
var _buttons: Array[Button] = []
var _tab: PanelContainer
var _eyebrow: Label
var _more: Button
var _restart: Button
var _settings: Control
var _back: Button
var _voice: AudioStreamPlayer
var _music: AudioStreamPlayer
var _music_tw: Tween

var _f_titular: FontVariation
var _f_etiqueta: FontVariation
var _f_aviso: FontVariation

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
	# Capitulares romanas (Cinzel) en negrita: se leen como letras talladas.
	var tm := TextMesh.new()
	tm.text = String(_series.get("title", "UNTITLED"))
	tm.font = _fuente(F_TITULO, 800, 6)
	tm.font_size = 215
	tm.pixel_size = 0.0062
	tm.depth = 0.3
	tm.curve_step = 0.35
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
	sphere.radius = GLOBE_R
	sphere.height = GLOBE_R * 2.0
	sphere.radial_segments = 64
	sphere.rings = 32

	# Primero la cara de atrás (tenue); luego la de delante encima.
	var back := ShaderMaterial.new()
	back.shader = GLOBE_BACK
	back.set_shader_parameter("map", GLOBE_MAP)
	back.render_priority = -1

	var front := ShaderMaterial.new()
	front.shader = GLOBE
	front.set_shader_parameter("map", GLOBE_MAP)
	back.next_pass = front

	var mi := MeshInstance3D.new()
	mi.mesh = sphere
	mi.material_override = back
	_globe.add_child(mi)

	# Atmósfera: cuadro de cara a la cámara, detrás de todo lo del globo.
	var atmos_mat := ShaderMaterial.new()
	atmos_mat.shader = ATMOS
	atmos_mat.set_shader_parameter("radius", GLOBE_R)
	atmos_mat.render_priority = -2
	var atmos_mesh := QuadMesh.new()
	atmos_mesh.size = Vector2.ONE * GLOBE_R * 3.4
	var atmos := MeshInstance3D.new()
	atmos.mesh = atmos_mesh
	atmos.material_override = atmos_mat
	atmos.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_globe.add_child(atmos)

	# Un marcador por evento, en su lat./lon. real.
	var evs := Array(_series.get("events", []))
	for i in evs.size():
		var e: Dictionary = evs[i]
		var m := _pin_evento(float(e.get("lat", 51.51)), float(e.get("lon", -0.14)))
		m["index"] = i
		_markers.append(m)

	for p in PISTAS:
		_pistas.append(_pin_pista(p.x, p.y))


func _on_sphere(lat_deg: float, lon_deg: float, r: float) -> Vector3:
	var la := deg_to_rad(lat_deg)
	var lo := deg_to_rad(lon_deg)
	return Vector3(
		r * cos(la) * sin(lo),
		r * sin(la),
		r * cos(la) * cos(lo))


## Nodo sobre el globo con +Y hacia fuera (la normal).
func _pin_root(lat: float, lon: float) -> Node3D:
	var pos := _on_sphere(lat, lon, GLOBE_R)
	var y := pos.normalized()
	var x := y.cross(Vector3.UP)
	if x.length() < 0.01:
		x = Vector3.RIGHT
	x = x.normalized()
	var root := Node3D.new()
	root.transform = Transform3D(Basis(x, y, x.cross(y)), pos)
	_globe.add_child(root)
	return root


func _pin_mat(kind: int, c: Color, prioridad: int) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = PIN
	m.set_shader_parameter("kind", kind)
	m.set_shader_parameter("color", c)
	m.render_priority = prioridad
	return m


func _pin_quad(parent: Node3D, mat: Material, size: float, plano: bool, y: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	if plano:
		var pm := PlaneMesh.new()
		pm.size = Vector2.ONE * size
		mi.mesh = pm
	else:
		var qm := QuadMesh.new()
		qm.size = Vector2.ONE * size
		mi.mesh = qm
	mi.material_override = mat
	mi.position = Vector3(0.0, y, 0.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


## Marca de un evento: punto de oro con halo que late y anillos sobre la superficie.
func _pin_evento(lat: float, lon: float) -> Dictionary:
	var root := _pin_root(lat, lon)

	var rings := _pin_mat(1, C_PIN_ORO, 1)
	rings.set_shader_parameter("billboard", 0.0)
	rings.set_shader_parameter("ring_loop", 1.0)
	_pin_quad(root, rings, 0.80, true, 0.012)

	var burst := _pin_mat(1, Color(1.0, 0.88, 0.62), 1)
	burst.set_shader_parameter("billboard", 0.0)
	_pin_quad(root, burst, 1.3, true, 0.016)

	var dot := _pin_mat(0, C_PIN_ORO, 2)
	dot.set_shader_parameter("pulse", 1.0)
	_pin_quad(root, dot, 0.52, false, 0.02)

	return {"node": root, "base": root.position, "dot": dot, "burst": burst,
		"mats": [rings, burst, dot], "stem": null, "label": null, "a": -1.0}


## Marca "?": punto en el suelo, palo fino y una insignia con la interrogación.
func _pin_pista(lat: float, lon: float) -> Dictionary:
	var root := _pin_root(lat, lon)
	const ALTO := 0.30

	var dot := _pin_mat(0, C_PIN_HIELO, 1)
	dot.set_shader_parameter("pulse", 0.4)
	_pin_quad(root, dot, 0.20, false, 0.01)

	var burst := _pin_mat(1, C_PIN_HIELO, 1)
	burst.set_shader_parameter("billboard", 0.0)
	_pin_quad(root, burst, 0.9, true, 0.014)

	var stem_mat := StandardMaterial3D.new()
	stem_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	stem_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	stem_mat.albedo_color = Color(C_PIN_HIELO, 0.55)
	stem_mat.render_priority = 1
	var stem_mesh := CylinderMesh.new()
	stem_mesh.top_radius = 0.0045
	stem_mesh.bottom_radius = 0.0045
	stem_mesh.height = ALTO - 0.1
	stem_mesh.radial_segments = 6
	stem_mesh.rings = 1
	var stem := MeshInstance3D.new()
	stem.mesh = stem_mesh
	stem.material_override = stem_mat
	stem.position = Vector3(0.0, (ALTO - 0.1) * 0.5, 0.0)
	root.add_child(stem)

	var badge := ShaderMaterial.new()
	badge.shader = BADGE
	badge.render_priority = 2
	_pin_quad(root, badge, 0.25, false, ALTO)

	var q := Label3D.new()
	q.text = "?"
	q.font = F_SERIF_FUERTE
	q.font_size = 84
	q.pixel_size = 0.0021
	q.outline_size = 0
	q.modulate = Color(0.90, 0.95, 1.0)
	q.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	q.double_sided = true
	q.render_priority = 3
	q.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	q.position = Vector3(0.0, ALTO, 0.0)
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(q)

	return {"node": root, "dot": dot, "burst": burst, "badge": badge,
		"mats": [dot, burst, badge], "stem": stem_mat, "label": q, "a": -1.0}


## Apaga las marcas que quedan detrás del globo.
func _fade_pins() -> void:
	var c := _globe.global_position
	var to_cam := (_cam.global_position - c).normalized()
	for list in [_markers, _pistas]:
		for p in list:
			var node: Node3D = p["node"]
			var n := (node.global_position - c).normalized()
			var a := smoothstep(0.04, 0.32, n.dot(to_cam))
			if absf(a - float(p["a"])) < 0.005:
				continue
			p["a"] = a
			for m in p["mats"]:
				(m as ShaderMaterial).set_shader_parameter("fade", a)
			if p["stem"] != null:
				var sm: StandardMaterial3D = p["stem"]
				sm.albedo_color = Color(sm.albedo_color, 0.55 * a)
			if p["label"] != null:
				var lb: Label3D = p["label"]
				lb.modulate = Color(lb.modulate, a)


# --- Tipografía y tema --------------------------------------------------------

## Fuente con peso (si es variable) y espacio extra entre letras.
func _fuente(base: Font, peso: int = 0, espacio: int = 0) -> FontVariation:
	var fv := FontVariation.new()
	fv.base_font = base
	if peso > 0:
		fv.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): peso}
	fv.spacing_glyph = espacio
	return fv


func _caja(bg: Color, borde: Color = Color(0, 0, 0, 0), radio: int = 8,
		mx: float = 22.0, my: float = 10.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.draw_center = bg.a > 0.0
	if borde.a > 0.0:
		sb.border_color = borde
		sb.set_border_width_all(1)
	sb.set_corner_radius_all(radio)
	sb.content_margin_left = mx
	sb.content_margin_right = mx
	sb.content_margin_top = my
	sb.content_margin_bottom = my + 2.0
	sb.anti_aliasing = true
	return sb


func _vacia(mx: float, my: float) -> StyleBoxEmpty:
	var sb := StyleBoxEmpty.new()
	sb.content_margin_left = mx
	sb.content_margin_right = mx
	sb.content_margin_top = my
	sb.content_margin_bottom = my + 2.0
	return sb


## Círculo suave para el tirador de los deslizadores.
func _circulo(d: int, c: Color) -> ImageTexture:
	var img := Image.create(d, d, false, Image.FORMAT_RGBA8)
	var r := float(d) * 0.5
	for y in d:
		for x in d:
			var dist := Vector2(float(x) + 0.5 - r, float(y) + 0.5 - r).length()
			var a := clampf(r - 1.0 - dist + 0.5, 0.0, 1.0)
			img.set_pixel(x, y, Color(c.r, c.g, c.b, a * c.a))
	return ImageTexture.create_from_image(img)


func _botones_colores(t: Theme, tipo: String, normal: Color, encima: Color, pulsado: Color) -> void:
	t.set_color("font_color", tipo, normal)
	t.set_color("font_hover_color", tipo, encima)
	t.set_color("font_focus_color", tipo, encima)
	t.set_color("font_hover_pressed_color", tipo, pulsado)
	t.set_color("font_pressed_color", tipo, pulsado)
	t.set_color("font_disabled_color", tipo, normal)


func _build_theme() -> Theme:
	var t := Theme.new()
	t.default_font = F_SERIF
	t.default_font_size = 24

	t.set_color("font_color", "Label", C_TEXTO)
	t.set_constant("line_spacing", "Label", 4)

	# Botón por defecto: sin caja, se aclara al pasar.
	t.set_font("font", "Button", F_SERIF_MEDIA)
	t.set_stylebox("normal", "Button", _vacia(10, 6))
	t.set_stylebox("hover", "Button", _caja(Color(0.62, 0.76, 1.0, 0.07), Color(0, 0, 0, 0), 6, 10, 6))
	t.set_stylebox("pressed", "Button", _caja(Color(0.62, 0.76, 1.0, 0.12), Color(0, 0, 0, 0), 6, 10, 6))
	t.set_stylebox("focus", "Button", _caja(Color(0, 0, 0, 0), Color(0.80, 0.90, 1.0, 0.45), 6, 10, 6))
	t.set_stylebox("disabled", "Button", _vacia(10, 6))
	_botones_colores(t, "Button", C_TEXTO, C_CLARO, C_HIELO)

	# Abanico: texto grande con sombra; al pasar, una píldora que brilla.
	t.set_type_variation("BotonAbanico", "Button")
	t.set_font("font", "BotonAbanico", F_SERIF_MEDIA)
	t.set_font_size("font_size", "BotonAbanico", 34)
	t.set_stylebox("normal", "BotonAbanico", _vacia(30, 8))
	t.set_stylebox("disabled", "BotonAbanico", _vacia(30, 8))
	var fan_hover := _caja(Color(0.62, 0.76, 1.0, 0.08), Color(0.78, 0.88, 1.0, 0.30), 28, 30, 8)
	fan_hover.shadow_color = Color(0.45, 0.65, 1.0, 0.16)
	fan_hover.shadow_size = 18
	t.set_stylebox("hover", "BotonAbanico", fan_hover)
	t.set_stylebox("pressed", "BotonAbanico", _caja(Color(0.62, 0.76, 1.0, 0.16), Color(0.78, 0.88, 1.0, 0.40), 28, 30, 8))
	t.set_stylebox("focus", "BotonAbanico", _caja(Color(0, 0, 0, 0), Color(0.85, 0.92, 1.0, 0.55), 28, 30, 8))
	_botones_colores(t, "BotonAbanico", C_TEXTO, C_CLARO, C_HIELO)

	# Volver: píldora discreta.
	t.set_type_variation("BotonVolver", "Button")
	t.set_font_size("font_size", "BotonVolver", 24)
	t.set_stylebox("normal", "BotonVolver", _caja(Color(0.03, 0.04, 0.08, 0.55), Color(0.70, 0.80, 1.0, 0.22), 22, 20, 6))
	var back_hover := _caja(Color(0.55, 0.70, 1.0, 0.12), Color(0.80, 0.90, 1.0, 0.50), 22, 20, 6)
	back_hover.shadow_color = Color(0.45, 0.65, 1.0, 0.14)
	back_hover.shadow_size = 12
	t.set_stylebox("hover", "BotonVolver", back_hover)
	t.set_stylebox("pressed", "BotonVolver", _caja(Color(0.55, 0.70, 1.0, 0.18), Color(0.80, 0.90, 1.0, 0.55), 22, 20, 6))
	t.set_stylebox("focus", "BotonVolver", _caja(Color(0, 0, 0, 0), Color(0.85, 0.92, 1.0, 0.65), 22, 20, 6))
	_botones_colores(t, "BotonVolver", Color(0.78, 0.84, 0.95), C_CLARO, C_HIELO)

	# Principal ("Enter this life"): relleno de oro, letra oscura.
	t.set_type_variation("BotonPrincipal", "Button")
	t.set_font("font", "BotonPrincipal", F_SERIF_FUERTE)
	t.set_font_size("font_size", "BotonPrincipal", 29)
	var main_n := _caja(Color(0.88, 0.74, 0.47), Color(1.0, 0.90, 0.70, 0.55), 8, 24, 10)
	main_n.shadow_color = Color(1.0, 0.76, 0.38, 0.14)
	main_n.shadow_size = 10
	var main_h := _caja(Color(0.97, 0.85, 0.60), Color(1.0, 0.95, 0.82, 0.8), 8, 24, 10)
	main_h.shadow_color = Color(1.0, 0.78, 0.40, 0.32)
	main_h.shadow_size = 22
	var main_f := _caja(Color(0, 0, 0, 0), Color(1.0, 0.97, 0.90, 0.9), 10, 24, 10)
	main_f.set_border_width_all(2)
	main_f.set_expand_margin_all(4)
	t.set_stylebox("normal", "BotonPrincipal", main_n)
	t.set_stylebox("hover", "BotonPrincipal", main_h)
	t.set_stylebox("pressed", "BotonPrincipal", _caja(Color(0.76, 0.62, 0.37), Color(1.0, 0.90, 0.70, 0.5), 8, 24, 10))
	t.set_stylebox("focus", "BotonPrincipal", main_f)
	t.set_stylebox("disabled", "BotonPrincipal", main_n)
	var oscuro := Color(0.08, 0.07, 0.10)
	_botones_colores(t, "BotonPrincipal", oscuro, oscuro, oscuro)

	# Paneles: ficha del evento y ajustes.
	t.set_type_variation("Ficha", "PanelContainer")
	var ficha := _caja(C_PANEL, Color(0.62, 0.72, 0.92, 0.20), 14, 40, 30)
	ficha.content_margin_bottom = 34
	ficha.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	ficha.shadow_size = 36
	t.set_stylebox("panel", "Ficha", ficha)

	# Barra de scroll fina.
	var track := _caja(Color(1, 1, 1, 0.05), Color(0, 0, 0, 0), 3, 3, 0)
	track.content_margin_bottom = 0
	t.set_stylebox("scroll", "VScrollBar", track)
	t.set_stylebox("scroll_focus", "VScrollBar", track)
	for nombre in [["grabber", 0.30], ["grabber_highlight", 0.50], ["grabber_pressed", 0.65]]:
		var g := _caja(Color(C_HIELO, nombre[1]), Color(0, 0, 0, 0), 3, 3, 0)
		g.content_margin_bottom = 0
		t.set_stylebox(nombre[0], "VScrollBar", g)

	# Deslizadores: pista fina, tramo lleno en hielo y tirador redondo.
	var pista := _caja(Color(1, 1, 1, 0.12), Color(0, 0, 0, 0), 3, 0, 3)
	pista.content_margin_bottom = 3
	t.set_stylebox("slider", "HSlider", pista)
	var lleno := _caja(Color(C_HIELO, 0.70), Color(0, 0, 0, 0), 3, 0, 3)
	lleno.content_margin_bottom = 3
	t.set_stylebox("grabber_area", "HSlider", lleno)
	var lleno_h := _caja(Color(C_HIELO, 0.95), Color(0, 0, 0, 0), 3, 0, 3)
	lleno_h.content_margin_bottom = 3
	t.set_stylebox("grabber_area_highlight", "HSlider", lleno_h)
	t.set_icon("grabber", "HSlider", _circulo(22, Color(0.92, 0.96, 1.0)))
	t.set_icon("grabber_highlight", "HSlider", _circulo(22, Color(1, 1, 1)))
	t.set_icon("grabber_disabled", "HSlider", _circulo(22, Color(0.6, 0.65, 0.75)))
	t.set_stylebox("focus", "HSlider", StyleBoxEmpty.new())

	# Desplegable de idioma.
	var opt := _caja(Color(1, 1, 1, 0.03), Color(0.70, 0.80, 1.0, 0.22), 6, 14, 5)
	for s in ["normal", "disabled", "hover", "pressed"]:
		t.set_stylebox(s, "OptionButton", opt)
	t.set_font("font", "OptionButton", F_SERIF)
	t.set_color("font_disabled_color", "OptionButton", C_TENUE)
	t.set_color("font_color", "OptionButton", C_TEXTO)
	return t


# --- Interfaz -----------------------------------------------------------------

func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 5
	add_child(_ui)

	_f_titular = _fuente(F_SERIF_FUERTE, 0, 3)
	_f_etiqueta = _fuente(F_SANS, 600, 4)
	_f_aviso = _fuente(F_SANS, 600, 8)

	# Raíz con el tema: todo lo de la interfaz cuelga de aquí.
	_raiz = Control.new()
	_raiz.theme = _build_theme()
	_raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_raiz)
	_raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

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


## Línea que se desvanece hacia un lado.
func _linea(c: Color, ancho: float, hacia_derecha: bool = true) -> TextureRect:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 1.0])
	var lleno := Color(c, c.a)
	var nada := Color(c, 0.0)
	g.colors = PackedColorArray([lleno, nada] if hacia_derecha else [nada, lleno])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.width = 256
	tex.height = 2
	var r := TextureRect.new()
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.custom_minimum_size = Vector2(ancho, 1)
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _build_press() -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 26)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.modulate.a = 0.0
	_raiz.add_child(row)
	row.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	row.offset_left = -400.0
	row.offset_right = 400.0
	row.offset_top = 760.0
	row.offset_bottom = 800.0
	row.pivot_offset = Vector2(400.0, 20.0)

	row.add_child(_linea(Color(C_HIELO, 0.6), 90.0, false))
	var l := Label.new()
	l.text = "PRESS ANY KEY"
	l.add_theme_font_override("font", _f_aviso)
	l.add_theme_font_size_override("font_size", 19)
	l.add_theme_color_override("font_color", Color(0.80, 0.88, 1.0))
	l.add_theme_color_override("font_shadow_color", Color(0.3, 0.5, 1.0, 0.35))
	l.add_theme_constant_override("shadow_outline_size", 10)
	l.add_theme_constant_override("shadow_offset_y", 0)
	row.add_child(l)
	row.add_child(_linea(Color(C_HIELO, 0.6), 90.0, true))
	_press = row


## Abanico: las posiciones siguen un arco; el texto queda horizontal.
func _build_fan() -> void:
	_fan = Control.new()
	_fan.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fan.modulate.a = 0.0
	_raiz.add_child(_fan)
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
		b.theme_type_variation = &"BotonAbanico"
		b.custom_minimum_size = Vector2(0, 60)
		_fan.add_child(b)
		# Centrado en su punto del arco, mida lo que mida el texto.
		var w := maxf(b.get_combined_minimum_size().x, 150.0)
		b.size = Vector2(w, 60)
		b.position = Vector2(
			960.0 + k * SPAN * 0.5 - w * 0.5,
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


## Esquina de la ficha: lugar y año a la izq.; "···" abre "Start over" (dos clics, a propósito).
func _build_corner() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	_eyebrow = Label.new()
	_eyebrow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_eyebrow.add_theme_font_override("font", _f_etiqueta)
	_eyebrow.add_theme_font_size_override("font_size", 16)
	_eyebrow.add_theme_color_override("font_color", C_ORO)
	_eyebrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_eyebrow)

	# Antes del "···" para que se abra hacia su izquierda.
	_restart = Button.new()
	_restart.text = "Start over"
	_restart.visible = false
	_restart.add_theme_font_size_override("font_size", 20)
	_restart.add_theme_color_override("font_color", Color(0.80, 0.73, 0.64))
	_restart.add_theme_color_override("font_hover_color", Color(1.0, 0.87, 0.71))
	_restart.pressed.connect(_confirmar_reinicio)
	row.add_child(_restart)

	# "···" y no "⋯": ese glifo no está en todas las fuentes.
	_more = Button.new()
	_more.text = "···"
	_more.custom_minimum_size = Vector2(46, 0)
	_more.add_theme_font_size_override("font_size", 24)
	_more.add_theme_color_override("font_color", Color(0.50, 0.57, 0.72))
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
	_tab.theme_type_variation = &"Ficha"
	_raiz.add_child(_tab)
	_tab.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	_tab.offset_left = -700.0
	_tab.offset_right = -60.0
	_tab.offset_top = 90.0
	_tab.offset_bottom = -90.0

	# El texto hace scroll; el botón de jugar queda fijo.
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	_tab.add_child(root)

	root.add_child(_build_corner())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)

	# Hueco a la der. para que el texto no toque la barra.
	var pad := MarginContainer.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_theme_constant_override("margin_right", 22)
	scroll.add_child(pad)

	var col := VBoxContainer.new()
	col.name = "Col"
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 8)
	pad.add_child(col)

	root.add_child(_hueco(4))

	var play := Button.new()
	play.name = "Play"
	play.text = "Enter this life"
	play.theme_type_variation = &"BotonPrincipal"
	play.custom_minimum_size = Vector2(0, 64)
	play.mouse_entered.connect(func(): _sound(SON_PASAR, -16.0))
	root.add_child(play)
	play.pressed.connect(func(): _begin(_terminado()))


func _fill_tab(i: int) -> void:
	var e := _event(i)

	# La esquina se cierra cada vez que se abre la ficha.
	if _restart != null:
		_restart.visible = false

	_eyebrow.text = "%s   ·   %s" % [
		String(e.get("place", "")).to_upper(), String(e.get("year", ""))]

	var col := _tab.find_child("Col", true, false) as VBoxContainer
	for c in col.get_children():
		col.remove_child(c)
		c.queue_free()

	col.add_child(_tab_title(String(e.get("name", ""))))
	col.add_child(_linea(Color(C_ORO, 0.55), 0.0))

	_tab_section(col, "You play")
	col.add_child(_tab_body(String(e.get("host", ""))))

	_tab_section(col, "What happened")
	col.add_child(_tab_body(String(e.get("description", ""))))

	_tab_section(col, "Why it still matters")
	col.add_child(_tab_body(String(e.get("impact", ""))))

	# Habilidades como verbos, no como asignaturas.
	_tab_section(col, "What you will get good at")
	for s in Array(e.get("skills", [])):
		col.add_child(_tab_bullet(String(s)))

	col.add_child(_hueco(10))
	col.add_child(_linea(Color(C_HIELO, 0.35), 0.0))

	# Progreso como hechos, no como nota.
	_tab_section(col, "Where you left it")
	for line in _progress_lines(e):
		var l := _tab_body(line)
		l.add_theme_color_override("font_color", Color(0.78, 0.82, 0.90))
		col.add_child(l)

	# La cámara va a la der. para que el globo no quede bajo el panel.
	# 2.7 m ≈ 350 px: panel de 640 px en 1920; a esta distancia 1 px ≈ 0.0069 m.
	_kill_cam_tw()
	_cam_tw = create_tween()
	_cam_tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_cam_tw.tween_property(_cam, "position:x", CAM_EVENTS.x + 2.7, MOVE)


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
	l.text = t
	l.add_theme_font_override("font", _f_titular)
	l.add_theme_font_size_override("font_size", 66)
	l.add_theme_color_override("font_color", C_CLARO)
	return l


## Hueco y cabecera de sección.
func _tab_section(col: VBoxContainer, t: String) -> void:
	col.add_child(_hueco(12))
	var l := Label.new()
	l.text = t.to_upper()
	l.add_theme_font_override("font", _f_etiqueta)
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", Color(0.58, 0.70, 0.92))
	col.add_child(l)


func _tab_body(t: String) -> Label:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 25)
	l.add_theme_color_override("font_color", C_TEXTO)
	return l


func _tab_bullet(t: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var dot := Label.new()
	dot.text = "·"
	dot.add_theme_font_size_override("font_size", 30)
	dot.add_theme_color_override("font_color", C_ORO)
	dot.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(dot)
	var body := _tab_body(t)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(body)
	return row


func _hueco(alto: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, alto)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _build_settings() -> void:
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"Ficha"
	panel.visible = false
	_raiz.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -440.0
	panel.offset_right = 440.0
	panel.offset_top = -250.0
	panel.offset_bottom = 250.0
	_settings = panel

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 20)
	panel.add_child(box)

	var head := Label.new()
	head.text = "Settings"
	head.add_theme_font_override("font", _f_titular)
	head.add_theme_font_size_override("font_size", 50)
	head.add_theme_color_override("font_color", C_CLARO)
	box.add_child(head)
	box.add_child(_linea(Color(C_ORO, 0.55), 0.0))

	var sub := Label.new()
	sub.text = "SOUND"
	sub.add_theme_font_override("font", _f_etiqueta)
	sub.add_theme_font_size_override("font_size", 15)
	sub.add_theme_color_override("font_color", Color(0.58, 0.70, 0.92))
	box.add_child(sub)

	for pair in BUSES:
		var bus: String = pair[0]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 24)
		var name_label := Label.new()
		name_label.text = pair[1]
		name_label.custom_minimum_size = Vector2(190, 0)
		name_label.add_theme_font_size_override("font_size", 25)
		row.add_child(name_label)

		var idx := AudioServer.get_bus_index(bus)
		var slider := HSlider.new()
		slider.min_value = -40.0
		slider.max_value = 6.0
		slider.value = AudioServer.get_bus_volume_db(idx) if idx >= 0 else 0.0
		slider.custom_minimum_size = Vector2(420, 32)
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		slider.value_changed.connect(func(v: float):
			if idx >= 0:
				AudioServer.set_bus_volume_db(idx, v))
		row.add_child(slider)
		box.add_child(row)

	box.add_child(_hueco(4))
	var lang := HBoxContainer.new()
	lang.add_theme_constant_override("separation", 24)
	var ll := Label.new()
	ll.text = "Language"
	ll.custom_minimum_size = Vector2(190, 0)
	ll.add_theme_font_size_override("font_size", 25)
	lang.add_child(ll)
	var opt := OptionButton.new()
	opt.add_item("English")
	opt.disabled = true
	opt.add_theme_font_size_override("font_size", 23)
	lang.add_child(opt)
	box.add_child(lang)


func _build_back() -> void:
	_back = Button.new()
	_back.text = "‹   Back"
	_back.theme_type_variation = &"BotonVolver"
	_back.visible = false
	_raiz.add_child(_back)
	_back.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_back.offset_left = 54.0
	_back.offset_top = 46.0
	_back.offset_right = 54.0
	_back.offset_bottom = 46.0
	_back.mouse_entered.connect(func(): _sound(SON_PASAR, -16.0))
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

	_kill_cam_tw()
	_cam_tw = create_tween()
	_cam_tw.set_parallel(true)
	_cam_tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_cam_tw.tween_property(_cam, "position", cam_to, MOVE)
	if s != State.INTRO:
		_cam_tw.tween_property(_title, "scale", title_scale, MOVE)
		_cam_tw.tween_property(_title, "position:y", title_y, MOVE)


func _kill_cam_tw() -> void:
	if _cam_tw != null and _cam_tw.is_valid():
		_cam_tw.kill()


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


# --- Cine (para el grabador) --------------------------------------------------

## Cine: oculta interfaz, orbe y título; deja estrellas y globo, con todas las marcas ocultas.
func cine_preparar() -> void:
	_cine = true
	_state = State.EVENTS
	_selected = -1
	_hovered = -1
	_ui.visible = false
	_orb.visible = false
	_halo.visible = false
	_title.visible = false
	_kill_cam_tw()
	_cam.position = CAM_EVENTS
	_giro = 0.0
	for list in [_markers, _pistas]:
		for p in list:
			var node: Node3D = p["node"]
			node.visible = false
			node.scale = Vector3.ONE * 0.001


## Cine: cuántas marcas "?" hay.
func cine_num_pistas() -> int:
	return _pistas.size()


## Cine: la marca "?" i aparece de golpe, con un destello y un anillo.
func cine_mostrar_pista(i: int) -> void:
	if i < 0 or i >= _pistas.size():
		return
	_revelar(_pistas[i], 0.55, 1.0)
	_sound(SON_PASAR, -14.0)


## Cine: la marca de Soho aparece con un pulso cálido.
func cine_mostrar_soho() -> void:
	if _markers.is_empty():
		return
	_revelar(_markers[0], 0.8, 1.6)
	_sound(SON_ELEGIR, -8.0)


## Cine: el nodo del globo (las marcas son hijas suyas y giran con él).
func cine_globo() -> Node3D:
	return _globe


## Cine: la cámara del menú.
func cine_camara() -> Camera3D:
	return _cam


## Cine: posición en el mundo de la marca de Soho (sobre la superficie).
func cine_posicion_soho() -> Vector3:
	return (_markers[0]["node"] as Node3D).global_position if not _markers.is_empty() else GLOBE_AT


## Cine: posición en el mundo de la marca "?" i (sobre la superficie).
func cine_posicion_pista(i: int) -> Vector3:
	if i < 0 or i >= _pistas.size():
		return GLOBE_AT
	return (_pistas[i]["node"] as Node3D).global_position


## Cine: giro del globo sobre su eje, en rad/s (0 lo para).
func cine_giro(vel: float) -> void:
	_giro = vel


## Cine: gira el globo para que lat./lon. mire a la cámara (segundos = 0, al instante).
func cine_mirar(lat: float, lon: float, segundos: float = 1.5) -> void:
	var to := Basis(Vector3.RIGHT, deg_to_rad(lat)) * Basis(Vector3.UP, deg_to_rad(-lon))
	if segundos <= 0.0:
		_globe.basis = to
		return
	var q0 := _globe.basis.get_rotation_quaternion()
	var q1 := to.get_rotation_quaternion()
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_method(func(k: float): _globe.basis = Basis(q0.slerp(q1, k)), 0.0, 1.0, segundos)


func _revelar(p: Dictionary, dur: float, fuerza: float) -> void:
	var node: Node3D = p["node"]
	node.visible = true
	node.scale = Vector3.ONE * 0.001
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(node, "scale", Vector3.ONE, dur) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var dot: ShaderMaterial = p["dot"]
	var burst: ShaderMaterial = p["burst"]
	tw.tween_method(func(v: float): dot.set_shader_parameter("flash", v), fuerza, 0.0, dur * 2.0)
	tw.tween_method(func(v: float): burst.set_shader_parameter("progreso", v), 0.0, 1.0, dur * 2.2)
	if p.has("badge"):
		var badge: ShaderMaterial = p["badge"]
		tw.tween_method(func(v: float): badge.set_shader_parameter("flash", v), 1.0, 0.0, dur * 1.6)


# --- Fotograma ----------------------------------------------------------------

func _process(delta: float) -> void:
	_t += delta
	_state_t += delta

	if _cine:
		if _giro != 0.0:
			_globe.rotate_object_local(Vector3.UP, delta * _giro)
		_drift_stars(delta)
		_fade_pins()
		return

	_run_state(delta)
	_move_orb(delta)
	_spin_orb(delta)
	_drift_stars(delta)

	# Vaivén leve del hielo: los brillos y la refracción se mueven.
	_title.rotation = Vector3(0.03 * sin(_t * 0.23), 0.06 * sin(_t * 0.31), 0.0)

	if _state == State.EVENTS:
		_globe.rotate_object_local(Vector3.UP, delta * 0.09)
		_fade_pins()
		_hover_markers()

	if _press.modulate.a > 0.01:
		# Leve balanceo: es lo único en pantalla que pide algo.
		_press.rotation = deg_to_rad(1.6 * sin(_t * 1.35))
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
		# Detrás de la cámara o en la cara oculta del globo: no cuenta.
		if _cam.is_position_behind(node.global_position) or float(m["a"]) < 0.5:
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
		var want := 1.6 if on else 1.0
		node.scale = node.scale.lerp(Vector3.ONE * want, 0.18)


func _unhandled_input(event: InputEvent) -> void:
	if _cine:
		return
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
