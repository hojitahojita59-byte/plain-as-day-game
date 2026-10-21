@tool
extends RefCounted
## Casas de Soho fundidas en pocas mallas: una por material y trozo de calle.
## Coords. de casa (xf): x a lo largo, y arriba, z hacia la calle; fachada en z = 0.

const TROZO := 24.0
## Capa que la cámara de juego no pinta: acera de enfrente y lo de más allá.
const CAPA_CINE := 1 << 10

const MURO := 0.3
const FONDO := 5.0
const PATIO := 1.0
const SOTANO := -2.4
const FUENTE := "res://art/fonts/EB_Garamond/static/EBGaramond-SemiBold.ttf"

## Hueco de la puerta de verdad: la hoja (hoja_abrible) va 0,375 por detrás.
const PUERTA_ANCHO := 1.3
const PUERTA_ALTO := 2.5
const MONTANTE_ARRIBA := 3.15
## Centro del número en el montante, y su fondo (casi a ras: la cámara mira de arriba).
const Y_NUMERO := 2.84
const Z_NUMERO := -0.085

const BLANCO := Color(0.9, 0.88, 0.82)
const PIEDRA := Color(0.66, 0.64, 0.58)
const ESTUCO := Color(0.88, 0.84, 0.74)
const TERRACOTA := Color(0.62, 0.36, 0.24)
const PIZARRA := Color(0.36, 0.38, 0.42)
const TEJA := Color(0.62, 0.33, 0.24)
const LATON := Color(0.8, 0.62, 0.3)
const ORO := Color(0.95, 0.8, 0.42)
const HIERRO := Color(0.07, 0.07, 0.08)
const GRANITO := Color(0.78, 0.78, 0.8)

## Sin contorno: piezas finas (el casco invertido las engorda) y lo plano.
const SIN_CONTORNO: PackedStringArray = ["fino", "vidrio", "luz", "acera", "calzada"]
const SIN_SOMBRA: PackedStringArray = ["fino", "vidrio", "luz", "acera", "calzada"]

## Ladrillo en mundo: aparejo flamenco y hollín. Vértice: tinte y hollín (alfa >= 0,5);
## alfa < 0,5 = ladrillo frotado del color del vértice.
const FABRICA := "shader_type spatial;
render_mode diffuse_burley;
uniform vec3 color_a : source_color = vec3(0.74, 0.6, 0.46);
uniform vec3 color_junta : source_color = vec3(0.58, 0.56, 0.51);
uniform vec2 pieza = vec2(0.115, 0.076);
uniform float junta = 0.01;
uniform float flamenco = 1.0;
uniform float variacion = 0.16;
uniform float hollin = 0.6;
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
	bool frotado = COLOR.a < 0.5;
	vec3 base = frotado ? COLOR.rgb : (tizon ? color_a * vec3(0.8, 0.82, 0.86) : color_a) * COLOR.rgb;
	float sucio = frotado ? COLOR.a * 2.0 : (COLOR.a - 0.5) * 2.0;
	vec3 ladrillo = base * (1.0 + (id - 0.5) * 2.0 * variacion);
	vec3 media = mix(color_junta, base, 0.8);
	float cerca = clamp(1.0 - w / (pieza.y * 0.7), 0.0, 1.0);
	vec3 c = mix(media, mix(color_junta, ladrillo, mortero), cerca);
	float s = hollin * sucio * (0.5 * ruido(q * vec2(0.8, 0.2)) + 0.3 * smoothstep(1.0, 13.0, pm.y) + 0.2 * ruido(q * 3.1));
	ALBEDO = c * (1.0 - clamp(s, 0.0, 0.85));
	ROUGHNESS = 0.95;
	SPECULAR = 0.2;
}"

## Pizarra o teja por hiladas en mundo; el color sale del vértice.
const CUBIERTA := "shader_type spatial;
render_mode diffuse_burley;
uniform float hilada = 0.16;
uniform float ancho = 0.28;
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

## Losas y adoquines; `cruzado` tiende las hiladas de través. El vértice tiñe.
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
	ALBEDO = mix(mix(color_junta, color_piedra, 0.75), mix(color_junta, piedra, mortero), cerca) * COLOR.rgb;
	ROUGHNESS = 0.9;
	SPECULAR = 0.2;
}"

## Lo que se ve de la calle: tiendas con rótulo, y oficios para variar.
const OFICIOS: PackedStringArray = ["DAIRY", "BAKER", "CHEESEMONGER", "TAILOR", "CHEMIST", "COFFEE ROOMS",
	"OIL & COLOUR", "TOBACCONIST", "CHANDLER", "BUTCHER", "GROCER", "BOOTMAKER", "PAWNBROKER",
	"IRONMONGER", "WINE & SPIRITS", "HATTER", "CORN DEALER", "STATIONER", "EATING HOUSE", "DRAPER"]
const COLORES_TIENDA: Array[Color] = [Color(0.12, 0.3, 0.2), Color(0.36, 0.08, 0.07), Color(0.1, 0.13, 0.3),
	Color(0.08, 0.08, 0.08), Color(0.7, 0.62, 0.42), Color(0.2, 0.24, 0.16), Color(0.3, 0.18, 0.1)]
## Tonos claros: con la niebla verde de noche, el lazo negro tiene que destacar sobre la puerta.
const COLORES_PUERTA: Array[Color] = [Color(0.34, 0.56, 0.4), Color(0.74, 0.27, 0.2), Color(0.32, 0.42, 0.68),
	Color(0.68, 0.48, 0.28), Color(0.76, 0.7, 0.56), Color(0.36, 0.56, 0.56)]

var xf := Transform3D.IDENTITY
## Lo que se crea mientras está a true va a la capa de cine.
var cine := false
var rng := RandomNumberGenerator.new()
var fuente: Font
## Fosos de sótano en mundo (Rect2 en x, z), para agujerear la acera.
var fosos: Array[Rect2] = []

var _lotes: Dictionary = {}
var _mats: Dictionary = {}
var _trozo := ""
var _raiz_rotulos: Node3D


func _init(rotulos: Node3D) -> void:
	_raiz_rotulos = rotulos
	fuente = load(FUENTE) as Font
	_materiales()


# ---------------------------------------------------------------- materiales

func material(k: String) -> Material:
	return _mats[k]


func _materiales() -> void:
	var lad := ShaderMaterial.new()
	lad.shader = _shader(FABRICA)
	_mats["ladrillo"] = lad

	# estuco y sillería: sillares grandes, juntas finas, poco hollín
	var est := ShaderMaterial.new()
	est.shader = lad.shader
	est.set_shader_parameter("color_a", Color(0.92, 0.88, 0.78))
	est.set_shader_parameter("color_junta", Color(0.5, 0.47, 0.42))
	est.set_shader_parameter("pieza", Vector2(0.6, 0.42))
	est.set_shader_parameter("junta", 0.012)
	est.set_shader_parameter("flamenco", 0.0)
	est.set_shader_parameter("variacion", 0.03)
	est.set_shader_parameter("hollin", 0.35)
	_mats["estuco"] = est

	var tej := ShaderMaterial.new()
	tej.shader = _shader(CUBIERTA)
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

	# como ventana_encendida.tscn
	var luz := StandardMaterial3D.new()
	luz.albedo_color = Color(0.5, 0.33, 0.14)
	luz.emission_enabled = true
	luz.emission = Color(1, 0.7, 0.33)
	luz.emission_energy_multiplier = 1.1
	luz.roughness = 1.0
	_mats["luz"] = luz

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
	cal.set_shader_parameter("pieza", Vector2(0.18, 0.3))
	cal.set_shader_parameter("junta", 0.018)
	cal.set_shader_parameter("variacion", 0.22)
	cal.set_shader_parameter("abombado", 0.5)
	_mats["calzada"] = cal
	# la de las calles que bajan: hiladas de través al otro eje
	var cal_z := cal.duplicate() as ShaderMaterial
	cal_z.set_shader_parameter("cruzado", 0.0)
	_mats["calzada_z"] = cal_z


var _shaders: Dictionary = {}


func _shader(codigo: String) -> Shader:
	if not _shaders.has(codigo):
		var s := Shader.new()
		s.code = codigo
		_shaders[codigo] = s
	return _shaders[codigo]


# ---------------------------------------------------------------- lotes

## Trozo de calle según el punto (mundo); lo siguiente cae en él.
func empezar(punto: Vector3) -> void:
	_trozo = "%s%d_%d" % ["c" if cine else "j", int(floor(punto.x / TROZO)), int(floor(punto.z / TROZO))]


## Trozo con nombre propio: lo enorme (el suelo) va solo, que cada luz no repinte casas.
func trozo(nombre: String) -> void:
	_trozo = ("c" if cine else "j") + nombre


## Una MeshInstance3D por trozo y material, colgadas de `raiz`.
func cerrar(raiz: Node3D) -> void:
	for clave in _lotes:
		var partes := String(clave).split("|")
		var k := partes[1]
		var st := _lotes[clave] as SurfaceTool
		var m := MeshInstance3D.new()
		m.name = "%s_%s" % [partes[0], k]
		m.mesh = st.commit()
		m.material_override = _mats[k]
		if k in SIN_CONTORNO:
			m.set_meta(&"sin_contorno", true)
		var de_cine := partes[0].begins_with("c")
		if k in SIN_SOMBRA or de_cine:
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if de_cine:
			m.layers = CAPA_CINE
		raiz.add_child(m)
	_lotes.clear()


func _st(k: String) -> SurfaceTool:
	var clave := _trozo + "|" + k
	if not _lotes.has(clave):
		var s := SurfaceTool.new()
		s.begin(Mesh.PRIMITIVE_TRIANGLES)
		_lotes[clave] = s
	return _lotes[clave]


# ---------------------------------------------------------------- geometría

## Triángulo en coords. de casa; Godot quiere el frente en sentido horario.
func tri(k: String, a: Vector3, b: Vector3, c: Vector3, n: Vector3, col: Color) -> void:
	var s := _st(k)
	var wa := xf * a
	var wb := xf * b
	var wc := xf * c
	var wn := (xf.basis * n).normalized()
	if (wb - wa).cross(wc - wa).dot(wn) > 0.0:
		var t := wb
		wb = wc
		wc = t
	for v in [wa, wb, wc]:
		s.set_color(col)
		s.set_normal(wn)
		s.add_vertex(v)


func quad(k: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3, col: Color) -> void:
	tri(k, a, b, c, n, col)
	tri(k, a, c, d, n, col)


const _EJES: Array[Vector3] = [Vector3.RIGHT, Vector3.UP, Vector3.BACK]


func caja(k: String, centro: Vector3, tam: Vector3, col: Color = Color.WHITE, base: Basis = Basis.IDENTITY) -> void:
	var h := tam * 0.5
	for i in 3:
		var j := (i + 1) % 3
		var l := (i + 2) % 3
		for sig in [-1.0, 1.0]:
			var n: Vector3 = _EJES[i] * float(sig)
			var c0: Vector3 = n * h[i]
			var ej: Vector3 = _EJES[j] * h[j]
			var el: Vector3 = _EJES[l] * h[l]
			quad(k, centro + base * (c0 - ej - el), centro + base * (c0 + ej - el),
				centro + base * (c0 + ej + el), centro + base * (c0 - ej + el), base * n, col)


## Cara sola mirando a +z: junquillos y barrotes, que de canto no se ven.
func placa(k: String, centro: Vector3, ancho: float, alto: float, col: Color) -> void:
	var x := Vector3(ancho * 0.5, 0, 0)
	var y := Vector3(0, alto * 0.5, 0)
	quad(k, centro - x - y, centro + x - y, centro + x + y, centro - x + y, Vector3.BACK, col)


## Barrote vertical: cuatro caras, sin tapas.
func barra(k: String, centro: Vector3, tam: Vector3, col: Color) -> void:
	var h := tam * 0.5
	var p := [Vector3(-h.x, 0, -h.z), Vector3(h.x, 0, -h.z), Vector3(h.x, 0, h.z), Vector3(-h.x, 0, h.z)]
	var normales := [Vector3.FORWARD, Vector3.RIGHT, Vector3.BACK, Vector3.LEFT]
	for i in 4:
		var a: Vector3 = centro + p[i]
		var b: Vector3 = centro + p[(i + 1) % 4]
		quad(k, a - Vector3.UP * h.y, b - Vector3.UP * h.y, b + Vector3.UP * h.y, a + Vector3.UP * h.y, normales[i], col)


func caja_ab(k: String, a: Vector3, b: Vector3, col: Color = Color.WHITE) -> void:
	caja(k, (a + b) * 0.5, (b - a).abs(), col)


func cilindro(k: String, pie: Vector3, r0: float, r1: float, alto: float, lados: int,
		col: Color, giro: float = 0.0) -> void:
	for i in lados:
		var a0 := giro + TAU * float(i) / float(lados)
		var a1 := giro + TAU * float(i + 1) / float(lados)
		var d0 := Vector3(cos(a0), 0.0, sin(a0))
		var d1 := Vector3(cos(a1), 0.0, sin(a1))
		var n := ((d0 + d1) * 0.5).normalized()
		n.y = (r0 - r1) / alto * 0.5
		quad(k, pie + d0 * r0, pie + d1 * r0, pie + d1 * r1 + Vector3.UP * alto,
			pie + d0 * r1 + Vector3.UP * alto, n.normalized(), col)
		if r1 > 0.0:
			tri(k, pie + Vector3.UP * alto, pie + d0 * r1 + Vector3.UP * alto,
				pie + d1 * r1 + Vector3.UP * alto, Vector3.UP, col)


func _p3(u: Vector2, w: float, eje: int) -> Vector3:
	return Vector3(w, u.y, u.x) if eje == 0 else Vector3(u.x, u.y, w)


## Prisma de un perfil 2D extruido de a a b. eje 0: perfil (z, y) a lo largo de x;
## eje 2: perfil (x, y) a lo largo de z.
func extruir(k: String, perfil: PackedVector2Array, a: float, b: float, eje: int, col: Color) -> void:
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
		if d.length() < 0.0001:
			continue
		var fuera := Vector2(d.y, -d.x) if area > 0.0 else Vector2(-d.y, d.x)
		quad(k, _p3(p, a, eje), _p3(q, a, eje), _p3(q, b, eje), _p3(p, b, eje),
			_p3(fuera.normalized(), 0.0, eje), col)
	var idx := Geometry2D.triangulate_polygon(perfil)
	var tapa := Vector3.RIGHT if eje == 0 else Vector3.BACK
	for t in range(0, idx.size(), 3):
		var u0 := perfil[idx[t]]
		var u1 := perfil[idx[t + 1]]
		var u2 := perfil[idx[t + 2]]
		tri(k, _p3(u0, a, eje), _p3(u1, a, eje), _p3(u2, a, eje), -tapa, col)
		tri(k, _p3(u0, b, eje), _p3(u1, b, eje), _p3(u2, b, eje), tapa, col)


## Lo que queda de un rectángulo quitándole huecos, en rectángulos.
static func rellenar(r: Rect2, huecos: Array) -> Array[Rect2]:
	var out: Array[Rect2] = []
	var cortes: Array[float] = [r.position.x, r.end.x]
	for h: Rect2 in huecos:
		for x in [h.position.x, h.end.x]:
			if x > r.position.x and x < r.end.x:
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
			if h.position.x <= mid and h.end.x >= mid and h.end.y > r.position.y and h.position.y < r.end.y:
				tapados.append(Vector2(maxf(h.position.y, r.position.y), minf(h.end.y, r.end.y)))
		tapados.sort_custom(func(p: Vector2, q: Vector2) -> bool: return p.x < q.x)
		var y := r.position.y
		for t in tapados:
			if t.x > y + 0.001:
				out.append(Rect2(a, y, b - a, t.x - y))
			y = maxf(y, t.y)
		if y < r.end.y - 0.001:
			out.append(Rect2(a, y, b - a, r.end.y - y))
	return out


## Muro con huecos (Rect2 en x, y) entre z0 y z0 - grosor.
func muro(k: String, x0: float, x1: float, y0: float, y1: float, huecos: Array,
		col: Color = Color.WHITE, z0: float = 0.0, grosor: float = MURO) -> void:
	for r in rellenar(Rect2(x0, y0, x1 - x0, y1 - y0), huecos):
		caja_ab(k, Vector3(r.position.x, r.position.y, z0 - grosor), Vector3(r.end.x, r.end.y, z0), col)


func rotulo(texto: String, pos: Vector3, tam: int, color: Color, contorno: int = 10) -> Label3D:
	var l := Label3D.new()
	l.text = texto
	l.font = fuente
	l.font_size = tam
	l.pixel_size = 0.003
	l.modulate = color
	l.outline_modulate = Color(0.14, 0.09, 0.05)
	l.outline_size = contorno
	l.double_sided = false
	l.shaded = false
	if cine:
		l.layers = CAPA_CINE
	_raiz_rotulos.add_child(l)
	l.transform = xf * Transform3D(Basis.IDENTITY, pos)
	return l


## Color de vértice del ladrillo: tinte y hollín (0..1); frotado = color tal cual.
static func ladrillo(tinte: Color, hollin: float, frotado: bool = false) -> Color:
	return Color(tinte.r, tinte.g, tinte.b, hollin * 0.49 if frotado else 0.5 + hollin * 0.5)


# ---------------------------------------------------------------- estilos

## Casa al azar de un estilo: A ladrillo londinense sobrio, B tienda, C estuco y teja.
## Ancho en metros (x0 = -ancho/2). `bajo` decide la planta baja.
func plantilla(estilo: String, ancho: float, bajo: String, pisos_max: int = 4, pisos_min: int = 3) -> Dictionary:
	var n := rng.randi_range(mini(pisos_min, pisos_max), pisos_max)
	var pisos: Array = [3.6 if bajo == "tienda" else 3.4, 3.1, 2.8, 2.4].slice(0, n)
	var c := {"x0": -ancho * 0.5, "x1": ancho * 0.5, "pisos": pisos, "estilo": estilo, "bajo": bajo,
		"puerta_color": COLORES_PUERTA[rng.randi() % COLORES_PUERTA.size()], "sotano": false,
		"buhardas": 0, "revoco": false, "balcon": false, "detalle": true}
	match estilo:
		"A":
			c["tinte"] = ladrillo(Color(0.9, 0.9, 0.82).darkened(rng.randf_range(0.0, 0.12)), rng.randf_range(0.7, 1.0))
			c["cubierta"] = "pretil"
			c["balcon"] = rng.randf() < 0.5
		"B":
			var tintes: Array[Color] = [Color(1.0, 0.72, 0.66), Color(0.9, 0.9, 0.82), Color(0.72, 0.62, 0.58),
				Color(0.86, 0.84, 0.82), Color(1.0, 0.82, 0.7)]
			c["tinte"] = ladrillo(tintes[rng.randi() % tintes.size()], rng.randf_range(0.4, 0.8))
			c["cubierta"] = "buhardas"
			c["buhardas"] = rng.randi_range(0, 2)
			c["revoco"] = rng.randf() < 0.18
		_:
			c["tinte"] = ladrillo(Color(0.7, 0.6, 0.56).darkened(rng.randf_range(0.0, 0.1)), rng.randf_range(0.4, 0.7))
			c["cubierta"] = "teja"
			c["buhardas"] = rng.randi_range(1, 2)
			c["pisos"] = [3.4, 3.2, 2.9, 2.5].slice(0, n)
	if bajo == "tienda":
		c["tienda"] = {"color": COLORES_TIENDA[rng.randi() % COLORES_TIENDA.size()],
			"texto": OFICIOS[rng.randi() % OFICIOS.size()]}
	return c


static func altura(c: Dictionary) -> float:
	var s := 0.0
	for h in Array(c["pisos"]):
		s += float(h)
	return s


static func pretil(c: Dictionary) -> float:
	match String(c["estilo"]):
		"A", "asilo":
			return 0.9
		"cerveceria":
			return 1.1
		"C":
			return 0.0
	return 0.6


static func cumbrera(c: Dictionary) -> float:
	match String(c["cubierta"]):
		"teja":
			return 3.0
		"buhardas":
			return 2.3
	return 1.5


# ---------------------------------------------------------------- la casa

## Casa entera en las coords. de xf.
func casa(c: Dictionary) -> void:
	var x0: float = c["x0"]
	var x1: float = c["x1"]
	var xm := (x0 + x1) * 0.5
	var ancho := x1 - x0
	var pisos: Array = c["pisos"]
	var yt := altura(c)
	var estilo := String(c["estilo"])
	var pret := pretil(c)
	var sotano := bool(c.get("sotano", false))
	var tinte: Color = c["tinte"]
	var bajo := String(c["bajo"])
	var revoco := bool(c.get("revoco", false))
	var y_base := SOTANO if sotano else 0.0
	var huecos: Array = []
	var bajos: Array = []
	var n := maxi(1, int(round(ancho / 1.66)))

	# planta baja
	match bajo:
		"tienda":
			_tienda(c, bajos)
		"puerta", "puerta_falsa":
			var xd: float = c.get("puerta_x", xm)
			portal(xd, c, bajos, bajo == "puerta_falsa")
			for i in n:
				var xv := x0 + ancho * (float(i) + 0.5) / float(n)
				if absf(xv - xd) < 1.2:
					continue
				_ventana(xv, 0.85, 0.92, 1.85, bajos, 3, 2, _encender(c, 0))
				_remates(c, xv, 0.85, 0.92, 1.85, 0)
		_:
			for i in n:
				var xv := x0 + ancho * (float(i) + 0.5) / float(n)
				_ventana(xv, 0.85, 0.92, 1.85, bajos, 3, 2, _encender(c, 0))
				_remates(c, xv, 0.85, 0.92, 1.85, 0)
	if sotano:
		for i in n:
			var xv := x0 + ancho * (float(i) + 0.5) / float(n)
			_ventana(xv, SOTANO + 0.7, 0.92, 1.25, bajos, 3, 1, rng.randf() < 0.35)
		_foso(x0, x1)

	# pisos altos
	var y: float = pisos[0]
	for p in range(1, pisos.size()):
		var h: float = pisos[p]
		var vh := h * (0.64 if p == 1 else (0.58 if p == 2 else 0.52))
		var sill := 0.75 if p == 1 else 0.7
		var balcon := p == 1 and bool(c.get("balcon", false))
		if balcon:
			vh = h * 0.72
			sill = 0.32
		var vw := 0.92 if p < 3 else 0.84
		for i in n:
			var xv := x0 + ancho * (float(i) + 0.5) / float(n)
			if c.has("trampilla") and i == int(c["trampilla"]):
				_trampilla(xv, y, h, huecos, p == pisos.size() - 1)
				continue
			_ventana(xv, y + sill, vw, vh, huecos, 3, 2 if p < 3 else 1, _encender(c, p), bool(c.get("detalle", true)))
			_remates(c, xv, y + sill, vw, vh, p)
			if balcon:
				_balconcillo(xv, y + sill, vw)
		y += h

	# fachada: bajo y alto (el bajo en estuco si toca)
	var mat_alto := "estuco" if revoco or estilo == "asilo" else "ladrillo"
	var mat_bajo := "estuco" if estilo == "C" or estilo == "asilo" else mat_alto
	var arriba := yt + pret
	var col_alto: Color = c.get("tinte_estuco", tinte) if mat_alto == "estuco" else tinte
	var col_bajo: Color = c.get("tinte_estuco", ladrillo(Color.WHITE, 0.5)) if mat_bajo == "estuco" else tinte
	muro(mat_bajo, x0, x1, y_base, pisos[0], bajos, col_bajo)
	muro(mat_alto, x0, x1, pisos[0], arriba, huecos, col_alto)
	var banda := ESTUCO if estilo == "C" else PIEDRA
	caja_ab("pintura", Vector3(x0, pisos[0] - 0.08, 0.0), Vector3(x1, pisos[0] + 0.12, 0.06), banda)
	if estilo == "C" or estilo == "asilo":
		y = pisos[0]
		for p in range(1, pisos.size() - 1):
			y += float(pisos[p])
			caja_ab("pintura", Vector3(x0, y - 0.06, 0.0), Vector3(x1, y + 0.1, 0.05), banda)
	if estilo == "C":
		_cornisa(x0, x1, yt)
	else:
		caja_ab("pintura", Vector3(x0, yt - 0.05, 0.0), Vector3(x1, yt + 0.12, 0.12), PIEDRA)
		caja_ab("pintura", Vector3(x0, arriba, -MURO - 0.04), Vector3(x1, arriba + 0.1, 0.05), PIEDRA)

	_trasera(c, yt)
	_cubierta(c, yt)
	match String(c.get("muestra", "")):
		"mortero", "bolas":
			_muestra(xm + ancho * 0.5 - 0.45, float(pisos[0]) + 0.85, String(c["muestra"]))


func _encender(c: Dictionary, piso: int) -> bool:
	if c.has("luces"):
		return piso in Array(c["luces"])
	return rng.randf() < 0.24


## Ventana de guillotina de 6 sobre 6 (o 3 sobre 3) dentro de su hueco.
func _ventana(x: float, y0: float, w: float, h: float, huecos: Array, cols: int = 3,
		filas: int = 2, encendida: bool = false, detalle: bool = true) -> void:
	huecos.append(Rect2(x - w * 0.5, y0, w, h))
	# marco y junquillos de cara: el hueco del muro ya da la hondura
	var z := -0.1
	placa("fino", Vector3(x - w * 0.5 + 0.04, y0 + h * 0.5, z), 0.08, h, BLANCO)
	placa("fino", Vector3(x + w * 0.5 - 0.04, y0 + h * 0.5, z), 0.08, h, BLANCO)
	placa("fino", Vector3(x, y0 + h - 0.04, z), w, 0.08, BLANCO)
	placa("fino", Vector3(x, y0 + 0.05, z), w, 0.1, BLANCO)
	placa("fino", Vector3(x, y0 + h * 0.5, z + 0.005), w, 0.06, BLANCO)
	if detalle:
		for i in range(1, cols):
			placa("fino", Vector3(x - w * 0.5 + w * float(i) / float(cols), y0 + h * 0.5, z - 0.01), 0.03, h, BLANCO)
		for s in 2:
			var ys := y0 + h * 0.5 * float(s)
			for j in range(1, filas):
				placa("fino", Vector3(x, ys + h * 0.5 * float(j) / float(filas), z - 0.01), w, 0.03, BLANCO)
	caja("luz" if encendida else "vidrio", Vector3(x, y0 + h * 0.5, -0.19), Vector3(w, h, 0.02))
	# persiana a medio bajar en alguna; cortinas en las encendidas
	if not encendida and rng.randf() < 0.35:
		var bh := h * rng.randf_range(0.18, 0.45)
		caja("pintura", Vector3(x, y0 + h - bh * 0.5, -0.175), Vector3(w - 0.12, bh, 0.01), Color(0.82, 0.76, 0.6))
	elif encendida and rng.randf() < 0.6:
		for lado in [-1.0, 1.0]:
			caja("pintura", Vector3(x + float(lado) * (w * 0.5 - 0.13), y0 + h * 0.5, -0.175),
				Vector3(0.2, h - 0.12, 0.01), Color(0.42, 0.12, 0.1))


## Ventana pintada sobre un muro sin hueco (costados y traseras lejanas).
func ventana_plana(x: float, y0: float, w: float, h: float, encendida: bool) -> void:
	caja("pintura", Vector3(x, y0 + h * 0.5, 0.015), Vector3(w + 0.12, h + 0.1, 0.03), BLANCO.darkened(0.15))
	caja("luz" if encendida else "vidrio", Vector3(x, y0 + h * 0.5, 0.035), Vector3(w - 0.06, h - 0.08, 0.02))
	placa("fino", Vector3(x, y0 + h * 0.5, 0.05), 0.05, h - 0.08, BLANCO.darkened(0.15))
	placa("fino", Vector3(x, y0 + h * 0.5, 0.051), w - 0.06, 0.06, BLANCO.darkened(0.15))
	caja("pintura", Vector3(x, y0 - 0.04, 0.06), Vector3(w + 0.2, 0.08, 0.12), PIEDRA)


## Alféizar y dintel según el estilo.
func _remates(c: Dictionary, x: float, y0: float, w: float, h: float, piso: int) -> void:
	caja("pintura", Vector3(x, y0 - 0.05, 0.02), Vector3(w + 0.2, 0.1, 0.22), PIEDRA)
	match String(c["estilo"]):
		"C":
			if piso == 0:
				caja("pintura", Vector3(x, y0 + h + 0.15, 0.03), Vector3(0.24, 0.32, 0.06), ESTUCO.darkened(0.06))
				return
			var rojo := ladrillo(Color(0.78, 0.4, 0.28), 0.4, true)
			for lado in [-1.0, 1.0]:
				caja("ladrillo", Vector3(x + float(lado) * (w * 0.5 + 0.07), y0 + h * 0.5, 0.008),
					Vector3(0.14, h, 0.016), rojo)
			caja("ladrillo", Vector3(x, y0 + h + 0.16, 0.01), Vector3(w + 0.42, 0.32, 0.02), rojo)
			caja("pintura", Vector3(x, y0 + h + 0.16, 0.03), Vector3(0.2, 0.36, 0.06), ESTUCO)
			if piso == 1:
				# guardapolvo de estuco sobre ménsulas en el piso noble
				caja("pintura", Vector3(x, y0 + h + 0.42, 0.09), Vector3(w + 0.6, 0.12, 0.2), ESTUCO)
				for lado in [-1.0, 1.0]:
					caja("pintura", Vector3(x + float(lado) * (w * 0.5 + 0.2), y0 + h + 0.25, 0.06),
						Vector3(0.12, 0.3, 0.14), ESTUCO)
		"asilo":
			caja("pintura", Vector3(x, y0 + h + 0.12, 0.03), Vector3(w + 0.3, 0.24, 0.06), ESTUCO.darkened(0.12))
		_:
			if String(c.get("bajo", "")) == "tienda" and piso == 0:
				return
			# arco plano de ladrillo frotado
			caja("ladrillo", Vector3(x, y0 + h + 0.15, 0.006), Vector3(w + 0.3, 0.3, 0.012),
				ladrillo(Color(0.74, 0.6, 0.45), 0.5, true))


func _balconcillo(x: float, y: float, w: float) -> void:
	caja("pintura", Vector3(x, y - 0.06, 0.12), Vector3(w + 0.3, 0.1, 0.34), PIEDRA)
	for i in 9:
		var xb := x - (w + 0.2) * 0.5 + (w + 0.2) * float(i) / 8.0
		placa("fino", Vector3(xb, y + 0.3, 0.26), 0.025, 0.6, HIERRO)
	caja("fino", Vector3(x, y + 0.6, 0.26), Vector3(w + 0.24, 0.04, 0.04), HIERRO)
	caja("fino", Vector3(x, y + 0.2, 0.26), Vector3(w + 0.2, 0.025, 0.025), HIERRO)


## Puerta de carga de la cervecería, con su viga de polea en lo alto.
func _trampilla(x: float, y: float, h: float, huecos: Array, arriba: bool) -> void:
	huecos.append(Rect2(x - 0.6, y + 0.1, 1.2, h - 0.45))
	var madera := Color(0.32, 0.2, 0.12)
	for lado in [-1.0, 1.0]:
		caja("pintura", Vector3(x + float(lado) * 0.3, y + 0.1 + (h - 0.45) * 0.5, -0.16), Vector3(0.58, h - 0.47, 0.06), madera)
		caja("fino", Vector3(x + float(lado) * 0.3, y + 0.1 + (h - 0.45) * 0.5, -0.12), Vector3(0.5, 0.06, 0.02), HIERRO)
	caja("pintura", Vector3(x, y + 0.04, 0.05), Vector3(1.4, 0.08, 0.26), PIEDRA)
	if arriba:
		# viga de la polea con su gancho
		caja("pintura", Vector3(x, y + h - 0.15, 0.55), Vector3(0.22, 0.24, 1.4), madera.darkened(0.2))
		caja("fino", Vector3(x, y + h - 0.6, 1.1), Vector3(0.02, 0.7, 0.02), HIERRO)


func _cornisa(x0: float, x1: float, yt: float) -> void:
	caja_ab("pintura", Vector3(x0, yt - 0.25, 0.0), Vector3(x1, yt, 0.12), ESTUCO)
	caja_ab("pintura", Vector3(x0, yt, -0.1), Vector3(x1, yt + 0.32, 0.5), ESTUCO)
	var x := x0 + 0.2
	while x < x1 - 0.1:
		caja("fino", Vector3(x, yt - 0.05, 0.3), Vector3(0.12, 0.1, 0.36), ESTUCO.darkened(0.05))
		x += 0.4


## Puerta: hueco, forros, montante con cristal, umbral y portada.
## La hoja la pone hoja_abrible.tscn; si es falsa, se pinta aquí.
func portal(xd: float, c: Dictionary, huecos: Array, falsa: bool) -> void:
	var w := PUERTA_ANCHO
	var arriba := MONTANTE_ARRIBA
	var col: Color = c["puerta_color"]
	huecos.append(Rect2(xd - w * 0.5, 0.0, w, arriba))
	# forros hasta la hoja (0,375 dentro) y el zaguán
	for lado in [-1.0, 1.0]:
		caja("fino", Vector3(xd + float(lado) * (w * 0.5 - 0.035), arriba * 0.5, -0.24), Vector3(0.07, arriba, 0.48), BLANCO)
	caja("fino", Vector3(xd, arriba - 0.035, -0.24), Vector3(w, 0.07, 0.48), BLANCO)
	caja("fino", Vector3(xd, PUERTA_ALTO + 0.04, -0.1), Vector3(w, 0.08, 0.12), BLANCO)
	# montante: oscuro detrás del número dorado; dos junquillos
	caja("vidrio", Vector3(xd, (PUERTA_ALTO + arriba) * 0.5 + 0.04, -0.11), Vector3(w - 0.08, arriba - PUERTA_ALTO - 0.08, 0.02))
	for lado in [-1.0, 1.0]:
		caja("fino", Vector3(xd + float(lado) * 0.47, (PUERTA_ALTO + arriba) * 0.5 + 0.04, -0.095),
			Vector3(0.03, arriba - PUERTA_ALTO - 0.08, 0.02), BLANCO)
	# umbral de piedra
	caja("pintura", Vector3(xd, 0.06, 0.1), Vector3(w + 0.3, 0.12, 0.26), PIEDRA)
	if falsa:
		caja("pintura", Vector3(xd, PUERTA_ALTO * 0.5, -0.375), Vector3(w - 0.08, PUERTA_ALTO, 0.06), col)
		var altos := [0.55, 0.75, 0.6]
		var y := 0.2
		for f in 3:
			for lado in [-1.0, 1.0]:
				caja("fino", Vector3(xd + float(lado) * w * 0.21, y + float(altos[f]) * 0.5, -0.34),
					Vector3(w * 0.3, float(altos[f]), 0.02), col.lightened(0.12))
			y += float(altos[f]) + 0.1
		caja("fino", Vector3(xd + w * 0.3, 1.15, -0.33), Vector3(0.07, 0.07, 0.05), LATON)
	match String(c["estilo"]):
		"asilo":
			# pilastras hasta el tablero del rótulo, que hace de dintel
			for lado in [-1.0, 1.0]:
				caja("pintura", Vector3(xd + float(lado) * (w * 0.5 + 0.15), 1.72, 0.07), Vector3(0.3, 3.44, 0.14),
					Color(0.66, 0.67, 0.69))
		"C":
			var est := ESTUCO
			for lado in [-1.0, 1.0]:
				caja("pintura", Vector3(xd + float(lado) * (w * 0.5 + 0.14), (arriba + 0.05) * 0.5, 0.05),
					Vector3(0.24, arriba + 0.05, 0.1), est)
			caja("pintura", Vector3(xd, arriba + 0.2, 0.05), Vector3(w + 0.8, 0.3, 0.16), est)
			var mitad := (w + 1.0) * 0.5
			extruir("pintura", PackedVector2Array([Vector2(xd - mitad, arriba + 0.35), Vector2(xd + mitad, arriba + 0.35),
				Vector2(xd, arriba + 0.85)]), -0.02, 0.14, 2, est)
		"cerveceria":
			caja("pintura", Vector3(xd, arriba + 0.08, 0.04), Vector3(w + 0.4, 0.16, 0.12), PIEDRA)
		_:
			for lado in [-1.0, 1.0]:
				caja("pintura", Vector3(xd + float(lado) * (w * 0.5 + 0.1), (arriba + 0.05) * 0.5, 0.03),
					Vector3(0.16, arriba + 0.05, 0.06), BLANCO)
			caja("pintura", Vector3(xd, arriba + 0.12, 0.05), Vector3(w + 0.6, 0.14, 0.16), BLANCO)


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
	caja_ab("pintura", Vector3(x0 + 0.3, 0.0, -1.3), Vector3(x1 - 0.3, alto + 0.25, -1.25), oscuro)
	caja_ab("pintura", Vector3(x0 + 0.3, alto + 0.2, -1.3), Vector3(x1 - 0.3, alto + 0.25, -0.3), oscuro)
	caja_ab("pintura", Vector3(x0 + 0.25, 0.0, -1.3), Vector3(x0 + 0.3, alto + 0.25, -0.3), oscuro)
	caja_ab("pintura", Vector3(x1 - 0.3, 0.0, -1.3), Vector3(x1 - 0.25, alto + 0.25, -0.3), oscuro)
	caja_ab("luz", Vector3(x0 + 0.3, 0.6, -1.25), Vector3(x1 - 0.3, alto, -1.22))
	for lado in [-1.0, 1.0]:
		var a := xm + float(lado) * 0.6
		var b := (x0 + 0.3) if lado < 0 else (x1 - 0.3)
		var lo := minf(a, b)
		var hi := maxf(a, b)
		for balda in 2:
			var yb := 0.95 + 0.75 * float(balda)
			caja_ab("pintura", Vector3(lo, yb, -0.8), Vector3(hi, yb + 0.04, -0.5), Color(0.35, 0.24, 0.15))
			var xx := lo + 0.12
			while xx < hi - 0.15:
				var ancho := rng.randf_range(0.1, 0.22)
				var altura_g := rng.randf_range(0.15, 0.4)
				caja("pintura", Vector3(xx + ancho * 0.5, yb + 0.04 + altura_g * 0.5, -0.65),
					Vector3(ancho, altura_g, 0.15), Color.from_hsv(rng.randf(), 0.45, rng.randf_range(0.35, 0.8)))
				xx += ancho + rng.randf_range(0.03, 0.12)
		# zócalo, antepecho y vidriera de cuadradillos
		caja_ab("pintura", Vector3(lo, 0.0, -0.08), Vector3(hi, 0.6, 0.06), col)
		caja_ab("pintura", Vector3(lo, 0.6, -0.12), Vector3(hi, 0.68, 0.1), claro)
		var n := maxi(2, int(round((hi - lo) / 0.4)))
		for i in n + 1:
			var xb := lerpf(lo, hi, float(i) / float(n))
			placa("fino", Vector3(xb, 0.68 + (alto - 0.68) * 0.5, 0.0), 0.04, alto - 0.68, claro)
		for j in 5:
			var yb := lerpf(0.68, alto, float(j) / 4.0)
			placa("fino", Vector3((lo + hi) * 0.5, yb, 0.002), hi - lo, 0.04, claro)
	# puerta de la tienda en el centro, metida, con medio cristal y montante
	caja_ab("pintura", Vector3(xm - 0.6, 0.0, -0.08), Vector3(xm - 0.5, alto, 0.06), col)
	caja_ab("pintura", Vector3(xm + 0.5, 0.0, -0.08), Vector3(xm + 0.6, alto, 0.06), col)
	caja_ab("pintura", Vector3(xm - 0.5, 0.0, -0.3), Vector3(xm + 0.5, 2.25, -0.24), col)
	caja_ab("luz", Vector3(xm - 0.36, 1.15, -0.24), Vector3(xm + 0.36, 2.05, -0.22))
	caja_ab("luz", Vector3(xm - 0.5, 2.32, -0.3), Vector3(xm + 0.5, alto, -0.27))
	caja_ab("pintura", Vector3(xm - 0.5, 2.25, -0.3), Vector3(xm + 0.5, 2.32, -0.2), claro)
	caja_ab("pintura", Vector3(xm - 0.55, 0.0, -0.3), Vector3(xm + 0.55, 0.1, 0.1), PIEDRA)
	# pilastras con ménsulas, rótulo y cornisa
	for lado in [-1.0, 1.0]:
		var xp := (x0 + 0.17) if lado < 0 else (x1 - 0.17)
		caja_ab("pintura", Vector3(xp - 0.17, 0.0, -0.02), Vector3(xp + 0.17, alto, 0.16), col)
		caja_ab("pintura", Vector3(xp - 0.2, alto, -0.02), Vector3(xp + 0.2, alto + 0.55, 0.3), col.darkened(0.2))
	caja_ab("pintura", Vector3(x0 + 0.37, alto, 0.02), Vector3(x1 - 0.37, alto + 0.55, 0.16), col)
	caja_ab("pintura", Vector3(x0 + 0.02, alto + 0.55, -0.05), Vector3(x1 - 0.02, alto + 0.68, 0.4), col.darkened(0.1))
	caja_ab("pintura", Vector3(x0 + 0.02, alto + 0.68, -0.05), Vector3(x1 - 0.02, alto + 0.71, 0.4), HIERRO)
	# toldo enrollado bajo el rótulo
	caja_ab("pintura", Vector3(x0 + 0.4, alto - 0.12, 0.05), Vector3(x1 - 0.4, alto, 0.2), Color(0.4, 0.34, 0.26))
	var texto := String(t["texto"])
	var ancho_rotulo := x1 - x0 - 0.9
	var tam := int(clampf(ancho_rotulo * 0.85 / (float(texto.length()) * 0.65 * 0.003), 40.0, 110.0))
	rotulo(texto, Vector3(xm, alto + 0.28, 0.17), tam, ORO if col.v < 0.5 else Color(0.18, 0.12, 0.08), 6)


## El foso del sótano: suelo, murete, escalera y verja de lanzas.
func _foso(x0: float, x1: float) -> void:
	caja_ab("pintura", Vector3(x0, SOTANO - 0.1, 0.0), Vector3(x1, SOTANO, PATIO), Color(0.34, 0.33, 0.3))
	caja_ab("ladrillo", Vector3(x0, SOTANO, PATIO), Vector3(x1, 0.0, PATIO + 0.25), ladrillo(Color(0.8, 0.8, 0.8), 0.8))
	for lado in [x0, x1]:
		caja_ab("ladrillo", Vector3(lado - 0.12, SOTANO, 0.0), Vector3(lado + 0.12, 0.0, PATIO), ladrillo(Color(0.8, 0.8, 0.8), 0.8))
	caja_ab("pintura", Vector3(x0, 0.0, PATIO - 0.02), Vector3(x1, 0.12, PATIO + 0.27), PIEDRA)
	# escalera contra el murete, de la verja abajo
	var pasos := 8
	for i in pasos:
		var top := -float(i + 1) * (-SOTANO) / float(pasos + 1)
		var xa := x1 - 0.15 - 0.26 * float(i + 1)
		caja_ab("pintura", Vector3(xa, SOTANO, PATIO - 0.55), Vector3(xa + 0.26, top, PATIO), PIEDRA.darkened(0.12))
	var zr := PATIO + 0.12
	var x := x0 + 0.08
	while x < x1 - 0.05:
		barra("fino", Vector3(x, 0.12 + 0.5, zr), Vector3(0.024, 1.0, 0.024), HIERRO)
		cilindro("fino", Vector3(x, 1.12, zr), 0.035, 0.0, 0.11, 4, HIERRO, PI * 0.25)
		x += 0.13
	caja_ab("fino", Vector3(x0 + 0.05, 1.0, zr - 0.02), Vector3(x1 - 0.05, 1.04, zr + 0.02), HIERRO)
	caja_ab("fino", Vector3(x0 + 0.05, 0.2, zr - 0.02), Vector3(x1 - 0.05, 0.24, zr + 0.02), HIERRO)
	for e in [x0 + 0.05, x1 - 0.05]:
		caja("pintura", Vector3(e, 0.7, zr), Vector3(0.07, 1.16, 0.07), HIERRO)
		cilindro("pintura", Vector3(e, 1.28, zr), 0.06, 0.02, 0.14, 6, HIERRO)
	fosos.append(_rect_mundo(Rect2(x0, 0.0, x1 - x0, PATIO + 0.25)))


## Rect2 (x, z) de casa a mundo (x, z); vale con giros de 90°.
func _rect_mundo(r: Rect2) -> Rect2:
	var a := xf * Vector3(r.position.x, 0.0, r.position.y)
	var b := xf * Vector3(r.end.x, 0.0, r.end.y)
	return Rect2(Vector2(minf(a.x, b.x), minf(a.z, b.z)), (Vector2(b.x, b.z) - Vector2(a.x, a.z)).abs())


## Trasera: muro con ventanas sencillas y una puerta al patio.
func _trasera(c: Dictionary, yt: float) -> void:
	var x0: float = c["x0"]
	var x1: float = c["x1"]
	var ancho := x1 - x0
	var tinte: Color = c["tinte"]
	var pisos: Array = c["pisos"]
	var guardado := xf
	xf = xf * Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0, -FONDO))
	var a := -x1
	var b := -x0
	var huecos: Array = []
	var y := 0.0
	var n := maxi(1, int(round(ancho / 2.5)))
	for p in pisos.size():
		var h: float = pisos[p]
		for i in n:
			var xv := a + ancho * (float(i) + 0.5) / float(n)
			if p == 0 and i == 0:
				huecos.append(Rect2(xv - 0.45, 0.0, 0.9, 2.2))
				caja("pintura", Vector3(xv, 1.1, -0.2), Vector3(0.9, 2.2, 0.06), Color(0.3, 0.26, 0.2))
				continue
			_ventana(xv, y + 0.8, 0.85, h * 0.55, huecos, 2, 2, rng.randf() < 0.22, false)
			caja("pintura", Vector3(xv, y + 0.75, 0.02), Vector3(1.0, 0.08, 0.16), PIEDRA)
		y += h
	var remate := 0.0 if String(c["estilo"]) == "C" else 0.5
	muro("ladrillo", a, b, 0.0, yt + remate, huecos, tinte)
	if remate > 0.0:
		caja_ab("pintura", Vector3(a, yt + remate, -MURO - 0.04), Vector3(b, yt + remate + 0.1, 0.05), PIEDRA)
	xf = guardado


## Cubierta de cada casa; medianeras y chimeneas van luego, a la par de la vecina.
func _cubierta(c: Dictionary, yt: float) -> void:
	var x0: float = c["x0"]
	var x1: float = c["x1"]
	var hr := cumbrera(c)
	match String(c["cubierta"]):
		"teja":
			var perfil := PackedVector2Array([Vector2(0.55, yt + 0.32), Vector2(0.55, yt + 0.4),
				Vector2(-FONDO * 0.5, yt + hr), Vector2(-FONDO - 0.3, yt + 0.4), Vector2(-FONDO - 0.3, yt + 0.32),
				Vector2(-FONDO * 0.5, yt + 0.3)])
			extruir("tejado", perfil, x0, x1, 0, TEJA)
			for i in int(c["buhardas"]):
				var xb := lerpf(x0, x1, (float(i) + 1.0) / (float(c["buhardas"]) + 1.0))
				_buharda(xb, yt + 0.9, -0.85, true)
		_:
			var perfil := PackedVector2Array([Vector2(-MURO, yt), Vector2(-MURO, yt + 0.2),
				Vector2(-FONDO * 0.5, yt + hr), Vector2(-FONDO + MURO, yt + 0.2), Vector2(-FONDO + MURO, yt)])
			extruir("tejado", perfil, x0, x1, 0, PIZARRA)
			for i in int(c["buhardas"]):
				var xb := lerpf(x0, x1, (float(i) + 1.0) / (float(c["buhardas"]) + 1.0))
				_buharda(xb, yt + 0.45, -0.75, false)


## Buhardilla: cajón con ventana y tejadillo (a dos aguas o de plomo).
func _buharda(x: float, y0: float, z: float, aguas: bool) -> void:
	var w := 1.05
	var h := 1.3
	var fondo := 1.6
	var col := ESTUCO.darkened(0.1) if aguas else Color(0.32, 0.33, 0.35)
	caja_ab("pintura", Vector3(x - w * 0.5, y0 - 0.6, z - fondo), Vector3(x + w * 0.5, y0 + h, z), col)
	caja("vidrio", Vector3(x, y0 + h * 0.48, z + 0.01), Vector3(w - 0.3, h - 0.4, 0.02))
	placa("fino", Vector3(x, y0 + h * 0.48, z + 0.03), 0.04, h - 0.4, BLANCO)
	placa("fino", Vector3(x, y0 + h * 0.48, z + 0.031), w - 0.3, 0.04, BLANCO)
	if aguas:
		extruir("tejado", PackedVector2Array([Vector2(x - w * 0.5 - 0.12, y0 + h), Vector2(x + w * 0.5 + 0.12, y0 + h),
			Vector2(x, y0 + h + 0.55)]), z - fondo, z + 0.12, 2, TEJA)
	else:
		caja_ab("pintura", Vector3(x - w * 0.5 - 0.08, y0 + h, z - fondo), Vector3(x + w * 0.5 + 0.08, y0 + h + 0.1, z + 0.1),
			Color(0.42, 0.44, 0.46))


## Perfil (z, y) de la medianera de una casa, de `abajo` a la cumbrera.
static func perfil_medianera(c: Dictionary, abajo: float) -> PackedVector2Array:
	var yt := altura(c)
	var hr := cumbrera(c)
	if String(c["cubierta"]) == "teja":
		return PackedVector2Array([Vector2(0.0, abajo), Vector2(0.0, yt + 0.5), Vector2(-FONDO * 0.5, yt + hr + 0.25),
			Vector2(-FONDO, yt + 0.5), Vector2(-FONDO, abajo)])
	return PackedVector2Array([Vector2(-MURO, abajo), Vector2(-MURO, yt + pretil(c)), Vector2(-FONDO * 0.5, yt + hr + 0.3),
		Vector2(-FONDO + MURO, yt + 0.6), Vector2(-FONDO + MURO, abajo)])


## Medianera en x (coords. de xf) entre dos casas; una vacía = costado a la vista.
## `ventanas`: el costado da a una calle (esquina) y lleva ventanas pintadas.
func medianera(x: float, izq: Dictionary, der: Dictionary, ventanas: bool = false) -> void:
	var alta: Dictionary = izq
	if izq.is_empty() or (not der.is_empty() and altura(der) > altura(izq)):
		alta = der
	var otra: Dictionary = der if alta == izq else izq
	var yt := altura(alta)
	var abajo := 0.0
	var a := x - 0.2
	var b := x + 0.2
	if not otra.is_empty():
		abajo = minf(yt, altura(otra)) - 0.3
	else:
		abajo = SOTANO if bool(alta.get("sotano", false)) else 0.0
		# costado a la vista: hacia dentro de su casa, que no asome a la calle
		a = x - 0.3 if alta == izq else x
		b = a + 0.3
	extruir("ladrillo", perfil_medianera(alta, abajo), a, b, 0, (alta["tinte"] as Color).darkened(0.06))
	if otra.is_empty() and ventanas:
		var guardado := xf
		var s := 1.0 if alta == izq else -1.0
		xf = xf * Transform3D(Basis(Vector3.UP, s * PI * 0.5), Vector3(x, 0.0, -FONDO * 0.5))
		var y: float = Array(alta["pisos"])[0]
		for p in range(1, Array(alta["pisos"]).size()):
			var h: float = Array(alta["pisos"])[p]
			ventana_plana(0.0, y + 0.75, 0.9, h * 0.56, rng.randf() < 0.25)
			y += h
		xf = guardado
	# chimenea sobre la medianera: cuerpo, cornisa de ladrillo volado y cañones
	var zc := -FONDO * 0.5
	var base := yt + cumbrera(alta) - 0.3
	var alto := 1.7
	if bool(alta.get("chimenea_atras", false)):
		# pegada a la trasera y más baja: queda bajo la grúa alta del tráiler
		zc = -FONDO + 1.0
		alto += base - yt - 0.8
		base = yt + 0.2
	var largo := 1.9
	var tinte: Color = (alta["tinte"] as Color).darkened(0.15)
	var xc := x if not otra.is_empty() else (x - 0.35 if alta == izq else x + 0.35)
	caja_ab("ladrillo", Vector3(xc - 0.45, base, zc - largo * 0.5), Vector3(xc + 0.45, base + alto, zc + largo * 0.5), tinte)
	caja_ab("ladrillo", Vector3(xc - 0.53, base + alto - 0.32, zc - largo * 0.5 - 0.08),
		Vector3(xc + 0.53, base + alto - 0.16, zc + largo * 0.5 + 0.08), tinte.darkened(0.1))
	caja_ab("pintura", Vector3(xc - 0.49, base + alto, zc - largo * 0.5 - 0.04),
		Vector3(xc + 0.49, base + alto + 0.1, zc + largo * 0.5 + 0.04), PIEDRA.darkened(0.2))
	var cuantos := rng.randi_range(3, 6)
	for i in cuantos:
		var z := zc - largo * 0.5 + 0.25 + (largo - 0.5) * float(i) / float(maxi(1, cuantos - 1))
		var h := rng.randf_range(0.42, 0.78)
		var col := TERRACOTA.lerp(Color(0.72, 0.6, 0.45), rng.randf() * 0.6)
		var xo := rng.randf_range(-0.12, 0.12)
		# cañón sin tapa (la boca la pone el remate)
		cilindro("pintura", Vector3(xc + xo, base + alto + 0.1, z), 0.14, 0.11, h, 5, col)
		cilindro("pintura", Vector3(xc + xo, base + alto + 0.1 + h, z), 0.15, 0.15, 0.07, 5, col.darkened(0.1))


## Muestra colgada de una ménsula, de canto a la calle: mortero o tres bolas.
func _muestra(x: float, y: float, cual: String) -> void:
	caja_ab("fino", Vector3(x - 0.02, y + 0.6, 0.0), Vector3(x + 0.02, y + 0.64, 1.1), HIERRO)
	caja_ab("fino", Vector3(x - 0.015, y + 0.1, 0.0), Vector3(x + 0.015, y + 0.62, 0.04), HIERRO)
	if cual == "bolas":
		caja("fino", Vector3(x, y + 0.45, 0.85), Vector3(0.02, 0.3, 0.02), HIERRO)
		caja("fino", Vector3(x, y + 0.3, 0.85), Vector3(0.02, 0.02, 0.5), HIERRO)
		for z in [0.62, 0.85, 1.08]:
			var yy := y + (0.02 if z == 0.85 else 0.12)
			cilindro("pintura", Vector3(x, yy - 0.2, z), 0.1, 0.1, 0.2, 8, ORO)
		return
	for z in [0.35, 0.95]:
		caja("fino", Vector3(x, y + 0.52, z), Vector3(0.015, 0.16, 0.015), HIERRO)
	caja("pintura", Vector3(x, y + 0.15, 0.65), Vector3(0.06, 0.62, 0.78), ORO.darkened(0.25))
	caja("pintura", Vector3(x, y + 0.15, 0.65), Vector3(0.08, 0.5, 0.66), Color(0.1, 0.13, 0.3))
	for lado in [-1.0, 1.0]:
		caja("fino", Vector3(x + float(lado) * 0.045, y + 0.1, 0.65), Vector3(0.01, 0.18, 0.24), ORO)
		caja("fino", Vector3(x + float(lado) * 0.045, y + 0.25, 0.7), Vector3(0.01, 0.2, 0.04), ORO)


# ---------------------------------------------------------------- relleno

## Casas de pocas piezas a lo largo de x (coords. de xf): caja, ventanas pintadas,
## pretil, cubierta y chimenea. `dos_caras`: también ventanas detrás.
func fila_simple(x0: float, x1: float, fondo: float, pisos_min: int, pisos_max: int,
		con_bajo: bool, dos_caras: bool) -> void:
	var x := x0
	while x < x1 - 1.0:
		var w := minf(rng.randf_range(4.4, 6.0), x1 - x)
		if x1 - x - w < 3.0:
			w = x1 - x
		empezar(xf * Vector3(x + w * 0.5, 0.0, -fondo * 0.5))
		var pisos := rng.randi_range(pisos_min, pisos_max)
		var h := 3.3 + 2.9 * float(pisos - 1)
		var tinte := Color(0.9, 0.9, 0.84).darkened(rng.randf_range(0.0, 0.25))
		if rng.randf() < 0.3:
			tinte = Color(1.0, 0.75, 0.66).darkened(rng.randf_range(0.0, 0.2))
		var col := ladrillo(tinte, rng.randf_range(0.5, 1.0))
		caja_ab("ladrillo", Vector3(x, 0.0, -fondo), Vector3(x + w, h + 0.7, 0.0), col)
		caja_ab("pintura", Vector3(x - 0.02, h + 0.7, -fondo - 0.04), Vector3(x + w + 0.02, h + 0.8, 0.04), PIEDRA.darkened(0.15))
		caja_ab("pintura", Vector3(x, 3.2, 0.0), Vector3(x + w, 3.36, 0.06), PIEDRA.darkened(0.1))
		extruir("tejado", PackedVector2Array([Vector2(-fondo + 0.3, h + 0.7), Vector2(-fondo * 0.5, h + 2.2),
			Vector2(-0.3, h + 0.7)]), x + 0.2, x + w - 0.2, 0, PIZARRA if rng.randf() < 0.75 else TEJA)
		var zc := -fondo * 0.5 + rng.randf_range(-1.0, 1.0)
		caja_ab("ladrillo", Vector3(x - 0.4, h + 0.7, zc - 0.9), Vector3(x + 0.4, h + 3.0, zc + 0.9), col.darkened(0.2))
		for i in rng.randi_range(2, 4):
			cilindro("pintura", Vector3(x, h + 3.0, zc - 0.6 + 0.4 * float(i)), 0.13, 0.11, 0.55, 6, TERRACOTA)
		var n := 3 if w > 5.0 else 2
		for cara in (2 if dos_caras else 1):
			var guardado := xf
			if cara == 1:
				xf = xf * Transform3D(Basis(Vector3.UP, PI), Vector3(2.0 * x + w, 0, -fondo))
			for p in pisos:
				var yv := 0.9 + (3.3 if p > 0 else 0.0) + 2.9 * float(maxi(0, p - 1))
				if p == 0 and (not con_bajo or cara == 1):
					continue
				for i in n:
					var xv := x + w * (float(i) + 0.5) / float(n)
					if p == 0 and i == n / 2:
						caja("pintura", Vector3(xv, 1.15, 0.02), Vector3(1.0, 2.3, 0.04), Color(0.14, 0.12, 0.1))
						caja("pintura", Vector3(xv, 2.5, 0.03), Vector3(1.2, 0.1, 0.06), BLANCO.darkened(0.2))
						continue
					ventana_plana(xv, yv, 0.86, 1.65 if p < 2 else 1.35, rng.randf() < 0.2)
			xf = guardado
		x += w


## Patios traseros a lo largo de x: tapias cada `paso`, retrete al fondo y suelo.
func patios(x0: float, x1: float, fondo: float, paso: float) -> void:
	caja_ab("pintura", Vector3(x0, 0.0, -fondo), Vector3(x1, 0.03, 0.0), Color(0.3, 0.29, 0.26))
	var x := x0
	var tinte := ladrillo(Color(0.75, 0.72, 0.66), 0.9)
	while x <= x1 + 0.01:
		empezar(xf * Vector3(x, 0.0, -fondo * 0.5))
		caja_ab("ladrillo", Vector3(x - 0.12, 0.0, -fondo), Vector3(x + 0.12, 2.1, 0.0), tinte)
		if x + paso <= x1 + 0.01:
			var izq := rng.randf() < 0.5
			var rx := x + 0.3 if izq else x + paso - 1.5
			caja_ab("pintura", Vector3(rx, 0.0, -fondo + 0.1), Vector3(rx + 1.2, 2.0, -fondo + 1.35), Color(0.4, 0.33, 0.25))
			extruir("tejado", PackedVector2Array([Vector2(-fondo, 2.3), Vector2(-fondo + 1.5, 2.0),
				Vector2(-fondo + 1.5, 1.92), Vector2(-fondo, 2.22)]), rx - 0.1, rx + 1.3, 0, PIZARRA)
			if rng.randf() < 0.5:
				cilindro("pintura", Vector3(x + paso * 0.5, 0.0, -0.6), 0.3, 0.3, 0.85, 8, Color(0.35, 0.25, 0.16))
		x += paso
	caja_ab("ladrillo", Vector3(x0, 0.0, -fondo - 0.24), Vector3(x1, 2.2, -fondo), tinte)
