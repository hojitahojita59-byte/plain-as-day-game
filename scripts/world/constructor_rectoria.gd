@tool
extends Node
## Construye la rectoría en código: estudio, salita con cocina y escalera, mesa, plano y puerta.
## Kit Kenney a escala 1/2 (ESCALA). Origen de las piezas en una esquina.
## Sin contorno: el casco invertido rompe las piezas del kit en lascas.

const ESCALA := 2.0
const KIT := "res://art/models/Furniture/%s.glb"
const MAQUETA := preload("res://scripts/world/maqueta.gd")

## Filtro (multiplica) sobre el color del kit, no color plano.
@export var tinte_madera: Color = Color(0.38, 0.28, 0.20):
	set(v):
		tinte_madera = v
		if Engine.is_editor_hint():
			_rehacer.call_deferred()

## Cal sucia de humo.
@export var tinte_pared: Color = Color(0.74, 0.70, 0.62):
	set(v):
		tinte_pared = v
		if Engine.is_editor_hint():
			_rehacer.call_deferred()

@export var rehacer: bool = false:
	set(v):
		rehacer = false
		if v and Engine.is_editor_hint():
			_rehacer.call_deferred()

@export var cuarto_path: NodePath = ^"../Cuarto"

## Límites de la casa, en metros. El estudio va de x = -3 a 3.
const X0 := -9.0
const X1 := 3.0
const Z0 := -2.0
const Z1 := 2.0
## Arco abierto entre el estudio y la salita.
const X_ARCO := -3.0
## Tamaño de una pieza de pared/suelo ya escalada.
const TRAMO := 2.0
## Hueco del techo sobre lo alto de la escalera.
const HUECO_X := -7.42
const HUECO_Z := 0.0

var _cuarto: Node3D


func _ready() -> void:
	_cuarto = get_node_or_null(cuarto_path) as Node3D
	if _cuarto == null:
		push_error("ConstructorRectoria: no encuentro el nodo Cuarto.")
		return
	_levantar()
	if not Engine.is_editor_hint():
		# Whitehead tampoco: en casa nada lleva contorno.
		var whitehead := get_node_or_null(^"../Whitehead")
		if whitehead != null:
			_sin_contorno(whitehead)
		var noche := CanvasLayer.new()
		noche.name = "Noche"
		noche.add_to_group(&"noche")
		noche.set_script(load("res://scripts/world/noche.gd"))
		add_child(noche)
		# El mismo mapa que en la calle: el escritorio lo abre.
		var vista := CanvasLayer.new()
		vista.name = "VistaPajaro"
		vista.add_to_group(&"vista_pajaro")
		vista.set_script(load("res://scripts/world/vista_pajaro.gd"))
		add_child(vista)


func _rehacer() -> void:
	_cuarto = get_node_or_null(cuarto_path) as Node3D
	if _cuarto == null:
		return
	for h in _cuarto.get_children():
		_cuarto.remove_child(h)
		h.queue_free()
	_levantar()


func _levantar() -> void:
	_suelo()
	_paredes()
	_techo()
	_muebles()
	_vida_del_cuarto()
	_salita()
	_cocina()
	_escalera()
	_remates()
	_calle_de_noche()
	_topes()
	_hoja_de_la_puerta()
	_papeles_en_la_mesa()
	_plano_en_la_pared()
	_lo_clicable()
	_sin_contorno(_cuarto)


## Marca todo el cuarto sin contorno (el plano de pared, en su SubViewport, no).
func _sin_contorno(n: Node) -> void:
	if n is SubViewport:
		return
	if n is MeshInstance3D:
		n.set_meta(&"sin_contorno", true)
	for h in n.get_children():
		_sin_contorno(h)


# ------------------------------------------------------------------ el cascarón

func _suelo() -> void:
	var raiz := _nodo("Suelo")
	var losa := Color(0.50, 0.47, 0.43)
	# la baldosa crece hacia +x y -z; losas de piedra en la cocina
	for i in int((X1 - X0) / TRAMO):
		var x := X0 + TRAMO * float(i)
		for j in 2:
			_poner(raiz, "floorFull", "Baldosa%d_%d" % [i, j],
				Vector3(x, 0.0, Z0 + TRAMO * float(j + 1)),
				0.0, losa if x < -5.0 else tinte_madera * 1.25)


## Cada pared mira hacia dentro; el grosor queda fuera.
func _paredes() -> void:
	var raiz := _nodo("Paredes")
	var n := int((X1 - X0) / TRAMO)

	# FONDO (z = Z0): la del estudio lleva la ventana
	for i in n:
		var x := X0 + TRAMO * float(i)
		_poner(raiz, "wallWindow" if is_equal_approx(x, -1.0) else "wall", "Fondo%d" % i,
			Vector3(x, 0.0, Z0), 0.0, tinte_pared)

	# FRENTE (z = Z1): la puerta de la calle y la ventana de la cocina; girada PI, el ancho corre hacia -x
	for i in n:
		var pieza := "wall"
		if i == 0:
			pieza = "wallDoorway"
		elif i == 4:
			pieza = "wallWindow"
		_poner(raiz, pieza, "Frente%d" % i,
			Vector3(X1 - TRAMO * float(i), 0.0, Z1), PI, tinte_pared)

	# IZQUIERDA (x = X0): mira a +x, y su ancho corre hacia -z.
	for j in 2:
		_poner(raiz, "wall", "Izq%d" % j,
			Vector3(X0, 0.0, Z1 - TRAMO * float(j)), PI * 0.5, tinte_pared)

	# DERECHA (x = X1): mira a -x, y su ancho corre hacia +z.
	for j in 2:
		_poner(raiz, "wall", "Der%d" % j,
			Vector3(X1, 0.0, Z0 + TRAMO * float(j)), -PI * 0.5, tinte_pared)


## Techo más oscuro que la pared, con el hueco de la escalera.
const ALTO_PARED := 2.58

func _techo() -> void:
	var raiz := _nodo("Techo")
	var sobra := 0.3
	var color := tinte_pared * Color(0.8, 0.78, 0.75)
	var y := ALTO_PARED + 0.05
	_bloque(Vector3((HUECO_X + X1 + sobra) * 0.5, y, (Z0 + Z1) * 0.5),
		Vector3(X1 + sobra - HUECO_X, 0.1, Z1 - Z0 + sobra * 2.0), color)
	_bloque(Vector3((X0 - sobra + HUECO_X) * 0.5, y, (HUECO_Z + Z1 + sobra) * 0.5),
		Vector3(HUECO_X - X0 + sobra, 0.1, Z1 + sobra - HUECO_Z), color)

	_bloque(Vector3((X0 + HUECO_X) * 0.5, 2.63, -1.86), Vector3(HUECO_X - X0, 0.1, 0.28), tinte_madera)
	_rellano()
	_cerrar_lote(raiz, "Losas")


## Rellano de arriba, lo que se ve por el hueco: pasillo con puertas, cuadro y barandilla.
const RELLANO_X1 := -5.2
const RELLANO_Z1 := 1.0
const ALTO_ARRIBA := 2.3

func _rellano() -> void:
	var suelo := ALTO_PARED + 0.1
	var techo := suelo + ALTO_ARRIBA
	var cal := tinte_pared * Color(0.85, 0.82, 0.78)
	var madera := tinte_madera * Color(0.7, 0.7, 0.7)
	var y0 := ALTO_PARED + 0.01
	var cy := (y0 + techo) * 0.5
	var h := techo - y0
	var ancho := RELLANO_X1 - X0
	var fondo := RELLANO_Z1 - Z0
	# paredes, techo y tarima
	_bloque(Vector3((X0 + RELLANO_X1) * 0.5, cy, Z0 - 0.05), Vector3(ancho + 0.2, h, 0.1), cal)
	_bloque(Vector3((X0 + RELLANO_X1) * 0.5, cy, RELLANO_Z1 + 0.05), Vector3(ancho + 0.2, h, 0.1), cal)
	_bloque(Vector3(X0 - 0.05, cy, (Z0 + RELLANO_Z1) * 0.5), Vector3(0.1, h, fondo), cal)
	_bloque(Vector3(RELLANO_X1 + 0.05, cy, (Z0 + RELLANO_Z1) * 0.5), Vector3(0.1, h, fondo), cal)
	_bloque(Vector3((X0 + RELLANO_X1) * 0.5, techo + 0.05, (Z0 + RELLANO_Z1) * 0.5),
		Vector3(ancho + 0.2, 0.1, fondo + 0.2), cal * Color(0.8, 0.78, 0.75))
	var tarima := tinte_madera * Color(1.1, 1.05, 1.0)
	_bloque(Vector3((HUECO_X + RELLANO_X1) * 0.5, suelo + 0.005, (Z0 + RELLANO_Z1) * 0.5),
		Vector3(RELLANO_X1 - HUECO_X, 0.01, fondo), tarima)
	_bloque(Vector3((X0 + HUECO_X) * 0.5, suelo + 0.005, (HUECO_Z + RELLANO_Z1) * 0.5),
		Vector3(HUECO_X - X0, 0.01, RELLANO_Z1 - HUECO_Z), tarima)
	# canto del forjado en el hueco y zócalos
	_bloque(Vector3(HUECO_X + 0.02, ALTO_PARED + 0.05, (Z0 + HUECO_Z) * 0.5), Vector3(0.04, 0.12, HUECO_Z - Z0), madera)
	_bloque(Vector3((X0 + HUECO_X) * 0.5, ALTO_PARED + 0.05, HUECO_Z + 0.02), Vector3(HUECO_X - X0, 0.12, 0.04), madera)
	_bloque(Vector3((X0 + RELLANO_X1) * 0.5, suelo + 0.06, Z0 + 0.015), Vector3(ancho, 0.12, 0.03), madera)
	_bloque(Vector3(X0 + 0.015, suelo + 0.06, (Z0 + RELLANO_Z1) * 0.5), Vector3(0.03, 0.12, fondo), madera)

	# barandilla del rellano: deja libre la llegada de la escalera
	var bx := HUECO_X + 0.05
	var alto := 0.84
	_bloque(Vector3(bx, suelo + alto, (-1.25 + HUECO_Z) * 0.5), Vector3(0.07, 0.06, 1.3), madera)
	_bloque(Vector3((X0 + bx) * 0.5, suelo + alto, HUECO_Z + 0.05), Vector3(bx - X0, 0.06, 0.07), madera)
	for z in [-1.25, HUECO_Z + 0.05]:
		_bloque(Vector3(bx, suelo + alto * 0.5 + 0.03, z), Vector3(0.1, alto + 0.06, 0.1), madera)
	var zb := -1.05
	while zb < HUECO_Z:
		_bloque(Vector3(bx, suelo + alto * 0.5, zb), Vector3(0.035, alto, 0.035), madera)
		zb += 0.2
	var xb := HUECO_X - 0.15
	while xb > X0 + 0.05:
		_bloque(Vector3(xb, suelo + alto * 0.5, HUECO_Z + 0.05), Vector3(0.035, alto, 0.035), madera)
		xb -= 0.2

	# dos puertas de cuartos en el fondo: una frente a la llegada de la escalera
	for px in [-8.2, -6.0]:
		_bloque(Vector3(px, suelo + 1.02, Z0 + 0.02), Vector3(1.0, 2.1, 0.04), madera * Color(0.8, 0.8, 0.8))
		_bloque(Vector3(px, suelo + 1.0, Z0 + 0.05), Vector3(0.82, 2.0, 0.04), tinte_madera * Color(0.8, 0.78, 0.76))
		for p in [Vector2(-0.2, 0.55), Vector2(0.2, 0.55), Vector2(-0.2, 1.45), Vector2(0.2, 1.45)]:
			_bloque(Vector3(px + p.x, suelo + p.y, Z0 + 0.075), Vector3(0.28, 0.7 if p.y < 1.0 else 0.8, 0.012),
				tinte_madera * Color(0.66, 0.64, 0.62))
		_bloque(Vector3(px + 0.3, suelo + 1.0, Z0 + 0.09), Vector3(0.05, 0.05, 0.04), Color(0.70, 0.55, 0.26))

	# cuadro en la pared de la izquierda, sobre el hueco, y un aplique apagado
	_cuadro(Vector3(X0 + 0.02, suelo + 1.45, -0.9), Vector2(0.5, 0.62), Color(0.30, 0.30, 0.26), PI * 0.5)
	_bloque(Vector3(X0 + 0.04, suelo + 1.6, 0.5), Vector3(0.06, 0.16, 0.08), Color(0.55, 0.45, 0.25))
	_bloque(Vector3((X0 + RELLANO_X1) * 0.5, techo - 0.06, (Z0 + RELLANO_Z1) * 0.5), Vector3(0.12, 0.12, fondo), madera)


# -------------------------------------------------------------------- el ajuar

func _muebles() -> void:
	var raiz := _nodo("Muebles")

	# origen en el canto izq.: -0,71 para centrar en x = 0
	_poner(raiz, "desk", "Mesa", Vector3(-0.71, 0.0, -1.2), 0.0, tinte_madera)

	# media vuelta, de cara a la mesa
	_poner(raiz, "chair", "Silla", Vector3(0.2, 0.0, -0.62), PI, tinte_madera)

	_poner(raiz, "lampSquareTable", "Quinque", Vector3(-0.58, 0.76, -1.6), 0.0,
		Color(0.72, 0.66, 0.52))

	_poner(raiz, "bookcaseClosed", "Estanteria1", Vector3(2.5, 0.0, -1.6),
		-PI * 0.5, tinte_madera)
	_poner(raiz, "bookcaseOpen", "Estanteria2", Vector3(2.5, 0.0, -0.6),
		-PI * 0.5, tinte_madera)

	_poner(raiz, "rugRectangle", "Alfombra", Vector3(-1.57, 0.02, 1.3), 0.0, Color.WHITE,
		{"carpet": Color(0.34, 0.20, 0.17), "carpetDarker": Color(0.22, 0.12, 0.10)})

	# junto al arco: mesita y planta; el perchero, al pie de la escalera
	_poner(raiz, "sideTable", "Mesita", Vector3(-2.2, 0.0, 1.98), 0.0, tinte_madera)
	_poner(raiz, "pottedPlant", "Planta", Vector3(-0.85, 0.0, 1.72), 0.0, Color.WHITE,
		{"wood": Color(0.42, 0.24, 0.16), "woodDark": Color(0.22, 0.15, 0.10), "plant": Color(0.22, 0.34, 0.18)})
	_poner(raiz, "coatRackStanding", "Perchero", Vector3(-7.0, 0.0, 1.7), 0.0, tinte_madera)


## Atrezo del estudio: chimenea (también luz), libros, crucifijo, cortinas, ventana.
## Todo fuera del camino de la puerta a la silla.
func _vida_del_cuarto() -> void:
	var raiz := _nodo("Vida")
	var piedra := Color(0.30, 0.28, 0.27)
	var madera := tinte_madera * Color(0.85, 0.85, 0.85)

	# --- La chimenea, en la pared derecha, mirando al cuarto ---
	var z := 0.95
	_bloque(Vector3(2.72, 0.03, z), Vector3(0.56, 0.06, 1.55), piedra)
	_bloque(Vector3(2.86, 0.52, z - 0.58), Vector3(0.28, 1.04, 0.26), piedra)
	_bloque(Vector3(2.86, 0.52, z + 0.58), Vector3(0.28, 1.04, 0.26), piedra)
	_bloque(Vector3(2.86, 0.92, z), Vector3(0.28, 0.24, 1.42), piedra)
	_bloque(Vector3(2.80, 1.08, z), Vector3(0.42, 0.07, 1.6), madera)
	_bloque(Vector3(2.96, 0.42, z), Vector3(0.06, 0.8, 0.92), Color(0.03, 0.02, 0.02))
	_brasa(raiz, "Brasas", Vector3(2.86, 0.09, z), Vector3(0.28, 0.08, 0.6))
	_bloque(Vector3(2.84, 0.16, z - 0.08), Vector3(0.12, 0.1, 0.5), Color(0.18, 0.12, 0.08))
	_bloque(Vector3(2.88, 0.2, z + 0.06), Vector3(0.1, 0.1, 0.46), Color(0.16, 0.11, 0.07))
	_fuego(raiz, "Fuego", Vector3(2.5, 0.45, z), Color(1.0, 0.56, 0.26), 1.7, 4.6, 0.28)
	# guardafuegos de latón
	_bloque(Vector3(2.5, 0.2, z), Vector3(0.02, 0.02, 1.0), Color(0.55, 0.42, 0.2))
	for dz in [-0.48, 0.48]:
		_bloque(Vector3(2.55, 0.1, z + dz), Vector3(0.1, 0.2, 0.02), Color(0.55, 0.42, 0.2))

	# en la repisa: reloj y dos velas
	_bloque(Vector3(2.8, 1.25, z), Vector3(0.14, 0.27, 0.2), madera * Color(0.7, 0.7, 0.7))
	_bloque(Vector3(2.725, 1.28, z), Vector3(0.01, 0.11, 0.11), Color(0.86, 0.82, 0.72))
	for dz in [-0.55, 0.55]:
		_bloque(Vector3(2.8, 1.16, z + dz), Vector3(0.07, 0.09, 0.07), Color(0.55, 0.45, 0.25))
		_bloque(Vector3(2.8, 1.29, z + dz), Vector3(0.04, 0.18, 0.04), Color(0.9, 0.88, 0.8))
	_cuadro(Vector3(2.97, 1.72, z), Vector2(0.72, 0.52), Color(0.32, 0.36, 0.30), -PI * 0.5)
	_poner(raiz, "rugRound", "AlfombraFuego", Vector3(2.0, 0.02, z), 0.0, Color.WHITE,
		{"carpet": Color(0.40, 0.18, 0.14), "carpetDarker": Color(0.26, 0.11, 0.09)})

	# --- Libros en las baldas ---
	for nombre in ["Estanteria1", "Estanteria2"]:
		var e := _cuarto.find_child(nombre, true, false) as Node3D
		if e != null:
			_llenar_de_libros(e)

	# --- Mesa: libros, tintero y pluma ---
	_libros_de_la_mesa()
	_bloque(Vector3(0.36, 0.81, -1.3), Vector3(0.07, 0.07, 0.07), Color(0.06, 0.06, 0.07))
	_bloque(Vector3(0.3, 0.78, -1.24), Vector3(0.012, 0.01, 0.26), Color(0.85, 0.82, 0.74),
		Basis(Vector3.UP, 0.7))

	# --- Ventana: Soho de noche ---
	_ventana_de_noche(raiz)

	# --- Crucifijo, pared del fondo junto al arco ---
	var cruz := madera * Color(0.7, 0.7, 0.7)
	_bloque(Vector3(-2.62, 1.85, Z0 + 0.03), Vector3(0.06, 0.52, 0.04), cruz)
	_bloque(Vector3(-2.62, 1.95, Z0 + 0.03), Vector3(0.32, 0.06, 0.04), cruz)

	# --- Cortinas ---
	var granate := Color(0.36, 0.14, 0.13)
	for x in [-0.78, 0.78]:
		_bloque(Vector3(x, 1.25, Z0 + 0.1), Vector3(0.34, 2.1, 0.06), granate)
	_bloque(Vector3(0.0, 2.33, Z0 + 0.1), Vector3(2.0, 0.08, 0.1), madera)

	# --- Mesita junto al arco: jarrón y velón; cuadro encima ---
	_cilindro(Vector3(-1.5, 0.89, 1.76), 0.07, 0.24, Color(0.30, 0.36, 0.42))
	_cilindro(Vector3(-1.9, 0.84, 1.78), 0.035, 0.14, Color(0.55, 0.45, 0.25))
	_cilindro(Vector3(-1.9, 0.97, 1.78), 0.02, 0.12, Color(0.9, 0.88, 0.8))
	_cuadro(Vector3(-1.65, 1.65, Z1 - 0.02), Vector2(0.6, 0.46), Color(0.42, 0.38, 0.28), PI)

	_cerrar_lote(raiz, "Atrezo")


## Brasas o lumbre: emiten, van aparte del lote.
func _brasa(raiz: Node3D, nombre: String, pos: Vector3, tam: Vector3) -> void:
	var brasas := _caja(raiz, nombre, pos, tam, Color(0.9, 0.36, 0.12))
	var mb := brasas.material_override as StandardMaterial3D
	mb.emission_enabled = true
	mb.emission = Color(1.0, 0.42, 0.12)
	mb.emission_energy_multiplier = 2.2


## Luz de fuego, sin sombras (Compatibility).
func _fuego(raiz: Node3D, nombre: String, pos: Vector3, color: Color, energia: float,
		alcance: float, viveza: float) -> OmniLight3D:
	var fuego := OmniLight3D.new()
	fuego.name = nombre
	fuego.set_script(load("res://scripts/world/llama.gd"))
	fuego.set(&"viveza", viveza)
	fuego.light_color = color
	fuego.light_energy = energia
	fuego.omni_range = alcance
	fuego.omni_attenuation = 1.3
	raiz.add_child(fuego)
	fuego.position = pos
	return fuego


## Cuadro colgado: marco y lienzo. `giro` orienta la cara hacia el cuarto (0 = mira a +z).
func _cuadro(pos: Vector3, tam: Vector2, lienzo: Color, giro: float) -> void:
	var b := Basis(Vector3.UP, giro)
	_bloque(pos, Vector3(tam.x, tam.y, 0.04), tinte_madera * Color(0.6, 0.6, 0.6), b)
	_bloque(pos + b * Vector3(0, 0, 0.022), Vector3(tam.x - 0.1, tam.y - 0.1, 0.01), lienzo, b)


## Cielo y tejados tras la pared del fondo (solo visibles por la ventana).
func _ventana_de_noche(raiz: Node3D) -> void:
	var cielo := MeshInstance3D.new()
	cielo.name = "Cielo"
	var q := QuadMesh.new()
	q.size = Vector2(30, 26)
	cielo.mesh = q
	var mc := StandardMaterial3D.new()
	mc.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mc.albedo_color = Color(0.17, 0.22, 0.33)
	mc.disable_fog = true
	cielo.material_override = mc
	raiz.add_child(cielo)
	cielo.position = Vector3(0, 9.0, Z0 - 9.0)

	var tejado := Color(0.035, 0.04, 0.055)
	var luz := Color(0.95, 0.72, 0.38)
	var semilla := 11
	var x := -5.0
	while x < 5.0:
		semilla = (semilla * 1103515245 + 12345) & 0x7fffffff
		var r := float(semilla % 1000) / 1000.0
		var ancho := 1.1 + r * 1.3
		var alto := 2.6 + r * 1.0
		var c := Vector3(x + ancho * 0.5, alto * 0.5 - 0.6, Z0 - 6.0 - r * 1.5)
		_bloque_noche(c, Vector3(ancho, alto, 0.4), tejado)
		if r > 0.45:
			_bloque_noche(c + Vector3(ancho * 0.25, alto * 0.5 + 0.25, 0), Vector3(0.22, 0.5, 0.22), tejado)
		if r > 0.55:
			_bloque_noche(c + Vector3((r - 0.7) * ancho, alto * 0.18, 0.21), Vector3(0.18, 0.26, 0.01), luz)
		x += ancho + 0.05

	# dos ventanas fijas que se ven desde la silla
	for p in [Vector3(-0.7, 1.15, Z0 - 5.7), Vector3(1.05, 1.75, Z0 - 5.7)]:
		_bloque_noche(p, Vector3(0.24, 0.34, 0.01), Color(0.98, 0.76, 0.42))


# ------------------------------------------------------------------ los libros

const TAPAS := [Color(0.42, 0.16, 0.13), Color(0.18, 0.24, 0.32), Color(0.34, 0.28, 0.16),
	Color(0.15, 0.24, 0.17), Color(0.46, 0.38, 0.27), Color(0.26, 0.12, 0.17), Color(0.12, 0.12, 0.13)]
const HOJAS := Color(0.84, 0.80, 0.68)
const DORADO := Color(0.62, 0.50, 0.26)


## Un libro: dos tapas, lomo y hojas. Ejes: x grosor, y alto, z fondo (lomo en +z).
func _libro(xf: Transform3D, grueso: float, alto: float, fondo: float, color: Color, oro: bool) -> void:
	var tapa := minf(0.006, grueso * 0.2)
	var delante := -fondo * 0.5 + 0.004
	var detras := fondo * 0.5 - tapa
	_bloque_en(xf, Vector3(0, 0, (delante + detras) * 0.5),
		Vector3(grueso - tapa * 2.0, alto - 0.012, detras - delante), HOJAS)
	_bloque_en(xf, Vector3(-grueso * 0.5 + tapa * 0.5, 0, 0), Vector3(tapa, alto, fondo), color)
	_bloque_en(xf, Vector3(grueso * 0.5 - tapa * 0.5, 0, 0), Vector3(tapa, alto, fondo), color)
	_bloque_en(xf, Vector3(0, 0, fondo * 0.5 - tapa * 0.5), Vector3(grueso, alto, tapa), color)
	if oro:
		for k in [-0.32, 0.3]:
			_bloque_en(xf, Vector3(0, alto * k, fondo * 0.5 + 0.001), Vector3(grueso * 0.92, 0.012, 0.003), DORADO)


## Libros en pie sobre las tres baldas del kit (alturas del .glb, sin escalar).
const BALDAS := [0.13, 0.37, 0.61]

func _llenar_de_libros(estanteria: Node3D) -> void:
	var g := estanteria.global_transform
	var giro := g.basis.orthonormalized()
	var semilla := (int(absf(g.origin.z) * 1000.0) + 7) & 0xffff
	for y0 in BALDAS:
		var x := 0.045
		while x < 0.35:
			semilla = (semilla * 1103515245 + 12345) & 0x7fffffff
			var r := float(semilla % 1000) / 1000.0
			var r2 := fmod(r * 7.31, 1.0)
			var color: Color = TAPAS[semilla % TAPAS.size()]
			# un montón tumbado en un hueco
			if r > 0.9 and x < 0.24:
				var y := float(y0)
				for k in 3:
					var g2 := 0.012 + 0.004 * float(k % 2)
					var c := g * Vector3(x + 0.055, y + g2 * 0.5, -0.11)
					var b := giro * Basis(Vector3.UP, 0.08 * float(k - 1)) * Basis(Vector3.BACK, PI * 0.5)
					_libro(Transform3D(b, c), g2 * ESCALA, 0.1 * ESCALA, 0.15 * ESCALA,
						TAPAS[(semilla + k) % TAPAS.size()], false)
					y += g2
				x += 0.12
				continue
			var grueso := 0.010 + r * 0.012
			if x + grueso > 0.355:
				break
			var alto := 0.13 + r2 * 0.06
			var fondo := 0.15 + r2 * 0.03
			var centro := g * Vector3(x + grueso * 0.5, float(y0) + alto * 0.5, -0.02 - fondo * 0.5)
			_libro(Transform3D(giro, centro), grueso * ESCALA, alto * ESCALA, fondo * ESCALA, color, r2 > 0.45)
			x += grueso + 0.0015


## Libros de la mesa: una fila en pie con sujetalibros y un montón tumbado.
func _libros_de_la_mesa() -> void:
	var tablero := 0.768
	var x := 0.3
	var medidas := [[0.045, 0.27, 0], [0.035, 0.25, 1], [0.05, 0.28, 3], [0.03, 0.22, 4], [0.04, 0.26, 2]]
	for m in medidas:
		var g := float(m[0])
		var a := float(m[1])
		_libro(Transform3D(Basis(), Vector3(x + g * 0.5, tablero + a * 0.5, -1.84)), g, a, 0.18,
			TAPAS[int(m[2])], true)
		x += g + 0.003
	# sujetalibros de hierro
	_bloque(Vector3(x + 0.008, tablero + 0.08, -1.84), Vector3(0.012, 0.16, 0.12), Color(0.1, 0.1, 0.11))
	_bloque(Vector3(x + 0.05, tablero + 0.004, -1.84), Vector3(0.09, 0.008, 0.12), Color(0.1, 0.1, 0.11))

	var y := tablero
	var tumbados := [[0.04, 0.26, 0.19, 5, 0.22], [0.03, 0.22, 0.16, 1, 0.34]]
	for t in tumbados:
		var g := float(t[0])
		var b := Basis(Vector3.UP, float(t[4])) * Basis(Vector3.BACK, PI * 0.5)
		_libro(Transform3D(b, Vector3(0.58, y + g * 0.5, -1.42)), g, float(t[1]), float(t[2]),
			TAPAS[int(t[3])], true)
		y += g


# ------------------------------------------------------------- salita y cocina

## Salita: sofá de cara al fogón, alfombra, mesita de té, butaca, lámpara, cuadros.
func _salita() -> void:
	var raiz := _nodo("Salita")
	var tapiz := Color(0.36, 0.13, 0.12)
	_poner(raiz, "loungeSofa", "Sofa", Vector3(-3.3, 0.0, 1.17), PI, Color.WHITE,
		{"carpet": tapiz, "wood": Color(0.16, 0.10, 0.07)})
	_poner(raiz, "loungeChair", "Butaca", Vector3(-5.37, 0.0, 1.35), PI * 0.78, Color.WHITE,
		{"carpet": Color(0.17, 0.25, 0.19), "wood": Color(0.16, 0.10, 0.07)})
	# alfombra redonda centrada en (-4.25, 0.45)
	_poner(raiz, "rugRound", "AlfombraSalita", Vector3(-5.17, 0.015, 1.37), 0.0, Color.WHITE,
		{"carpet": Color(0.30, 0.16, 0.12), "carpetDarker": Color(0.44, 0.30, 0.18)})
	# mesita de té centrada en (-4.25, 0.5)
	_poner(raiz, "tableCoffee", "MesitaTe", Vector3(-3.99, 0.0, 0.7), 0.0, tinte_madera)
	# la lámpara de pie, ya del lado del estudio, junto a la pilastra
	_poner(raiz, "lampRoundFloor", "Lampara", Vector3(-2.62, 0.0, 1.75), 0.0, Color.WHITE,
		{"metal": Color(0.32, 0.26, 0.16), "lamp": Color(0.95, 0.82, 0.58)})
	var luz := _fuego(raiz, "LuzLampara", Vector3(-2.75, 1.55, 1.5), Color(1.0, 0.80, 0.52), 1.15, 3.6, 0.05)
	luz.omni_attenuation = 1.1

	# cojines
	_bloque(Vector3(-4.85, 0.62, 1.68), Vector3(0.36, 0.3, 0.12), Color(0.62, 0.52, 0.34), Basis(Vector3.RIGHT, -0.25))
	_bloque(Vector3(-3.65, 0.62, 1.68), Vector3(0.36, 0.3, 0.12), Color(0.62, 0.52, 0.34), Basis(Vector3.RIGHT, -0.25))

	# en la mesita: tetera, dos tazas y un libro
	var tablero := 0.46
	var loza := Color(0.86, 0.84, 0.78)
	_cilindro(Vector3(-4.35, tablero + 0.08, 0.45), 0.08, 0.16, Color(0.24, 0.30, 0.38))
	_cilindro(Vector3(-4.35, tablero + 0.17, 0.45), 0.04, 0.03, Color(0.24, 0.30, 0.38))
	_bloque(Vector3(-4.24, tablero + 0.1, 0.45), Vector3(0.12, 0.025, 0.025), Color(0.24, 0.30, 0.38), Basis(Vector3.BACK, 0.6))
	for p in [Vector3(-4.0, 0, 0.35), Vector3(-4.62, 0, 0.62)]:
		_cilindro(p + Vector3(0, tablero + 0.004, 0), 0.07, 0.008, loza)
		_cilindro(p + Vector3(0, tablero + 0.035, 0), 0.04, 0.06, loza)
	_libro(Transform3D(Basis(Vector3.UP, -0.3) * Basis(Vector3.BACK, PI * 0.5), Vector3(-3.95, tablero + 0.016, 0.66)),
		0.032, 0.22, 0.16, TAPAS[3], true)

	# cuadros sobre el sofá
	_cuadro(Vector3(-4.6, 1.62, Z1 - 0.02), Vector2(0.58, 0.72), Color(0.30, 0.34, 0.40), PI)
	_cuadro(Vector3(-3.75, 1.7, Z1 - 0.02), Vector2(0.46, 0.36), Color(0.44, 0.36, 0.26), PI)
	_cuadro(Vector3(-3.75, 1.3, Z1 - 0.02), Vector2(0.46, 0.3), Color(0.26, 0.32, 0.24), PI)

	# alacena de loza junto al arco, contra el fondo
	_poner(raiz, "bookcaseClosedDoors", "Alacena", Vector3(-3.98, 0.0, -1.5), 0.0, tinte_madera * 1.1)
	for k in 3:
		_plato_en_pie(Vector3(-3.84 + 0.25 * float(k), 1.71, -1.88), 0.11, loza)

	_cerrar_lote(raiz, "AtrezoSalita")


## Plato apoyado en la pared (de canto, mirando al cuarto).
func _plato_en_pie(base: Vector3, radio: float, color: Color) -> void:
	_cilindro(base + Vector3(0, radio, 0.03), radio, 0.012, color, Basis(Vector3.RIGHT, PI * 0.5 - 0.15), 14)


## Cocina: fogón de hierro en su chimenea, alacenas de madera, vasar con loza, mesa.
func _cocina() -> void:
	var raiz := _nodo("Cocina")
	var madera := tinte_madera * Color(1.2, 1.15, 1.1)
	var loza := Color(0.86, 0.84, 0.78)
	var azul := Color(0.30, 0.38, 0.52)
	var cobre := Color(0.62, 0.34, 0.18)
	var hierro := Color(0.07, 0.07, 0.08)

	# --- muebles bajos de madera contra el fondo ---
	_poner(raiz, "kitchenCabinetDrawer", "Bajo1", Vector3(-7.35, 0.0, -1.1), 0.0, madera)
	_poner(raiz, "kitchenSink", "Fregadero", Vector3(-6.49, 0.0, -1.1), 0.0, madera)

	# --- vasar: dos baldas con platos, tazas y tarros ---
	for y in [1.42, 1.86]:
		_bloque(Vector3(-6.49, y, -1.88), Vector3(1.7, 0.035, 0.24), madera)
		for x in [-7.25, -5.73]:
			_bloque(Vector3(x, y - 0.08, -1.95), Vector3(0.03, 0.14, 0.1), madera)
	for k in 6:
		_plato_en_pie(Vector3(-7.2 + 0.25 * float(k), 1.44, -1.95), 0.1, azul if k % 2 == 0 else loza)
	for k in 4:
		_cilindro(Vector3(-7.15 + 0.38 * float(k), 1.94, -1.86), 0.05, 0.12 + 0.03 * float(k % 2),
			[Color(0.55, 0.45, 0.30), Color(0.30, 0.34, 0.30), loza, Color(0.42, 0.24, 0.16)][k])
	for k in 5:
		# tazas colgadas
		_cilindro(Vector3(-7.1 + 0.3 * float(k), 1.29, -1.88), 0.035, 0.07, loza)

	# --- el fogón en su chimenea, de cara a la salita ---
	var cx := -4.8
	var yeso := tinte_pared * Color(0.92, 0.9, 0.86)
	_bloque(Vector3(cx - 0.6, 0.675, -1.76), Vector3(0.3, 1.35, 0.48), yeso)
	_bloque(Vector3(cx + 0.6, 0.675, -1.76), Vector3(0.3, 1.35, 0.48), yeso)
	_bloque(Vector3(cx, 1.965, -1.76), Vector3(1.5, 1.23, 0.48), yeso)
	_bloque(Vector3(cx, 0.675, -1.98), Vector3(0.9, 1.35, 0.04), Color(0.06, 0.05, 0.05))
	_bloque(Vector3(cx, 1.38, -1.69), Vector3(1.7, 0.06, 0.62), madera)
	# cuerpo de hierro, plancha, puertas y barra de latón
	_bloque(Vector3(cx, 0.4, -1.76), Vector3(0.86, 0.8, 0.42), hierro)
	_bloque(Vector3(cx, 0.82, -1.75), Vector3(0.9, 0.04, 0.48), Color(0.11, 0.11, 0.12))
	for dx in [-0.27, 0.27]:
		_bloque(Vector3(cx + dx, 0.42, -1.545), Vector3(0.24, 0.4, 0.012), Color(0.14, 0.14, 0.15))
		_bloque(Vector3(cx + dx * 0.6, 0.5, -1.535), Vector3(0.03, 0.03, 0.02), Color(0.62, 0.5, 0.26))
	_cilindro(Vector3(cx, 0.72, -1.5), 0.012, 0.9, Color(0.62, 0.5, 0.26), Basis(Vector3.BACK, PI * 0.5), 8)
	_brasa(raiz, "Lumbre", Vector3(cx, 0.44, -1.55), Vector3(0.2, 0.18, 0.02))
	# tetera de cobre y olla
	_cilindro(Vector3(cx - 0.18, 0.92, -1.74), 0.1, 0.16, cobre)
	_cilindro(Vector3(cx - 0.18, 1.02, -1.74), 0.05, 0.04, cobre)
	_bloque(Vector3(cx - 0.05, 0.94, -1.74), Vector3(0.12, 0.025, 0.025), cobre, Basis(Vector3.BACK, 0.5))
	_cilindro(Vector3(cx + 0.2, 0.91, -1.74), 0.12, 0.14, Color(0.18, 0.18, 0.19))
	# en la repisa: tarros, candeleros y cazos de cobre
	for k in 4:
		_cilindro(Vector3(cx - 0.55 + 0.36 * float(k), 1.48, -1.78), 0.06, 0.14, [cobre, loza, cobre, azul][k])
	_fuego(raiz, "LuzFogon", Vector3(cx, 0.6, -1.15), Color(1.0, 0.55, 0.25), 1.5, 3.8, 0.22)

	# --- mesa de cocina, de pino fregado, con dos sillas ---
	var pino := tinte_madera * Color(1.7, 1.6, 1.45)
	_poner(raiz, "table", "MesaCocina", Vector3(-7.2, 0.0, 0.2), 0.0, pino)
	_poner(raiz, "chair", "SillaCocina1", Vector3(-6.55, 0.0, 0.27), PI, madera)
	_poner(raiz, "chair", "SillaCocina2", Vector3(-5.75, 0.0, 0.27), PI, madera)
	var tablero := 0.654
	_bloque(Vector3(-6.75, tablero + 0.05, -0.35), Vector3(0.26, 0.1, 0.14), Color(0.55, 0.36, 0.18), Basis(Vector3.UP, 0.3))
	_bloque(Vector3(-6.72, tablero + 0.008, -0.33), Vector3(0.36, 0.016, 0.22), tinte_madera, Basis(Vector3.UP, 0.3))
	_cilindro(Vector3(-6.2, tablero + 0.1, -0.4), 0.06, 0.2, loza)
	_cilindro(Vector3(-5.85, tablero + 0.04, -0.42), 0.12, 0.08, azul)
	for x in [-6.75, -5.95]:
		_cilindro(Vector3(x, tablero + 0.005, -0.02), 0.1, 0.01, loza)
	_cilindro(Vector3(-6.45, tablero + 0.03, -0.05), 0.035, 0.06, Color(0.55, 0.45, 0.25))
	_cilindro(Vector3(-6.45, tablero + 0.12, -0.05), 0.018, 0.14, Color(0.9, 0.88, 0.8))

	# --- quinqué colgado sobre la mesa: alumbra cocina y escalera ---
	_bloque(Vector3(-6.4, 2.3, -0.25), Vector3(0.015, 0.56, 0.015), hierro)
	_cilindro(Vector3(-6.4, 1.98, -0.25), 0.07, 0.06, Color(0.62, 0.5, 0.26))
	var globo := _caja(raiz, "Globo", Vector3(-6.4, 1.9, -0.25), Vector3(0.11, 0.13, 0.11), Color(0.9, 0.78, 0.58))
	var mg := globo.material_override as StandardMaterial3D
	mg.emission_enabled = true
	mg.emission = Color(1.0, 0.82, 0.55)
	mg.emission_energy_multiplier = 0.45
	_fuego(raiz, "LuzCocina", Vector3(-6.4, 1.75, -0.25), Color(1.0, 0.8, 0.55), 1.3, 4.6, 0.06)

	# --- visillos de la ventana de la cocina ---
	var tela := Color(0.66, 0.62, 0.52)
	for x in [-6.42, -5.58]:
		_bloque(Vector3(x, 1.5, Z1 - 0.1), Vector3(0.24, 1.5, 0.04), tela)
	_bloque(Vector3(-6.0, 2.3, Z1 - 0.1), Vector3(1.2, 0.04, 0.06), madera)

	_cerrar_lote(raiz, "AtrezoCocina")


## Escalera contra la pared del fondo izquierda: sube hacia -z hasta el hueco.
## 11 peldaños del kit: huella 0,328 y tabica 0,244 ya escalados.
func _escalera() -> void:
	var raiz := _nodo("Escalera")
	var pie := 1.95
	_poner(raiz, "stairs", "Peldanos", Vector3(HUECO_X, 0.0, pie), PI * 0.5, Color.WHITE,
		{"wood": tinte_madera * Color(0.9, 0.9, 0.9), "woodDark": tinte_madera * Color(1.3, 1.25, 1.2)})
	var madera := tinte_madera * Color(0.7, 0.7, 0.7)
	var x := HUECO_X - 0.06
	# barrotes, uno por peldaño
	for k in 11:
		var z := pie - 0.328 * (float(k) + 0.5)
		var base := 0.244 * float(k + 1)
		_bloque(Vector3(x, base + 0.42, z), Vector3(0.035, 0.84, 0.035), madera)
	# poste del arranque y pasamanos
	_bloque(Vector3(x, 0.6, pie - 0.12), Vector3(0.1, 1.2, 0.1), madera)
	var a := Vector3(x, 1.2, pie - 0.12)
	var b := Vector3(x, 0.244 * 11.0 + 0.84, pie - 0.328 * 10.5)
	var d := b - a
	_bloque((a + b) * 0.5, Vector3(0.07, 0.06, d.length()), madera,
		Basis(Vector3.RIGHT, atan2(d.y, -d.z)))
	# cuadrito en la pared lateral, bajo la escalera
	_cuadro(Vector3(X0 + 0.02, 1.0, 1.35), Vector2(0.36, 0.44), Color(0.36, 0.30, 0.24), PI * 0.5)
	_cerrar_lote(raiz, "Barandilla")


## Zócalos, vigas del techo y el arco entre estudio y salita.
func _remates() -> void:
	var raiz := _nodo("Remates")
	var oscura := tinte_madera * Color(0.6, 0.6, 0.6)
	var alto := 0.14
	_bloque(Vector3((X0 + X1) * 0.5, alto * 0.5, Z0 + 0.015), Vector3(X1 - X0, alto, 0.03), oscura)
	_bloque(Vector3((X0 + 1.47) * 0.5, alto * 0.5, Z1 - 0.015), Vector3(1.47 - X0, alto, 0.03), oscura)
	_bloque(Vector3((2.53 + X1) * 0.5, alto * 0.5, Z1 - 0.015), Vector3(X1 - 2.53, alto, 0.03), oscura)
	_bloque(Vector3(X1 - 0.015, alto * 0.5, (Z0 + Z1) * 0.5), Vector3(0.03, alto, Z1 - Z0), oscura)
	# vigas
	for x in [-6.4, -4.7, -1.5, 0.0, 1.5]:
		_bloque(Vector3(x, ALTO_PARED - 0.08, (Z0 + Z1) * 0.5), Vector3(0.14, 0.16, Z1 - Z0), oscura)
	# el arco: dos pilastras y una viga gruesa
	for z in [Z0 + 0.1, Z1 - 0.1]:
		_bloque(Vector3(X_ARCO, ALTO_PARED * 0.5, z), Vector3(0.28, ALTO_PARED, 0.2), tinte_pared * Color(0.9, 0.88, 0.85))
	_bloque(Vector3(X_ARCO, ALTO_PARED - 0.16, 0.0), Vector3(0.3, 0.32, Z1 - Z0), oscura)
	_cerrar_lote(raiz, "Molduras")


## Lo que se ve al abrir la puerta: acera, la casa de enfrente, una farola. Sin luz propia.
func _calle_de_noche() -> void:
	var raiz := _nodo("CalleDeNoche")
	_bloque_noche(Vector3(-1.5, -0.05, 5.0), Vector3(17.0, 0.1, 6.0), Color(0.2, 0.21, 0.25))
	_bloque_noche(Vector3(2.0, -0.02, 2.35), Vector3(1.3, 0.04, 0.6), Color(0.30, 0.29, 0.30))
	_bloque_noche(Vector3(-1.5, 0.05, 4.2), Vector3(17.0, 0.1, 0.12), Color(0.24, 0.24, 0.26))
	# la casa de enfrente
	_bloque_noche(Vector3(-1.5, 3.0, 8.4), Vector3(17.0, 6.2, 0.4), Color(0.22, 0.21, 0.24))
	for v in [Vector3(-6.2, 1.5, 8.18), Vector3(0.6, 1.4, 8.18), Vector3(3.6, 3.6, 8.18), Vector3(-3.0, 3.8, 8.18)]:
		_bloque_noche(v, Vector3(0.7, 1.0, 0.02), Color(0.88, 0.66, 0.36))
	for v in [Vector3(-4.5, 1.5, 8.18), Vector3(2.2, 1.4, 8.18), Vector3(5.0, 1.5, 8.18), Vector3(-0.8, 3.8, 8.18)]:
		_bloque_noche(v, Vector3(0.7, 1.0, 0.02), Color(0.07, 0.08, 0.1))
	# farola: poste y farol
	_bloque_noche(Vector3(3.6, 1.3, 3.4), Vector3(0.08, 2.6, 0.08), Color(0.03, 0.03, 0.035))
	_bloque_noche(Vector3(3.6, 2.7, 3.4), Vector3(0.26, 0.32, 0.26), Color(1.0, 0.86, 0.55))
	# niebla de fondo
	var cielo := MeshInstance3D.new()
	cielo.name = "CieloCalle"
	var q := QuadMesh.new()
	q.size = Vector2(30, 12)
	cielo.mesh = q
	var mc := StandardMaterial3D.new()
	mc.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mc.albedo_color = Color(0.32, 0.36, 0.45)
	mc.disable_fog = true
	cielo.material_override = mc
	raiz.add_child(cielo)
	cielo.position = Vector3(-1.5, 4.0, 12.0)
	cielo.rotation.y = PI
	_cerrar_lote(raiz, "Calle", true)


## Colisión en las 4 paredes.
func _topes() -> void:
	var raiz := _nodo("Topes")
	var lados := [
		[Vector3((X0 + X1) * 0.5, 1.3, Z0 - 0.1), Vector3(X1 - X0, 2.6, 0.2)],
		[Vector3((X0 + X1) * 0.5, 1.3, Z1 + 0.1), Vector3(X1 - X0, 2.6, 0.2)],
		[Vector3(X0 - 0.1, 1.3, (Z0 + Z1) * 0.5), Vector3(0.2, 2.6, Z1 - Z0)],
		[Vector3(X1 + 0.1, 1.3, (Z0 + Z1) * 0.5), Vector3(0.2, 2.6, Z1 - Z0)],
	]
	for k in lados.size():
		var cuerpo := StaticBody3D.new()
		cuerpo.name = "Tope%d" % k
		raiz.add_child(cuerpo)
		cuerpo.position = lados[k][0]
		var cs := CollisionShape3D.new()
		var caja := BoxShape3D.new()
		caja.size = lados[k][1]
		cs.shape = caja
		cuerpo.add_child(cs)


## Plano de la parroquia en la pared: el mismo plano vía SubViewport.
var _plano_pared: Node3D = null
var _vp_pared: SubViewport = null


func _repintar_el_plano_de_la_pared(_e: Variant = null) -> void:
	if _plano_pared == null or not is_instance_valid(_plano_pared):
		return
	_plano_pared.call(&"limpiar_marcas")
	for a in Casefile.records():
		_plano_pared.call(&"marcar", a, false)
	var c := Cuaderno.circulo()
	if c.size() == 4 and Casefile.has("broad_street_racimo"):
		_plano_pared.call(&"anillo", Vector2(float(c[0]), float(c[1])), float(c[2]))
	_vp_pared.render_target_update_mode = SubViewport.UPDATE_ONCE


func _cercar_el_plano_de_la_pared(id: String) -> void:
	if id == "broad_street_racimo":
		_repintar_el_plano_de_la_pared()


## La misma maqueta que el mapa (M), vista desde arriba y colgada en la pared.
func _plano_en_la_pared() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(780, 572)
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	_cuarto.add_child(vp)
	_vp_pared = vp

	var entorno := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = MAQUETA.C_SUELO
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.58, 0.66)
	env.ambient_light_energy = 0.6
	entorno.environment = env
	vp.add_child(entorno)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-60.0, -38.0, 0.0)
	sol.light_color = Color(1.0, 0.92, 0.80)
	sol.light_energy = 0.9
	vp.add_child(sol)

	var maqueta := Node3D.new()
	maqueta.set_script(MAQUETA)
	vp.add_child(maqueta)
	_plano_pared = maqueta

	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 112.0
	cam.far = 600.0
	vp.add_child(cam)
	cam.position = Vector3(0.0, 220.0, 20.0)
	cam.look_at(Vector3(0.0, 0.0, -14.0))

	_repintar_el_plano_de_la_pared.call_deferred()
	# métodos, no lambdas: una lambda en señal de autoload sobrevive a la escena
	Casefile.recorded.connect(_repintar_el_plano_de_la_pared)
	Casefile.evidence_collected.connect(_cercar_el_plano_de_la_pared)

	var marco := MeshInstance3D.new()
	marco.name = "PlanoDePared"
	var q := QuadMesh.new()
	q.size = Vector2(1.35, 0.99)
	marco.mesh = q
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = vp.get_texture()
	# Sin sombreado: el cuarto es oscuro y el mapa debe leerse.
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.82, 0.8, 0.76)
	mat.roughness = 1.0
	marco.material_override = mat
	_cuarto.add_child(marco)
	# pared del fondo, a la izq. de la ventana, altura de ojos sentado
	marco.position = Vector3(-1.52, 1.62, Z0 + 0.06)

	# marco de madera detrás
	var borde := MeshInstance3D.new()
	borde.name = "PlanoMarco"
	var caja := BoxMesh.new()
	caja.size = Vector3(1.47, 1.11, 0.05)
	borde.mesh = caja
	var mb := StandardMaterial3D.new()
	mb.albedo_color = tinte_madera * Color(0.9, 0.9, 0.9)
	mb.roughness = 1.0
	borde.material_override = mb
	_cuarto.add_child(borde)
	borde.position = marco.position - Vector3(0.0, 0.0, 0.04)


## Papeles: lo más claro del cuarto, para guiar la vista.
func _papeles_en_la_mesa() -> void:
	var hojas := [
		[Vector3(-0.06, 0.775, -1.52), Vector2(0.42, 0.30), 0.10, 0.96],
		[Vector3(0.10, 0.777, -1.46), Vector2(0.38, 0.28), -0.16, 0.90],
		[Vector3(-0.30, 0.779, -1.40), Vector2(0.26, 0.19), 0.34, 0.84],
	]
	for i in hojas.size():
		var h: Array = hojas[i]
		var m := MeshInstance3D.new()
		m.name = "Papel%d" % i
		var q := QuadMesh.new()
		q.size = h[1]
		m.mesh = q
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.93, 0.90, 0.83) * float(h[3])
		mat.roughness = 1.0
		m.material_override = mat
		_cuarto.add_child(m)
		m.basis = Basis(Vector3.UP, float(h[2])) * Basis(Vector3.RIGHT, -PI * 0.5)
		m.position = h[0]


## Zona clicable: todo el tablero de la mesa.
func _lo_clicable() -> void:
	var cuerpo := StaticBody3D.new()
	cuerpo.name = "ElLibro"
	cuerpo.set_meta(&"accion", "libro")
	_cuarto.add_child(cuerpo)
	cuerpo.position = Vector3(0.0, 0.88, -1.58)
	var cs := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = Vector3(1.7, 0.45, 0.85)
	cs.shape = caja
	cuerpo.add_child(cs)


# ------------------------------------------------------------------- utilería

func _nodo(nombre: String) -> Node3D:
	var n := Node3D.new()
	n.name = nombre
	_cuarto.add_child(n)
	return n


func _caja(padre: Node3D, nombre: String, pos: Vector3, tam: Vector3, color: Color) -> MeshInstance3D:
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


## Cajas y cilindros sueltos se juntan por color en una malla: pocas llamadas de dibujo.
var _lote: Dictionary = {}
var _lote_noche: Dictionary = {}


func _bloque(pos: Vector3, tam: Vector3, color: Color, giro: Basis = Basis()) -> void:
	var b := BoxMesh.new()
	b.size = tam
	_al_lote(_lote, b, Transform3D(giro, pos), color)


## Caja en los ejes de `xf` (p.ej. los de un libro).
func _bloque_en(xf: Transform3D, local: Vector3, tam: Vector3, color: Color) -> void:
	var b := BoxMesh.new()
	b.size = tam
	_al_lote(_lote, b, xf * Transform3D(Basis(), local), color)


## Sin sombreado: lo de fuera, que no debe gastar luces.
func _bloque_noche(pos: Vector3, tam: Vector3, color: Color) -> void:
	var b := BoxMesh.new()
	b.size = tam
	_al_lote(_lote_noche, b, Transform3D(Basis(), pos), color)


func _cilindro(pos: Vector3, radio: float, alto: float, color: Color, giro: Basis = Basis(),
		lados: int = 10) -> void:
	var c := CylinderMesh.new()
	c.top_radius = radio
	c.bottom_radius = radio
	c.height = alto
	c.radial_segments = lados
	c.rings = 1
	_al_lote(_lote, c, Transform3D(giro, pos), color)


func _al_lote(lote: Dictionary, malla: Mesh, xf: Transform3D, color: Color) -> void:
	if not lote.has(color):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		lote[color] = st
	(lote[color] as SurfaceTool).append_from(malla, 0, xf)


## Vuelca el lote en una MeshInstance3D: una superficie por color.
func _cerrar_lote(padre: Node3D, nombre: String, noche: bool = false) -> void:
	var lote := _lote_noche if noche else _lote
	if lote.is_empty():
		return
	var am := ArrayMesh.new()
	for c in lote:
		(lote[c] as SurfaceTool).commit(am)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = c
		mat.roughness = 1.0
		if noche:
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.disable_fog = true
		am.surface_set_material(am.get_surface_count() - 1, mat)
	lote.clear()
	var m := MeshInstance3D.new()
	m.name = nombre
	m.mesh = am
	padre.add_child(m)


## Instancia una pieza del kit, la escala, la gira y la tiñe.
## `colores` pone color fijo por nombre de material del kit (p.ej. "carpet").
func _poner(padre: Node3D, pieza: String, nombre: String, pos: Vector3,
		giro: float, tinte: Color, colores: Dictionary = {}) -> Node3D:
	var esc := load(KIT % pieza) as PackedScene
	if esc == null:
		push_warning("ConstructorRectoria: no encuentro la pieza '%s'." % pieza)
		return null
	var n := esc.instantiate() as Node3D
	n.name = nombre
	padre.add_child(n)
	n.basis = Basis(Vector3.UP, giro).scaled(Vector3.ONE * ESCALA)
	n.position = pos
	_tenir(n, tinte, colores)
	return n


## Multiplica el color; duplica materiales porque el .glb los comparte.
func _tenir(n: Node, tinte: Color, colores: Dictionary = {}) -> void:
	if n is MeshInstance3D:
		var m := n as MeshInstance3D
		var malla := m.mesh
		if malla != null:
			for s in malla.get_surface_count():
				var mat := m.get_active_material(s)
				if mat is StandardMaterial3D:
					var copia := (mat as StandardMaterial3D).duplicate() as StandardMaterial3D
					if copia.resource_name == "glass":
						_hacer_de_noche(copia)
					elif colores.has(copia.resource_name):
						copia.albedo_color = colores[copia.resource_name]
						copia.roughness = 1.0
					else:
						copia.albedo_color = copia.albedo_color * tinte
						copia.roughness = 1.0
					m.set_surface_override_material(s, copia)
	for h in n.get_children():
		_tenir(h, tinte, colores)


## Cristal: ALPHA sin escribir profundidad (el pre-pass tapaba lo de detrás).
func _hacer_de_noche(mat: StandardMaterial3D) -> void:
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.13, 0.17, 0.26, 0.45)


## Hoja de la puerta: pivote en la jamba + tabla con cuarterones y pomo de latón.
## El pomo de dentro es clicable (meta "accion" = "pomo") para abrirle a Snow.
func _hoja_de_la_puerta() -> void:
	var pivote := Node3D.new()
	pivote.name = "HojaPuerta"
	_cuarto.add_child(pivote)
	# bahía de la puerta centrada en x = 2; pivote en la jamba izq.
	pivote.position = Vector3(1.55, 0.0, Z1 - 0.06)

	var tabla := MeshInstance3D.new()
	tabla.name = "Tabla"
	var caja := BoxMesh.new()
	caja.size = Vector3(0.92, 2.02, 0.06)
	tabla.mesh = caja
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tinte_madera * Color(0.8, 0.78, 0.76)
	mat.roughness = 1.0
	tabla.material_override = mat
	pivote.add_child(tabla)
	tabla.position = Vector3(0.46, 1.01, 0.0)

	# cuarterones a las dos caras
	var cuarteron := tinte_madera * Color(0.66, 0.64, 0.62)
	for cara in [-1.0, 1.0]:
		for p in [Vector2(0.25, 0.5), Vector2(0.67, 0.5), Vector2(0.25, 1.45), Vector2(0.67, 1.45)]:
			_bloque(Vector3(p.x, p.y, 0.034 * cara), Vector3(0.3, 0.72 if p.y < 1.0 else 0.84, 0.012), cuarteron)
	# pomo de fuera y bocallave
	var laton := Color(0.70, 0.55, 0.26)
	_bloque(Vector3(0.8, 1.0, 0.04), Vector3(0.06, 0.13, 0.012), laton)
	_cilindro(Vector3(0.8, 1.0, 0.075), 0.035, 0.05, laton, Basis(Vector3.RIGHT, PI * 0.5), 12)
	_bloque(Vector3(0.8, 1.0, -0.04), Vector3(0.06, 0.13, 0.012), laton)
	_bloque(Vector3(0.8, 0.9, -0.047), Vector3(0.014, 0.03, 0.004), Color(0.05, 0.04, 0.03))
	_cerrar_lote(pivote, "Cuarterones")

	# pomo de dentro: va aparte para poder iluminarlo
	var pomo := MeshInstance3D.new()
	pomo.name = "Pomo"
	var esfera := SphereMesh.new()
	esfera.radius = 0.042
	esfera.height = 0.07
	esfera.radial_segments = 14
	esfera.rings = 7
	pomo.mesh = esfera
	var mp := StandardMaterial3D.new()
	mp.albedo_color = laton
	mp.metallic = 0.6
	mp.roughness = 0.4
	pomo.material_override = mp
	pivote.add_child(pomo)
	pomo.position = Vector3(0.8, 1.0, -0.08)

	var cuerpo := StaticBody3D.new()
	cuerpo.name = "PomoClic"
	cuerpo.set_meta(&"accion", "pomo")
	pivote.add_child(cuerpo)
	cuerpo.position = Vector3(0.78, 1.0, -0.07)
	var cs := CollisionShape3D.new()
	var bola := SphereShape3D.new()
	bola.radius = 0.13
	cs.shape = bola
	cuerpo.add_child(cs)
