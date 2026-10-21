extends Node3D
## Dentro de la cervecería Huggins: Whitehead cruza la sala llena hasta la barra y allí habla el mozo.
## Al terminar, de vuelta a la calle delante de la puerta (Barrio guarda dónde estaba).

const FIGURA := preload("res://scenes/world/props/figura.tscn")
const VESTUARIO := preload("res://scripts/world/vestuario.gd")
const BRINDIS := preload("res://scripts/world/brindis.gd")
const BANCO := "res://art/models/Medieval/GLB format/stall-bench.glb"
const DIALOGO := "ch1_s3_cambridge_cervecero"
const LETRA := "res://art/fonts/EB_Garamond/static/EBGaramond-SemiBold.ttf"

## Ropa del mozo si la calle no la trae.
const MOZO := {"abrigo": [0.62, 0.45, 0.24], "pantalon": [0.24, 0.22, 0.2], "sombrero": [0.4, 0.3, 0.18],
	"cuello": [0.93, 0.9, 0.84], "chistera": false, "gorra": true, "alzacuellos": false, "estatura": 1.14}
const WHITEHEAD := {"chistera": true, "alzacuellos": true, "mira_alrededor": false}

## Camino de Whitehead: la puerta, un rodeo entre las mesas y la barra.
const CAMINO: Array[Vector3] = [Vector3(7.3, 0.0, 1.8), Vector3(4.8, 0.0, 0.4), Vector3(3.1, 0.0, -2.7)]
## El mozo, algo a un lado para que Whitehead no lo tape.
const SITIO_MOZO := Vector3(2.4, 0.0, -4.45)
const PASO := 1.6
## Barra: centro, largo y fondo.
const BARRA := Vector3(2.7, 0.0, -3.6)
const LARGO_BARRA := 4.8

## Plano general y plano a dos en la barra.
const CAM_LEJOS := Vector3(-2.6, 2.2, 8.2)
const MIRA_LEJOS := Vector3(1.2, 1.5, -2.4)
const CAM_CERCA := Vector3(5.9, 1.95, -0.3)
const MIRA_CERCA := Vector3(2.4, 1.75, -4.0)

## Ropa de faena: camisa, chaleco o mandil de cuero; gorra casi todos.
const OBREROS := [
	{"abrigo": [0.78, 0.74, 0.64], "pantalon": [0.22, 0.2, 0.18], "sombrero": [0.3, 0.26, 0.2], "gorra": true},
	{"abrigo": [0.5, 0.36, 0.2], "pantalon": [0.26, 0.23, 0.2], "sombrero": [0.22, 0.2, 0.18], "gorra": true},
	{"abrigo": [0.38, 0.44, 0.55], "pantalon": [0.2, 0.2, 0.22], "sombrero": [0.25, 0.25, 0.28], "gorra": true},
	{"abrigo": [0.7, 0.66, 0.58], "pantalon": [0.3, 0.26, 0.2], "gorra": false},
	{"abrigo": [0.42, 0.3, 0.2], "pantalon": [0.2, 0.18, 0.16], "sombrero": [0.35, 0.3, 0.22], "gorra": true},
	{"abrigo": [0.6, 0.58, 0.5], "pantalon": [0.28, 0.25, 0.22], "sombrero": [0.18, 0.17, 0.16], "gorra": true},
	{"abrigo": [0.55, 0.4, 0.26], "pantalon": [0.24, 0.22, 0.2], "gorra": false},
	{"abrigo": [0.8, 0.77, 0.7], "pantalon": [0.32, 0.28, 0.24], "sombrero": [0.28, 0.22, 0.16], "gorra": true},
]

## Corros alrededor de barriles de pie: centro, cuántos y ángulo del primero.
const CORROS := [
	[Vector3(-2.7, 0.0, 0.7), 4, 0.4],
	[Vector3(0.3, 0.0, 1.9), 3, 1.2],
	[Vector3(-1.4, 0.0, -2.0), 3, 2.2],
	[Vector3(4.6, 0.0, 3.0), 3, 0.3],
	# en primer plano, a contraluz: enmarcan el plano general
	[Vector3(-3.5, 0.0, 6.0), 3, 1.4],
]

## Yeso cálido con un friso pintado de hojas y flores, como en una taberna de cuento.
const YESO := "shader_type spatial;
varying vec3 p;
void vertex() { p = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float h = p.x + p.z;
	float n = fract(sin(dot(floor(vec2(h, p.y) * 2.5), vec2(12.9898, 78.233))) * 43758.5453);
	vec3 c = vec3(0.86, 0.66, 0.42) * (0.92 + 0.08 * n);
	float onda = 3.35 + 0.14 * sin(h * 2.4);
	float tallo = 1.0 - smoothstep(0.012, 0.03, abs(p.y - onda));
	float t = h * 2.4 / 3.14159;
	float lado = mod(floor(t), 2.0) * 2.0 - 1.0;
	vec2 q = vec2((fract(t) - 0.5) * 0.9, (p.y - onda - lado * 0.12) * 3.2);
	float hoja = 1.0 - smoothstep(0.16, 0.2, length(q));
	vec2 f = vec2(fract(h * 0.35) - 0.5, (p.y - onda) * 1.2);
	float flor = 1.0 - smoothstep(0.05, 0.07, length(f));
	c = mix(c, vec3(0.3, 0.46, 0.26), max(tallo, hoja) * step(2.9, p.y));
	c = mix(c, vec3(0.78, 0.22, 0.2), flor * step(2.9, p.y));
	ALBEDO = c;
	ROUGHNESS = 1.0;
}"

## Baldosas en damero, crema y negro, con algo de brillo.
const DAMERO := "shader_type spatial;
varying vec3 p;
void vertex() { p = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 b = floor(p.xz / 0.55);
	float c = mod(b.x + b.y, 2.0);
	float n = fract(sin(dot(b, vec2(12.9898, 78.233))) * 43758.5453);
	vec2 g = fract(p.xz / 0.55);
	float j = max(step(g.x, 0.02), step(g.y, 0.02));
	vec3 col = mix(vec3(0.86, 0.74, 0.5), vec3(0.07, 0.06, 0.05), c) * (0.9 + 0.1 * n);
	ALBEDO = mix(col, vec3(0.3, 0.25, 0.2), j);
	ROUGHNESS = 0.3;
}"

const TABLAS := "shader_type spatial;
varying vec3 p;
void vertex() { p = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float tabla = floor(p.z / 0.24);
	float n = fract(sin(tabla * 12.9898) * 43758.5453);
	float corte = fract((p.x + n * 3.0) / 2.6);
	float j = max(step(fract(p.z / 0.24), 0.06), step(corte, 0.012));
	vec3 c = mix(vec3(0.3, 0.19, 0.11), vec3(0.42, 0.28, 0.16), n);
	ALBEDO = c * (1.0 - 0.5 * j);
	ROUGHNESS = 0.8;
}"

## Duelas y aros por coordenadas locales: un barril, una malla.
const DUELAS := "shader_type spatial;
uniform vec3 madera : source_color = vec3(0.5, 0.32, 0.17);
uniform float alto = 0.8;
uniform float duelas = 14.0;
varying vec3 v;
void vertex() { v = VERTEX; }
void fragment() {
	float y = abs(v.y) / (alto * 0.5);
	float aro = max(step(abs(y - 0.76), 0.06), step(abs(y - 0.3), 0.04));
	float a = atan(v.z, v.x) / 6.2832 * duelas;
	float n = fract(sin(floor(a) * 12.9898) * 43758.5453);
	vec3 c = madera * (0.85 + 0.25 * n) * (1.0 - 0.35 * step(fract(a), 0.06));
	ALBEDO = mix(c, vec3(0.12, 0.11, 0.1), aro);
	ROUGHNESS = 0.85;
}"

var _wh: Node3D
var _mozo: Node3D
var _cam: Camera3D
var _mira: Vector3 = MIRA_LEJOS
var _mats: Dictionary = {}
var _deriva: float = 0.0


func _ready() -> void:
	HUD.esquina(false)
	HUD.show()
	_sala()
	_barra()
	_tinas()
	_luces()
	_gente()
	_wh = Node3D.new()
	_wh.name = "Whitehead"
	var fig := FIGURA.instantiate() as Node3D
	VESTUARIO.aplicar(fig, WHITEHEAD)
	_wh.add_child(fig)
	add_child(_wh)
	_wh.position = CAMINO[0]
	_cam = get_node_or_null(^"Camera3D") as Camera3D
	if _cam != null:
		_cam.position = CAM_LEJOS
		_cam.look_at(MIRA_LEJOS)
	# el estilo corre antes (hijo); contorno a lo construido aquí
	var estilo := get_node_or_null(^"EstiloArtistico")
	if estilo != null and estilo.has_method(&"_apply_outline"):
		estilo.call(&"_apply_outline", self)
	DialogueRunner.dialogue_finished.connect(_al_terminar)
	_correr()


func _exit_tree() -> void:
	HUD.esquina(true)


func _correr() -> void:
	await get_tree().create_timer(0.3).timeout
	for i in range(1, CAMINO.size()):
		await _andar_hasta(CAMINO[i])
	# De cara al mozo: gira el padre (la figura fija su giro al pararse).
	var d := SITIO_MOZO - _wh.position
	var fig := _wh.get_child(0) as Node3D
	var giro := create_tween()
	giro.tween_property(_wh, "rotation:y", wrapf(atan2(d.x, d.z) - fig.rotation.y, -PI, PI), 0.35)
	await get_tree().create_timer(0.45).timeout
	DialogueRunner.start(DIALOGO)


func _andar_hasta(destino: Vector3) -> void:
	while is_inside_tree():
		var d := destino - _wh.position
		var paso := PASO * minf(get_process_delta_time(), 0.05)
		if d.length() <= paso:
			_wh.position = destino
			return
		_wh.position += d.normalized() * paso
		await get_tree().process_frame


## La cámara sigue a Whitehead y se acerca a la barra según avanza.
func _process(delta: float) -> void:
	if _cam == null or _wh == null:
		return
	var total := CAMINO[0].distance_to(CAMINO[CAMINO.size() - 1])
	var hecho := clampf(1.0 - _wh.position.distance_to(CAMINO[CAMINO.size() - 1]) / total, 0.0, 1.0)
	var k := smoothstep(0.0, 1.0, hecho)
	var t := 1.0 - exp(-2.5 * delta)
	# Hablando, la cámara se acerca despacio y se mece un poco: plano de cine.
	if DialogueRunner.active:
		_deriva += delta
	var empuje := (MIRA_CERCA - CAM_CERCA).normalized() * minf(_deriva * 0.04, 0.9) + Vector3(sin(_deriva * 0.3) * 0.15, 0.0, 0.0)
	_cam.position = _cam.position.lerp(CAM_LEJOS.lerp(CAM_CERCA, k) + empuje * k, t)
	var objetivo := MIRA_LEJOS.lerp(MIRA_CERCA, k).lerp(_wh.position + Vector3.UP, 0.25 * (1.0 - k))
	_mira = _mira.lerp(objetivo, t)
	_cam.look_at(_mira)


func _al_terminar(id: String) -> void:
	if id != DIALOGO:
		return
	# Fuera, de pie ante la puerta: la posición la dejó la barra de puertas.
	Barrio.entrada_por = Barrio.GUARDADA
	SceneRouter.change_scene(Barrio.ESCENA_CALLE, SceneRouter.Kind.SHORT_FADE)


# ---------------------------------------------------------------- la sala

func _sala() -> void:
	var suelo := _caja(self, "Suelo", Vector3(16.0, 0.2, 17.6), Vector3(0.0, -0.1, 1.8), _shader(DAMERO, {}))
	suelo.set_meta(&"sin_contorno", true)
	var yeso := _shader(YESO, {})
	var friso := _color(Color(0.32, 0.17, 0.09))
	# fondo, laterales y frente; el frente queda detrás de la cámara, en penumbra
	for m in [["MuroFondo", Vector3(15.0, 4.4, 0.3), Vector3(0.0, 2.2, -6.15)],
			["MuroIzq", Vector3(0.3, 4.4, 16.6), Vector3(-7.35, 2.2, 2.05)],
			["MuroDerFondo", Vector3(0.3, 4.4, 7.0), Vector3(7.65, 2.2, -2.75)],
			["MuroDerFrente", Vector3(0.3, 4.4, 7.7), Vector3(7.65, 2.2, 6.5)],
			["MuroFrente", Vector3(15.3, 4.4, 0.3), Vector3(0.15, 2.2, 10.2)],
			["Dintel", Vector3(0.3, 1.6, 2.0), Vector3(7.65, 3.6, 1.65)]]:
		_caja(self, m[0], m[1], m[2], yeso).set_meta(&"sin_contorno", true)
	# zócalo de madera hasta media altura
	_caja(self, "ZocaloFondo", Vector3(15.0, 1.2, 0.08), Vector3(0.0, 0.6, -5.97), friso)
	_caja(self, "ZocaloIzq", Vector3(0.08, 1.2, 16.6), Vector3(-7.17, 0.6, 2.05), friso)
	_caja(self, "Moldura", Vector3(15.0, 0.08, 0.14), Vector3(0.0, 1.22, -5.94), _color(Color(0.45, 0.25, 0.12)))
	# la puerta de la calle, abierta a la noche
	var noche := StandardMaterial3D.new()
	noche.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	noche.albedo_color = Color(0.05, 0.12, 0.08)
	_caja(self, "Cristal", Vector3(0.05, 2.8, 2.0), Vector3(7.85, 1.4, 1.65), noche)
	_caja(self, "Hoja", Vector3(1.0, 2.6, 0.08), Vector3(7.1, 1.3, 2.62), _color(Color(0.3, 0.17, 0.09)))
	# letrero pintado, rojo y oro, sobre las estanterías
	_caja(self, "Tablero", Vector3(4.4, 0.5, 0.08), Vector3(2.85, 3.42, -5.9), _color(Color(0.2, 0.1, 0.05)))
	_caja(self, "Filete", Vector3(4.56, 0.6, 0.06), Vector3(2.85, 3.42, -5.93), _color(Color(0.5, 0.32, 0.12)))
	var l := Label3D.new()
	l.text = "HUGGINS & CO.  ALE AND PORTER"
	l.font = load(LETRA) as Font
	l.font_size = 80
	l.pixel_size = 0.0034
	# Oro viejo que recibe la luz de los faroles, no un blanco que brilla solo.
	l.shaded = true
	l.modulate = Color(0.82, 0.6, 0.28)
	l.outline_size = 0
	l.position = Vector3(2.85, 3.42, -5.85)
	add_child(l)
	# bancos contra la pared
	for z in [-0.6, 1.8]:
		var b := _modelo(BANCO)
		if b != null:
			b.position = Vector3(-6.75, 0.0, z)
	_techo()
	_estanterias()
	_mesas()


## Techo de tablas con vigas gruesas y postes con jabalcones, como una vieja taberna.
func _techo() -> void:
	var techo := _caja(self, "Techo", Vector3(15.6, 0.15, 16.8), Vector3(0.0, 4.45, 2.0), _shader(TABLAS, {}))
	techo.set_meta(&"sin_contorno", true)
	var viga := _color(Color(0.36, 0.2, 0.1))
	for z in [-4.6, -1.8, 1.0, 3.6, 6.4, 9.0]:
		_caja(self, "Viga", Vector3(15.2, 0.42, 0.38), Vector3(0.0, 4.15, z), viga)
	for x in [-4.4, 0.6, 5.4]:
		_caja(self, "Correa", Vector3(0.3, 0.3, 16.4), Vector3(x, 3.85, 2.0), viga)
	# postes con abrazadera de hierro y jabalcones
	var hierro := _color(Color(0.16, 0.15, 0.14))
	for p in [Vector3(-2.2, 0.0, -1.8), Vector3(6.2, 0.0, -1.8), Vector3(-4.4, 0.0, 3.6)]:
		_caja(self, "Poste", Vector3(0.46, 4.0, 0.46), p + Vector3(0.0, 2.0, 0.0), viga)
		_caja(self, "Abrazadera", Vector3(0.52, 0.22, 0.52), p + Vector3(0.0, 1.15, 0.0), hierro)
		for lado in [-1.0, 1.0]:
			var j := _caja(self, "Jabalcon", Vector3(0.18, 1.3, 0.22), p + Vector3(lado * 0.5, 3.45, 0.0), viga)
			j.rotation.z = -lado * 0.75


## Estanterías altas tras la barra, como una vieja tienda: latas rojas, tarros y botellas.
func _estanterias() -> void:
	var madera := _color(Color(0.4, 0.2, 0.09))
	var x0 := -1.6
	var x1 := 7.3
	var z := -5.75
	_caja(self, "Mueble", Vector3(x1 - x0, 2.9, 0.08), Vector3((x0 + x1) * 0.5, 1.65, z - 0.18), madera)
	_caja(self, "Cornisa", Vector3(x1 - x0 + 0.2, 0.18, 0.5), Vector3((x0 + x1) * 0.5, 3.1, z), madera)
	var baldas := [0.95, 1.55, 2.15, 2.72]
	for y in baldas:
		_caja(self, "Balda", Vector3(x1 - x0, 0.05, 0.42), Vector3((x0 + x1) * 0.5, y, z), madera)
	var x := x0
	while x <= x1 + 0.01:
		_caja(self, "Divisor", Vector3(0.08, 2.9, 0.44), Vector3(x, 1.65, z), madera)
		x += 1.48
	# lo de las baldas en tres multimallas: una llamada de dibujo por tipo
	var mallas := [_multi(Color(0.72, 0.12, 0.1), 0.07, 0.16), _multi(Color(0.55, 0.62, 0.42), 0.08, 0.2),
		_multi(Color(0.32, 0.18, 0.08), 0.045, 0.28)]
	var altos := [0.16, 0.2, 0.28]
	var donde: Array = [[], [], []]
	var rng := RandomNumberGenerator.new()
	rng.seed = 1854
	for y in baldas:
		var xx := x0 + 0.14
		while xx < x1 - 0.1:
			if fmod(xx - x0, 1.48) < 0.1:
				xx += 0.1
				continue
			var tipo := rng.randi() % 3
			donde[tipo].append(Vector3(xx, float(y) + 0.025 + float(altos[tipo]) * 0.5, z + rng.randf_range(-0.06, 0.06)))
			xx += 0.17 if tipo != 1 else 0.2
	for i in 3:
		var mm := (mallas[i] as MultiMeshInstance3D).multimesh
		mm.instance_count = donde[i].size()
		for k in donde[i].size():
			mm.set_instance_transform(k, Transform3D(Basis(), donde[i][k]))


func _multi(color: Color, r: float, h: float) -> MultiMeshInstance3D:
	var malla := CylinderMesh.new()
	malla.top_radius = r
	malla.bottom_radius = r
	malla.height = h
	malla.radial_segments = 8
	malla.rings = 1
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.4
	malla.material = mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = malla
	var n := MultiMeshInstance3D.new()
	n.multimesh = mm
	n.set_meta(&"sin_contorno", true)
	add_child(n)
	return n


## Mesas redondas de café con sillas de madera curvada.
func _mesas() -> void:
	var madera := _color(Color(0.62, 0.38, 0.17))
	var oscura := _color(Color(0.3, 0.16, 0.07))
	for c in [Vector3(-5.0, 0.0, 2.4), Vector3(2.1, 0.0, 3.9), Vector3(-5.4, 0.0, -3.0)]:
		var tapa := _cilindro(self, 0.48, 0.05, madera)
		tapa.position = c + Vector3(0.0, 0.76, 0.0)
		var pie := _cilindro(self, 0.05, 0.74, oscura)
		pie.position = c + Vector3(0.0, 0.37, 0.0)
		var jarra := _cilindro(self, 0.06, 0.15, _color(Color(0.55, 0.52, 0.47)))
		jarra.position = c + Vector3(0.15, 0.86, 0.05)
		for i in 3:
			var a := TAU * float(i) / 3.0 + 0.5
			var silla := Node3D.new()
			add_child(silla)
			silla.position = c + Vector3(sin(a), 0.0, cos(a)) * 0.78
			silla.rotation.y = a + PI
			var asiento := _cilindro(silla, 0.22, 0.05, madera)
			asiento.position.y = 0.46
			for k in 4:
				var pata := _cilindro(silla, 0.02, 0.46, oscura)
				pata.position = Vector3(0.15 * (1.0 if k % 2 == 0 else -1.0), 0.23, 0.15 * (1.0 if k < 2 else -1.0))
			# respaldo curvado: un aro de madera
			var aro := MeshInstance3D.new()
			var t := TorusMesh.new()
			t.inner_radius = 0.17
			t.outer_radius = 0.21
			t.rings = 12
			t.ring_segments = 4
			aro.mesh = t
			aro.material_override = madera
			silla.add_child(aro)
			aro.position = Vector3(0.0, 0.72, -0.2)
			aro.rotation.x = PI * 0.5


func _barra() -> void:
	var madera := _color(Color(0.4, 0.14, 0.07))
	var tapa := _color(Color(0.58, 0.25, 0.1))
	_caja(self, "Barra", Vector3(LARGO_BARRA, 1.05, 0.7), BARRA + Vector3(0.0, 0.525, 0.0), madera)
	_caja(self, "TapaBarra", Vector3(LARGO_BARRA + 0.2, 0.08, 0.86), BARRA + Vector3(0.0, 1.09, 0.0), tapa)
	# paneles en el frente
	for k in 6:
		var x := -LARGO_BARRA * 0.5 + 0.4 + float(k) * (LARGO_BARRA - 0.8) / 5.0
		_caja(self, "Panel", Vector3(0.55, 0.6, 0.04), BARRA + Vector3(x, 0.52, 0.37), tapa)
	# barra de latón para el pie
	var laton := StandardMaterial3D.new()
	laton.albedo_color = Color(0.85, 0.66, 0.3)
	laton.metallic = 0.8
	laton.roughness = 0.35
	var barra_pie := _cilindro(self, 0.03, LARGO_BARRA, laton)
	barra_pie.position = BARRA + Vector3(0.0, 0.16, 0.5)
	barra_pie.rotation.z = PI * 0.5
	# tiradores de cerveza
	for x in [-0.6, -0.2, 0.2]:
		var tirador := _cilindro(self, 0.025, 0.4, _color(Color(0.12, 0.08, 0.05)))
		tirador.position = BARRA + Vector3(x, 1.33, 0.12)
		var pomo := _cilindro(self, 0.05, 0.08, laton)
		pomo.position = BARRA + Vector3(x, 1.12, 0.12)
	# jarras en la barra
	var peltre := _color(Color(0.55, 0.52, 0.47))
	for x in [-1.9, -1.5, 1.4, 1.9]:
		var j := _cilindro(self, 0.065, 0.15, peltre)
		j.position = BARRA + Vector3(x, 1.2, 0.05)
	# taburetes redondos delante de la barra
	for k in 7:
		var x := -LARGO_BARRA * 0.5 + 0.35 + float(k) * (LARGO_BARRA - 0.7) / 6.0
		if absf(BARRA.x + x - CAMINO[CAMINO.size() - 1].x) < 0.45:
			continue
		var asiento := _cilindro(self, 0.2, 0.08, tapa)
		asiento.position = BARRA + Vector3(x, 0.72, 0.85)
		var pata := _cilindro(self, 0.05, 0.68, madera)
		pata.position = BARRA + Vector3(x, 0.34, 0.85)


func _tinas() -> void:
	var piedra := _color(Color(0.4, 0.38, 0.34))
	for t in [[Vector3(-5.4, 0.0, -4.3), 1.35, 3.4], [Vector3(-5.6, 0.0, -1.3), 1.1, 2.9]]:
		var c: Vector3 = t[0]
		var r: float = t[1]
		var h: float = t[2]
		_caja(self, "Basa", Vector3(r * 2.1, 0.3, r * 2.1), c + Vector3(0.0, 0.15, 0.0), piedra)
		var tina := _barril(self, r, h, Color(0.45, 0.29, 0.15))
		tina.position = c + Vector3(0.0, 0.3 + h * 0.5, 0.0)
	# tubería de cobre de la tina al muro
	var cobre := StandardMaterial3D.new()
	cobre.albedo_color = Color(0.72, 0.42, 0.22)
	cobre.metallic = 0.7
	cobre.roughness = 0.4
	var tubo := _cilindro(self, 0.08, 3.0, cobre)
	tubo.position = Vector3(-4.1, 3.3, -4.3)
	tubo.rotation.z = PI * 0.5
	# barriles de pie junto a la tina pequeña
	for p in [Vector3(-4.0, 0.0, -0.2), Vector3(-3.5, 0.0, -0.9), Vector3(-4.6, 0.0, 0.6)]:
		var b := _barril(self, 0.33, 0.85, Color(0.5, 0.32, 0.17))
		b.position = p + Vector3(0.0, 0.425, 0.0)


## Muchos faroles colgados de las vigas; solo algunos dan luz de verdad (sin sombras).
func _luces() -> void:
	var cristal := StandardMaterial3D.new()
	cristal.albedo_color = Color(1.0, 0.8, 0.5)
	cristal.emission_enabled = true
	cristal.emission = Color(1.0, 0.68, 0.32)
	cristal.emission_energy_multiplier = 1.8
	var hierro := _color(Color(0.1, 0.09, 0.08))
	var sitios := [Vector3(0.6, 3.0, -4.6), Vector3(6.3, 3.0, -4.6), Vector3(-1.8, 3.1, -1.8), Vector3(2.6, 3.1, -1.8),
		Vector3(-4.4, 3.0, 1.0), Vector3(0.6, 3.1, 1.0), Vector3(5.4, 3.1, 1.0), Vector3(-2.0, 3.0, 3.6),
		Vector3(3.2, 3.0, 3.6), Vector3(-5.6, 3.0, -4.6)]
	var con_luz := [0, 1, 3, 4, 6, 8]
	for i in sitios.size():
		var p: Vector3 = sitios[i]
		var farol := _caja(self, "Cristal", Vector3(0.26, 0.34, 0.26), p, cristal)
		farol.set_meta(&"sin_contorno", true)
		_caja(self, "Tapa", Vector3(0.36, 0.06, 0.36), p + Vector3(0.0, 0.2, 0.0), hierro)
		_caja(self, "Remate", Vector3(0.16, 0.1, 0.16), p + Vector3(0.0, 0.27, 0.0), hierro)
		_caja(self, "Base", Vector3(0.3, 0.05, 0.3), p + Vector3(0.0, -0.19, 0.0), hierro)
		var largo := 3.95 - p.y - 0.3
		var cadena := _cilindro(self, 0.012, largo, hierro)
		cadena.position = p + Vector3(0.0, 0.3 + largo * 0.5, 0.0)
		if i in con_luz:
			var luz := OmniLight3D.new()
			luz.light_color = Color(1.0, 0.66, 0.34)
			luz.light_energy = 2.0
			luz.omni_range = 6.5
			luz.omni_attenuation = 1.4
			luz.shadow_enabled = false
			add_child(luz)
			luz.position = p + Vector3(0.0, -0.35, 0.0)
	# apliques en la pared izquierda
	for z in [-3.6, 0.4]:
		var a := _caja(self, "Cristal", Vector3(0.18, 0.26, 0.18), Vector3(-7.0, 2.2, z), cristal)
		a.set_meta(&"sin_contorno", true)


func _gente() -> void:
	var k := 0
	var c := 0
	for corro in CORROS:
		c += 1
		var centro: Vector3 = corro[0]
		# barril de pie como mesa, con jarras
		var mesa := _barril(self, 0.36, 1.0, Color(0.5, 0.32, 0.17))
		mesa.position = centro + Vector3(0.0, 0.5, 0.0)
		for j in 2:
			var jarra := _cilindro(self, 0.06, 0.15, _color(Color(0.55, 0.52, 0.47)))
			jarra.position = centro + Vector3(-0.12 + 0.24 * float(j), 1.08, 0.08 * float(j))
		for i in int(corro[1]):
			var a := float(corro[2]) + TAU * float(i) / float(corro[1])
			var p := centro + Vector3(sin(a), 0.0, cos(a)) * 0.78
			_bebedor(OBREROS[k % OBREROS.size()], p, centro, "sala%d" % c, k)
			k += 1
	# dos acodados en la barra
	_bebedor(OBREROS[3], BARRA + Vector3(-1.8, 0.0, 0.85), BARRA + Vector3(-1.8, 0.0, 0.0), "", 20)
	_bebedor(OBREROS[6], Vector3(6.7, 0.0, -4.1), Vector3(5.4, 0.0, -4.0), "", 21)
	# el mozo, tras la barra
	_mozo = Node3D.new()
	_mozo.name = "Mozo"
	var fig := FIGURA.instantiate() as Node3D
	var ropa := _ropa_del_mozo()
	ropa["mira_alrededor"] = false
	ropa["gesto"] = 0.12
	VESTUARIO.aplicar(fig, ropa)
	_mozo.add_child(fig)
	add_child(_mozo)
	_mozo.position = SITIO_MOZO
	var d := CAMINO[CAMINO.size() - 1] - SITIO_MOZO
	_mozo.rotation.y = atan2(d.x, d.z)


func _bebedor(ropa: Dictionary, p: Vector3, mira: Vector3, corro: String, k: int) -> void:
	var r := ropa.duplicate()
	r["chistera"] = false
	r["alzacuellos"] = false
	r["mira_alrededor"] = false
	r["estatura"] = 0.94 + 0.04 * float(k % 4)
	r["brazo_izquierdo"] = -0.1 if k % 2 == 0 else 0.15
	r["gesto"] = 0.12 if k % 3 == 0 else 0.0
	var b := Node3D.new()
	b.name = "Bebedor%d" % k
	b.set_script(BRINDIS)
	b.set("ropa", r)
	b.set("corro", corro)
	add_child(b)
	b.position = p
	var d := mira - p
	b.rotation.y = atan2(d.x, d.z)


func _ropa_del_mozo() -> Dictionary:
	for p in Array(Barrio.datos(Barrio.actual).get("puertas", [])):
		var d: Dictionary = p
		if String(d.get("dialogo", "")) == DIALOGO and d.has("ropa"):
			return Dictionary(d["ropa"]).duplicate()
	return MOZO.duplicate()


# ---------------------------------------------------------------- utilería

func _caja(padre: Node, nombre: String, tam: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.name = nombre
	var b := BoxMesh.new()
	b.size = tam
	m.mesh = b
	m.material_override = mat
	padre.add_child(m)
	m.position = pos
	return m


func _cilindro(padre: Node, r: float, h: float, mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = h
	c.radial_segments = 12
	c.rings = 1
	m.mesh = c
	m.material_override = mat
	padre.add_child(m)
	return m


## Barril o tina: cilindro algo panzudo con duelas y aros.
func _barril(padre: Node, r: float, h: float, madera: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = r * 0.9
	c.bottom_radius = r * 0.9
	c.height = h
	c.radial_segments = 16
	c.rings = 1
	m.mesh = c
	var clave := "barril%s%.2f" % [str(madera), h]
	if not _mats.has(clave):
		_mats[clave] = _shader(DUELAS, {"madera": madera, "alto": h, "duelas": 14.0 if r < 0.6 else 28.0})
	m.material_override = _mats[clave]
	padre.add_child(m)
	return m


func _color(c: Color) -> StandardMaterial3D:
	var clave := str(c)
	if not _mats.has(clave):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 0.9
		_mats[clave] = m
	return _mats[clave]


func _shader(codigo: String, params: Dictionary) -> ShaderMaterial:
	var s := Shader.new()
	s.code = codigo
	var m := ShaderMaterial.new()
	m.shader = s
	for k in params:
		m.set_shader_parameter(k, params[k])
	return m


func _modelo(ruta: String) -> Node3D:
	var escena := load(ruta) as PackedScene
	if escena == null:
		return null
	var n := escena.instantiate() as Node3D
	add_child(n)
	return n
