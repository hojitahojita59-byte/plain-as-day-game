extends Node3D
## Maqueta de la parroquia (vista de pájaro): la calle 3D desde arriba, más calles de contexto.
## Mismas coordenadas que la calle: mundo = (plano - ORIGEN) * ESCALA.

const PLANO := preload("res://scripts/ui/plano_parroquia.gd")
const ESTELAS := preload("res://scripts/estelas.gd")
const GARAMOND_SEMI := preload("res://art/fonts/EB_Garamond/static/EBGaramond-SemiBold.ttf")
const BARRIO := "res://data/barrio/soho.json"

const ESCALA := PLANO.ESCALA
## Casas de contexto, en metros.
const ANCHO_CASA_M := 5.0
const FONDO_CASA_M := 6.0
## Barra de muerte (Snow): alto, fondo y paso entre barras, en m.
const ALTO_MARCA := 0.6
const BARRA_FONDO := 0.85
const BARRA_PASO := 1.15
## Rótulos por encima de los tejados, para que no los tapen.
const ALTO_ROTULO := 12.5

const C_SUELO := Color(0.13, 0.13, 0.12)
const C_CALLE := Color(0.25, 0.24, 0.23)
const C_CASA := Color(0.82, 0.78, 0.70)
const C_CONTEXTO := Color(0.66, 0.63, 0.57)
const C_ROTULO := Color(0.95, 0.92, 0.84, 0.9)
const C_MARCA := Color(0.04, 0.03, 0.03)
const C_TINTA := Color(0.62, 0.10, 0.06)
const C_ORO := Color(1.0, 0.80, 0.28)

var _casas: Array[Dictionary] = []      # {r: Rect2 del plano, h: m}
var _pilas: Dictionary = {}             # clave de sitio -> nº de marcas
var _marcas: Node3D
var _anillo: MeshInstance3D
var _cursor: MeshInstance3D
var _estelas: Node3D
var _jugador: Node3D
var _brillos: Dictionary = {}           # id de fuente -> MeshInstance3D
var _mats: Dictionary = {}


func _ready() -> void:
	construir()


static func a_mundo(p: Vector2, y: float = 0.0) -> Vector3:
	var w := PLANO.a_mundo(p)
	return Vector3(w.x, y, w.y)


static func a_plano(v: Vector3) -> Vector2:
	return PLANO.de_mundo(Vector2(v.x, v.z))


static func rect_calle(c: Dictionary) -> Rect2:
	var w := float(c["w"])
	var largo := float(c["a"]) - float(c["de"])
	if bool(c["h"]):
		return Rect2(float(c["de"]), float(c["en"]) - w * 0.5, largo, w)
	return Rect2(float(c["en"]) - w * 0.5, float(c["de"]), w, largo)


## Centro de la casa de un asiento, o INF.
static func sitio(a: Dictionary) -> Vector2:
	var casa := PLANO.casa_de(String(a.get("calle", "")))
	return casa if casa != Vector2.INF else PLANO.punto_de_asiento(a)


## Margen para clicar el tejado y que cuente como su calle (una casa de fondo).
static func margen_de_clic() -> float:
	return 7.0 / ESCALA


static func _rect_m(centro: Vector2, tam: Vector2) -> Rect2:
	var c := PLANO.de_mundo(centro)
	var t := tam / ESCALA
	return Rect2(c - t * 0.5, t)


func construir() -> void:
	for n in get_children():
		n.free()
	_casas.clear()
	_pilas.clear()
	_suelo()
	for c in PLANO.CALLES:
		_caja(rect_calle(c), 0.0, 0.08, C_CALLE)
	var ocupado: Array[Rect2] = []
	_casas_del_barrio(ocupado)
	_contexto(ocupado)
	_brillos.clear()
	for f in Cuaderno.fuentes():
		if f["tipo"] == "bomba":
			_bomba(f["p"])
		_brillo_de(f)
	_rotulos_de_calle()
	_numeros()
	_marcas = Node3D.new()
	_marcas.name = "Marcas"
	add_child(_marcas)
	_estelas = Node3D.new()
	_estelas.name = "Estelas"
	add_child(_estelas)
	_anillo = MeshInstance3D.new()
	_anillo.visible = false
	add_child(_anillo)
	_cursor = MeshInstance3D.new()
	var aro := TorusMesh.new()
	aro.inner_radius = 2.4
	aro.outer_radius = 3.0
	aro.rings = 24
	aro.ring_segments = 4
	_cursor.mesh = aro
	_cursor.material_override = _mat(C_MARCA, true)
	_cursor.visible = false
	add_child(_cursor)
	_jugador = _marcador_del_jugador()


func _mat(color: Color, sin_luz: bool = false) -> StandardMaterial3D:
	var clave := str(color) + str(sin_luz)
	if not _mats.has(clave):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 1.0
		if sin_luz:
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mats[clave] = m
	return _mats[clave]


func _suelo() -> void:
	var m := MeshInstance3D.new()
	var p := PlaneMesh.new()
	p.size = Vector2(ESCALA * 8.0, ESCALA * 8.0)
	m.mesh = p
	m.material_override = _mat(C_SUELO)
	add_child(m)


func _caja(r: Rect2, y0: float, alto: float, color: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(r.size.x * ESCALA, alto, r.size.y * ESCALA)
	m.mesh = b
	m.material_override = _mat(color)
	m.position = a_mundo(r.get_center(), y0 + alto * 0.5)
	add_child(m)
	return m


## Las casas de la calle que se anda: una por bahía de cada tramo, como en 3D.
func _casas_del_barrio(ocupado: Array[Rect2]) -> void:
	var datos: Variant = JSON.parse_string(FileAccess.get_file_as_string(BARRIO))
	if not (datos is Dictionary):
		return
	var porte := {}
	var naves := {}
	for p in Array(datos.get("puertas", [])):
		if p.has("porte"):
			naves[p["porte"]] = []
			for j in maxi(1, int(p["porte"].get("bahias", 1))):
				porte["%s/%d" % [p["tramo"], int(p["bahia"]) + j]] = p["porte"]
	var rectoria := {}
	for e in Array(datos.get("esquinas", [])):
		var portal: Dictionary = Dictionary(e.get("portal", {}))
		if not portal.is_empty():
			rectoria["%s/%d" % [portal["tramo"], int(portal["bahia"])]] = String(e.get("nombre", ""))
	var pasos := {"+x": Vector2(5, 0), "-x": Vector2(-5, 0), "+z": Vector2(0, 5), "-z": Vector2(0, -5)}
	for t in Array(datos.get("tramos", [])):
		# El JSON da floats: a int, o 4 no está en [4.0].
		var vacias: Array[int] = []
		for v in Array(t.get("huecos", [])) + Array(t.get("bocas", [])):
			vacias.append(int(v))
		var desde: Array = t.get("desde", [0, 0])
		for b in int(t.get("bahias", 1)):
			if b in vacias:
				continue
			var centro := Vector2(float(desde[0]), float(desde[1])) + Vector2(pasos[String(t["eje"])]) * b
			var r := _rect_m(centro, Vector2(4.9, 4.9))
			var clave := "%s/%d" % [t["id"], b]
			if porte.has(clave):
				(naves[porte[clave]] as Array).append(r)
				continue
			var alto := 7.6
			_caja(r, 0.0, alto, C_CASA)
			_casas.append({"r": r, "h": alto})
			ocupado.append(r)
			if rectoria.has(clave):
				_rotulo(rectoria[clave], a_mundo(r.get_center(), alto + 0.2), 0.0, 0.03, 56)
	for n in naves:
		_nave(n, naves[n], ocupado)


## Cervecería y asilo: una nave grande, más honda y alta que las casas, con su remate.
func _nave(datos: Dictionary, bahias: Array, ocupado: Array[Rect2]) -> void:
	if bahias.is_empty():
		return
	var r: Rect2 = bahias[0]
	for b in bahias:
		r = r.merge(b)
	var dentro := _hacia_dentro(r.get_center())
	var fondo := 9.0 / ESCALA
	r = r.merge(Rect2(r.position + dentro * fondo, r.size))
	var cervecera := String(datos.get("rotulo", "")).ends_with("BREWERY")
	var color := Color(0.56, 0.34, 0.26) if cervecera else Color(0.60, 0.61, 0.60)
	var alto := 3.3 * float(datos.get("plantas", 3)) + 3.5
	_caja(r, 0.0, alto, color)
	_casas.append({"r": r, "h": alto})
	ocupado.append(r)
	var c := PLANO.a_mundo(r.get_center())
	if cervecera:
		# Chimenea alta en la esquina de atrás.
		var esq := PLANO.a_mundo(r.get_center() + dentro * r.size * 0.3)
		_caja(_rect_m(esq, Vector2(1.6, 1.6)), alto, 9.0, color.darkened(0.25))
	else:
		# Torreta con reloj en medio.
		_caja(_rect_m(c, Vector2(3.2, 3.2)), alto, 4.5, color.lightened(0.1))
	_rotulo(String(datos.get("rotulo", "")).capitalize(), a_mundo(r.get_center(), alto + (9.5 if cervecera else 5.2)), 0.0, 0.04, 72)


## Casas de contexto: a los dos lados de las calles que no se andan, y la acera sur de Broad.
func _contexto(ocupado: Array[Rect2]) -> void:
	var ancho := ANCHO_CASA_M / ESCALA
	var fondo := FONDO_CASA_M / ESCALA
	var calzadas: Array[Rect2] = []
	for c in PLANO.CALLES:
		calzadas.append(rect_calle(c))
	var rng := RandomNumberGenerator.new()
	rng.seed = 1854
	var nuevas: Array[Dictionary] = []
	for c in PLANO.CALLES:
		var lados: Array = [-1.0, 1.0] if bool(c.get("contexto", false)) else ([1.0] if String(c["n"]) == "Broad Street" else [])
		var h := bool(c["h"])
		for lado in lados:
			var centro: float = float(c["en"]) + lado * (float(c["w"]) * 0.5 + fondo * 0.5)
			var a := float(c["de"])
			while a + ancho <= float(c["a"]) + 0.0001:
				var r := Rect2(a, centro - fondo * 0.5, ancho, fondo) if h \
					else Rect2(centro - fondo * 0.5, a, fondo, ancho)
				a += ancho
				var dentro := r.grow(-0.002)
				if _choca(dentro, calzadas) or _choca(dentro, ocupado):
					continue
				ocupado.append(r)
				nuevas.append({"r": r, "h": rng.randf_range(5.5, 8.0), "tono": rng.randf_range(0.9, 1.05)})
	_casas.append_array(nuevas)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = BoxMesh.new()
	mm.instance_count = nuevas.size()
	for i in nuevas.size():
		var c: Dictionary = nuevas[i]
		var r: Rect2 = c["r"]
		var alto := float(c["h"])
		var b := Basis.from_scale(Vector3(r.size.x * ESCALA * 0.96, alto, r.size.y * ESCALA))
		mm.set_instance_transform(i, Transform3D(b, a_mundo(r.get_center(), alto * 0.5)))
		mm.set_instance_color(i, C_CONTEXTO * float(c["tono"]))
	var mi := MultiMeshInstance3D.new()
	mi.name = "Contexto"
	mi.multimesh = mm
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	mi.material_override = mat
	add_child(mi)


func _choca(r: Rect2, lista: Array[Rect2]) -> bool:
	for o in lista:
		if r.intersects(o):
			return true
	return false


## Todas las bombas iguales: el mapa no señala ninguna.
func _bomba(en: Vector2) -> void:
	var p := a_mundo(en)
	var m := MeshInstance3D.new()
	var cil := CylinderMesh.new()
	cil.top_radius = 0.4
	cil.bottom_radius = 0.5
	cil.height = 2.4
	m.mesh = cil
	m.material_override = _mat(Color(0.1, 0.1, 0.11))
	m.position = p + Vector3(0, 1.2, 0)
	add_child(m)
	_rotulo("pump", p + Vector3(0, ALTO_ROTULO * 0.5, -2.2), 0.0, 0.025, 48)


func _rotulo(texto: String, pos: Vector3, giro_y: float, tam: float, puntos: int = 96) -> Label3D:
	var l := Label3D.new()
	l.text = texto
	l.font = GARAMOND_SEMI
	l.font_size = puntos
	l.pixel_size = tam
	l.modulate = C_ROTULO
	l.outline_size = 0
	l.shaded = false
	l.double_sided = false
	l.rotation = Vector3(-PI * 0.5, giro_y, 0.0)
	l.position = pos
	add_child(l)
	return l


## Nombre de cada calle, en un tramo libre a media calle.
func _rotulos_de_calle() -> void:
	for c in PLANO.CALLES:
		var medio := (float(c["de"]) + float(c["a"])) * 0.5
		if String(c["n"]) == "Broad Street":
			medio = PLANO.de_mundo(Vector2(-50.0, 0.0)).x
		if bool(c["h"]):
			_rotulo(String(c["n"]), a_mundo(Vector2(medio, float(c["en"])), 9.0), 0.0, 0.04)
		else:
			_rotulo(String(c["n"]), a_mundo(Vector2(float(c["en"]), medio), 9.0), PI * 0.5, 0.032)


## Nº de cada casa con dirección, sobre su tejado.
func _numeros() -> void:
	for k in PLANO.DIRECCIONES:
		var casa: Vector2 = PLANO.DIRECCIONES[k]["casa"]
		var l := _rotulo(String(k).split(" ")[0], a_mundo(casa, alto_en(casa) + 0.15), 0.0, 0.03, 64)
		l.modulate = Color(0.30, 0.22, 0.14)


## Dónde está Whitehead: un farol encendido y "You".
func _marcador_del_jugador() -> Node3D:
	var raiz := Node3D.new()
	raiz.name = "Jugador"
	add_child(raiz)
	var m := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.9
	c.bottom_radius = 0.9
	c.height = 0.1
	m.mesh = c
	m.material_override = _mat(Color(1.0, 0.82, 0.4), true)
	m.position = Vector3(0, 0.2, 0)
	raiz.add_child(m)
	var l := _rotulo("You", Vector3.ZERO, 0.0, 0.03, 56)
	remove_child(l)
	raiz.add_child(l)
	l.position = Vector3(0, 0.3, -2.0)
	l.modulate = Color(1.0, 0.86, 0.5)
	raiz.visible = false
	return raiz


func poner_jugador(donde: Vector3) -> void:
	_jugador.position = Vector3(donde.x, 0.0, donde.z)
	_jugador.visible = true


## Alto del tejado bajo un sitio del plano (0 si no hay casa).
func alto_en(p: Vector2) -> float:
	for c in _casas:
		if Rect2(c["r"]).grow(0.002).has_point(p):
			return float(c["h"])
	return 0.0


func limpiar_marcas() -> void:
	for n in _marcas.get_children():
		n.free()
	_pilas.clear()


## Barras de Snow: una por muerte, en fila de la fachada hacia dentro. Devuelve la marca.
func marcar(a: Dictionary, animar: bool) -> Node3D:
	var p := sitio(a)
	if p == Vector2.INF:
		return null
	var clave := "%.3f,%.3f" % [p.x, p.y]
	var i := int(_pilas.get(clave, 0))
	_pilas[clave] = i + 1
	var hacia := _hacia_dentro(p)
	var q := p + hacia * BARRA_PASO * i / ESCALA
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(3.0, ALTO_MARCA, BARRA_FONDO) if absf(hacia.y) > 0.5 else Vector3(BARRA_FONDO, ALTO_MARCA, 3.0)
	m.mesh = b
	m.material_override = _mat(C_MARCA)
	var destino := a_mundo(q, alto_en(p) + ALTO_MARCA * 0.5)
	_marcas.add_child(m)
	if animar:
		m.position = destino + Vector3(0, 18.0, 0)
		var t := m.create_tween()
		t.tween_property(m, "position", destino, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.tween_property(m, "scale", Vector3(1.25, 0.7, 1.25), 0.06)
		t.tween_property(m, "scale", Vector3.ONE, 0.12)
	else:
		m.position = destino
	return m


## Lejos de la calle más cercana, en el eje que la cruza.
func _hacia_dentro(p: Vector2) -> Vector2:
	var mejor := INF
	var dir := Vector2.DOWN
	for c in PLANO.CALLES:
		var h := bool(c["h"])
		var a_traves := p.y if h else p.x
		var a_lo_largo := p.x if h else p.y
		if a_lo_largo < float(c["de"]) or a_lo_largo > float(c["a"]):
			continue
		var d := a_traves - float(c["en"])
		if absf(d) < mejor:
			mejor = absf(d)
			var sg := 1.0 if d >= 0.0 else -1.0
			dir = Vector2(0, sg) if h else Vector2(sg, 0)
	return dir


# --- Estelas ---

## Disco de luz bajo cada fuente; crece con las estelas que llegan.
func _brillo_de(f: Dictionary) -> void:
	var m := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 1.0
	c.bottom_radius = 1.0
	c.height = 0.05
	m.mesh = c
	m.material_override = ESTELAS.material("muerte", 10.0)
	m.position = a_mundo(f["p"], 0.3)
	m.visible = false
	add_child(m)
	_brillos[f["id"]] = m


func limpiar_estelas() -> void:
	for n in _estelas.get_children():
		n.free()
	for b in _brillos.values():
		(b as Node3D).visible = false


## Una estela (Cuaderno.estela) por las calles; animar la dibuja poco a poco.
func estela(e: Dictionary, animar: bool, segundos: float = 2.2) -> MeshInstance3D:
	var plano := ESTELAS.camino(e["desde"], e["hasta"])
	var puntos := PackedVector3Array()
	for p in plano:
		puntos.append(a_mundo(p, 0.35))
	# Cada estela, a su carril (fijo por ficha).
	puntos = ESTELAS.desplazar(puntos, (absi(String(e["id"]).hash()) % 7 - 3) * 1.3)
	var ancho := 2.2 if e["clase"] == "muerte" else 1.7
	var m := MeshInstance3D.new()
	m.mesh = ESTELAS.cinta(puntos, ancho)
	var metros := ESTELAS.largo(plano) * ESCALA
	m.material_override = ESTELAS.material(String(e["clase"]), metros)
	m.set_meta(&"plano", plano)
	m.set_meta(&"ficha", e["id"])
	_estelas.add_child(m)
	if animar:
		ESTELAS.animar(m, segundos)
	return m


## Brillo de cada fuente según cuántas estelas de muerte llegan.
func contar_en_fuentes(estelas: Array[Dictionary]) -> Dictionary:
	var n := {}
	for e in estelas:
		if e["clase"] == "muerte":
			n[e["fuente"]] = int(n.get(e["fuente"], 0)) + 1
	for id in _brillos:
		var b: MeshInstance3D = _brillos[id]
		var k := int(n.get(id, 0))
		b.visible = k > 0
		var r := 1.4 + 0.45 * k
		b.scale = Vector3(r, 1.0, r)
	return n


func estelas_dibujadas() -> Array[Node]:
	return _estelas.get_children()


## Aro hueco que sigue al ratón con un nombre en la mano; INF lo oculta.
func cursor(p: Vector2) -> void:
	_cursor.visible = p != Vector2.INF
	if _cursor.visible:
		_cursor.position = a_mundo(p, alto_en(p) + 0.4)


func marcas() -> int:
	return _marcas.get_child_count()


## Anillo de tinta del cerco (radio en unidades del plano); r <= 0 lo oculta.
func anillo(centro: Vector2, r: float) -> void:
	if r <= 0.002:
		_anillo.visible = false
		return
	var t := TorusMesh.new()
	t.inner_radius = r * ESCALA - 0.7
	t.outer_radius = r * ESCALA + 0.7
	t.rings = 64
	t.ring_segments = 6
	_anillo.mesh = t
	var m := _mat(C_ORO if Casefile.has("broad_street_racimo") else C_TINTA, true).duplicate() as StandardMaterial3D
	m.no_depth_test = true
	m.render_priority = 2
	_anillo.material_override = m
	_anillo.scale = Vector3(1.0, 0.3, 1.0)
	# Por encima de los tejados: las casas no lo tapan.
	_anillo.position = a_mundo(centro, ALTO_ROTULO)
	_anillo.visible = true


## Cerco bien hecho: el anillo se vuelve oro y suelta un halo con chispas.
func anillo_dorado() -> void:
	if not _anillo.visible:
		return
	var m := _anillo.material_override as StandardMaterial3D
	create_tween().tween_property(m, "albedo_color", C_ORO, 0.5)
	var r := (_anillo.mesh as TorusMesh).inner_radius + 0.7
	for k in 3:
		var halo := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = r - 0.5
		tm.outer_radius = r + 0.5
		tm.rings = 64
		tm.ring_segments = 6
		halo.mesh = tm
		var hm := _mat(C_ORO, true).duplicate() as StandardMaterial3D
		hm.no_depth_test = true
		hm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		hm.render_priority = 1
		halo.material_override = hm
		halo.position = _anillo.position
		halo.scale = Vector3(1.0, 0.3, 1.0)
		add_child(halo)
		var th := halo.create_tween().set_parallel()
		th.tween_property(halo, "scale", Vector3(1.4, 0.3, 1.4), 1.5).set_delay(k * 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		th.tween_property(hm, "albedo_color:a", 0.0, 1.5).set_delay(k * 0.4)
		th.chain().tween_callback(halo.queue_free)
	var chispas := CPUParticles3D.new()
	chispas.amount = 70
	chispas.lifetime = 1.8
	chispas.one_shot = true
	chispas.explosiveness = 0.5
	chispas.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	chispas.emission_ring_axis = Vector3.UP
	chispas.emission_ring_radius = r
	chispas.emission_ring_inner_radius = r - 0.6
	chispas.emission_ring_height = 0.2
	chispas.direction = Vector3.UP
	chispas.spread = 25.0
	chispas.initial_velocity_min = 3.0
	chispas.initial_velocity_max = 8.0
	chispas.gravity = Vector3(0, -3.0, 0)
	chispas.scale_amount_min = 0.5
	chispas.scale_amount_max = 1.2
	var bola := SphereMesh.new()
	bola.radius = 0.35
	bola.height = 0.7
	chispas.mesh = bola
	var cm := _mat(Color(1.0, 0.95, 0.7), true).duplicate() as StandardMaterial3D
	cm.no_depth_test = true
	chispas.material_override = cm
	chispas.position = _anillo.position
	add_child(chispas)
	chispas.emitting = true
	get_tree().create_timer(3.5).timeout.connect(chispas.queue_free)
