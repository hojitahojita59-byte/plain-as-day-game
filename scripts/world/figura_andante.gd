extends Node3D
## Figura de cajas: ropa, cara, giro y ciclo de andar procedural (sin esqueleto).

## Apertura de piernas en rad (0,5 ≈ 29°).
@export var amplitud: float = 0.52

## Zancadas por metro.
@export var cadencia: float = 2.1

## Velocidad de paso normal (m/s); igual que `speed` del point_click_controller.
@export var velocidad_normal: float = 4.2

## Velocidad de giro. Alto = en seco.
@export var giro: float = 10.0

@export_group("Vestimenta")
## Materiales propios por instancia (los del .tscn se comparten entre copias).
@export var color_abrigo: Color = Color(0.27, 0.27, 0.31)
@export var color_pantalon: Color = Color(0.31, 0.28, 0.26)
@export var color_sombrero: Color = Color(0.16, 0.15, 0.18)
@export var color_cuello: Color = Color(0.93, 0.91, 0.85)

## Chistera (de caballero; distingue a Whitehead).
@export var lleva_chistera: bool = true
## Gorra de obrero.
@export var lleva_gorra: bool = false
## Chal (mujer).
@export var lleva_chal: bool = false
## Alzacuellos de clérigo (solo Whitehead).
@export var lleva_alzacuellos: bool = true
## Factor de estatura (0,82 chaval, 1,05 grande).
@export var estatura: float = 1.0

@export_group("Postura en reposo")
## Inclinación del cuerpo en rad; + = hacia delante.
@export var inclinacion: float = 0.0
@export var brazo_izquierdo: float = 0.0
@export var brazo_derecho: float = 0.0
## Codo: negativo dobla el antebrazo hacia delante.
@export var codo_izquierdo: float = 0.0
@export var codo_derecho: float = 0.0
## Sentado (pescante, banco): muslos al frente y rodillas dobladas; no anda.
@export var sentado: bool = false:
	set(v):
		sentado = v
		if v and is_node_ready() and _rodilla_izq == null:
			_partir_piernas()
			for z in find_children("Zapato", "MeshInstance3D", true, false):
				var r := z.get_parent().get_node_or_null(^"Rodilla") as Node3D
				if r != null:
					z.reparent(r, false)
					z.position.y = -0.365

@export_group("Vida en reposo")
## Mira a los lados de vez en cuando.
@export var mira_alrededor: bool = true
## Gesticulación parado: 0 nada, 0,25 habla con las manos.
@export var gesto: float = 0.0

@export_group("Cara")
## Color del pelo. Transparente = por semilla.
@export var pelo: Color = Color(0, 0, 0, 0)
## Cara de art/actors/caras («h00», «m03»…). Vacío = por semilla. h00 Whitehead, h01 Snow.
@export var cara: String = ""
## Id del personaje en los diálogos; se oculta mientras se ve su retrato.
@export var quien: String = ""
## Exponente del superelipsoide de la cabeza: 2 esfera, más alto = cubo, <2 = caja.
@export var redondez: float = 4.5

@export_group("Piezas")
@export var cuerpo_path: NodePath = ^"Cuerpo"
@export var cadera_izq_path: NodePath = ^"Cuerpo/CaderaIzq"
@export var cadera_der_path: NodePath = ^"Cuerpo/CaderaDer"
@export var hombro_izq_path: NodePath = ^"Cuerpo/HombroIzq"
@export var hombro_der_path: NodePath = ^"Cuerpo/HombroDer"

var _cuerpo: Node3D
var _cadera_izq: Node3D
var _cadera_der: Node3D
var _hombro_izq: Node3D
var _hombro_der: Node3D
var _codo_izq: Node3D
var _codo_der: Node3D
var _rodilla_izq: Node3D
var _rodilla_der: Node3D

var _actor: CharacterBody3D = null
var _padre: Node3D = null
var _pos_anterior: Vector3 = Vector3.ZERO
var _fase: float = 0.0
var _altura_base: float = 0.0

## Reloj propio con fase aleatoria (que no respiren todos a la vez).
var _vida: float = 0.0
var _quieto: bool = false
var _rot_reposo: float = 0.0
var _mirada: float = 0.0
var _mirada_objetivo: float = 0.0
var _proxima_mirada: float = 0.0


func _ready() -> void:
	_cuerpo = get_node_or_null(cuerpo_path) as Node3D
	_cadera_izq = get_node_or_null(cadera_izq_path) as Node3D
	_cadera_der = get_node_or_null(cadera_der_path) as Node3D
	_hombro_izq = get_node_or_null(hombro_izq_path) as Node3D
	_hombro_der = get_node_or_null(hombro_der_path) as Node3D

	if _cuerpo == null:
		push_warning("FiguraAndante: no encuentro el nodo Cuerpo; me quedo quieta.")
		return
	_altura_base = _cuerpo.position.y
	_vida = randf() * TAU
	_proxima_mirada = randf_range(1.5, 6.0)
	_rot_reposo = rotation.y

	# Método, no lambda: el HUD es autoload y retendría la figura liberada.
	if not quien.is_empty():
		HUD.retrato_visible.connect(_al_cambiar_el_retrato)
	_partir_brazos()
	if sentado:
		_partir_piernas()
	_vestir()
	_detallar()
	_vestirse_la_cabeza()
	scale = Vector3.ONE * estatura

	# Anda si el padre se mueve, sea o no CharacterBody3D.
	_padre = get_parent() as Node3D
	_actor = _padre as CharacterBody3D
	if _padre:
		_pos_anterior = _padre.global_position


## Brazo en dos: brazo y antebrazo, con el codo en medio.
func _partir_brazos() -> void:
	for h in [_hombro_izq, _hombro_der]:
		if h == null:
			continue
		var brazo := h.get_node_or_null(^"Brazo") as MeshInstance3D
		if brazo == null:
			continue
		var arriba := BoxMesh.new()
		arriba.size = Vector3(0.13, 0.29, 0.15)
		brazo.mesh = arriba
		brazo.position.y = -0.145
		var codo := Node3D.new()
		codo.name = "Codo"
		h.add_child(codo)
		codo.position.y = -0.28
		var ante := MeshInstance3D.new()
		ante.name = "Antebrazo"
		var abajo := BoxMesh.new()
		abajo.size = Vector3(0.12, 0.29, 0.14)
		ante.mesh = abajo
		codo.add_child(ante)
		ante.position.y = -0.135
		if h == _hombro_izq:
			_codo_izq = codo
		else:
			_codo_der = codo


## Pierna en dos (muslo y espinilla) para poder sentarse.
func _partir_piernas() -> void:
	for c in [_cadera_izq, _cadera_der]:
		if c == null:
			continue
		var pierna := c.get_node_or_null(^"Pierna") as MeshInstance3D
		if pierna == null:
			continue
		var muslo := BoxMesh.new()
		muslo.size = Vector3(0.16, 0.42, 0.18)
		pierna.mesh = muslo
		pierna.position.y = -0.2
		var rodilla := Node3D.new()
		rodilla.name = "Rodilla"
		c.add_child(rodilla)
		rodilla.position.y = -0.4
		var espinilla := MeshInstance3D.new()
		espinilla.name = "Espinilla"
		var abajo := BoxMesh.new()
		abajo.size = Vector3(0.15, 0.4, 0.17)
		espinilla.mesh = abajo
		espinilla.material_override = pierna.material_override
		espinilla.visible = pierna.visible
		rodilla.add_child(espinilla)
		espinilla.position.y = -0.2
		if c == _cadera_izq:
			_rodilla_izq = rodilla
		else:
			_rodilla_der = rodilla


## Sombreros, chal, alzacuellos y postura de reposo.
func _vestirse_la_cabeza() -> void:
	for nombre in ["SombreroCopa", "SombreroAla"]:
		var n := get_node_or_null(NodePath("Cuerpo/" + nombre)) as Node3D
		if n: n.visible = lleva_chistera
	for nombre in ["Gorra", "Visera"]:
		var n := get_node_or_null(NodePath("Cuerpo/" + nombre)) as Node3D
		if n: n.visible = lleva_gorra
	var chal := get_node_or_null(^"Cuerpo/Chal") as Node3D
	if chal: chal.visible = lleva_chal
	var cuello := get_node_or_null(^"Cuerpo/Cuello") as Node3D
	if cuello: cuello.visible = lleva_alzacuellos

	# Postura solo para quien no anda.
	if get_parent() is CharacterBody3D:
		return
	if _cuerpo: _cuerpo.rotation.x = inclinacion
	if _hombro_izq: _hombro_izq.rotation.x = brazo_izquierdo
	if _hombro_der: _hombro_der.rotation.x = brazo_derecho


# --- Detalle: manos, zapatos, pelo, cara (SVG de herramientas/generar_caras.js), tela ---
# Semilla derivada de la ropa: cada persona sale siempre igual.

const PIEL := Color(0.82, 0.62, 0.48)
const CABELLOS := [Color(0.16, 0.11, 0.08), Color(0.28, 0.19, 0.12), Color(0.42, 0.30, 0.18),
	Color(0.12, 0.10, 0.09), Color(0.55, 0.52, 0.48)]

## Texturas de tela compartidas, una por grano.
static var _telas: Dictionary = {}

var _semilla: int = 0


func _azar() -> float:
	_semilla = (_semilla * 1103515245 + 12345) & 0x7fffffff
	return float(_semilla % 10000) / 10000.0


const CARAS := "res://art/actors/caras/"
static var _indice_caras: Dictionary = {}


func _detallar() -> void:
	_semilla = absi(hash([color_abrigo, color_pantalon, color_sombrero, estatura]))
	var mujer := lleva_chal
	var cabello: Color = CABELLOS[int(_azar() * CABELLOS.size()) % CABELLOS.size()]
	# Whitehead (único con alzacuellos): pelo oscuro, cara h00.
	if lleva_alzacuellos:
		cabello = CABELLOS[1]
		cara = "h00"
	if pelo.a > 0.0:
		cabello = pelo
	if cara.is_empty():
		cara = _cara_por_semilla(mujer)
	var ficha := _ficha(cara)
	# Mayores: canosos.
	if int(ficha.get("edad", 0)) > 0 and pelo.a == 0.0 and not lleva_alzacuellos:
		cabello = cabello.lerp(Color(0.62, 0.6, 0.57), 0.6)
	var piel := PIEL * Color(0.92 + _azar() * 0.14, 0.92 + _azar() * 0.12, 0.92 + _azar() * 0.1)

	var cabeza := get_node_or_null(^"Cuerpo/Cabeza") as MeshInstance3D
	if cabeza:
		var mp := StandardMaterial3D.new()
		mp.albedo_color = piel
		mp.roughness = 1.0
		cabeza.material_override = mp

	# Manos y puños.
	for lado in ["HombroIzq", "HombroDer"]:
		var h := get_node_or_null(NodePath("Cuerpo/" + lado + "/Codo")) as Node3D
		if h:
			_pieza(h, "Mano", Vector3(0, -0.32, 0.01), Vector3(0.1, 0.1, 0.11), piel)
			_pieza(h, "Puño", Vector3(0, -0.265, 0), Vector3(0.135, 0.03, 0.155), color_cuello)

	# Zapatos, marrón oscuro o negro.
	var cuero := Color(0.2, 0.13, 0.09) if _azar() < 0.5 else Color(0.09, 0.08, 0.08)
	for lado in ["CaderaIzq", "CaderaDer"]:
		var c := get_node_or_null(NodePath("Cuerpo/" + lado)) as Node3D
		var rodilla := get_node_or_null(NodePath("Cuerpo/" + lado + "/Rodilla")) as Node3D
		if rodilla:
			_pieza(rodilla, "Zapato", Vector3(0, -0.365, 0.045), Vector3(0.17, 0.07, 0.27), cuero)
		elif c:
			_pieza(c, "Zapato", Vector3(0, -0.765, 0.045), Vector3(0.17, 0.07, 0.27), cuero)

	var cuerpo := get_node_or_null(^"Cuerpo") as Node3D
	if cuerpo:
		_pieza(cuerpo, "CuelloPiel", Vector3(0, 1.48, 0), Vector3(0.1, 0.08, 0.1), piel)
		_pieza(cuerpo, "Pelo", Vector3(0, 1.735, -0.018), Vector3(0.236, 0.145, 0.205), cabello)
		_pieza(cuerpo, "Nuca", Vector3(0, 1.64, -0.1), Vector3(0.226, 0.12, 0.03), cabello)
		if mujer:
			_peinado_de_mujer(cuerpo, cabello)
			_falda(cuerpo)
		else:
			# Patillas largas si la cara tiene barba de patillas o completa.
			var largas := String(ficha.get("barba", "")) in ["patillas", "completa"]
			for x in [-0.113, 0.113]:
				_pieza(cuerpo, "Patilla", Vector3(x, 1.62 if largas else 1.66, 0.02),
					Vector3(0.016, 0.16 if largas else 0.08, 0.09), cabello)
		if redondez >= 2.0:
			_redondear_cabeza(cuerpo, piel, cabello)
		else:
			_cara(cuerpo, cabello)
		if not lleva_alzacuellos and not mujer:
			_pechera(cuerpo)

	if redondez >= 2.0:
		_redondear_cuerpo()
	# Contorno a la mitad que el de una casa.
	for m in find_children("*", "MeshInstance3D", true, false):
		m.set_meta(&"contorno", 0.5)

	_tela(["Cuerpo/Torso", "Cuerpo/Faldon", "Cuerpo/HombroIzq/Brazo", "Cuerpo/HombroDer/Brazo",
		"Cuerpo/HombroIzq/Codo/Antebrazo", "Cuerpo/HombroDer/Codo/Antebrazo", "Cuerpo/Chal", "Cuerpo/Falda"], 0.10)
	_tela(["Cuerpo/CaderaIzq/Pierna", "Cuerpo/CaderaDer/Pierna",
		"Cuerpo/CaderaIzq/Rodilla/Espinilla", "Cuerpo/CaderaDer/Rodilla/Espinilla"], 0.08)


## Cara por semilla. h00 y h01 reservadas (Whitehead, Snow).
func _cara_por_semilla(mujer: bool) -> String:
	var idx := _caras()
	var n := int(idx.get("mujeres" if mujer else "hombres", 1))
	if mujer:
		return "m%02d" % (int(_azar() * n) % n)
	return "h%02d" % (2 + int(_azar() * (n - 2)) % maxi(n - 2, 1))


func _caras() -> Dictionary:
	if _indice_caras.is_empty():
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(CARAS + "caras.json"))
		_indice_caras = d if d is Dictionary else {}
	return _indice_caras


func _ficha(id: String) -> Dictionary:
	for c in Array(_caras().get("caras", [])):
		if String(c.get("id", "")) == id:
			return c
	return {}


## Falda hasta el tobillo; oculta las piernas y deja ver los zapatos.
func _falda(cuerpo: Node3D) -> void:
	for lado in ["CaderaIzq/Pierna", "CaderaDer/Pierna"]:
		var p := get_node_or_null(NodePath("Cuerpo/" + lado)) as Node3D
		if p: p.visible = false
	var faldon := get_node_or_null(^"Cuerpo/Faldon") as Node3D
	if faldon: faldon.visible = false
	var m := MeshInstance3D.new()
	m.name = "Falda"
	var c := CylinderMesh.new()
	c.top_radius = 0.2
	c.bottom_radius = 0.3
	c.height = 0.84
	c.radial_segments = 8
	c.rings = 1
	m.mesh = c
	# Color del abrigo, algo más oscuro (color_pantalon es el del delantal).
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color_abrigo * Color(0.86, 0.86, 0.86)
	mat.roughness = 1.0
	m.material_override = mat
	cuerpo.add_child(m)
	m.position = Vector3(0, 0.49, 0)
	# Delantal si color_pantalon es claro (o al azar).
	if color_pantalon.get_luminance() > 0.45 or _azar() < 0.3:
		var claro := color_pantalon if color_pantalon.get_luminance() > 0.45 else Color(0.82, 0.8, 0.74)
		var d := _pieza(cuerpo, "Delantal", Vector3(0, 0.55, 0.255), Vector3(0.3, 0.62, 0.02), claro)
		d.rotation.x = -0.12


## Moño, pelo largo o cofia.
func _peinado_de_mujer(cuerpo: Node3D, cabello: Color) -> void:
	var r := _azar()
	if r < 0.45:
		_pieza(cuerpo, "Moño", Vector3(0, 1.66, -0.14), Vector3(0.13, 0.11, 0.07), cabello)
	elif r < 0.75:
		_pieza(cuerpo, "PeloLargo", Vector3(0, 1.48, -0.125), Vector3(0.22, 0.42, 0.05), cabello)
	else:
		# Cofia de sirvienta.
		_pieza(cuerpo, "Cofia", Vector3(0, 1.77, -0.02), Vector3(0.25, 0.09, 0.23), Color(0.92, 0.9, 0.84))
		_pieza(cuerpo, "Moño", Vector3(0, 1.66, -0.14), Vector3(0.12, 0.1, 0.06), cabello)


func _pieza(padre: Node3D, nombre: String, pos: Vector3, tam: Vector3, color: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.name = nombre
	var b := BoxMesh.new()
	b.size = tam
	m.mesh = b
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	m.material_override = mat
	padre.add_child(m)
	m.position = pos
	return m


## Cabeza superelipsoide; piel, pelo y cara los pinta cabeza_redonda.gdshader.
const TAM_CABEZA := Vector3(0.24, 0.27, 0.235)
static var _cabezas: Dictionary = {}


func _redondear_cabeza(cuerpo: Node3D, piel: Color, cabello: Color) -> void:
	var cabeza := get_node_or_null(^"Cuerpo/Cabeza") as MeshInstance3D
	if cabeza == null:
		return
	cabeza.mesh = _caja_redonda(TAM_CABEZA, redondez, 28, 14)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://materials/cabeza_redonda.gdshader")
	mat.set_shader_parameter(&"piel", piel)
	mat.set_shader_parameter(&"pelo", cabello)
	mat.set_shader_parameter(&"rasgos", load(CARAS + "rasgos_%s.svg" % cara))
	mat.set_shader_parameter(&"vello", load(CARAS + "vello_%s.svg" % cara))
	cabeza.material_override = mat
	# Más baja que la caja, para acortar el cuello.
	cabeza.position.y = 1.632
	# Alzacuellos más estrecho que la cabeza.
	var alzacuellos := get_node_or_null(^"Cuerpo/Cuello") as MeshInstance3D
	if alzacuellos:
		var b := BoxMesh.new()
		b.size = Vector3(0.15, 0.055, 0.15)
		alzacuellos.mesh = b
		alzacuellos.position.y = 1.485
	# Bajar peinados y sombreros a la nueva altura; ocultar el pelo de caja.
	for hijo in cuerpo.get_children():
		if String(hijo.name) in ["Moño", "PeloLargo", "Cofia"]:
			(hijo as Node3D).position.y -= 0.038
	for n in ["SombreroAla", "SombreroCopa", "Gorra", "Visera"]:
		var h := cuerpo.get_node_or_null(NodePath(n)) as Node3D
		if h: h.position.y -= 0.035
	for n in ["Pelo", "Nuca", "Patilla"]:
		for hijo in cuerpo.get_children():
			if String(hijo.name).begins_with(n):
				(hijo as Node3D).visible = false


## Cajas redondeadas en el cuerpo: normales continuas = contorno sin roturas.
const REDONDEZ_CUERPO := 9.0


func _redondear_cuerpo() -> void:
	for m in find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.name == "Cabeza" or not (mi.mesh is BoxMesh):
			continue
		var tam: Vector3 = (mi.mesh as BoxMesh).size
		# Las piezas planas no se redondean.
		if minf(minf(tam.x, tam.y), tam.z) < 0.04:
			continue
		mi.mesh = _caja_redonda(tam, REDONDEZ_CUERPO, 16, 8)


## Superelipsoide |x|ⁿ+|y|ⁿ+|z|ⁿ=1 desde una esfera (conserva UV). Cacheado.
func _caja_redonda(tam: Vector3, n: float, lados: int = 16, anillos: int = 8) -> ArrayMesh:
	var clave := "%s|%.2f|%d" % [tam.snapped(Vector3.ONE * 0.001), n, lados]
	if _cabezas.has(clave):
		return _cabezas[clave]
	var esfera := SphereMesh.new()
	esfera.radius = 0.5
	esfera.height = 1.0
	esfera.radial_segments = lados
	esfera.rings = anillos
	var a := esfera.get_mesh_arrays()
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var nr: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
	for i in v.size():
		var d := v[i].normalized()
		var k := pow(pow(absf(d.x), n) + pow(absf(d.y), n) + pow(absf(d.z), n), 1.0 / n)
		var p := d / maxf(k, 0.0001)
		var g := Vector3(signf(p.x) * pow(absf(p.x), n - 1.0), signf(p.y) * pow(absf(p.y), n - 1.0),
			signf(p.z) * pow(absf(p.z), n - 1.0))
		v[i] = p * 0.5 * tam
		nr[i] = (g / tam).normalized()
	a[Mesh.ARRAY_VERTEX] = v
	a[Mesh.ARRAY_NORMAL] = nr
	a[Mesh.ARRAY_TANGENT] = null
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
	_cabezas[clave] = m
	return m


## Cara plana (cabeza de caja): rasgos + vello teñido con el pelo.
func _cara(cuerpo: Node3D, cabello: Color) -> void:
	var capas := [["rasgos_%s.svg" % cara, Color.WHITE, 0.114], ["vello_%s.svg" % cara, cabello, 0.116]]
	for capa in capas:
		var tex := load(CARAS + String(capa[0])) as Texture2D
		if tex == null:
			push_warning("FiguraAndante: no encuentro la cara %s" % capa[0])
			continue
		var m := MeshInstance3D.new()
		m.name = "Cara" if capa[2] < 0.115 else "Vello"
		var q := QuadMesh.new()
		q.size = Vector2(0.21, 0.245)
		m.mesh = q
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = tex
		mat.albedo_color = capa[1]
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.roughness = 1.0
		m.material_override = mat
		m.set_meta(&"sin_contorno", true)
		cuerpo.add_child(m)
		# Separada unos mm de la cabeza para evitar z-fighting.
		m.position = Vector3(0, 1.67, float(capa[2]))


## Pechera: camisa en V y corbatín (textura 8x12).
func _pechera(cuerpo: Node3D) -> void:
	var W := 8
	var H := 12
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var camisa := color_cuello
	var corbata := Color(0.08, 0.08, 0.09) if _azar() < 0.6 else Color(0.3, 0.1, 0.1)
	for y in H:
		var medio := int(round((1.0 - float(y) / H) * 3.5))
		for x in range(4 - medio, 4 + medio):
			img.set_pixel(x, y, camisa)
	for y in range(0, 4):
		img.set_pixel(3, y, corbata)
		img.set_pixel(4, y, corbata)
	img.set_pixel(2, 0, corbata)
	img.set_pixel(5, 0, corbata)
	var m := MeshInstance3D.new()
	m.name = "Pechera"
	var q := QuadMesh.new()
	q.size = Vector2(0.16, 0.24)
	m.mesh = q
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = ImageTexture.create_from_image(img)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.5
	mat.roughness = 1.0
	m.material_override = mat
	m.set_meta(&"sin_contorno", true)
	cuerpo.add_child(m)
	m.position = Vector3(0, 1.33, 0.136)


## Grano de tela: ruido 16x16 casi blanco que multiplica el color.
func _tela(rutas: Array, fuerza: float) -> void:
	var tex: ImageTexture = _telas.get(fuerza)
	if tex == null:
		var img := Image.create(16, 16, false, Image.FORMAT_RGB8)
		var ruido := FastNoiseLite.new()
		ruido.seed = int(fuerza * 1000.0)
		ruido.frequency = 0.22
		for y in 16:
			for x in 16:
				var v := 1.0 - fuerza + ruido.get_noise_2d(x, y) * fuerza
				# Más oscuro abajo.
				v -= float(y) / 16.0 * fuerza * 0.5
				img.set_pixel(x, y, Color(v, v, v))
		tex = ImageTexture.create_from_image(img)
		_telas[fuerza] = tex
	for r in rutas:
		var malla := get_node_or_null(NodePath(r)) as MeshInstance3D
		if malla == null:
			continue
		var mat := malla.material_override as StandardMaterial3D
		if mat == null:
			continue
		mat.albedo_texture = tex
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST


func _vestir() -> void:
	var ropa := {
		"Cuerpo/Torso": color_abrigo, "Cuerpo/Faldon": color_abrigo,
		"Cuerpo/HombroIzq/Brazo": color_abrigo, "Cuerpo/HombroDer/Brazo": color_abrigo,
		"Cuerpo/HombroIzq/Codo/Antebrazo": color_abrigo, "Cuerpo/HombroDer/Codo/Antebrazo": color_abrigo,
		"Cuerpo/CaderaIzq/Pierna": color_pantalon, "Cuerpo/CaderaDer/Pierna": color_pantalon,
		"Cuerpo/CaderaIzq/Rodilla/Espinilla": color_pantalon, "Cuerpo/CaderaDer/Rodilla/Espinilla": color_pantalon,
		"Cuerpo/SombreroCopa": color_sombrero, "Cuerpo/SombreroAla": color_sombrero,
		"Cuerpo/Cuello": color_cuello, "Cuerpo/Chal": color_abrigo,
		"Cuerpo/Gorra": color_sombrero, "Cuerpo/Visera": color_sombrero,
	}
	for ruta in ropa:
		var malla := get_node_or_null(NodePath(ruta)) as MeshInstance3D
		if malla == null:
			continue
		var mat := StandardMaterial3D.new()
		mat.albedo_color = ropa[ruta]
		mat.roughness = 1.0
		malla.material_override = mat


func _process(delta: float) -> void:
	if _cuerpo == null:
		return

	# Velocidad del CharacterBody3D o medida por desplazamiento del padre.
	var vel := Vector3.ZERO
	if _actor != null:
		vel = _actor.velocity
	elif _padre != null and delta > 0.0:
		var salto := _padre.global_position - _pos_anterior
		_pos_anterior = _padre.global_position
		# >= 40 cm en un frame es una colocación, no un paso.
		if salto.length() < 0.4:
			vel = salto / delta

	var rapidez := Vector2(vel.x, vel.z).length()
	# Sentado no anda aunque el carro se mueva.
	if sentado:
		rapidez = 0.0

	# Quieto: respira, cambia el peso, mira.
	if rapidez < 0.05:
		_en_reposo(delta)
		return
	_quieto = false

	# Mirar hacia donde anda (modelo mira a +Z); umbral contra ruido al parar.
	if rapidez > 0.08:
		var objetivo := atan2(vel.x, vel.z)
		rotation.y = lerp_angle(rotation.y, objetivo, 1.0 - exp(-giro * delta))

	# Fase por distancia: los pies no patinan.
	_fase += rapidez * cadencia * delta

	var fuerza := clampf(rapidez / maxf(velocidad_normal, 0.01), 0.0, 1.0)
	var balanceo := sin(_fase) * amplitud * fuerza

	if _cadera_izq: _cadera_izq.rotation.x = balanceo
	if _cadera_der: _cadera_der.rotation.x = -balanceo
	# Brazos opuestos a la pierna del mismo lado.
	if _hombro_izq: _hombro_izq.rotation.x = -balanceo * 0.65
	if _hombro_der: _hombro_der.rotation.x = balanceo * 0.65
	if _codo_izq: _codo_izq.rotation.x = -0.25 * fuerza
	if _codo_der: _codo_der.rotation.x = -0.25 * fuerza

	# Rebote al doble de frecuencia que el balanceo.
	_cuerpo.position.y = _altura_base + absf(sin(_fase)) * 0.035 * fuerza


## Parado: respira, balancea el peso, mira y vuelve a la pose de reposo.
func _en_reposo(delta: float) -> void:
	# Al pararse, fijar la orientación base de las miradas.
	if not _quieto:
		_quieto = true
		_rot_reposo = rotation.y
		_mirada = 0.0
		_mirada_objetivo = 0.0
	_vida += delta

	# Respirar.
	var aire := sin(_vida * 1.25)
	_cuerpo.position.y = _altura_base + aire * 0.014
	_cuerpo.rotation.x = inclinacion + aire * 0.018
	# Cambiar el peso de pie.
	_cuerpo.rotation.z = sin(_vida * 0.41) * 0.035

	# Mirar a un lado de vez en cuando.
	if mira_alrededor:
		_proxima_mirada -= delta
		if _proxima_mirada <= 0.0:
			_mirada_objetivo = randf_range(-0.5, 0.5) if randf() < 0.6 else 0.0
			_proxima_mirada = randf_range(2.5, 7.0)
	else:
		_mirada_objetivo = 0.0
	_mirada = lerpf(_mirada, _mirada_objetivo, 1.0 - exp(-1.8 * delta))
	rotation.y = _rot_reposo + _mirada

	_recoger_el_paso(delta)


func _recoger_el_paso(delta: float) -> void:
	var t := 1.0 - exp(-7.0 * delta)
	# Pose de brazos + gesto (senos distintos por brazo).
	var mano_izq := brazo_izquierdo + gesto * sin(_vida * 2.1) * 0.6
	var mano_der := brazo_derecho + gesto * sin(_vida * 1.7 + 1.3)
	var muslo := -PI * 0.5 if sentado else 0.0
	if _cadera_izq: _cadera_izq.rotation.x = lerpf(_cadera_izq.rotation.x, muslo, t)
	if _cadera_der: _cadera_der.rotation.x = lerpf(_cadera_der.rotation.x, muslo, t)
	if _rodilla_izq: _rodilla_izq.rotation.x = lerpf(_rodilla_izq.rotation.x, -muslo, t)
	if _rodilla_der: _rodilla_der.rotation.x = lerpf(_rodilla_der.rotation.x, -muslo, t)
	if _hombro_izq: _hombro_izq.rotation.x = lerpf(_hombro_izq.rotation.x, mano_izq, t)
	if _hombro_der: _hombro_der.rotation.x = lerpf(_hombro_der.rotation.x, mano_der, t)
	if _codo_izq: _codo_izq.rotation.x = lerpf(_codo_izq.rotation.x, codo_izquierdo, t)
	if _codo_der: _codo_der.rotation.x = lerpf(_codo_der.rotation.x, codo_derecho, t)
	# Doblado, el antebrazo va hacia el centro (manos a la cara).
	if _codo_izq: _codo_izq.rotation.y = -_codo_izq.rotation.x * 0.42
	if _codo_der: _codo_der.rotation.y = _codo_der.rotation.x * 0.42


## Oculta la figura mientras se ve el retrato de esta persona.
func _al_cambiar_el_retrato(si: bool, de: String) -> void:
	if de == quien:
		visible = not si
