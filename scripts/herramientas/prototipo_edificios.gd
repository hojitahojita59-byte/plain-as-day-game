extends Node3D
## Prototipo: tres propuestas de fachada de Soho (A, B, C) con las luces de la calle.
## Uso: -- <carpeta> [A,B,C | calle | cine]. Sin argumentos levanta la A para mirarla.
## cine: la calle de verdad desde la cámara de juego, la vista de puerta y los planos del tráiler.
## Todo va fundido en una malla por material y bloque: pocas llamadas de dibujo.

const FUENTE := "res://art/fonts/EB_Garamond/static/EBGaramond-SemiBold.ttf"
const FIGURA := "res://scenes/world/props/figura.tscn"
const CALLE := "res://scenes/world/calle.tscn"

const MURO := 0.3        ## grosor del muro; la carpintería va dentro del hueco
const FONDO := 9.0       ## fondo de la casa
const ACERA := 3.3       ## del muro al bordillo
const PATIO := 1.25      ## foso del sótano, dentro de la acera
const SOTANO := -2.5
const CALZADA := 7.0
const ALTO_BORDILLO := 0.14

## Cámaras: posición, a dónde mira, fov.
const VISTAS := {
	"juego": [Vector3(0, 9, 14), Vector3(0, 2.31, 6.57), 52.0],
	"ojos": [Vector3(-11, 1.7, 6.2), Vector3(3, 3.0, 0.0), 55.0],
	"tejados": [Vector3(-16, 18, 19), Vector3(3, 7, -7), 55.0],
	"espalda": [Vector3(13, 15, -19.5), Vector3(-2, 4, -6), 58.0],
	"dia": [Vector3(-9, 7.5, 17), Vector3(1, 6.5, -2), 55.0],
}

const BLANCO := Color(0.9, 0.88, 0.82)
const PIEDRA := Color(0.66, 0.64, 0.58)
const GRANITO := Color(0.52, 0.52, 0.53)
const TERRACOTA := Color(0.62, 0.36, 0.24)
const PIZARRA := Color(0.36, 0.38, 0.42)
const TEJA := Color(0.62, 0.33, 0.24)
const LATON := Color(0.8, 0.62, 0.3)
const ORO := Color(0.95, 0.8, 0.42)

## Lotes sin contorno: piezas finas que el casco invertido engordaría.
const SIN_CONTORNO: PackedStringArray = ["fino", "hierro_fino", "acera", "calzada", "vidrio", "luz", "farol"]
const SIN_SOMBRA: PackedStringArray = ["fino", "hierro_fino", "acera", "calzada", "vidrio", "luz", "farol"]

## Fábrica de ladrillo en coordenadas de mundo: aparejo flamenco, hollín, realces (alfa 0).
const FABRICA := "shader_type spatial;
render_mode diffuse_burley;
uniform vec3 color_a : source_color = vec3(0.6, 0.52, 0.4);
uniform vec3 color_b : source_color = vec3(0.45, 0.42, 0.4);
uniform vec3 color_realce : source_color = vec3(0.7, 0.4, 0.3);
uniform vec3 color_junta : source_color = vec3(0.55, 0.52, 0.47);
uniform vec2 pieza = vec2(0.115, 0.076);
uniform float junta = 0.01;
uniform float flamenco = 1.0;
uniform float variacion = 0.16;
uniform float hollin = 0.4;
varying vec3 pm;
varying vec3 nm;
float h21(vec2 p) { p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }
float ruido(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1.0, 0.0)), f.x), mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0, 1.0)), f.x), f.y);
}
void vertex() { pm = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; nm = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz; }
void fragment() {
	vec3 n = abs(normalize(nm));
	vec2 q = n.y > 0.7 ? pm.xz : vec2(n.x > n.z ? pm.z : pm.x, pm.y);
	float fila = floor(q.y / pieza.y);
	float periodo = flamenco > 0.5 ? 3.0 : 2.0;
	float u = q.x / pieza.x + mod(fila, 2.0) * periodo * 0.5;
	float k = floor(u / periodo);
	float r = u - k * periodo;
	bool tizon = flamenco > 0.5 && r >= 2.0;
	float dx = tizon ? min(r - 2.0, 3.0 - r) : min(r, 2.0 - r);
	float fy = fract(q.y / pieza.y);
	float d = min(dx * pieza.x, min(fy, 1.0 - fy) * pieza.y);
	float w = fwidth(q.y);
	float mortero = smoothstep(junta - w, junta + w, d);
	float id = h21(vec2(k * 3.0 + (tizon ? 1.0 : 0.0), fila));
	vec3 base = COLOR.a < 0.5 ? color_realce : (tizon ? color_b : color_a);
	vec3 ladrillo = base * (1.0 + (id - 0.5) * 2.0 * variacion);
	vec3 media = mix(color_junta, base, 0.8);
	float cerca = clamp(1.0 - w / (pieza.y * 0.7), 0.0, 1.0);
	vec3 c = mix(media, mix(color_junta, ladrillo, mortero), cerca);
	float s = hollin * (0.5 * ruido(q * vec2(0.8, 0.2)) + 0.3 * smoothstep(1.0, 13.0, pm.y) + 0.2 * ruido(q * 3.1));
	ALBEDO = c * COLOR.rgb * (1.0 - clamp(s, 0.0, 0.85));
	ROUGHNESS = 0.95;
	SPECULAR = 0.2;
}"

## Pizarra o teja por hiladas en mundo; el color sale del vértice.
const CUBIERTA := "shader_type spatial;
render_mode diffuse_burley;
uniform float hilada = 0.17;
uniform float ancho = 0.3;
uniform float variacion = 0.12;
varying vec3 pm;
varying vec3 nm;
float h21(vec2 p) { p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }
void vertex() { pm = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; nm = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz; }
void fragment() {
	vec3 n = normalize(nm);
	float a = abs(n.x) < abs(n.z) ? pm.x : pm.z;
	float fila = floor(pm.y / hilada);
	float u = a / ancho + mod(fila, 2.0) * 0.5;
	float fy = fract(pm.y / hilada);
	float fx = fract(u);
	float w = fwidth(pm.y / hilada) + 0.0001;
	float linea = smoothstep(0.0, 0.1 + w, fy) * smoothstep(0.0, 0.05 + fwidth(u), min(fx, 1.0 - fx));
	float id = h21(vec2(floor(u), fila));
	vec3 c = COLOR.rgb * (1.0 + (id - 0.5) * 2.0 * variacion);
	float cerca = clamp(1.0 - w * 2.0, 0.0, 1.0);
	float plano = step(0.97, abs(n.y));
	ALBEDO = c * mix(mix(0.85, mix(0.55, 1.0, linea) * (0.85 + 0.25 * fy), cerca), 1.0, plano);
	ROUGHNESS = 0.75;
}"

## Losas y adoquines; `cruzado` tiende las hiladas de través a la calle.
const SUELO := "shader_type spatial;
render_mode diffuse_burley;
uniform vec3 color_piedra : source_color = vec3(0.44, 0.41, 0.37);
uniform vec3 color_junta : source_color = vec3(0.24, 0.22, 0.21);
uniform vec2 pieza = vec2(0.22, 0.32);
uniform float junta = 0.02;
uniform float variacion = 0.18;
uniform float cruzado = 1.0;
uniform float abombado = 0.3;
float h21(vec2 p) { p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }
void fragment() {
	vec3 m = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 q = cruzado > 0.5 ? m.zx : m.xz;
	float fila = floor(q.y / pieza.y);
	float u = q.x / pieza.x + mod(fila, 2.0) * 0.5 + h21(vec2(fila, 3.0)) * 0.3;
	vec2 f = vec2(fract(u) * pieza.x, fract(q.y / pieza.y) * pieza.y);
	float d = min(min(f.x, pieza.x - f.x), min(f.y, pieza.y - f.y));
	float w = fwidth(q.y);
	float mortero = smoothstep(junta - w, junta + w, d);
	float id = h21(vec2(floor(u), fila));
	vec3 piedra = color_piedra * (1.0 + (id - 0.5) * 2.0 * variacion);
	piedra *= 1.0 - abombado * (1.0 - smoothstep(0.0, min(pieza.x, pieza.y) * 0.5, d)) * 0.5;
	float cerca = clamp(1.0 - w / (min(pieza.x, pieza.y) * 0.5), 0.0, 1.0);
	ALBEDO = mix(mix(color_junta, color_piedra, 0.75), mix(color_junta, piedra, mortero), cerca);
	ROUGHNESS = 0.9;
	SPECULAR = 0.2;
}"

var _lotes: Dictionary = {}
var _mats: Dictionary = {}
var _xf := Transform3D.IDENTITY
var _bloque: Node3D
var _rng := RandomNumberGenerator.new()
var _fuente: Font
var _e: Dictionary = {}          ## estilo de la propuesta en curso
var _luces: Array[OmniLight3D] = []
var _sin_patio: Array[Vector2] = []
var _copia: Variant = null
var _xa := -12.5        ## extremos del bloque
var _xb := 12.5


func _ready() -> void:
	if FileAccess.file_exists(SaveSystem.SAVE_PATH):
		_copia = FileAccess.get_file_as_bytes(SaveSystem.SAVE_PATH)
	SaveSystem.set(&"_pendiente", true)
	_fuente = load(FUENTE) as Font
	GameState.dia = 2
	$EstiloArtistico.call(&"_on_miasma_changed", GameState.get_miasma())

	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		_construir("A")
		return
	var carpeta := args[0]
	DirAccess.make_dir_recursive_absolute(carpeta)
	var cuales := (args[1] if args.size() > 1 else "A,B,C").split(",")
	if "cine" in cuales:
		await _cine(carpeta)
		get_tree().quit()
		return
	if "calle" in cuales:
		await _medir_calle()
		get_tree().quit()
		return
	for c in cuales:
		_construir(c)
		for v in ["juego", "ojos", "tejados", "espalda"]:
			await _foto(carpeta, "%s_%s" % [c, v], VISTAS[v])
		_de_dia(true)
		await _foto(carpeta, c + "_dia", VISTAS["dia"])
		_de_dia(false)
		_vaciar()
		await get_tree().process_frame
	get_tree().quit()


func _exit_tree() -> void:
	if _copia != null:
		FileAccess.open(SaveSystem.SAVE_PATH, FileAccess.WRITE).store_buffer(_copia)


# ---------------------------------------------------------------- fotos

func _foto(carpeta: String, nombre: String, v: Array) -> void:
	HUD.hide()
	for c in get_tree().root.find_children("*", "CanvasLayer", true, false):
		if c != HUD and not is_ancestor_of(c):
			(c as CanvasLayer).visible = false
	var cam := $Camera3D as Camera3D
	cam.global_position = v[0]
	cam.look_at(v[1])
	cam.fov = float(v[2])
	for i in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(carpeta.path_join(nombre + ".png"))
	var vp := get_viewport()
	print("[Prototipo] %s: llamadas %d (sombras %d), objetos %d, primitivas %d" % [nombre,
		vp.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME),
		vp.get_render_info(Viewport.RENDER_INFO_TYPE_SHADOW, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME),
		vp.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_OBJECTS_IN_FRAME),
		vp.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME)])
	if nombre.ends_with("_juego"):
		await _desglose()


## Llamadas de cada parte: se apaga una cada vez.
func _desglose() -> void:
	var vp := get_viewport()
	var partes: Array = [""]
	for n in _bloque.get_children():
		if n is Node3D and not (n is Label3D) and not (n is OmniLight3D):
			partes.append(n.name)
	partes.append("rotulos")
	var total := 0
	for p in partes:
		var apagados: Array[Node3D] = []
		for n in _bloque.get_children():
			if (p == "rotulos" and n is Label3D) or String(n.name) == String(p):
				(n as Node3D).visible = false
				apagados.append(n)
		for i in 3:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var k := vp.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)
		if p == "":
			total = k
		else:
			print("[Prototipo]   %s: %d llamadas" % [p, total - k])
		for n in apagados:
			n.visible = true


## La calle de ahora, para comparar llamadas: cámara de juego y grúa alta.
func _medir_calle() -> void:
	for n in [$WorldEnvironment, $Sun, $EstiloArtistico, $CapaTramado]:
		remove_child(n)
		n.queue_free()
	add_child((load(CALLE) as PackedScene).instantiate())
	await get_tree().create_timer(2.0).timeout
	var vp := get_viewport()
	for i in 2:
		if i == 1:
			var cam := Camera3D.new()
			cam.fov = 55.0
			add_child(cam)
			cam.current = true
			cam.global_position = Vector3(-6, 16, 14)
			cam.look_at(Vector3(0, 0, -4))
			for k in 6:
				await get_tree().process_frame
		await RenderingServer.frame_post_draw
		print("[Prototipo] calle %s: llamadas %d (sombras %d), objetos %d, primitivas %d" % [
			"juego" if i == 0 else "grua",
			vp.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME),
			vp.get_render_info(Viewport.RENDER_INFO_TYPE_SHADOW, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME),
			vp.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_OBJECTS_IN_FRAME),
			vp.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME)])


## Planos del tráiler (grabador.gd, calle_cine): nombre, posición, a dónde mira.
const PLANOS_CINE := [
	["cine_travelling_a", Vector3(-46, 1.7, 1.8), Vector3(-36, 1.6, -2.5)],
	["cine_travelling_b", Vector3(-29, 1.7, 1.8), Vector3(-19, 1.6, -2.5)],
	["cine_bomba_a", Vector3(0.1, 1.6, 5.14), Vector3(-3, 1.4, 0.6)],
	["cine_bomba_b", Vector3(2.5, 2.5, 0.66), Vector3(-3, 1.4, 0.6)],
	["cine_bomba_c", Vector3(1.4, 3.1, -2.6), Vector3(-3, 1.4, 0.6)],
	["cine_contrapicado", Vector3(0, 0.45, 3.2), Vector3(0, 3.5, -4)],
	["cine_grua_cambridge_a", Vector3(-15, 1.4, -6), Vector3(-15, 1.2, -26)],
	["cine_grua_cambridge_b", Vector3(-15, 11, 2), Vector3(-15, 0, -30)],
	["cine_grua_alta_a", Vector3(-30, 16, 14), Vector3(-25, 0, -4)],
	["cine_grua_alta_b", Vector3(0, 16, 14), Vector3(5, 0, -4)],
	["cine_grua_alta_c", Vector3(25, 16, 14), Vector3(30, 0, -4)],
	["cine_enfrente", Vector3(-12, 1.7, -3.4), Vector3(-15, 3.4, 9)],
	["cine_barrio", Vector3(-45, 24, 22), Vector3(-5, 0, -18)],
	["cine_cerveceria", Vector3(-13.5, 1.8, -28), Vector3(-20, 3.2, -36)],
	["cine_asilo", Vector3(33.5, 1.8, -12.5), Vector3(40, 4.5, -18)],
	["cine_traseras", Vector3(8, 20, -34), Vector3(8, 2, -10)],
	["cine_rectoria", Vector3(-38, 1.7, 1.5), Vector3(-44, 2.8, -5)],
]

## Jugando: dónde se pone Whitehead.
const PLANOS_JUEGO := [
	["juego_broad", Vector3(2, 0.9, 1)],
	["juego_cambridge", Vector3(-15, 0.9, -22)],
	["juego_peter", Vector3(35, 0.9, -17)],
	["juego_new", Vector3(-35, 0.9, -17)],
]


func _cine(carpeta: String) -> void:
	for n in [$WorldEnvironment, $Sun, $EstiloArtistico, $CapaTramado, $Camera3D]:
		remove_child(n)
		n.queue_free()
	GameState.dia = 2
	for f in ["apertura_vista", "dia_2"]:
		GameState.set_flag(f)
	var calle := (load(CALLE) as PackedScene).instantiate()
	add_child(calle)
	await get_tree().create_timer(2.0).timeout
	HUD.hide()
	_contar_triangulos(calle)
	var yo := get_tree().get_first_node_in_group(&"jugador") as Node3D
	for p in PLANOS_JUEGO:
		yo.global_position = p[1]
		await get_tree().create_timer(1.2).timeout
		await _sacar(carpeta, String(p[0]))
		if String(p[0]) == "juego_broad":
			await _desglose_calle(calle.get_node(^"Calle"))
	# vista de puerta ante el 40
	yo.global_position = Vector3(7.5, 0.9, -2.5)
	await get_tree().create_timer(0.8).timeout
	for n in get_tree().get_nodes_in_group(&"puertas"):
		if String((n as Node).get_meta(&"numero", "")) == "40":
			DoorMode.entrar(n)
	await get_tree().create_timer(1.6).timeout
	await _sacar(carpeta, "puerta_40")
	for i in 2:
		DoorMode.mover(-1)
		await get_tree().create_timer(1.0).timeout
	await _sacar(carpeta, "puerta_38")
	DoorMode.salir()
	await get_tree().create_timer(1.2).timeout
	# el tráiler va sin interfaz ni tramado
	for c in get_tree().root.find_children("*", "CanvasLayer", true, false):
		if c != HUD and c.get_parent() != HUD:
			(c as CanvasLayer).visible = false
	var cam := Camera3D.new()
	cam.fov = 55.0
	add_child(cam)
	cam.current = true
	for p in PLANOS_CINE:
		cam.global_position = p[1]
		cam.look_at(p[2])
		await get_tree().create_timer(0.3).timeout
		await _sacar(carpeta, String(p[0]))


## Triángulos por material en las mallas fundidas (juego y cine).
func _contar_triangulos(calle: Node) -> void:
	var suma := {}
	for m in calle.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null or not String(mi.name).contains("_") or not (String(mi.name).begins_with("j") or String(mi.name).begins_with("c")):
			continue
		var k := String(mi.name).split("_", true, 2)[-1] + (" cine" if String(mi.name).begins_with("c") else "")
		var n := 0
		for sfc in mi.mesh.get_surface_count():
			n += (mi.mesh as ArrayMesh).surface_get_array_len(sfc) / 3
		suma[k] = int(suma.get(k, 0)) + n
	print("[Prototipo] triangulos: ", suma)


## Llamadas de cada hijo de Calle (y de Fachadas): se apaga uno cada vez.
func _desglose_calle(calle: Node) -> void:
	var vp := get_viewport()
	await RenderingServer.frame_post_draw
	var total := vp.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)
	var nodos: Array = calle.get_children()
	var fach := calle.get_node_or_null(^"Fachadas")
	if fach != null:
		nodos.append_array(fach.get_children())
	for n in nodos:
		if not (n is Node3D) or not (n as Node3D).visible:
			continue
		(n as Node3D).visible = false
		for i in 2:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var k := vp.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)
		(n as Node3D).visible = true
		if total - k > 0:
			print("[Prototipo]   %s: %d" % [n.name, total - k])


func _sacar(carpeta: String, nombre: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(carpeta.path_join(nombre + ".png"))
	var vp := get_viewport()
	print("[Prototipo] %s: llamadas %d, objetos %d, primitivas %d" % [nombre,
		vp.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME),
		vp.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_OBJECTS_IN_FRAME),
		vp.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME)])


## De día: cielo claro, sol blanco, sin niebla ni farolas.
func _de_dia(si: bool) -> void:
	var env := ($WorldEnvironment as WorldEnvironment).environment
	var sol := $Sun as DirectionalLight3D
	if si:
		env.background_color = Color(0.62, 0.7, 0.78)
		env.ambient_light_color = Color(0.78, 0.8, 0.84)
		env.ambient_light_energy = 0.75
		env.fog_enabled = false
		sol.light_color = Color(1.0, 0.95, 0.88)
		sol.light_energy = 1.4
	else:
		env.background_color = Color(0.1, 0.05, 0.11)
		env.ambient_light_color = Color(0.36, 0.5, 0.34)
		env.ambient_light_energy = 0.24
		env.fog_enabled = true
		sol.light_color = Color(0.85, 0.42, 0.82)
		sol.light_energy = 0.26
	for l in _luces:
		l.visible = not si


func _vaciar() -> void:
	if _bloque != null:
		remove_child(_bloque)
		_bloque.queue_free()
	_bloque = null
	_luces.clear()
	_sin_patio.clear()


# ---------------------------------------------------------------- propuestas

func _construir(cual: String) -> void:
	_bloque = Node3D.new()
	_bloque.name = "Propuesta" + cual
	add_child(_bloque)
	_rng.seed = 1854
	_e = _estilo(cual)
	_materiales()
	var casas: Array = _casas(cual)
	_xa = float(casas[0]["x0"])
	_xb = float(casas[-1]["x1"])
	_hilera(casas)
	_cerrar("Bloque")
	_suelo()
	_farola(float(casas[1]["x1"]), ACERA - 0.45)
	_figura(Vector3(-1.2, 0.0, 4.0))
	_cerrar("Calle")
	_fondo()
	_cerrar("Fondo")
	$EstiloArtistico.call(&"_apply_outline", _bloque)


func _estilo(cual: String) -> Dictionary:
	match cual:
		"A":
			return {"ladrillo": [Color(0.66, 0.58, 0.43), Color(0.5, 0.48, 0.45), Color(0.74, 0.6, 0.45)],
				"junta": Color(0.6, 0.58, 0.53), "hollin": 0.6, "pretil": 1.0, "cubierta": "m",
				"teja": PIZARRA, "dintel": "adovelado", "balcon": true, "estuco_bajo": false,
				"portada": "sencilla", "cornisa": false}
		"B":
			return {"ladrillo": [Color(0.62, 0.5, 0.4), Color(0.52, 0.44, 0.4), Color(0.72, 0.42, 0.32)],
				"junta": Color(0.6, 0.57, 0.52), "hollin": 0.4, "pretil": 0.6, "cubierta": "aguas",
				"teja": PIZARRA, "dintel": "adovelado", "balcon": false, "estuco_bajo": false,
				"portada": "sencilla", "cornisa": false}
		_:
			return {"ladrillo": [Color(0.5, 0.37, 0.27), Color(0.42, 0.32, 0.26), Color(0.74, 0.36, 0.24)],
				"junta": Color(0.58, 0.54, 0.48), "hollin": 0.35, "pretil": 0.0, "cubierta": "teja",
				"teja": TEJA, "dintel": "realce", "balcon": false, "estuco_bajo": true,
				"portada": "fronton", "cornisa": true}


## Casas de la hilera de cada propuesta, de izquierda a derecha.
func _casas(cual: String) -> Array:
	var r: Array = []
	match cual:
		"A":
			var puertas := [Color(0.08, 0.08, 0.09), Color(0.12, 0.24, 0.16), Color(0.38, 0.1, 0.08),
				Color(0.08, 0.08, 0.09), Color(0.13, 0.16, 0.28)]
			for i in 5:
				var tienda := i == 3
				r.append({"x0": -12.5 + 5.0 * i, "x1": -7.5 + 5.0 * i, "pisos": [3.1, 3.2, 2.8, 2.4],
					"sotano": not tienda, "tinte": Color(1, 1, 1).darkened(0.05 * (i % 3)),
					"puerta": puertas[i], "num": str(36 + i),
					"tienda": {"color": Color(0.13, 0.22, 0.17), "texto": "CHANDLER"} if tienda else {},
					"cubierta": "m", "buhardas": 0, "ventanas": 3})
		"B":
			var anchos := [4.6, 5.4, 4.8, 5.6, 4.6]
			var pisos := [[3.6, 3.0, 2.7], [3.6, 3.1, 2.8, 2.3], [3.6, 2.9, 2.6], [3.6, 3.2, 2.9, 2.4], [3.6, 3.0, 2.6]]
			var tintes := [Color(1, 1, 1), Color(1.0, 0.72, 0.62), Color(0.94, 0.92, 0.8), Color(0.82, 0.8, 0.78), Color(1.0, 0.86, 0.72)]
			var tiendas := [
				{"color": Color(0.12, 0.3, 0.2), "texto": "DAIRY"},
				{"color": Color(0.36, 0.08, 0.07), "texto": "COOPER  TAILOR"},
				{"color": Color(0.1, 0.13, 0.3), "texto": "CHEMIST"},
				{"color": Color(0.08, 0.08, 0.08), "texto": "COFFEE ROOMS"},
				{"color": Color(0.7, 0.62, 0.42), "texto": "OIL & COLOUR"},
			]
			var x := -12.5
			for i in 5:
				r.append({"x0": x, "x1": x + float(anchos[i]), "pisos": pisos[i], "sotano": false,
					"tinte": tintes[i], "puerta": Color(0.1, 0.1, 0.1), "num": str(40 + i),
					"tienda": tiendas[i], "cubierta": "aguas", "buhardas": 2 if i in [0, 3] else 0,
					"ventanas": 3 if float(anchos[i]) > 5.0 else 2, "revoco": i == 2,
					"muestra": i == 2})
				x += float(anchos[i])
		_:
			var puertas := [Color(0.1, 0.1, 0.1), Color(0.32, 0.12, 0.09), Color(0.12, 0.2, 0.15), Color(0.1, 0.1, 0.1)]
			for i in 4:
				var tienda := i == 2
				r.append({"x0": -11.0 + 5.5 * i, "x1": -5.5 + 5.5 * i, "pisos": [3.4, 3.3, 2.9, 2.5],
					"sotano": not tienda, "tinte": Color(1, 1, 1).darkened(0.06 * (i % 2)),
					"puerta": puertas[i], "num": str(12 + i),
					"tienda": {"color": Color(0.1, 0.12, 0.1), "texto": "COFFEE ROOMS"} if tienda else {},
					"cubierta": "teja", "buhardas": 2, "ventanas": 3})
	return r


# ---------------------------------------------------------------- materiales

func _materiales() -> void:
	_mats.clear()
	var lad := ShaderMaterial.new()
	lad.shader = _shader(FABRICA)
	var c: Array = _e["ladrillo"]
	lad.set_shader_parameter("color_a", c[0])
	lad.set_shader_parameter("color_b", c[1])
	lad.set_shader_parameter("color_realce", c[2])
	lad.set_shader_parameter("color_junta", _e["junta"])
	lad.set_shader_parameter("hollin", _e["hollin"])
	_mats["ladrillo"] = lad

	# estuco: sillares grandes, juntas finas y apenas variación
	var est := ShaderMaterial.new()
	est.shader = lad.shader
	est.set_shader_parameter("color_a", Color(0.86, 0.81, 0.68))
	est.set_shader_parameter("color_b", Color(0.86, 0.81, 0.68))
	est.set_shader_parameter("color_realce", Color(0.86, 0.81, 0.68))
	est.set_shader_parameter("color_junta", Color(0.5, 0.47, 0.42))
	est.set_shader_parameter("pieza", Vector2(0.6, 0.42))
	est.set_shader_parameter("junta", 0.012)
	est.set_shader_parameter("flamenco", 0.0)
	est.set_shader_parameter("variacion", 0.03)
	est.set_shader_parameter("hollin", 0.3)
	_mats["estuco"] = est

	var tej := ShaderMaterial.new()
	tej.shader = _shader(CUBIERTA)
	if _e["cubierta"] == "teja":
		tej.set_shader_parameter("hilada", 0.14)
		tej.set_shader_parameter("ancho", 0.24)
	_mats["tejado"] = tej

	var pint := StandardMaterial3D.new()
	pint.vertex_color_use_as_albedo = true
	pint.roughness = 0.85
	_mats["pintura"] = pint
	_mats["fino"] = pint

	var vid := StandardMaterial3D.new()
	vid.albedo_color = Color(0.07, 0.08, 0.1)
	vid.roughness = 0.18
	vid.metallic_specular = 0.8
	_mats["vidrio"] = vid

	var luz := StandardMaterial3D.new()
	luz.albedo_color = Color(0.5, 0.33, 0.14)
	luz.emission_enabled = true
	luz.emission = Color(1, 0.7, 0.33)
	luz.emission_energy_multiplier = 1.1
	luz.roughness = 1.0
	_mats["luz"] = luz

	var hie := StandardMaterial3D.new()
	hie.albedo_color = Color(0.07, 0.07, 0.08)
	hie.roughness = 0.5
	_mats["hierro"] = hie
	_mats["hierro_fino"] = hie

	var far := StandardMaterial3D.new()
	far.albedo_color = Color(1, 0.86, 0.6)
	far.emission_enabled = true
	far.emission = Color(0.6, 1, 0.5)
	far.emission_energy_multiplier = 2.6
	_mats["farol"] = far

	var acera := ShaderMaterial.new()
	acera.shader = _shader(SUELO)
	acera.set_shader_parameter("color_piedra", Color(0.6, 0.58, 0.5))
	acera.set_shader_parameter("color_junta", Color(0.4, 0.39, 0.35))
	acera.set_shader_parameter("pieza", Vector2(0.9, 0.62))
	acera.set_shader_parameter("junta", 0.018)
	acera.set_shader_parameter("variacion", 0.1)
	acera.set_shader_parameter("cruzado", 0.0)
	acera.set_shader_parameter("abombado", 0.0)
	_mats["acera"] = acera

	var cal := ShaderMaterial.new()
	cal.shader = acera.shader
	cal.set_shader_parameter("color_piedra", Color(0.46, 0.44, 0.42))
	cal.set_shader_parameter("color_junta", Color(0.2, 0.19, 0.18))
	cal.set_shader_parameter("pieza", Vector2(0.17, 0.28))
	cal.set_shader_parameter("junta", 0.018)
	cal.set_shader_parameter("variacion", 0.22)
	cal.set_shader_parameter("cruzado", 1.0)
	cal.set_shader_parameter("abombado", 0.5)
	_mats["calzada"] = cal


var _shaders: Dictionary = {}


func _shader(codigo: String) -> Shader:
	if not _shaders.has(codigo):
		var s := Shader.new()
		s.code = codigo
		_shaders[codigo] = s
	return _shaders[codigo]


## Una MeshInstance3D por material con lo acumulado; vacía los lotes.
func _cerrar(nombre: String) -> void:
	var raiz := Node3D.new()
	raiz.name = nombre
	_bloque.add_child(raiz)
	for k in _lotes:
		var st := _lotes[k] as SurfaceTool
		var m := MeshInstance3D.new()
		m.name = nombre + "_" + String(k)
		m.mesh = st.commit()
		m.material_override = _mats[k]
		if String(k) in SIN_CONTORNO:
			m.set_meta(&"sin_contorno", true)
		if String(k) in SIN_SOMBRA:
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		raiz.add_child(m)
	_lotes.clear()


# ---------------------------------------------------------------- geometría

func _st(k: String) -> SurfaceTool:
	if not _lotes.has(k):
		var s := SurfaceTool.new()
		s.begin(Mesh.PRIMITIVE_TRIANGLES)
		_lotes[k] = s
	return _lotes[k]


## Triángulo en coords. locales (_xf); frente en sentido horario, como pide Godot.
func _tri(k: String, a: Vector3, b: Vector3, c: Vector3, n: Vector3, col: Color) -> void:
	var s := _st(k)
	var wa := _xf * a
	var wb := _xf * b
	var wc := _xf * c
	var wn := (_xf.basis * n).normalized()
	if (wb - wa).cross(wc - wa).dot(wn) > 0.0:
		var t := wb
		wb = wc
		wc = t
	for v in [wa, wb, wc]:
		s.set_color(col)
		s.set_normal(wn)
		s.add_vertex(v)


func _quad(k: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3, col: Color) -> void:
	_tri(k, a, b, c, n, col)
	_tri(k, a, c, d, n, col)


const _EJES: Array[Vector3] = [Vector3.RIGHT, Vector3.UP, Vector3.BACK]


func _caja(k: String, centro: Vector3, tam: Vector3, col: Color = Color.WHITE, base: Basis = Basis.IDENTITY) -> void:
	var h := tam * 0.5
	for i in 3:
		var j := (i + 1) % 3
		var l := (i + 2) % 3
		for sig in [-1.0, 1.0]:
			var n: Vector3 = _EJES[i] * float(sig)
			var c0: Vector3 = n * h[i]
			var ej: Vector3 = _EJES[j] * h[j]
			var el: Vector3 = _EJES[l] * h[l]
			_quad(k, centro + base * (c0 - ej - el), centro + base * (c0 + ej - el),
				centro + base * (c0 + ej + el), centro + base * (c0 - ej + el), base * n, col)


func _caja_ab(k: String, a: Vector3, b: Vector3, col: Color = Color.WHITE) -> void:
	_caja(k, (a + b) * 0.5, (b - a).abs(), col)


func _cilindro(k: String, pie: Vector3, r0: float, r1: float, alto: float, lados: int,
		col: Color, giro: float = 0.0) -> void:
	for i in lados:
		var a0 := giro + TAU * float(i) / float(lados)
		var a1 := giro + TAU * float(i + 1) / float(lados)
		var d0 := Vector3(cos(a0), 0.0, sin(a0))
		var d1 := Vector3(cos(a1), 0.0, sin(a1))
		var n := ((d0 + d1) * 0.5).normalized()
		n.y = (r0 - r1) / alto * 0.5
		_quad(k, pie + d0 * r0, pie + d1 * r0, pie + d1 * r1 + Vector3.UP * alto,
			pie + d0 * r1 + Vector3.UP * alto, n.normalized(), col)
		if r1 > 0.0:
			_tri(k, pie + Vector3.UP * alto, pie + d0 * r1 + Vector3.UP * alto,
				pie + d1 * r1 + Vector3.UP * alto, Vector3.UP, col)


## Prisma de un perfil 2D (u, v) extruido de a a b. eje 0: perfil (z, y) a lo largo de x;
## eje 2: perfil (x, y) a lo largo de z.
func _extruir(k: String, perfil: PackedVector2Array, a: float, b: float, eje: int, col: Color) -> void:
	var p3 := func(u: Vector2, w: float) -> Vector3:
		return Vector3(w, u.y, u.x) if eje == 0 else Vector3(u.x, u.y, w)
	var area := 0.0
	var n := perfil.size()
	for i in n:
		var p := perfil[i]
		var q := perfil[(i + 1) % n]
		area += p.x * q.y - q.x * p.y
	for i in n:
		var p := perfil[i]
		var q := perfil[(i + 1) % n]
		var d := q - p
		var fuera := Vector2(d.y, -d.x) if area > 0.0 else Vector2(-d.y, d.x)
		var nn: Vector3 = p3.call(fuera.normalized(), 0.0)
		_quad(k, p3.call(p, a), p3.call(q, a), p3.call(q, b), p3.call(p, b), nn, col)
	var idx := Geometry2D.triangulate_polygon(perfil)
	var tapa := Vector3.RIGHT if eje == 0 else Vector3.BACK
	for t in range(0, idx.size(), 3):
		var u0 := perfil[idx[t]]
		var u1 := perfil[idx[t + 1]]
		var u2 := perfil[idx[t + 2]]
		_tri(k, p3.call(u0, a), p3.call(u1, a), p3.call(u2, a), -tapa, col)
		_tri(k, p3.call(u0, b), p3.call(u1, b), p3.call(u2, b), tapa, col)


## Muro con huecos (Rect2 en x, y) entre z0 y z0 - grosor.
func _muro(k: String, x0: float, x1: float, y0: float, y1: float, huecos: Array,
		col: Color = Color.WHITE, z0: float = 0.0, grosor: float = MURO) -> void:
	var cortes: Array[float] = [x0, x1]
	for h: Rect2 in huecos:
		for x in [h.position.x, h.end.x]:
			if x > x0 and x < x1:
				cortes.append(x)
	cortes.sort()
	for i in cortes.size() - 1:
		var a := cortes[i]
		var b := cortes[i + 1]
		if b - a < 0.001:
			continue
		var mid := (a + b) * 0.5
		var tapados: Array[Vector2] = []
		for h: Rect2 in huecos:
			if h.position.x <= mid and h.end.x >= mid and h.end.y > y0 and h.position.y < y1:
				tapados.append(Vector2(maxf(h.position.y, y0), minf(h.end.y, y1)))
		tapados.sort_custom(func(p: Vector2, q: Vector2) -> bool: return p.x < q.x)
		var y := y0
		for t in tapados:
			if t.x > y + 0.001:
				_caja_ab(k, Vector3(a, y, z0 - grosor), Vector3(b, t.x, z0), col)
			y = maxf(y, t.y)
		if y < y1 - 0.001:
			_caja_ab(k, Vector3(a, y, z0 - grosor), Vector3(b, y1, z0), col)


func _rotulo(texto: String, pos: Vector3, tam: int, color: Color, contorno: int = 10) -> Label3D:
	var l := Label3D.new()
	l.text = texto
	l.font = _fuente
	l.font_size = tam
	l.pixel_size = 0.003
	l.modulate = color
	l.outline_modulate = Color(0.14, 0.09, 0.05)
	l.outline_size = contorno
	l.double_sided = false
	l.shaded = false
	_bloque.add_child(l)
	l.transform = _xf * Transform3D(Basis.IDENTITY, pos)
	return l


# ---------------------------------------------------------------- la casa

## Ventana de guillotina de 6 sobre 6 (o 3 sobre 3) dentro de su hueco.
func _ventana(x: float, y0: float, w: float, h: float, huecos: Array, cols: int = 3,
		filas: int = 2, encendida: bool = false, detalle: bool = true) -> void:
	huecos.append(Rect2(x - w * 0.5, y0, w, h))
	var z := -0.13
	var marco := BLANCO
	_caja("fino", Vector3(x - w * 0.5 + 0.04, y0 + h * 0.5, z), Vector3(0.08, h, 0.07), marco)
	_caja("fino", Vector3(x + w * 0.5 - 0.04, y0 + h * 0.5, z), Vector3(0.08, h, 0.07), marco)
	_caja("fino", Vector3(x, y0 + h - 0.04, z), Vector3(w, 0.08, 0.07), marco)
	_caja("fino", Vector3(x, y0 + 0.05, z), Vector3(w, 0.1, 0.07), marco)
	_caja("fino", Vector3(x, y0 + h * 0.5, z + 0.01), Vector3(w, 0.06, 0.06), marco)
	if detalle:
		for i in range(1, cols):
			_caja("fino", Vector3(x - w * 0.5 + w * float(i) / float(cols), y0 + h * 0.5, z - 0.02),
				Vector3(0.03, h, 0.04), marco)
		for s in 2:
			var ys := y0 + h * 0.5 * float(s)
			for j in range(1, filas):
				_caja("fino", Vector3(x, ys + h * 0.5 * float(j) / float(filas), z - 0.02),
					Vector3(w, 0.03, 0.04), marco)
	_caja("luz" if encendida else "vidrio", Vector3(x, y0 + h * 0.5, -0.19), Vector3(w, h, 0.02))
	# persiana a medio bajar en alguna
	if not encendida and _rng.randf() < 0.35:
		var bh := h * _rng.randf_range(0.18, 0.45)
		_caja("pintura", Vector3(x, y0 + h - bh * 0.5, -0.175), Vector3(w - 0.12, bh, 0.01),
			Color(0.82, 0.76, 0.6))
	elif encendida and _rng.randf() < 0.6:
		for lado in [-1.0, 1.0]:
			_caja("pintura", Vector3(x + float(lado) * (w * 0.5 - 0.13), y0 + h * 0.5, -0.175),
				Vector3(0.2, h - 0.12, 0.01), Color(0.42, 0.12, 0.1))


## Alféizar y dintel según el estilo.
func _remates_de_ventana(x: float, y0: float, w: float, h: float, piso: int) -> void:
	_caja("pintura", Vector3(x, y0 - 0.05, 0.02), Vector3(w + 0.2, 0.1, 0.22), PIEDRA)
	match String(_e["dintel"]):
		"adovelado":
			# arco plano de ladrillo frotado, un poco más ancho que el hueco
			_caja("ladrillo", Vector3(x, y0 + h + 0.15, 0.006), Vector3(w + 0.3, 0.3, 0.012), Color(1, 1, 1, 0))
		"realce":
			for lado in [-1.0, 1.0]:
				_caja("ladrillo", Vector3(x + float(lado) * (w * 0.5 + 0.07), y0 + h * 0.5, 0.008),
					Vector3(0.14, h, 0.016), Color(1, 1, 1, 0))
			_caja("ladrillo", Vector3(x, y0 + h + 0.16, 0.01), Vector3(w + 0.42, 0.32, 0.02), Color(1, 1, 1, 0))
			_caja("pintura", Vector3(x, y0 + h + 0.16, 0.03), Vector3(0.2, 0.36, 0.06), BLANCO.darkened(0.08))
			if piso == 1:
				# guardapolvo de estuco sobre ménsulas en el piso noble
				_caja("pintura", Vector3(x, y0 + h + 0.42, 0.09), Vector3(w + 0.6, 0.12, 0.2), BLANCO.darkened(0.1))
				for lado in [-1.0, 1.0]:
					_caja("pintura", Vector3(x + float(lado) * (w * 0.5 + 0.2), y0 + h + 0.25, 0.06),
						Vector3(0.12, 0.3, 0.14), BLANCO.darkened(0.1))


func _encender() -> bool:
	return _rng.randf() < 0.26


## Puerta de seis cuarterones con montante, escalón y portada.
func _portal(x: float, col: Color, num: String, huecos: Array, y_suelo: float = 0.0) -> void:
	var w := 1.05
	var hp := 2.3
	var fan := 0.55
	var y0 := y_suelo + 0.16
	huecos.append(Rect2(x - w * 0.5 - 0.06, y_suelo, w + 0.12, hp + fan + 0.16))
	_caja("pintura", Vector3(x, y0 + hp * 0.5, -0.2), Vector3(w, hp, 0.06), col)
	for lado in [-1.0, 1.0]:
		_caja("fino", Vector3(x + float(lado) * (w * 0.5 + 0.03), y_suelo + (hp + fan + 0.16) * 0.5, -0.14),
			Vector3(0.08, hp + fan + 0.16, 0.22), BLANCO)
	# cuarterones: dos columnas, tres alturas
	var altos := [0.55, 0.75, 0.6]
	var y := y0 + 0.18
	for f in 3:
		for lado in [-1.0, 1.0]:
			_caja("fino", Vector3(x + float(lado) * w * 0.22, y + float(altos[f]) * 0.5, -0.165),
				Vector3(w * 0.32, float(altos[f]), 0.02), col.lightened(0.12))
		y += float(altos[f]) + 0.1
	_caja("fino", Vector3(x + w * 0.3, y0 + hp * 0.48, -0.15), Vector3(0.07, 0.07, 0.05), LATON)
	_caja("fino", Vector3(x, y0 + hp * 0.62, -0.15), Vector3(0.16, 0.05, 0.04), LATON)
	# montante: cristal con radios y el número pintado
	_caja("fino", Vector3(x, y0 + hp + 0.04, -0.14), Vector3(w + 0.1, 0.08, 0.08), BLANCO)
	var lit := _rng.randf() < 0.5
	_caja("luz" if lit else "vidrio", Vector3(x, y0 + hp + fan * 0.5, -0.19), Vector3(w + 0.1, fan, 0.02))
	for i in 5:
		var a := PI * (0.12 + 0.76 * float(i) / 4.0)
		var largo := fan * 0.95
		var b := Basis(Vector3.BACK, a - PI * 0.5)
		_caja("fino", Vector3(x, y0 + hp + 0.06, -0.16) + b * Vector3(0, largo * 0.5, 0),
			Vector3(0.025, largo, 0.03), BLANCO, b)
	if not num.is_empty():
		_rotulo(num, Vector3(x, y0 + hp + fan * 0.42, -0.165), 64, ORO, 6)
	# escalón de piedra
	_caja("pintura", Vector3(x, y_suelo + 0.08, 0.16), Vector3(w + 0.5, 0.16, 0.5), PIEDRA)
	match String(_e["portada"]):
		"sencilla":
			for lado in [-1.0, 1.0]:
				_caja("pintura", Vector3(x + float(lado) * (w * 0.5 + 0.13), y0 + (hp + fan) * 0.5, 0.03),
					Vector3(0.16, hp + fan, 0.06), BLANCO)
			_caja("pintura", Vector3(x, y0 + hp + fan + 0.08, 0.08), Vector3(w + 0.7, 0.14, 0.24), BLANCO)
		"fronton":
			var est := Color(0.88, 0.84, 0.74)
			for lado in [-1.0, 1.0]:
				_caja("pintura", Vector3(x + float(lado) * (w * 0.5 + 0.2), y0 + (hp + fan) * 0.5, 0.06),
					Vector3(0.26, hp + fan, 0.12), est)
			var ye := y0 + hp + fan
			_caja("pintura", Vector3(x, ye + 0.17, 0.08), Vector3(w + 0.9, 0.34, 0.2), est)
			var mitad := (w + 1.1) * 0.5
			_extruir("pintura", PackedVector2Array([Vector2(x - mitad, ye + 0.34), Vector2(x + mitad, ye + 0.34),
				Vector2(x, ye + 0.95)]), -0.02, 0.24, 2, est)


## Escaparate: pilastras, rótulo, cornisa, zócalo y vidrieras de cuadradillos encendidas.
func _tienda(c: Dictionary, huecos: Array) -> void:
	var x0: float = c["x0"]
	var x1: float = c["x1"]
	var xm := (x0 + x1) * 0.5
	var t: Dictionary = c["tienda"]
	var col: Color = t["color"]
	var claro := col.lightened(0.35)
	var alto := 2.8
	huecos.append(Rect2(x0 + 0.3, 0.0, x1 - x0 - 0.6, alto + 0.25))
	# hueco interior: fondo encendido, paredes oscuras y género en baldas
	var oscuro := Color(0.2, 0.15, 0.1)
	_caja_ab("pintura", Vector3(x0 + 0.3, 0.0, -1.3), Vector3(x1 - 0.3, alto + 0.25, -1.25), oscuro)
	_caja_ab("pintura", Vector3(x0 + 0.3, alto + 0.2, -1.3), Vector3(x1 - 0.3, alto + 0.25, -0.3), oscuro)
	_caja_ab("pintura", Vector3(x0 + 0.25, 0.0, -1.3), Vector3(x0 + 0.3, alto + 0.25, -0.3), oscuro)
	_caja_ab("pintura", Vector3(x1 - 0.3, 0.0, -1.3), Vector3(x1 - 0.25, alto + 0.25, -0.3), oscuro)
	_caja_ab("luz", Vector3(x0 + 0.3, 0.6, -1.25), Vector3(x1 - 0.3, alto, -1.22))
	for lado in [-1.0, 1.0]:
		var a := xm + float(lado) * 0.6
		var b := (x0 + 0.3) if lado < 0 else (x1 - 0.3)
		var lo := minf(a, b)
		var hi := maxf(a, b)
		for balda in 2:
			var yb := 0.95 + 0.75 * float(balda)
			_caja_ab("pintura", Vector3(lo, yb, -0.8), Vector3(hi, yb + 0.04, -0.5), Color(0.35, 0.24, 0.15))
			var xx := lo + 0.12
			while xx < hi - 0.15:
				var ancho := _rng.randf_range(0.1, 0.22)
				var altura := _rng.randf_range(0.15, 0.4)
				_caja("pintura", Vector3(xx + ancho * 0.5, yb + 0.04 + altura * 0.5, -0.65),
					Vector3(ancho, altura, 0.15), Color.from_hsv(_rng.randf(), 0.45, _rng.randf_range(0.35, 0.8)))
				xx += ancho + _rng.randf_range(0.03, 0.12)
		# zócalo, antepecho y vidriera de cuadradillos
		_caja_ab("pintura", Vector3(lo, 0.0, -0.08), Vector3(hi, 0.6, 0.06), col)
		_caja_ab("pintura", Vector3(lo, 0.6, -0.12), Vector3(hi, 0.68, 0.1), claro)
		var n := maxi(2, int(round((hi - lo) / 0.4)))
		for i in n + 1:
			var xb := lerpf(lo, hi, float(i) / float(n))
			_caja("fino", Vector3(xb, 0.68 + (alto - 0.68) * 0.5, -0.02), Vector3(0.04, alto - 0.68, 0.05), claro)
		for j in 5:
			var yb := lerpf(0.68, alto, float(j) / 4.0)
			_caja("fino", Vector3((lo + hi) * 0.5, yb, -0.02), Vector3(hi - lo, 0.04, 0.05), claro)
	# puerta en el centro, metida, con medio cristal y montante
	_caja_ab("pintura", Vector3(xm - 0.6, 0.0, -0.08), Vector3(xm - 0.5, alto, 0.06), col)
	_caja_ab("pintura", Vector3(xm + 0.5, 0.0, -0.08), Vector3(xm + 0.6, alto, 0.06), col)
	_caja_ab("pintura", Vector3(xm - 0.5, 0.0, -0.3), Vector3(xm + 0.5, 2.25, -0.24), col)
	_caja_ab("luz", Vector3(xm - 0.36, 1.15, -0.24), Vector3(xm + 0.36, 2.05, -0.22))
	_caja_ab("luz", Vector3(xm - 0.5, 2.32, -0.3), Vector3(xm + 0.5, alto, -0.27))
	_caja_ab("pintura", Vector3(xm - 0.5, 2.25, -0.3), Vector3(xm + 0.5, 2.32, -0.2), claro)
	_caja_ab("pintura", Vector3(xm - 0.55, 0.0, -0.3), Vector3(xm + 0.55, 0.1, 0.1), PIEDRA)
	# pilastras con ménsulas, rótulo y cornisa
	for lado in [-1.0, 1.0]:
		var xp := (x0 + 0.17) if lado < 0 else (x1 - 0.17)
		_caja_ab("pintura", Vector3(xp - 0.17, 0.0, -0.02), Vector3(xp + 0.17, alto, 0.16), col)
		_caja_ab("pintura", Vector3(xp - 0.2, alto, -0.02), Vector3(xp + 0.2, alto + 0.55, 0.3), col.darkened(0.2))
	_caja_ab("pintura", Vector3(x0 + 0.37, alto, 0.02), Vector3(x1 - 0.37, alto + 0.55, 0.16), col)
	_caja_ab("pintura", Vector3(x0 + 0.02, alto + 0.55, -0.05), Vector3(x1 - 0.02, alto + 0.68, 0.4), col.darkened(0.1))
	_caja_ab("hierro", Vector3(x0 + 0.02, alto + 0.68, -0.05), Vector3(x1 - 0.02, alto + 0.71, 0.4))
	# toldo enrollado bajo el rótulo
	_caja_ab("pintura", Vector3(x0 + 0.4, alto - 0.12, 0.05), Vector3(x1 - 0.4, alto, 0.2), Color(0.4, 0.34, 0.26))
	var texto := String(t["texto"])
	var ancho_rotulo := x1 - x0 - 0.9
	var tam := int(clampf(ancho_rotulo * 0.85 / (float(texto.length()) * 0.65 * 0.003), 40.0, 110.0))
	_rotulo(texto, Vector3(xm, alto + 0.28, 0.17), tam, ORO if col.v < 0.5 else Color(0.18, 0.12, 0.08), 6)


func _casa(c: Dictionary) -> void:
	var x0: float = c["x0"]
	var x1: float = c["x1"]
	var xm := (x0 + x1) * 0.5
	var ancho := x1 - x0
	var pisos: Array = c["pisos"]
	var yt := _altura(c)
	var pret: float = _e["pretil"]
	var sotano: bool = c["sotano"]
	var tinte: Color = c["tinte"]
	var tienda := not Dictionary(c["tienda"]).is_empty()
	var revoco := bool(c.get("revoco", false))
	var y_base := SOTANO if sotano else 0.0
	var huecos: Array = []
	var bajos: Array = []

	# planta baja
	if tienda:
		_tienda(c, bajos)
	else:
		_portal(xm, c["puerta"], String(c["num"]), bajos)
		for lado in [-1.0, 1.0]:
			var xv := xm + float(lado) * ancho * 0.31
			_ventana(xv, 0.85, 0.95, 1.85, bajos, 3, 2, _encender())
			_remates_de_ventana(xv, 0.85, 0.95, 1.85, 0)
	# sótano con su foso, puente, escalera y verja
	if sotano:
		for lado in [-1.0, 1.0]:
			var xv := xm + float(lado) * ancho * 0.31
			_ventana(xv, SOTANO + 0.75, 0.95, 1.3, bajos, 3, 1, _rng.randf() < 0.4)
		bajos.append(Rect2(xm - 0.45, SOTANO, 0.9, 1.95))
		_caja_ab("pintura", Vector3(xm - 0.45, SOTANO, -0.22), Vector3(xm + 0.45, SOTANO + 1.95, -0.18), Color(0.16, 0.13, 0.1))
		_patio(x0, x1, xm)
	else:
		_sin_patio.append(Vector2(x0, x1))

	# pisos altos
	var y: float = pisos[0]
	var n: int = c["ventanas"]
	for p in range(1, pisos.size()):
		var h: float = pisos[p]
		var vh := h * (0.66 if p == 1 else (0.6 if p == 2 else 0.52))
		var sill := 0.75 if p == 1 else 0.7
		if p == 1 and bool(_e["balcon"]):
			vh = h * 0.74
			sill = 0.3
		var vw := 0.95 if p < 3 else 0.85
		for i in n:
			var xv := xm + (float(i) - float(n - 1) * 0.5) * (ancho * (0.31 if n == 3 else 0.42))
			_ventana(xv, y + sill, vw, vh, huecos, 3, 2 if p < 3 else 1, _encender())
			_remates_de_ventana(xv, y + sill, vw, vh, p)
			if p == 1 and bool(_e["balcon"]):
				_balconcillo(xv, y + sill, vw)
		y += h

	# fachada: bajo y alto (el bajo en estuco si toca)
	var mat_alto := "estuco" if revoco else "ladrillo"
	var mat_bajo := "estuco" if bool(_e["estuco_bajo"]) else mat_alto
	var col_alto := Color(0.86, 0.9, 0.82) if revoco else tinte
	var arriba := yt + pret
	_muro(mat_bajo, x0, x1, y_base, pisos[0], bajos, Color.WHITE if mat_bajo == "estuco" else tinte)
	_muro(mat_alto, x0, x1, pisos[0], arriba, huecos, col_alto)
	# imposta de piedra sobre el bajo
	_caja_ab("pintura", Vector3(x0, pisos[0] - 0.08, 0.0), Vector3(x1, pisos[0] + 0.12, 0.06), PIEDRA)
	if bool(_e["cornisa"]):
		y = pisos[0]
		for p in range(1, pisos.size() - 1):
			y += float(pisos[p])
			_caja_ab("pintura", Vector3(x0, y - 0.06, 0.0), Vector3(x1, y + 0.1, 0.05), Color(0.86, 0.82, 0.72))
		_cornisa(x0, x1, yt)
	else:
		# cornisa fina bajo el pretil y albardilla
		_caja_ab("pintura", Vector3(x0, yt - 0.05, 0.0), Vector3(x1, yt + 0.12, 0.12), PIEDRA)
		_caja_ab("pintura", Vector3(x0, arriba, -MURO - 0.04), Vector3(x1, arriba + 0.1, 0.05), PIEDRA)

	# trasera, con su propio giro: x local va al revés
	_trasera(c, yt)
	_cubierta(c, yt)
	if c.has("muestra") and bool(c["muestra"]):
		_muestra(xm + ancho * 0.5 - 0.5, pisos[0] + 0.9)

	# carbonera y respiradero en la acera
	_cilindro("hierro", Vector3(xm + ancho * 0.28, 0.005, ACERA - 0.75), 0.2, 0.2, 0.012, 10, Color.WHITE)


func _altura(c: Dictionary) -> float:
	var s := 0.0
	for h in Array(c["pisos"]):
		s += float(h)
	return s


func _balconcillo(x: float, y: float, w: float) -> void:
	_caja("pintura", Vector3(x, y - 0.06, 0.12), Vector3(w + 0.3, 0.1, 0.34), PIEDRA)
	for i in 9:
		var xb := x - (w + 0.2) * 0.5 + (w + 0.2) * float(i) / 8.0
		_caja("hierro_fino", Vector3(xb, y + 0.3, 0.26), Vector3(0.025, 0.6, 0.025))
	_caja("hierro_fino", Vector3(x, y + 0.6, 0.26), Vector3(w + 0.24, 0.04, 0.04))
	_caja("hierro_fino", Vector3(x, y + 0.2, 0.26), Vector3(w + 0.2, 0.025, 0.025))


func _cornisa(x0: float, x1: float, yt: float) -> void:
	var c := Color(0.86, 0.82, 0.72)
	_caja_ab("pintura", Vector3(x0, yt - 0.25, 0.0), Vector3(x1, yt + 0.0, 0.12), c)
	_caja_ab("pintura", Vector3(x0, yt, -0.1), Vector3(x1, yt + 0.32, 0.5), c)
	var x := x0 + 0.2
	while x < x1 - 0.1:
		_caja("fino", Vector3(x, yt - 0.05, 0.3), Vector3(0.12, 0.1, 0.36), c.darkened(0.05))
		x += 0.4


## El foso: suelo, muro de contención, puente a la puerta, escalera y verja.
func _patio(x0: float, x1: float, xm: float) -> void:
	_caja_ab("pintura", Vector3(x0, SOTANO - 0.1, 0.0), Vector3(x1, SOTANO, PATIO), Color(0.34, 0.33, 0.3))
	_caja_ab("ladrillo", Vector3(x0, SOTANO, PATIO), Vector3(x1, 0.0, PATIO + 0.25), Color(0.8, 0.8, 0.8))
	_caja_ab("pintura", Vector3(x0, 0.0, PATIO - 0.02), Vector3(x1, 0.1, PATIO + 0.27), PIEDRA)
	_caja_ab("pintura", Vector3(xm - 0.8, -0.32, 0.0), Vector3(xm + 0.8, 0.0, PATIO + 0.25), PIEDRA.darkened(0.05))
	# escalera bajando hacia el lado de la medianera
	var pasos := 8
	for i in pasos:
		var top := -float(i + 1) * (-SOTANO) / float(pasos + 1)
		var xa := xm + 0.8 + 0.27 * float(i)
		_caja_ab("pintura", Vector3(xa, SOTANO, PATIO - 0.7), Vector3(xa + 0.27, top, PATIO), PIEDRA.darkened(0.12))
	# verja de lanzas sobre el murete, abierta frente al puente
	var zr := PATIO + 0.12
	var x := x0 + 0.08
	while x < x1 - 0.05:
		if absf(x - xm) > 0.82:
			_caja("hierro_fino", Vector3(x, 0.1 + 0.5, zr), Vector3(0.024, 1.0, 0.024))
			_cilindro("hierro_fino", Vector3(x, 1.1, zr), 0.035, 0.0, 0.11, 4, Color.WHITE, PI * 0.25)
		x += 0.13
	for tramo in [Vector2(x0 + 0.05, xm - 0.82), Vector2(xm + 0.82, x1 - 0.05)]:
		var a: float = tramo.x
		var b: float = tramo.y
		_caja_ab("hierro_fino", Vector3(a, 0.98, zr - 0.02), Vector3(b, 1.02, zr + 0.02))
		_caja_ab("hierro_fino", Vector3(a, 0.18, zr - 0.02), Vector3(b, 0.22, zr + 0.02))
		# machones con remate en los extremos
		for e in [a, b]:
			_caja("hierro", Vector3(e, 0.68, zr), Vector3(0.07, 1.16, 0.07))
			_cilindro("hierro", Vector3(e, 1.26, zr), 0.06, 0.02, 0.14, 6, Color.WHITE)
	# barandilla del puente
	for lado in [-1.0, 1.0]:
		var xb := xm + float(lado) * 0.82
		var z := 0.35
		while z < PATIO:
			_caja("hierro_fino", Vector3(xb, 0.5, z), Vector3(0.024, 1.0, 0.024))
			z += 0.13
		_caja_ab("hierro_fino", Vector3(xb - 0.02, 0.98, 0.3), Vector3(xb + 0.02, 1.02, PATIO + 0.12))


## Trasera: muro con ventanas sencillas, cuerpo de atrás y patio con su tapia y retrete.
func _trasera(c: Dictionary, yt: float) -> void:
	var x0: float = c["x0"]
	var x1: float = c["x1"]
	var ancho := x1 - x0
	var tinte: Color = c["tinte"]
	var pisos: Array = c["pisos"]
	_xf = Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0, -FONDO))
	var a := -x1
	var b := -x0
	var huecos: Array = []
	var y := 0.0
	for p in pisos.size():
		var h: float = pisos[p]
		for i in 2:
			var xv := a + ancho * (0.3 + 0.4 * float(i))
			if p == 0 and i == 0:
				huecos.append(Rect2(xv - 0.45, 0.0, 0.9, 2.2))
				_caja("pintura", Vector3(xv, 1.1, -0.2), Vector3(0.9, 2.2, 0.06), Color(0.3, 0.26, 0.2))
				continue
			_ventana(xv, y + 0.8, 0.85, h * 0.55, huecos, 2, 2, _encender(), false)
			_caja("pintura", Vector3(xv, y + 0.75, 0.02), Vector3(1.0, 0.08, 0.16), PIEDRA)
		y += h
	var remate := 0.0 if bool(_e["cornisa"]) else 0.5
	_muro("ladrillo", a, b, 0.0, yt + remate, huecos, tinte.darkened(0.1))
	if remate > 0.0:
		_caja_ab("pintura", Vector3(a, yt + remate, -MURO - 0.04), Vector3(b, yt + remate + 0.1, 0.05), PIEDRA)
	_xf = Transform3D.IDENTITY
	# cuerpo trasero de dos plantas con tejadillo a un agua
	var izq := int(round(x0)) % 2 == 0
	var wx0 := x0 + 0.3 if izq else x1 - 2.7
	var wx1 := wx0 + 2.4
	var hh := float(pisos[0]) + float(pisos[1])
	_caja_ab("ladrillo", Vector3(wx0, 0.0, -FONDO - 3.4), Vector3(wx1, hh, -FONDO), tinte.darkened(0.12))
	for p in 2:
		_caja("vidrio", Vector3((wx0 + wx1) * 0.5, 1.4 + 3.0 * float(p), -FONDO - 3.41), Vector3(0.8, 1.2, 0.02))
		_caja("pintura", Vector3((wx0 + wx1) * 0.5, 0.75 + 3.0 * float(p), -FONDO - 3.45), Vector3(0.95, 0.08, 0.1), PIEDRA)
	_extruir("tejado", PackedVector2Array([Vector2(-FONDO - 3.6, hh), Vector2(-FONDO, hh + 1.0),
		Vector2(-FONDO, hh + 0.9), Vector2(-FONDO - 3.6, hh - 0.1)]), wx0 - 0.1, wx1 + 0.1, 0, _e["teja"])
	# tapias, suelo del patio y retrete al fondo
	var hondo := -FONDO - 8.5
	_caja_ab("pintura", Vector3(x0, 0.0, hondo), Vector3(x1, 0.03, -FONDO), Color(0.3, 0.29, 0.26))
	_caja_ab("ladrillo", Vector3(x0 - 0.12, 0.0, hondo), Vector3(x0 + 0.12, 2.2, -FONDO), tinte.darkened(0.15))
	_caja_ab("ladrillo", Vector3(x0, 0.0, hondo - 0.24), Vector3(x1, 2.2, hondo), tinte.darkened(0.15))
	var rx := x1 - 1.5 if izq else x0 + 0.3
	_caja_ab("pintura", Vector3(rx, 0.0, hondo + 0.05), Vector3(rx + 1.2, 2.0, hondo + 1.3), Color(0.4, 0.33, 0.25))
	_extruir("tejado", PackedVector2Array([Vector2(hondo, 2.3), Vector2(hondo + 1.45, 2.0),
		Vector2(hondo + 1.45, 1.92), Vector2(hondo, 2.22)]), rx - 0.1, rx + 1.3, 0, _e["teja"])
	# tonel del agua de lluvia
	_cilindro("pintura", Vector3(wx1 + 0.45 if izq else wx0 - 0.45, 0.0, -FONDO - 0.5), 0.32, 0.32, 0.9, 8,
		Color(0.35, 0.25, 0.16))


## Cubierta de cada casa; las medianeras y chimeneas van luego, a la par de la vecina.
func _cubierta(c: Dictionary, yt: float) -> void:
	var x0: float = c["x0"]
	var x1: float = c["x1"]
	var col: Color = _e["teja"]
	match String(c["cubierta"]):
		"m":
			# cubierta en M de Londres: dos limas, oculta tras el pretil
			var hr := 1.7
			var perfil := PackedVector2Array([Vector2(-MURO, yt), Vector2(-MURO, yt + 0.2), Vector2(-FONDO * 0.25, yt + hr),
				Vector2(-FONDO * 0.5, yt + 0.2), Vector2(-FONDO * 0.75, yt + hr), Vector2(-FONDO + MURO, yt + 0.2),
				Vector2(-FONDO + MURO, yt)])
			_extruir("tejado", perfil, x0, x1, 0, col)
		"aguas":
			var hr := 2.6
			var perfil := PackedVector2Array([Vector2(-MURO, yt), Vector2(-MURO, yt + 0.25),
				Vector2(-FONDO * 0.5, yt + hr), Vector2(-FONDO + MURO, yt + 0.25), Vector2(-FONDO + MURO, yt)])
			_extruir("tejado", perfil, x0, x1, 0, col)
			for i in int(c["buhardas"]):
				var xb := lerpf(x0, x1, (float(i) + 1.0) / (float(c["buhardas"]) + 1.0))
				_buharda(xb, yt + 0.65, -1.2, false)
		"teja":
			var hr := 3.8
			var perfil := PackedVector2Array([Vector2(0.55, yt + 0.32), Vector2(0.55, yt + 0.4),
				Vector2(-FONDO * 0.5, yt + hr), Vector2(-FONDO - 0.4, yt + 0.4), Vector2(-FONDO - 0.4, yt + 0.32),
				Vector2(-FONDO * 0.5, yt + 0.3)])
			_extruir("tejado", perfil, x0, x1, 0, col)
			for i in int(c["buhardas"]):
				var xb := lerpf(x0, x1, (float(i) + 1.0) / (float(c["buhardas"]) + 1.0))
				_buharda(xb, yt + 1.35, -1.0, true)


## Buhardilla: cajón con ventana y tejadillo a dos aguas (o plomo plano).
func _buharda(x: float, y0: float, z: float, aguas: bool) -> void:
	var w := 1.15
	var h := 1.45
	var fondo := 2.2
	var col := BLANCO.darkened(0.1) if aguas else Color(0.32, 0.33, 0.35)
	_caja_ab("pintura", Vector3(x - w * 0.5, y0 - 0.6, z - fondo), Vector3(x + w * 0.5, y0 + h, z), col)
	_caja("vidrio", Vector3(x, y0 + h * 0.48, z + 0.01), Vector3(w - 0.3, h - 0.4, 0.02))
	_caja("fino", Vector3(x, y0 + h * 0.48, z + 0.03), Vector3(0.04, h - 0.4, 0.03), BLANCO)
	_caja("fino", Vector3(x, y0 + h * 0.48, z + 0.03), Vector3(w - 0.3, 0.04, 0.03), BLANCO)
	if aguas:
		_extruir("tejado", PackedVector2Array([Vector2(x - w * 0.5 - 0.12, y0 + h), Vector2(x + w * 0.5 + 0.12, y0 + h),
			Vector2(x, y0 + h + 0.6)]), z - fondo, z + 0.12, 2, _e["teja"])
	else:
		_caja_ab("pintura", Vector3(x - w * 0.5 - 0.08, y0 + h, z - fondo), Vector3(x + w * 0.5 + 0.08, y0 + h + 0.1, z + 0.1),
			Color(0.42, 0.44, 0.46))


## Medianera cortafuegos que asoma sobre la cubierta, con su chimenea y cañones.
func _medianera(x: float, izq: Dictionary, der: Dictionary) -> void:
	var alta: Dictionary = izq if (der.is_empty() or (not izq.is_empty() and _altura(izq) >= _altura(der))) else der
	var otra: Dictionary = der if alta == izq else izq
	var yt := _altura(alta)
	var abajo := (SOTANO if bool(alta["sotano"]) else 0.0) if otra.is_empty() else minf(yt, _altura(otra)) - 0.3
	var tinte: Color = alta["tinte"]
	var perfil: PackedVector2Array
	var zc := -FONDO * 0.25
	match String(alta["cubierta"]):
		"m":
			perfil = [Vector2(-MURO, abajo), Vector2(-MURO, yt + float(_e["pretil"])), Vector2(-FONDO * 0.25, yt + 2.0),
				Vector2(-FONDO * 0.5, yt + 0.6), Vector2(-FONDO * 0.75, yt + 2.0), Vector2(-FONDO + MURO, yt + 0.6),
				Vector2(-FONDO + MURO, abajo)]
		"aguas":
			zc = -FONDO * 0.5
			perfil = [Vector2(-MURO, abajo), Vector2(-MURO, yt + float(_e["pretil"])), Vector2(-FONDO * 0.5, yt + 2.9),
				Vector2(-FONDO + MURO, yt + 0.55), Vector2(-FONDO + MURO, abajo)]
		_:
			zc = -FONDO * 0.5
			perfil = [Vector2(0.0, abajo), Vector2(0.0, yt + 0.6), Vector2(-FONDO * 0.5, yt + 4.1),
				Vector2(-FONDO, yt + 0.6), Vector2(-FONDO, abajo)]
	_extruir("ladrillo", perfil, x - 0.2, x + 0.2, 0, tinte.darkened(0.08))
	# chimenea sobre la medianera: cuerpo, cornisa de ladrillo volado y cañones
	var base := yt + (2.0 if alta["cubierta"] == "m" else (2.9 if alta["cubierta"] == "aguas" else 4.1)) - 0.6
	var alto := 1.9
	var largo := 2.0
	_caja_ab("ladrillo", Vector3(x - 0.48, base, zc - largo * 0.5), Vector3(x + 0.48, base + alto, zc + largo * 0.5), tinte.darkened(0.15))
	_caja_ab("ladrillo", Vector3(x - 0.56, base + alto - 0.32, zc - largo * 0.5 - 0.08),
		Vector3(x + 0.56, base + alto - 0.16, zc + largo * 0.5 + 0.08), tinte.darkened(0.2))
	_caja_ab("pintura", Vector3(x - 0.52, base + alto, zc - largo * 0.5 - 0.04),
		Vector3(x + 0.52, base + alto + 0.1, zc + largo * 0.5 + 0.04), PIEDRA.darkened(0.2))
	var cuantos := _rng.randi_range(3, 6)
	for i in cuantos:
		var z := zc - largo * 0.5 + 0.25 + (largo - 0.5) * float(i) / float(maxi(1, cuantos - 1))
		var h := _rng.randf_range(0.42, 0.78)
		var col := TERRACOTA.lerp(Color(0.72, 0.6, 0.45), _rng.randf() * 0.6)
		var xo := _rng.randf_range(-0.12, 0.12)
		_cilindro("pintura", Vector3(x + xo, base + alto + 0.1, z), 0.14, 0.11, h, 6, col)
		_cilindro("pintura", Vector3(x + xo, base + alto + 0.1 + h, z), 0.15, 0.15, 0.07, 6, col.darkened(0.1))


func _hilera(casas: Array) -> void:
	for c in casas:
		_casa(c)
	for i in casas.size() + 1:
		var izq: Dictionary = casas[i - 1] if i > 0 else {}
		var der: Dictionary = casas[i] if i < casas.size() else {}
		var x: float = izq["x1"] if not izq.is_empty() else der["x0"]
		_medianera(x, izq, der)


## Muestra colgada de una ménsula de hierro, de canto a la calle.
func _muestra(x: float, y: float) -> void:
	_caja_ab("hierro_fino", Vector3(x - 0.02, y + 0.6, 0.0), Vector3(x + 0.02, y + 0.64, 1.1))
	_caja_ab("hierro_fino", Vector3(x - 0.015, y + 0.1, 0.0), Vector3(x + 0.015, y + 0.62, 0.04))
	for z in [0.35, 0.95]:
		_caja("hierro_fino", Vector3(x, y + 0.52, z), Vector3(0.015, 0.16, 0.015))
	_caja("pintura", Vector3(x, y + 0.15, 0.65), Vector3(0.06, 0.62, 0.78), ORO.darkened(0.25))
	_caja("pintura", Vector3(x, y + 0.15, 0.65), Vector3(0.08, 0.5, 0.66), Color(0.1, 0.13, 0.3))
	# un mortero dorado pintado en cada cara
	for lado in [-1.0, 1.0]:
		_caja("fino", Vector3(x + float(lado) * 0.045, y + 0.1, 0.65), Vector3(0.01, 0.18, 0.24), ORO)
		_caja("fino", Vector3(x + float(lado) * 0.045, y + 0.25, 0.7), Vector3(0.01, 0.2, 0.04), ORO)


# ---------------------------------------------------------------- la calle

func _suelo() -> void:
	var x0 := -70.0
	var x1 := 70.0
	_caja_ab("pintura", Vector3(-160, -0.6, -160), Vector3(160, -0.3, 160), Color(0.2, 0.19, 0.17))
	# acera: tira de fuera y, donde no hay foso, también la de dentro
	_caja_ab("acera", Vector3(x0, -0.3, PATIO + 0.25), Vector3(x1, 0.0, ACERA))
	var tramos: Array[Vector2] = [Vector2(x0, _xa)]
	tramos.append_array(_sin_patio)
	tramos.append(Vector2(_xb, x1))
	for t in tramos:
		_caja_ab("acera", Vector3(t.x, -0.3, 0.0), Vector3(t.y, 0.0, PATIO + 0.25))
	# bordillo de granito, calzada de adoquín y acera de enfrente
	_caja_ab("pintura", Vector3(x0, -0.3, ACERA), Vector3(x1, 0.0, ACERA + 0.3), GRANITO)
	_caja_ab("calzada", Vector3(x0, -0.3, ACERA + 0.3), Vector3(x1, -ALTO_BORDILLO, ACERA + 0.3 + CALZADA))
	_caja_ab("pintura", Vector3(x0, -0.3, ACERA + 0.3 + CALZADA), Vector3(x1, 0.0, ACERA + 0.6 + CALZADA), GRANITO)
	_caja_ab("acera", Vector3(x0, -0.3, ACERA + 0.6 + CALZADA), Vector3(x1, 0.0, ACERA + 3.6 + CALZADA))
	# trampilla de bodega frente a una tienda, de madera con flejes
	if not _sin_patio.is_empty():
		var t: Vector2 = _sin_patio[0]
		_caja_ab("pintura", Vector3(t.x + 0.6, 0.0, 1.2), Vector3(t.x + 1.8, 0.02, 2.0), Color(0.3, 0.22, 0.14))
		_caja_ab("hierro", Vector3(t.x + 0.6, 0.02, 1.58), Vector3(t.x + 1.8, 0.03, 1.62))


## Farola de hierro colado: basa, fuste, travesaño para la escalera y farol de cuatro caras.
func _farola(x: float, z: float) -> void:
	var p := Vector3(x, 0.0, z)
	_cilindro("hierro", p, 0.2, 0.17, 0.55, 8, Color.WHITE, PI / 8.0)
	_cilindro("hierro", p + Vector3.UP * 0.55, 0.11, 0.07, 0.25, 8, Color.WHITE, PI / 8.0)
	_cilindro("hierro", p + Vector3.UP * 0.8, 0.065, 0.055, 2.05, 8, Color.WHITE)
	_cilindro("hierro", p + Vector3.UP * 2.82, 0.09, 0.09, 0.1, 8, Color.WHITE)
	_caja("hierro", p + Vector3(0, 2.72, 0), Vector3(0.7, 0.05, 0.05))
	_cilindro("farol", p + Vector3.UP * 2.95, 0.13, 0.2, 0.46, 4, Color.WHITE, PI * 0.25)
	_cilindro("hierro", p + Vector3.UP * 2.91, 0.15, 0.15, 0.05, 4, Color.WHITE, PI * 0.25)
	_cilindro("hierro", p + Vector3.UP * 3.41, 0.25, 0.05, 0.22, 4, Color.WHITE, PI * 0.25)
	_cilindro("hierro", p + Vector3.UP * 3.63, 0.03, 0.0, 0.14, 4, Color.WHITE)
	var luz := OmniLight3D.new()
	luz.light_color = Color(0.5, 1, 0.42)
	luz.light_energy = 4.2
	luz.omni_range = 5.2
	luz.omni_attenuation = 2.0
	luz.light_specular = 0.0
	_bloque.add_child(luz)
	luz.position = p + Vector3.UP * 3.15
	_luces.append(luz)


func _figura(p: Vector3) -> void:
	var f := (load(FIGURA) as PackedScene).instantiate() as Node3D
	_bloque.add_child(f)
	f.position = p
	f.rotation.y = 0.5


# ---------------------------------------------------------------- más allá

## Hileras sencillas que siguen la calle y se pierden en la niebla.
func _fondo() -> void:
	_hilera_simple(-62.0, _xa, 0.0, 1.0, true)
	_hilera_simple(_xb, 62.0, 0.0, 1.0, true)
	# callejón entre los patios y las traseras de la calle de atrás
	_caja_ab("pintura", Vector3(-70, -0.3, -FONDO - 12.0), Vector3(70, 0.01, -FONDO - 8.7), Color(0.32, 0.31, 0.28))
	# traseras de la calle de atrás y tejados más lejos
	_hilera_simple(-62.0, 62.0, -FONDO - 12.0, 1.0, false)
	_hilera_simple(-70.0, 70.0, -FONDO - 36.0, 1.0, false)
	# la acera de enfrente, lejos detrás de la cámara de juego
	_hilera_simple(-62.0, 62.0, ACERA + CALZADA + 19.0, -1.0, false)


## Casas de pocas piezas: caja, ventanas planas, pretil, cubierta y una chimenea.
func _hilera_simple(x0: float, x1: float, zf: float, mira: float, con_bajo: bool) -> void:
	var x := x0
	var fondo := 8.0
	while x < x1 - 1.0:
		var w := minf(_rng.randf_range(4.4, 6.0), x1 - x)
		var pisos := _rng.randi_range(3, 4)
		var h := 3.2 + 2.9 * float(pisos - 1)
		var tinte := Color(1, 1, 1).darkened(_rng.randf_range(0.0, 0.25))
		if _rng.randf() < 0.3:
			tinte = Color(1.0, 0.8, 0.7).darkened(_rng.randf_range(0.0, 0.2))
		var za := zf if mira > 0.0 else zf + fondo
		var zb := zf - fondo if mira > 0.0 else zf
		_caja_ab("ladrillo", Vector3(x, 0.0, minf(za, zb)), Vector3(x + w, h + 0.8, maxf(za, zb)), tinte)
		_caja_ab("pintura", Vector3(x - 0.02, h + 0.8, minf(za, zb) - 0.04), Vector3(x + w + 0.02, h + 0.9, maxf(za, zb) + 0.04), PIEDRA.darkened(0.15))
		# cubierta en M asomando y chimenea en la medianera
		_extruir("tejado", PackedVector2Array([Vector2(zb + 0.3, h + 0.8), Vector2((za + zb) * 0.5, h + 2.4),
			Vector2(za - 0.3, h + 0.8)]), x + 0.2, x + w - 0.2, 0, _e["teja"])
		var zc := (za + zb) * 0.5 + _rng.randf_range(-1.5, 1.5)
		_caja_ab("ladrillo", Vector3(x - 0.4, h + 0.8, zc - 0.9), Vector3(x + 0.4, h + 3.2, zc + 0.9), tinte.darkened(0.2))
		for i in _rng.randi_range(2, 4):
			_cilindro("pintura", Vector3(x, h + 3.2, zc - 0.6 + 0.4 * float(i)), 0.13, 0.11, 0.55, 6, TERRACOTA)
		# imposta de piedra sobre el bajo
		_caja("pintura", Vector3(x + w * 0.5, 3.2, zf + mira * 0.03), Vector3(w, 0.16, 0.06), PIEDRA.darkened(0.1))
		# ventanas: cristal con alféizar; alguna encendida
		var n := 3 if w > 5.0 else 2
		var zv := zf + mira * 0.02
		for p in pisos:
			var yv := 0.9 + (3.2 if p > 0 else 0.0) + 2.9 * float(maxi(0, p - 1))
			if p == 0 and not con_bajo:
				continue
			for i in n:
				var xv := x + w * (float(i) + 0.5) / float(n)
				if p == 0 and i == n / 2:
					_caja("pintura", Vector3(xv, 1.15, zv), Vector3(1.0, 2.3, 0.04), Color(0.14, 0.12, 0.1))
					continue
				var hv := 1.7 if p < 2 else 1.4
				_caja("pintura", Vector3(xv, yv + hv * 0.5, zv), Vector3(1.0, hv + 0.1, 0.03), BLANCO.darkened(0.2))
				_caja("luz" if _rng.randf() < 0.2 else "vidrio", Vector3(xv, yv + hv * 0.5, zv + mira * 0.02), Vector3(0.82, hv - 0.08, 0.02))
				_caja("pintura", Vector3(xv, yv - 0.04, zv + mira * 0.06), Vector3(1.1, 0.08, 0.12), PIEDRA)
				# montante y peinazo: basta para leer una guillotina de lejos
				_caja("fino", Vector3(xv, yv + hv * 0.5, zv + mira * 0.04), Vector3(0.05, hv - 0.08, 0.02), BLANCO.darkened(0.2))
				_caja("fino", Vector3(xv, yv + hv * 0.5, zv + mira * 0.04), Vector3(0.82, 0.06, 0.02), BLANCO.darkened(0.2))
		x += w
