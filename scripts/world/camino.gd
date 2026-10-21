extends Node3D
## Camino a Hampstead: el carro esquiva baches, piedras, charcos y tablones (A/D, flechas).
## De la niebla de Soho al campo con sol.

const CARRUAJE := preload("res://scripts/world/carruaje.gd")
const VESTUARIO := preload("res://scripts/world/vestuario.gd")
const FIGURA := "res://scenes/world/props/figura.tscn"
const HAMPSTEAD := "res://scenes/world/hampstead.tscn"
const GUIA := preload("res://scripts/guia.gd")
## Cada tantos golpes se cae un papel del maletín.
const GOLPES_POR_PAPEL := 3
## Las que no se pueden volver a preguntar en una puerta.
const NO_SE_PIERDEN := ["f_40", "f_hampstead"]
const MODELOS := "res://art/models/Medieval/GLB format/%s.glb"
const GARAMOND_SEMI := preload("res://art/fonts/EB_Garamond/static/EBGaramond-SemiBold.ttf")
const GOLPES := ["res://audio/sfx/puerta/golpe_1.ogg", "res://audio/sfx/puerta/golpe_2.ogg",
	"res://audio/sfx/puerta/golpe_3.ogg"]

## Segundos de viaje.
const DURA := 42.0
## m/s a los que pasa el suelo.
const VELOCIDAD := 15.0
## Medio ancho del camino por el que se puede mover el carro.
const BORDE := 2.1
## m/s de lado.
const GIRO := 5.5
const LEJOS := -110.0

const NOCHE := {"cielo": Color(0.09, 0.11, 0.09), "niebla": Color(0.20, 0.24, 0.16), "densidad": 0.05,
	"sol": 0.25, "ambiente": 0.35}
const DIA := {"cielo": Color(0.5, 0.74, 1.0), "niebla": Color(0.84, 0.9, 0.98), "densidad": 0.004,
	"sol": 1.35, "ambiente": 0.8}

var golpes: int = 0
var _carro: Node3D
var _t: float = 0.0
var _hasta_obstaculo: float = 2.5
var _hasta_decorado: float = 0.0
var _obstaculos: Array[Node3D] = []
var _decorado: Array[Node3D] = []
var _env: Environment
var _sol: DirectionalLight3D
var _cam: Camera3D
var _cam_base: Vector3
var _sacudida: float = 0.0
var _son: AudioStreamPlayer
var _capa: CanvasLayer
var _terminando: bool = false
var _rng := RandomNumberGenerator.new()
var _suelos: Array[MeshInstance3D] = []
var _cielo: ProceduralSkyMaterial


func _ready() -> void:
	_rng.seed = 1854
	HUD.hide()
	_entorno()
	_suelo()
	_carro = Node3D.new()
	_carro.set_script(CARRUAJE)
	add_child(_carro)
	_carro.set(&"andando", true)
	_vestir_carro()
	var wh := _figura({"chistera": true, "alzacuellos": true, "mira_alrededor": false, "sentado": true})
	_carro.add_child(wh)
	wh.position = CARRUAJE.ASIENTO_2 + CARRUAJE.SENTADO
	var carretero := _figura({"abrigo": [0.30, 0.24, 0.17], "pantalon": [0.22, 0.2, 0.17], "gorra": true,
		"chistera": false, "alzacuellos": false, "mira_alrededor": false, "sentado": true})
	_carro.add_child(carretero)
	carretero.position = CARRUAJE.ASIENTO_1 + CARRUAJE.SENTADO
	for f in [wh, carretero]:
		(f as Node3D).rotation.y = -PI * 0.5
	_cam = Camera3D.new()
	_cam.fov = 55.0
	_cam.far = 400.0
	add_child(_cam)
	# Tres cuartos por detrás: se ven el caballo, los dos sentados y lo que viene.
	_cam_base = Vector3(6.2, 3.3, 4.2)
	_cam.position = _cam_base
	_cam.look_at(Vector3(-6.0, 0.9, -0.6))
	_cam.current = true
	_son = AudioStreamPlayer.new()
	_son.bus = &"Efectos"
	add_child(_son)
	_capa = CanvasLayer.new()
	add_child(_capa)
	_pista("A / D or the arrow keys: steer round the holes, stones, puddles and planks.\nEvery third bump, a paper falls out of your case.")
	# Primeros metros con casas.
	for i in 12:
		_poner_decorado(LEJOS * float(i) / 12.0)


func _process(delta: float) -> void:
	var dt := minf(delta, 0.05)
	_t += dt
	var p := clampf(_t / DURA, 0.0, 1.0)
	_luz(p)
	# Mover el carro de lado.
	var lado := Input.get_axis(&"andar_izquierda", &"andar_derecha")
	if lado == 0.0:
		lado = Input.get_axis(&"ui_left", &"ui_right")
	if not _terminando:
		_carro.position.z = clampf(_carro.position.z - lado * GIRO * dt, -BORDE, BORDE)
	_carro.rotation.x = lerpf(_carro.rotation.x, lado * 0.05, 0.2)
	_carro.position.y = absf(sin(_t * 11.0)) * 0.04
	var v := VELOCIDAD * (0.4 if _terminando else 1.0)
	for s in _suelos:
		s.position.x += v * dt
		if s.position.x > 60.0:
			s.position.x -= 240.0
	_mover(_obstaculos, v * dt, true)
	_mover(_decorado, v * dt, false)
	_hasta_obstaculo -= dt
	if _hasta_obstaculo <= 0.0 and _t < DURA - 4.0:
		_poner_obstaculo()
		_hasta_obstaculo = _rng.randf_range(0.9, 1.6)
	_hasta_decorado -= dt
	if _hasta_decorado <= 0.0:
		_poner_decorado(LEJOS)
		_hasta_decorado = 0.55
	# Polvo de las ruedas: motas que se quedan atrás y se encogen.
	_hasta_polvo -= dt
	if _hasta_polvo <= 0.0 and _mat_polvo != null:
		_hasta_polvo = 0.07
		var mota := _caja(self, Vector3(0.08, 0.08, 0.08), _carro.position + Vector3(0.7, 0.1, _rng.randf_range(-0.7, 0.7)), Color.WHITE)
		mota.material_override = _mat_polvo
		var t := mota.create_tween().set_parallel()
		t.tween_property(mota, "position", mota.position + Vector3(_rng.randf_range(2.0, 3.5), _rng.randf_range(0.2, 0.5), 0), 0.6)
		t.tween_property(mota, "scale", Vector3.ONE * 0.1, 0.6)
		t.chain().tween_callback(mota.queue_free)
	# Sacudida tras un golpe.
	_sacudida = maxf(0.0, _sacudida - dt * 2.5)
	_cam.position = _cam_base + Vector3(0, sin(_t * 60.0), cos(_t * 47.0)) * 0.12 * _sacudida
	if _t >= DURA and not _terminando:
		_llegar()


func _mover(lista: Array[Node3D], dx: float, chocan: bool) -> void:
	for n in lista.duplicate():
		n.position.x += dx
		if chocan and not n.get_meta(&"visto", false) and n.position.x > -0.8:
			n.set_meta(&"visto", true)
			if absf(n.position.z - _carro.position.z) < float(n.get_meta(&"ancho", 0.9)):
				_golpe()
		if n.position.x > 25.0:
			lista.erase(n)
			n.queue_free()


func _golpe() -> void:
	golpes += 1
	_sacudida = 1.0
	_son.stream = load(GOLPES[_rng.randi() % GOLPES.size()]) as AudioStream
	_son.pitch_scale = _rng.randf_range(0.6, 0.8)
	_son.play()
	if golpes % GOLPES_POR_PAPEL == 0:
		_perder_un_papel()


## El último papel sellado que una puerta puede volver a dar se va con el viento.
func _perder_un_papel() -> void:
	var cual := ""
	for id in Cuaderno.selladas():
		if id in NO_SE_PIERDEN:
			continue
		var se_puede := true
		for w in Dictionary(Cuaderno.ficha(id).get("huecos", {})).values():
			if GUIA.dialogo_de_palabra(String(w)).is_empty():
				se_puede = false
		if se_puede:
			cual = id
	if cual.is_empty():
		return
	Cuaderno.perder(cual)
	GameState.set_flag("papel_perdido_" + cual)
	_papel_al_viento()
	_pista("A paper fell out of your case: %s." % String(Cuaderno.ficha(cual).get("titulo", "")), 120.0, 3.0)


func _papel_al_viento() -> void:
	var hoja := _caja(self, Vector3(0.32, 0.02, 0.42), _carro.position + Vector3(0.2, 1.4, 0.0), Color(0.95, 0.92, 0.84))
	var t := hoja.create_tween().set_parallel()
	t.tween_property(hoja, "position", hoja.position + Vector3(9.0, 3.5, _rng.randf_range(-3.0, 3.0)), 1.8)
	t.tween_property(hoja, "rotation", Vector3(_rng.randf_range(4.0, 8.0), _rng.randf_range(2.0, 5.0), 3.0), 1.8)
	t.chain().tween_callback(hoja.queue_free)


func _poner_obstaculo() -> void:
	var raiz := Node3D.new()
	var tipo := _rng.randi() % 4
	var z := float(_rng.randi_range(-1, 1)) * 1.5 + _rng.randf_range(-0.3, 0.3)
	match tipo:
		0:
			_disco(raiz, 0.75, Color(0.08, 0.06, 0.05))
		1:
			var roca := _modelo("rock-small", raiz)
			if roca != null:
				for mi in roca.find_children("*", "MeshInstance3D", true, false):
					(mi as MeshInstance3D).material_override = _mate_roca()
			else:
				_caja(raiz, Vector3(0.7, 0.45, 0.7), Vector3(0, 0.22, 0), Color(0.45, 0.44, 0.42))
		2:
			_disco(raiz, 0.95, Color(0.30, 0.42, 0.55, 0.85))
		3:
			var tabla := _caja(raiz, Vector3(0.3, 0.12, 1.6), Vector3(0, 0.07, 0), Color(0.42, 0.30, 0.18))
			tabla.rotation.y = _rng.randf_range(-0.5, 0.5)
	raiz.set_meta(&"ancho", 1.0 if tipo == 2 else 0.85)
	add_child(raiz)
	raiz.position = Vector3(LEJOS, 0.0, z)
	_obstaculos.append(raiz)


## Casas al principio; luego setos, árboles y algún molino.
func _poner_decorado(x: float) -> void:
	var p := clampf(_t / DURA, 0.0, 1.0)
	for lado in [-1.0, 1.0]:
		var raiz := Node3D.new()
		add_child(raiz)
		var z: float = lado * _rng.randf_range(9.0, 14.0)
		raiz.position = Vector3(x + _rng.randf_range(-2.0, 2.0), 0.0, z)
		if _rng.randf() > p * 1.4:
			_casa(raiz, lado)
		else:
			var r := _rng.randf()
			var nombre := "tree" if r < 0.45 else ("hedge-large" if r < 0.7 else ("tree-high-round" if r < 0.9 else "tree-crooked"))
			var m := _modelo(nombre, raiz)
			if m != null:
				m.scale = Vector3.ONE * (1.6 if nombre.begins_with("hedge") else 2.2)
				m.rotation.y = _rng.randf() * TAU
		_decorado.append(raiz)
		# Bosquecillo detrás: más árboles cuanto más campo.
		if p > 0.3:
			for k in 1 + int(p * 2.0):
				var fondo := Node3D.new()
				add_child(fondo)
				fondo.position = Vector3(x + _rng.randf_range(-3.0, 3.0), 0.0, lado * _rng.randf_range(15.0, 32.0))
				var arb := _modelo(["tree", "tree-high", "tree-high-round", "tree-crooked", "tree-high-crooked"][_rng.randi() % 5], fondo)
				if arb != null:
					arb.scale = Vector3.ONE * _rng.randf_range(2.0, 3.2)
					arb.rotation.y = _rng.randf() * TAU
				_decorado.append(fondo)
		# Valla de campo junto al camino, cuando ya no hay casas.
		if p > 0.35 and _rng.randf() < 0.8:
			var valla := Node3D.new()
			add_child(valla)
			valla.position = Vector3(x, 0.0, lado * 4.4)
			var v := _modelo("fence" if _rng.randf() < 0.85 else "fence-broken", valla)
			if v != null:
				v.scale = Vector3.ONE * 1.5
				v.rotation.y = PI * 0.5
			_decorado.append(valla)
		# Flores y matas en la hierba, con el sol.
		if p > 0.5:
			var mata := Node3D.new()
			add_child(mata)
			mata.position = Vector3(x + _rng.randf_range(-3.0, 3.0), 0.0, lado * _rng.randf_range(5.0, 8.0))
			var flor: Color = [Color(0.95, 0.85, 0.3), Color(0.9, 0.45, 0.5), Color(0.95, 0.95, 0.9)][_rng.randi() % 3]
			for k in 5:
				_caja(mata, Vector3(0.14, 0.14, 0.14), Vector3(_rng.randf_range(-0.6, 0.6), 0.25, _rng.randf_range(-0.6, 0.6)), flor)
			_caja(mata, Vector3(1.3, 0.22, 1.1), Vector3(0, 0.1, 0), Color(0.30, 0.48, 0.20))
			_decorado.append(mata)
	# Piedrecillas en el camino: se nota la velocidad.
	for k in 2:
		var china := Node3D.new()
		add_child(china)
		china.position = Vector3(x + _rng.randf_range(-3.0, 3.0), 0.0, _rng.randf_range(-2.6, 2.6))
		_caja(china, Vector3(0.12, 0.05, 0.1), Vector3(0, 0.02, 0), Color(0.35, 0.31, 0.26))
		_decorado.append(china)


var _roca: StandardMaterial3D


func _mate_roca() -> StandardMaterial3D:
	if _roca == null:
		_roca = StandardMaterial3D.new()
		_roca.albedo_color = Color(0.42, 0.4, 0.37)
		_roca.roughness = 1.0
	return _roca


## Casa de las afueras, oscura, con alguna ventana encendida.
func _casa(raiz: Node3D, lado: float) -> void:
	var nombres := ["building-sample-house-a", "building-sample-house-b", "building-sample-house-c"]
	var m := _modelo(nombres[_rng.randi() % nombres.size()], raiz)
	if m == null:
		return
	m.scale = Vector3.ONE * 2.4
	# De cara al camino.
	m.rotation.y = 0.0 if lado < 0.0 else PI
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		var malla := mi as MeshInstance3D
		for i in malla.mesh.get_surface_count():
			var base := malla.get_active_material(i) as StandardMaterial3D
			if base != null:
				if not _oscuros.has(base):
					var c := base.duplicate() as StandardMaterial3D
					c.albedo_color = base.albedo_color * Color(0.55, 0.52, 0.5)
					_oscuros[base] = c
				malla.set_surface_override_material(i, _oscuros[base])
	if _rng.randf() < 0.6:
		var luz := _caja(raiz, Vector3(0.5, 0.6, 0.05), Vector3(_rng.randf_range(-1.0, 1.0), 1.6, -lado * 2.45), Color(1.0, 0.75, 0.4))
		var mat := luz.material_override as StandardMaterial3D
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_ventanas.append(luz)


var _oscuros: Dictionary = {}
var _ventanas: Array[MeshInstance3D] = []
var _farol: OmniLight3D
var _mat_polvo: StandardMaterial3D
var _hasta_polvo: float = 0.0


## Ruedas de hierro, farol con luz y polvo detrás.
func _vestir_carro() -> void:
	for mi in _carro.find_children("*", "MeshInstance3D", true, false):
		var malla := mi as MeshInstance3D
		if malla.mesh == null:
			continue
		for i in malla.mesh.get_surface_count():
			var base := malla.get_active_material(i) as StandardMaterial3D
			if base == null:
				continue
			var c := base.duplicate() as StandardMaterial3D
			# Textura del kit: se calienta y oscurece un poco (el hierro azulado pasa a pardo).
			c.albedo_color = base.albedo_color * Color(0.82, 0.68, 0.58)
			malla.set_surface_override_material(i, c)
	# Farol de carro: palo, caja de hierro y cristal encendido.
	_caja(_carro, Vector3(0.05, 0.7, 0.05), Vector3(-0.95, 1.5, -0.78), Color(0.14, 0.12, 0.1))
	_caja(_carro, Vector3(0.2, 0.26, 0.2), Vector3(-0.95, 1.95, -0.78), Color(0.14, 0.12, 0.1))
	var vidrio := _caja(_carro, Vector3(0.16, 0.2, 0.22), Vector3(-0.95, 1.95, -0.78), Color(1.0, 0.8, 0.45))
	(vidrio.material_override as StandardMaterial3D).shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_caja(_carro, Vector3(0.22, 0.12, 0.08), Vector3(-0.95, 2.11, -0.78), Color(0.14, 0.12, 0.1)).rotation.x = PI * 0.25
	_farol = OmniLight3D.new()
	_farol.light_color = Color(1.0, 0.72, 0.4)
	_farol.omni_range = 6.5
	_carro.add_child(_farol)
	_farol.position = Vector3(-0.95, 1.8, -0.78)
	_mat_polvo = StandardMaterial3D.new()
	_mat_polvo.albedo_color = Color(0.5, 0.43, 0.33)
	_mat_polvo.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED


func _luz(p: float) -> void:
	var k := smoothstep(0.15, 0.85, p)
	_env.fog_light_color = NOCHE["niebla"].lerp(DIA["niebla"], k)
	_env.fog_density = lerpf(NOCHE["densidad"], DIA["densidad"], k)
	_env.ambient_light_energy = lerpf(NOCHE["ambiente"], DIA["ambiente"], k)
	_sol.light_energy = lerpf(NOCHE["sol"], DIA["sol"], k)
	_sol.light_color = Color(0.7, 0.78, 0.9).lerp(Color(1.0, 0.86, 0.62), k)
	_env.adjustment_saturation = lerpf(0.8, 1.08, k)
	_env.ambient_light_color = Color(0.7, 0.72, 0.75).lerp(Color(1.0, 0.86, 0.74), k)
	if _farol != null:
		_farol.light_energy = lerpf(2.6, 0.0, k)
	if _cielo != null:
		_cielo.sky_top_color = Color(0.05, 0.07, 0.06).lerp(Color(0.28, 0.58, 0.98), k)
		_cielo.sky_horizon_color = NOCHE["niebla"].lerp(Color(0.8, 0.9, 1.0), k)
		_cielo.ground_horizon_color = _cielo.sky_horizon_color
		_cielo.ground_bottom_color = Color(0.1, 0.1, 0.08).lerp(Color(0.45, 0.62, 0.3), k)
	for s in _suelos:
		var mat := s.material_override as StandardMaterial3D
		if s.has_meta(&"hierba"):
			mat.albedo_color = Color(0.16, 0.17, 0.12).lerp(Color(0.38, 0.62, 0.3), k)
		elif s.has_meta(&"orilla"):
			mat.albedo_color = Color(0.13, 0.15, 0.10).lerp(Color(0.3, 0.54, 0.24), k)
		elif s.has_meta(&"rodada"):
			mat.albedo_color = Color(0.15, 0.12, 0.09).lerp(Color(0.6, 0.44, 0.3), k)
		else:
			mat.albedo_color = Color(0.20, 0.17, 0.13).lerp(Color(0.74, 0.58, 0.4), k)


func _llegar() -> void:
	_terminando = true
	var negro := ColorRect.new()
	negro.color = Color.BLACK
	negro.modulate.a = 0.0
	negro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_capa.add_child(negro)
	var t := create_tween()
	t.tween_interval(1.2)
	t.tween_property(negro, "modulate:a", 1.0, 1.2)
	await t.finished
	SceneRouter.change_scene(HAMPSTEAD, SceneRouter.Kind.SHORT_FADE)


# --- Construcción ---

func _entorno() -> void:
	var we := WorldEnvironment.new()
	_env = Environment.new()
	# Cielo con degradado: de la noche verdosa al azul.
	_cielo = ProceduralSkyMaterial.new()
	var sky := Sky.new()
	sky.sky_material = _cielo
	_env.sky = sky
	_env.background_mode = Environment.BG_SKY
	_env.adjustment_enabled = true
	_env.adjustment_saturation = 0.8
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = Color(0.7, 0.72, 0.75)
	_env.fog_enabled = true
	_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	we.environment = _env
	add_child(we)
	_sol = DirectionalLight3D.new()
	_sol.rotation_degrees = Vector3(-50.0, 30.0, 0.0)
	add_child(_sol)
	_luz(0.0)


## Tres tramos que se reciclan: camino de tierra entre dos franjas de hierba.
func _suelo() -> void:
	for i in 3:
		for parte in [[Vector2(80, 5.6), 0.0, false], [Vector2(80, 40), 22.8, true], [Vector2(80, 40), -22.8, true],
				[Vector2(80, 0.35), 0.75, false, true], [Vector2(80, 0.35), -0.75, false, true],
				[Vector2(80, 0.5), 2.95, false, true, true], [Vector2(80, 0.5), -2.95, false, true, true]]:
			var m := MeshInstance3D.new()
			var q := PlaneMesh.new()
			q.size = parte[0]
			m.mesh = q
			var mat := StandardMaterial3D.new()
			mat.roughness = 1.0
			m.material_override = mat
			if parte[2]:
				m.set_meta(&"hierba", true)
			# Rodadas del carro y orillas de hierba alta.
			if parte.size() > 3:
				m.set_meta(&"orilla" if parte.size() > 4 else &"rodada", true)
			add_child(m)
			m.position = Vector3(40.0 - 80.0 * i, 0.005 if parte.size() > 3 else (-0.01 if parte[2] else 0.0), float(parte[1]))
			_suelos.append(m)


func _pista(texto: String, arriba: float = 30.0, dura: float = 6.0) -> void:
	var l := Label.new()
	l.text = texto
	l.add_theme_font_override("font", GARAMOND_SEMI)
	l.add_theme_font_size_override("font_size", 26)
	l.add_theme_color_override("font_color", Color(0.97, 0.96, 0.93))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.30, 0.30, 0.31, 0.90)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(10)
	l.add_theme_stylebox_override("normal", sb)
	l.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	l.offset_top = arriba
	l.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_capa.add_child(l)
	var t := l.create_tween()
	t.tween_interval(dura)
	t.tween_property(l, "modulate:a", 0.0, 1.0)
	t.tween_callback(l.queue_free)


func _disco(padre: Node3D, r: float, color: Color) -> void:
	var m := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = 0.03
	m.mesh = c
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.3 if color.a < 1.0 else 1.0
	if color.a < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.material_override = mat
	m.scale = Vector3(1.0, 1.0, 0.7)
	m.position.y = 0.02
	padre.add_child(m)


func _caja(padre: Node3D, tam: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = tam
	m.mesh = b
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	m.material_override = mat
	m.position = pos
	padre.add_child(m)
	return m


func _modelo(nombre: String, padre: Node3D) -> Node3D:
	var escena := load(MODELOS % nombre) as PackedScene
	if escena == null:
		return null
	var n := escena.instantiate() as Node3D
	padre.add_child(n)
	return n


## Dentro de un padre: la figura anda cuando se mueve el padre.
func _figura(ropa: Dictionary) -> Node3D:
	var fig := (load(FIGURA) as PackedScene).instantiate() as Node3D
	VESTUARIO.aplicar(fig, ropa)
	var padre := Node3D.new()
	padre.add_child(fig)
	return padre
