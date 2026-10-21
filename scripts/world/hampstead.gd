extends Node3D
## Hampstead, con sol: la casa de la viuda Eley. Su hija cuenta lo del agua; luego, de vuelta a Soho.

const CARRUAJE := preload("res://scripts/world/carruaje.gd")
const VESTUARIO := preload("res://scripts/world/vestuario.gd")
const FIGURA := "res://scenes/world/props/figura.tscn"
const MODELOS := "res://art/models/Medieval/GLB format/%s.glb"
const GARAMOND := preload("res://art/fonts/EB_Garamond/static/EBGaramond-Regular.ttf")
const DIALOGO := "ch1_s4_hampstead"
const HIJA := {"abrigo": [0.16, 0.15, 0.17], "pantalon": [0.16, 0.15, 0.17], "chal": true, "sombrero": [0.5, 0.45, 0.4],
	"chistera": false, "alzacuellos": false, "estatura": 0.95, "mira_alrededor": false}

const PUERTA := Vector3(0.0, 0.0, -3.2)
const DESDE := Vector3(3.5, 0.0, 3.0)
const HASTA := Vector3(1.55, 0.0, -1.0)

var _wh: Node3D
var _capa: CanvasLayer


func _ready() -> void:
	HUD.esquina(false)
	HUD.show()
	_entorno()
	_casa()
	var carro := Node3D.new()
	carro.set_script(CARRUAJE)
	add_child(carro)
	carro.position = Vector3(10.0, 0.0, -1.0)
	carro.rotation.y = -PI * 0.5
	var hija := _figura(HIJA)
	add_child(hija)
	hija.position = Vector3(-0.45, 0.0, -1.85)
	hija.rotation.y = 1.1
	_wh = _figura({"chistera": true, "alzacuellos": true})
	add_child(_wh)
	_wh.position = DESDE
	var cam := Camera3D.new()
	cam.fov = 50.0
	add_child(cam)
	cam.position = Vector3(6.0, 4.2, 8.5)
	cam.look_at(Vector3(0.6, 0.4, -2.2))
	cam.current = true
	_capa = CanvasLayer.new()
	_capa.layer = 30
	add_child(_capa)
	DialogueRunner.dialogue_finished.connect(_al_terminar)
	_correr()


func _exit_tree() -> void:
	HUD.esquina(true)


func _correr() -> void:
	await _letrero("Hampstead, six miles north of Soho.")
	var t := create_tween()
	t.tween_property(_wh, "position", HASTA, DESDE.distance_to(HASTA) / 1.3)
	await t.finished
	await get_tree().create_timer(0.5).timeout
	DialogueRunner.start(DIALOGO)


func _al_terminar(id: String) -> void:
	if id != DIALOGO:
		return
	var texto := "The carter took him back to Soho before dark."
	# Papeles que se cayeron en el camino: a qué casas volver.
	var perdidas: PackedStringArray = []
	for f in Cuaderno.abiertas():
		if GameState.has_flag("papel_perdido_" + f):
			GameState.set_flag("papel_perdido_" + f, false)
			perdidas.append(String(Cuaderno.ficha(f).get("titulo", f)))
	if not perdidas.is_empty():
		texto += "\n\nOn the road, papers fell out of his case:\n%s.\nHe will have to ask at those houses again." % ", ".join(perdidas)
	await _letrero(texto, true, 2.4 if perdidas.is_empty() else 6.0)
	Barrio.volver()


## Texto sobre negro. Con al_negro, funde a negro; si no, de negro a la escena.
func _letrero(texto: String, al_negro: bool = false, dura: float = 2.4) -> void:
	var negro := ColorRect.new()
	negro.color = Color(0.03, 0.03, 0.03)
	negro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	negro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	negro.modulate.a = 0.0 if al_negro else 1.0
	_capa.add_child(negro)
	var l := Label.new()
	l.text = texto
	l.add_theme_font_override("font", GARAMOND)
	l.add_theme_font_size_override("font_size", 40)
	l.add_theme_color_override("font_color", Color(0.86, 0.82, 0.72))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	negro.add_child(l)
	var t := create_tween()
	if al_negro:
		t.tween_property(negro, "modulate:a", 1.0, 1.0)
		t.tween_interval(dura)
	else:
		t.tween_interval(2.2)
		t.tween_property(negro, "modulate:a", 0.0, 1.4)
		t.tween_callback(negro.queue_free)
	await t.finished


func _entorno() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	# Igual que el final del camino: cielo azul, sol dorado, color subido.
	var cielo := ProceduralSkyMaterial.new()
	cielo.sky_top_color = Color(0.28, 0.58, 0.98)
	cielo.sky_horizon_color = Color(0.8, 0.9, 1.0)
	cielo.ground_horizon_color = cielo.sky_horizon_color
	cielo.ground_bottom_color = Color(0.45, 0.62, 0.3)
	var sky := Sky.new()
	sky.sky_material = cielo
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1.0, 0.86, 0.74)
	env.ambient_light_energy = 0.6
	env.fog_enabled = true
	env.fog_light_color = Color(0.84, 0.9, 0.98)
	env.fog_density = 0.004
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.08
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	we.environment = env
	add_child(we)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-48.0, 35.0, 0.0)
	sol.light_color = Color(1.0, 0.86, 0.62)
	sol.light_energy = 1.1
	sol.shadow_enabled = not OS.has_feature("web")
	add_child(sol)


func _casa() -> void:
	var suelo := MeshInstance3D.new()
	var q := PlaneMesh.new()
	q.size = Vector2(400, 400)
	suelo.mesh = q
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.38, 0.62, 0.3)
	suelo.material_override = mat
	add_child(suelo)
	var camino := MeshInstance3D.new()
	var c := PlaneMesh.new()
	c.size = Vector2(1.6, 9.0)
	camino.mesh = c
	var mc := StandardMaterial3D.new()
	mc.albedo_color = Color(0.74, 0.58, 0.4)
	camino.material_override = mc
	camino.position = Vector3(0.4, 0.01, 1.0)
	add_child(camino)
	var casa := _modelo("building-sample-house-a")
	if casa != null:
		casa.position = PUERTA + Vector3(0, 0, -2.2)
		casa.scale = Vector3.ONE * 1.7
	for p in [[Vector3(-5.5, 0, -3.0), "tree"], [Vector3(5.0, 0, -4.5), "tree-high-round"],
			[Vector3(-9.0, 0, 2.0), "tree"], [Vector3(-4.5, 0, -1.0), "hedge"],
			[Vector3(-28, 0, -34), "tree-high"]]:
		var m := _modelo(p[1])
		if m != null:
			m.position = p[0]
			m.scale = Vector3.ONE * (1.4 if String(p[1]).begins_with("hedge") else (2.2 if p[1] != "windmill" else 4.0))
	# Más árboles alrededor y un jardín con flores.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 26:
		var ang := rng.randf_range(-PI * 0.97, -PI * 0.03)
		var dist := rng.randf_range(10.0, 28.0)
		var arb := _modelo(["tree", "tree-high", "tree-high-round", "tree-crooked"][rng.randi() % 4])
		if arb != null:
			arb.position = Vector3(cos(ang) * dist, 0.0, sin(ang) * dist - 4.0)
			arb.scale = Vector3.ONE * rng.randf_range(1.9, 3.0)
			arb.rotation.y = rng.randf() * TAU
	# Y por delante y a los lados, lejos del carro: que ningún plano dé al campo vacío.
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 11
	for i in 18:
		var ang := rng2.randf_range(PI * 0.02, PI * 0.98)
		var dist := rng2.randf_range(21.0, 36.0)
		var arb := _modelo(["tree", "tree-high", "tree-high-round", "tree-crooked"][rng2.randi() % 4])
		if arb != null:
			arb.position = Vector3(cos(ang) * dist, 0.0, sin(ang) * dist - 4.0)
			arb.scale = Vector3.ONE * rng2.randf_range(2.0, 3.2)
			arb.rotation.y = rng2.randf() * TAU
			# su sombra caería en el plano de la casa
			for m in arb.find_children("*", "GeometryInstance3D", true, false):
				(m as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in 14:
		var flor: Color = [Color(0.95, 0.85, 0.3), Color(0.92, 0.45, 0.55), Color(0.97, 0.96, 0.92), Color(0.62, 0.5, 0.9)][rng.randi() % 4]
		# Solo a la izquierda del sendero: por la derecha llega Whitehead.
		var x := rng.randf_range(-5.0, -0.9)
		var mata := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(0.9, 0.2, 0.7)
		mata.mesh = b
		var mm := StandardMaterial3D.new()
		mm.albedo_color = Color(0.3, 0.52, 0.22)
		mata.material_override = mm
		add_child(mata)
		mata.position = Vector3(x, 0.1, rng.randf_range(-1.0, 3.5))
		var fm := StandardMaterial3D.new()
		fm.albedo_color = flor
		for k in 4:
			var f := MeshInstance3D.new()
			var fb := BoxMesh.new()
			fb.size = Vector3(0.12, 0.12, 0.12)
			f.mesh = fb
			f.material_override = fm
			mata.add_child(f)
			f.position = Vector3(rng.randf_range(-0.35, 0.35), 0.15, rng.randf_range(-0.25, 0.25))


func _modelo(nombre: String) -> Node3D:
	var escena := load(MODELOS % nombre) as PackedScene
	if escena == null:
		return null
	var n := escena.instantiate() as Node3D
	add_child(n)
	return n


## Dentro de un padre: la figura anda cuando se mueve el padre.
func _figura(ropa: Dictionary) -> Node3D:
	var fig := (load(FIGURA) as PackedScene).instantiate() as Node3D
	VESTUARIO.aplicar(fig, ropa)
	var padre := Node3D.new()
	padre.add_child(fig)
	return padre
