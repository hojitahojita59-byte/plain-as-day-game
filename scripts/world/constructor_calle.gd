@tool
extends Node
## Levanta el barrio desde data/barrio/<id>.json: tramos, puertas, vecinos, props.
## @tool: se ve en el editor sin guardarse (nodos sin dueño). Ver REJILLA.md.

# --- Rejilla: una bahía = una casa de 5 m de frente y 5 de fondo ---
const MODULO := 5.0
## Alto de la colisión de las hileras (las casas tienen 3 o 4 plantas).
const CUBIERTA := 14.0

## Distancias desde el origen del módulo a lo largo de la normal de la fachada.
const D_FACHADA := 2.5     ## El plano de la fachada. Ahí van las puertas.

const FACHADAS := preload("res://scripts/world/fachadas.gd")

const PROPS := {
	"arbol": "res://scenes/world/props/arbol.tscn",
	"farola": "res://scenes/world/props/farola.tscn",
	"cubo": "res://scenes/world/props/cubo.tscn",
	"basura": "res://scenes/world/props/basura.tscn",
	"bomba": "res://scenes/world/props/bomba_broad_street.tscn",
	"bomba_muda": "res://scenes/world/props/bomba_broad_street.tscn",
	"puesto_rojo": "res://art/models/Medieval/GLB format/stall-red.glb",
	"puesto_verde": "res://art/models/Medieval/GLB format/stall-green.glb",
	"carro": "res://art/models/Medieval/GLB format/cart.glb",
	"carro_alto": "res://art/models/Medieval/GLB format/cart-high.glb",
}

## Giro del módulo según adónde mira la fachada (cara decorada = +Z).
const MIRA := {"+z": 0.0, "-z": PI, "+x": PI * 0.5, "-x": -PI * 0.5}

## Dirección de crecimiento de un tramo (con signo).
const EJES := {
	"+x": Vector3.RIGHT, "-x": Vector3.LEFT,
	"+z": Vector3.BACK, "-z": Vector3.FORWARD,
}

## Tipado: con Variant, multiplicar por distancia da error de tipado inseguro.
const LADOS: Array[float] = [-1.0, 1.0]

const VESTUARIO := preload("res://scripts/world/vestuario.gd")
const FIGURA := "res://scenes/world/props/figura.tscn"
const HOJA := "res://scenes/world/props/hoja_abrible.tscn"
const BURBUJA := "res://scenes/world/props/burbuja_murmullo.tscn"
const INTERACTUABLE := "res://scripts/world/interactable.gd"
const MARCHARSE := "res://scripts/world/se_marcha.gd"
const CAMINO := "res://scripts/world/camino_a_casa.gd"
const FUENTE_NUMEROS := "res://art/fonts/EB_Garamond/static/EBGaramond-SemiBold.ttf"

@export var calle_path: NodePath = ^"../Calle"
@export var nav_path: NodePath = ^"../NavRegion"
@export var jugador_path: NodePath = ^"../Whitehead"
@export var camara_path: NodePath = ^"../Camera3D"

## Solo editor: id de data/barrio/_indice.json.
@export var calle_en_el_editor: String = "soho":
	set(v):
		calle_en_el_editor = v
		if Engine.is_editor_hint():
			_rehacer_para_el_editor.call_deferred()

## Marcar para reconstruir en el editor.
@export var rehacer: bool = false:
	set(v):
		rehacer = false
		if v and Engine.is_editor_hint():
			_rehacer_para_el_editor.call_deferred()

var _calle: Node3D
var _datos: Dictionary = {}
var _fuente: Font = null
## id -> tramo resuelto (origen, paso, giro, normal, bahías...).
var _tramos: Dictionary = {}


func _ready() -> void:
	if Engine.is_editor_hint():
		_rehacer_para_el_editor.call_deferred()
		return

	_calle = get_node_or_null(calle_path) as Node3D
	if _calle == null:
		push_error("ConstructorCalle: no encuentro el nodo Calle.")
		return

	_datos = Barrio.datos(Barrio.actual)
	if _datos.is_empty():
		push_error("ConstructorCalle: no hay datos para '" + Barrio.actual + "'.")
		return

	_levantar()
	_colocar_al_jugador()
	_ajustar_la_camara()
	# la navegación al final, con la geometría ya creada
	_hornear_navegacion()


# ---------------------------------------------------------------- el editor

## Reconstruye en el editor leyendo el JSON directo (sin autoloads).
## No coloca jugador, cámara ni navegación.
func _rehacer_para_el_editor() -> void:
	_calle = get_node_or_null(calle_path) as Node3D
	if _calle == null:
		return
	for hijo in _calle.get_children():
		_calle.remove_child(hijo)
		hijo.queue_free()
	_datos = _leer(calle_en_el_editor)
	if _datos.is_empty():
		push_warning("ConstructorCalle: no hay datos de '" + calle_en_el_editor + "'.")
		return
	_levantar()


func _leer(id: String) -> Dictionary:
	if id.is_empty():
		return {}
	var f := FileAccess.open("res://data/barrio/" + id + ".json", FileAccess.READ)
	if f == null:
		return {}
	var d = JSON.parse_string(f.get_as_text())
	if typeof(d) != TYPE_DICTIONARY:
		return {}
	var datos: Dictionary = d
	datos["id"] = id
	return datos


func _levantar() -> void:
	_fuente = load(FUENTE_NUMEROS) as Font
	_resolver_tramos()
	_poner_el_rotulo_de_la_escena()
	_f = FACHADAS.new(_nodo("Letreros", _calle))
	_f.rng.seed = int(_datos.get("semilla", 1854))
	# las casas antes que el suelo: la acera se agujerea donde hay foso
	_construir_hileras()
	_construir_suelo()
	_construir_puertas()
	_construir_esquinas()
	if not Engine.is_editor_hint():
		var burbujas := CanvasLayer.new()
		burbujas.name = "BurbujasDePuerta"
		burbujas.set_script(load("res://scripts/world/burbujas_de_puerta.gd"))
		_calle.add_child(burbujas)
		var vista := CanvasLayer.new()
		vista.name = "VistaPajaro"
		vista.add_to_group(&"vista_pajaro")
		vista.set_script(load("res://scripts/world/vista_pajaro.gd"))
		_calle.add_child(vista)
		var estelas := Node3D.new()
		estelas.name = "EstelasCalle"
		estelas.add_to_group(&"estelas_calle")
		estelas.set_script(load("res://scripts/world/estelas_calle.gd"))
		_calle.add_child(estelas)
		var lazos := Node3D.new()
		lazos.name = "Lazos"
		lazos.add_to_group(&"lazos")
		lazos.set_script(load("res://scripts/world/lazos.gd"))
		_calle.add_child(lazos)
		var carro := Node3D.new()
		carro.name = "CarroDeMuertos"
		carro.add_to_group(&"carro_de_muertos")
		carro.set_script(load("res://scripts/world/carro_de_muertos.gd"))
		_calle.add_child(carro)
		var eley := Node3D.new()
		eley.name = "CarroDeHampstead"
		eley.set_script(load("res://scripts/world/carruaje_calle.gd"))
		_calle.add_child(eley)
		var aguadores := Node3D.new()
		aguadores.name = "Aguadores"
		aguadores.add_to_group(&"aguadores")
		aguadores.set_script(load("res://scripts/world/aguadores.gd"))
		_calle.add_child(aguadores)
		var apertura := Node3D.new()
		apertura.name = "Apertura"
		apertura.add_to_group(&"apertura")
		apertura.set_script(load("res://scripts/world/apertura.gd"))
		_calle.add_child(apertura)
	_construir_vecinos()
	_construir_props()


# ---------------------------------------------------------------- los tramos

## Un tramo = una hilera de fachada. `desde` es el origen del 1er módulo
## (la fachada cae 2,5 m por delante).
func _resolver_tramos() -> void:
	_tramos.clear()
	for t_raw in Array(_datos.get("tramos", [])):
		var t := _resolver(Dictionary(t_raw))
		if not t.is_empty():
			_tramos[String(Dictionary(t_raw).get("id", ""))] = t
	# cada puerta marca su bahía, que decide el tipo de casa
	for p_raw in Array(_datos.get("puertas", [])):
		var p: Dictionary = p_raw
		var t: Dictionary = _tramos.get(String(p.get("tramo", "")), {})
		if t.is_empty():
			continue
		var b := int(p.get("bahia", -1))
		t["puertas"][b] = true

		# porte: edificio grande (asilo, cervecería) con bahías, plantas y rótulo
		if p.has("porte"):
			var porte: Dictionary = p["porte"]
			t["porte"][b] = porte
			for j in range(1, maxi(1, int(porte.get("bahias", 1)))):
				t["absorbidas"][b + j] = b

	# esquina con `portal` = puerta de la rectoría, con rótulo encima
	for e_raw in Array(_datos.get("esquinas", [])):
		var portal: Dictionary = Dictionary((e_raw as Dictionary).get("portal", {}))
		var t: Dictionary = _tramos.get(String(portal.get("tramo", "")), {})
		if t.is_empty():
			continue
		var b := int(portal.get("bahia", -1))
		t["puertas"][b] = true
		t["porte"][b] = {"rotulo": String(portal.get("rotulo", ""))}

	# bahías con el nombre de la calle: sin balcón ni frontón que lo tapen
	for r_raw in Array(_datos.get("rotulos", [])):
		var t: Dictionary = _tramos.get(String(Dictionary(r_raw).get("tramo", "")), {})
		if not t.is_empty():
			t["rotulos"][int(Dictionary(r_raw).get("bahia", 0))] = true


## Hilera de los datos (tramo o acera de enfrente) con sus vectores y bahías vacías.
func _resolver(t: Dictionary) -> Dictionary:
	var mira := String(t.get("mira", "+z"))
	if not MIRA.has(mira):
		push_warning("ConstructorCalle: '" + mira + "' no es una orientación.")
		return {}
	var desde := Array(t.get("desde", [0, 0]))
	var eje := String(t.get("eje", "+x"))
	if not EJES.has(eje):
		push_warning("ConstructorCalle: '" + eje + "' no es un eje. Usa +x, -x, +z o -z.")
		return {}
	var paso: Vector3 = EJES[eje] * MODULO
	var giro: float = MIRA[mira]
	# hueco = callejón (fondo y tope); boca = entrada de otra calle (se cruza)
	var huecos := {}
	var bocas := {}
	var vacias := {}
	for h in Array(t.get("huecos", [])):
		huecos[int(h)] = true
		vacias[int(h)] = true
	for b in Array(t.get("bocas", [])):
		bocas[int(b)] = true
		vacias[int(b)] = true
	return {
		"origen": Vector3(float(desde[0]), 0.0, float(desde[1])),
		"paso": paso,
		"giro": giro,
		# normal hacia donde mira la fachada, sacada del giro
		"normal": Basis(Vector3.UP, giro) * Vector3.BACK,
		"bahias": int(t.get("bahias", 1)),
		"huecos": huecos,
		"bocas": bocas,
		"vacias": vacias,
		"puertas": {},
		# bahía de puerta -> porte {bahias, plantas, rotulo}
		"porte": {},
		# bahía absorbida -> bahía de la puerta dueña
		"absorbidas": {},
		"rotulos": {},
		# tiendas (Broad St) o sencillo (calles de al lado)
		"estilo": String(t.get("estilo", "sencillo")),
		"pisos_max": int(t.get("pisos_max", 4)),
		"pisos_min": int(t.get("pisos_min", 3)),
		# cubierta forzada y chimeneas atrás: la acera de enfrente, que no tape la grúa
		"cubierta": String(t.get("cubierta", "")),
		"chimenea_atras": bool(t.get("chimenea_atras", false)),
		# bahía -> ficha de la casa que se levantó
		"casas": {},
	}


## Origen del módulo de una bahía, en mundo.
func _origen(t: Dictionary, i: int) -> Vector3:
	return (t["origen"] as Vector3) + (t["paso"] as Vector3) * float(i)


## Desplazamiento a lo largo del tramo.
func _a_lo_largo(t: Dictionary, d: float) -> Vector3:
	return ((t["paso"] as Vector3).normalized()) * d


## Desplazamiento hacia donde mira la fachada.
func _hacia_fuera(t: Dictionary, d: float) -> Vector3:
	return (t["normal"] as Vector3) * d


# ---------------------------------------------------------------- la fachada

## Constructor de casas (fachadas.gd): todo fundido por material y trozo de calle.
var _f: RefCounted


func _construir_hileras() -> void:
	var raiz := _nodo("Fachadas", _calle)
	for id in _tramos:
		_construir_tramo(String(id), _tramos[id], _nodo(String(id), raiz))
	# lo que solo ve el cine: la acera de enfrente y las manzanas de alrededor
	_f.cine = true
	var enfrente := _nodo("Enfrente", raiz)
	for e_raw in Array(_datos.get("enfrente", [])):
		var t := _resolver(Dictionary(e_raw))
		if not t.is_empty():
			_hilera_de_casas(t, enfrente, true)
	for r_raw in Array(_datos.get("relleno", [])):
		_relleno(Dictionary(r_raw))
	_f.cine = false
	_f.cerrar(_nodo("Mallas", raiz))


func _construir_tramo(id: String, t: Dictionary, raiz: Node3D) -> void:
	_hilera_de_casas(t, raiz, false)
	var giro: float = t["giro"]
	for i in t["huecos"]:
		_fondo_de_hueco(raiz, "Callejon%d" % (int(i) + 1), _origen(t, int(i)), giro)
	_pintar_rotulos_de_edificio(raiz, t, giro)
	_vestir_edificios(raiz, t, giro)
	_muro(raiz, t, id)


## Casas de una hilera (una por bahía, o una por edificio grande), medianeras y fosos.
func _hilera_de_casas(t: Dictionary, raiz: Node3D, cine: bool) -> void:
	var n: int = t["bahias"]
	var vacias: Dictionary = t["vacias"]
	var base := Basis(Vector3.UP, float(t["giro"]))
	var eje_x := base * Vector3.RIGHT
	# signo de x de casa al avanzar de bahía
	var s := signf((t["paso"] as Vector3).dot(eje_x))
	var unidades: Array = []
	var i := 0
	while i < n:
		if vacias.has(i):
			unidades.append([])
			i += 1
			continue
		var c := _ficha(t, i, cine)
		var nb := int(c.get("bahias", 1))
		var mitad := (_origen(t, i) + _origen(t, i + nb - 1)) * 0.5
		var marco := Transform3D(base, mitad + _hacia_fuera(t, D_FACHADA))
		if nb > 1:
			c["puerta_x"] = (_origen(t, i) - mitad).dot(eje_x)
			if c.has("trampilla"):
				var ancho := MODULO * float(nb)
				var nv := maxi(1, int(round(ancho / 1.66)))
				c["trampilla"] = int(round((-float(c["puerta_x"]) + ancho * 0.5) / ancho * float(nv) - 0.5))
		_f.xf = marco
		_f.empezar(marco.origin)
		_f.casa(c)
		for j in nb:
			t["casas"][i + j] = c
			if not cine:
				_nodo("Bahia%d_0" % (i + j + 1), raiz)
		if bool(c.get("sotano", false)) and not cine:
			_foso_cuerpo(raiz, marco, c)
		unidades.append([i, nb, c, marco])
		i += nb

	# medianeras: entre vecinas, y costado a la vista junto a un hueco o al final
	for k in unidades.size():
		var u: Array = unidades[k]
		if u.is_empty():
			continue
		var c: Dictionary = u[2]
		var borde := float(u[1]) * MODULO * 0.5
		_f.xf = u[3]
		_f.empezar((u[3] as Transform3D).origin)
		var sig: Array = unidades[k + 1] if k + 1 < unidades.size() else []
		var vecina: Dictionary = sig[2] if not sig.is_empty() else {}
		# ventanas en el costado que da a una calle o a un callejón; ciego al final de la hilera
		var a_la_calle: bool = sig.is_empty() and vacias.has(int(u[0]) + int(u[1]))
		if s > 0.0:
			_f.medianera(borde, c, vecina, a_la_calle)
		else:
			_f.medianera(-borde, vecina, c, a_la_calle)
		var ant: Array = unidades[k - 1] if k > 0 else []
		if ant.is_empty():
			a_la_calle = vacias.has(int(u[0]) - 1)
			if s > 0.0:
				_f.medianera(-borde, {}, c, a_la_calle)
			else:
				_f.medianera(borde, c, {}, a_la_calle)


## Ficha de la casa de una bahía según la calle: tiendas (Broad St) o sencillo.
func _ficha(t: Dictionary, i: int, cine: bool) -> Dictionary:
	var porte: Dictionary = t["porte"]
	var es_puerta: bool = (t["puertas"] as Dictionary).has(i)
	var pisos_max: int = t["pisos_max"]
	var r: float = _f.rng.randf()
	var c: Dictionary
	if porte.has(i):
		var datos: Dictionary = porte[i]
		var texto := String(datos.get("rotulo", ""))
		var nb := maxi(1, int(datos.get("bahias", 1)))
		if texto.ends_with("BREWERY"):
			c = _f.plantilla("A", MODULO * float(nb), "puerta")
			c["estilo"] = "cerveceria"
			c["pisos"] = [3.8, 3.3, 3.1, 2.8]
			c["tinte"] = FACHADAS.ladrillo(Color(1.0, 0.66, 0.55), 0.35)
			c["luces"] = [0, 1]
			c["trampilla"] = 0
			c["puerta_color"] = Color(0.48, 0.3, 0.16)
		elif texto.ends_with("WORKHOUSE"):
			c = _f.plantilla("A", MODULO * float(nb), "puerta")
			c["estilo"] = "asilo"
			c["pisos"] = [3.6, 3.2, 3.0, 2.8]
			c["tinte"] = FACHADAS.ladrillo(Color(0.62, 0.64, 0.68), 0.6)
			c["tinte_estuco"] = FACHADAS.ladrillo(Color(0.74, 0.77, 0.82), 0.5)
			c["luces"] = [0]
			c["puerta_color"] = Color(0.2, 0.32, 0.26)
		else:
			# la rectoría: casa sobria con el rótulo sobre la puerta
			c = _f.plantilla("A", MODULO, "puerta", 4)
		c["bahias"] = nb
		c["balcon"] = false
		c["cubierta"] = "pretil"
		return c
	var estilo := "A"
	var bajo := "ventanas"
	if cine:
		bajo = "tienda" if r < 0.5 else "puerta_falsa"
		estilo = "B" if r < 0.5 else ("A" if r < 0.82 else "C")
	elif String(t["estilo"]) == "tiendas":
		if es_puerta:
			bajo = "puerta"
			estilo = "A" if r < 0.5 else ("B" if r < 0.8 else "C")
		else:
			bajo = "tienda" if r < 0.85 else "ventanas"
			estilo = "B" if r < 0.72 else ("A" if r < 0.85 else "C")
	else:
		if es_puerta:
			bajo = "puerta"
			estilo = "A" if r < 0.75 else "C"
		else:
			bajo = "ventanas" if (r < 0.55 or (r >= 0.7 and r < 0.85)) else "tienda"
			estilo = "A" if r < 0.7 else "C"
	# con el nombre de la calle encima: portada baja y sin balcón
	if (t["rotulos"] as Dictionary).has(i) and bajo == "puerta":
		estilo = "A"
	c = _f.plantilla(estilo, MODULO, bajo, pisos_max, int(t["pisos_min"]))
	if not String(t["cubierta"]).is_empty():
		c["cubierta"] = t["cubierta"]
		c["buhardas"] = 0
	c["chimenea_atras"] = t["chimenea_atras"]
	if (t["rotulos"] as Dictionary).has(i):
		c["balcon"] = false
	if bajo == "tienda":
		match String(c["tienda"]["texto"]):
			"PAWNBROKER":
				c["muestra"] = "bolas"
			"CHEMIST":
				c["muestra"] = "mortero"
	if bajo != "tienda" and bajo != "puerta":
		c["sotano"] = _f.rng.randf() < 0.5 if cine else (_f.rng.randf() < 0.6 and _foso_libre(t, i))
	return c


## Foso de sótano solo en las calles de al lado y sin nada delante (vecino, prop, esquina).
func _foso_libre(t: Dictionary, i: int) -> bool:
	if String(t["estilo"]) == "tiendas":
		return false
	var o := _origen(t, i) + _hacia_fuera(t, D_FACHADA)
	var eje := (t["paso"] as Vector3).normalized()
	var normal: Vector3 = t["normal"]
	var puntos: Array[Vector3] = []
	for clave in ["props", "vecinos", "esquinas"]:
		for x_raw in Array(_datos.get(clave, [])):
			var pos := Array(Dictionary(x_raw).get("pos", []))
			if pos.size() >= 2:
				puntos.append(Vector3(float(pos[0]), 0.0, float(pos[1])))
	for p in puntos:
		var d := p - o
		var fuera := d.dot(normal)
		if absf(d.dot(eje)) < MODULO * 0.5 + 0.7 and fuera > -0.5 and fuera < FACHADAS.PATIO + 1.0:
			return false
	return true


## Que nadie pise el foso: caja sólida delante de la casa (la navegación lo esquiva).
func _foso_cuerpo(raiz: Node3D, marco: Transform3D, c: Dictionary) -> void:
	var cuerpo := StaticBody3D.new()
	cuerpo.name = "Foso"
	raiz.add_child(cuerpo)
	var cs := CollisionShape3D.new()
	var forma := BoxShape3D.new()
	var x0: float = c["x0"]
	var x1: float = c["x1"]
	forma.size = Vector3(x1 - x0, 3.6, FACHADAS.PATIO + 0.25)
	cs.shape = forma
	cuerpo.add_child(cs)
	cuerpo.transform = marco * Transform3D(Basis.IDENTITY,
		Vector3((x0 + x1) * 0.5, -0.6, (FACHADAS.PATIO + 0.25) * 0.5))


## Relleno de cine: hileras sencillas o patios, a lo largo de una línea.
func _relleno(r: Dictionary) -> void:
	var mira := String(r.get("mira", "+z"))
	var base := Basis(Vector3.UP, float(MIRA.get(mira, 0.0)))
	var a := Array(r.get("desde", [0, 0]))
	var b := Array(r.get("hasta", [0, 0]))
	var pa := Vector3(float(a[0]), 0.0, float(a[1]))
	var pb := Vector3(float(b[0]), 0.0, float(b[1]))
	_f.xf = Transform3D(base, pa)
	_f.empezar(pa)
	var largo := (pb - pa).dot(base * Vector3.RIGHT)
	var x0 := minf(0.0, largo)
	var x1 := maxf(0.0, largo)
	var fondo := float(r.get("fondo", 8.0))
	if String(r.get("tipo", "fila")) == "patios":
		_f.patios(x0, x1, fondo, float(r.get("paso", MODULO)))
		return
	var pisos := Array(r.get("pisos", [3, 4]))
	_f.fila_simple(x0, x1, fondo, int(pisos[0]), int(pisos[1]), bool(r.get("bajo", false)),
		bool(r.get("dos_caras", true)))


## Bahía de la puerta del edificio con porte, o -1 si es casa normal.
func _edificio_de(t: Dictionary, i: int) -> int:
	if (t["porte"] as Dictionary).has(i):
		return i
	return int((t["absorbidas"] as Dictionary).get(i, -1))


## Rótulo de edificio sobre la portada, bajo el primer piso: la cámara no ve más arriba.
const Y_ROTULO_EDIFICIO := 3.75

## Más sacado que la portada.
const D_ROTULO_EDIFICIO := 2.85


## Centrado sobre todas las bahías del edificio.
func _pintar_rotulos_de_edificio(raiz: Node3D, t: Dictionary, giro: float) -> void:
	var porte: Dictionary = t["porte"]
	for b in porte:
		var datos: Dictionary = porte[b]
		var texto := String(datos.get("rotulo", ""))
		if texto.is_empty():
			continue
		var anchura := maxi(1, int(datos.get("bahias", 1)))
		var l := _rotulo("RotuloEdificio%d" % int(b), texto, 110,
			Color(0.90, 0.87, 0.79), 15, false)
		raiz.add_child(l)
		l.position = (_origen(t, int(b))
			+ _a_lo_largo(t, MODULO * (float(anchura) - 1.0) * 0.5)
			+ _hacia_fuera(t, D_ROTULO_EDIFICIO)
			+ Vector3.UP * Y_ROTULO_EDIFICIO)
		l.basis = Basis(Vector3.UP, giro)
		# tablero oscuro detrás de las letras
		_tablero(raiz, l.position - _hacia_fuera(t, 0.04), giro,
			minf(0.22 * float(texto.length()) + 0.7, MODULO * float(anchura) - 0.3))


## Fondo de un callejón: pared, tope, losa y una luz tenue.
func _fondo_de_hueco(raiz: Node3D, nombre: String, o: Vector3, giro: float) -> void:
	var m := MeshInstance3D.new()
	m.name = nombre
	var caja := BoxMesh.new()
	caja.size = Vector3(MODULO, 7.5, 0.5)
	m.mesh = caja
	# ladrillo como el de las casas; sin color de vértice = tinte blanco y hollín entero
	m.material_override = _f.material("ladrillo")
	raiz.add_child(m)
	m.basis = Basis(Vector3.UP, giro)
	# al fondo del módulo: 5 m de callejón
	var fondo := (o + Vector3.UP * 3.75
		- (Basis(Vector3.UP, giro) * Vector3.BACK) * (MODULO * 0.5 - 0.25))
	m.position = fondo

	# tope: es lo que distingue un callejón de una boca de calle
	var cuerpo := StaticBody3D.new()
	cuerpo.name = nombre + "_Tope"
	raiz.add_child(cuerpo)
	var cs := CollisionShape3D.new()
	var forma := BoxShape3D.new()
	forma.size = Vector3(MODULO, 6.25, 0.5)
	cs.shape = forma
	cuerpo.add_child(cs)
	cuerpo.position = fondo - Vector3.UP * (3.75 - 3.125)
	cuerpo.basis = m.basis

	# losa y luz tenue para que no se lea como agujero
	var losa := MeshInstance3D.new()
	losa.name = nombre + "_Losa"
	var plano := BoxMesh.new()
	plano.size = Vector3(MODULO, 0.1, MODULO)
	losa.mesh = plano
	losa.material_override = _material_de_suelo("acera")
	raiz.add_child(losa)
	losa.position = o + Vector3.UP * 0.05
	losa.basis = m.basis

	var luz := OmniLight3D.new()
	luz.name = nombre + "_Luz"
	luz.light_color = Color(1.0, 0.78, 0.5)
	luz.light_energy = 0.6
	luz.omni_range = 4.5
	luz.shadow_enabled = false
	raiz.add_child(luz)
	luz.position = o + Vector3.UP * 2.6 \
		- (Basis(Vector3.UP, giro) * Vector3.BACK) * (MODULO * 0.5 - 0.8)


## Colisión por tiradas de bahías con casa; los huecos quedan abiertos.
func _muro(raiz: Node3D, t: Dictionary, id: String) -> void:
	var cuerpo := StaticBody3D.new()
	cuerpo.name = "Muro_" + id
	raiz.add_child(cuerpo)

	var n: int = t["bahias"]
	var vacias: Dictionary = t["vacias"]
	var eje_x := absf((t["paso"] as Vector3).x) > 0.0
	var desde := -1
	for i in n + 1:
		var hay_casa := i < n and not vacias.has(i)
		if hay_casa and desde < 0:
			desde = i
		elif not hay_casa and desde >= 0:
			var cuantas := i - desde
			var largo := float(cuantas) * MODULO
			var forma := BoxShape3D.new()
			# fondo = un módulo
			forma.size = (Vector3(largo, CUBIERTA, MODULO) if eje_x
				else Vector3(MODULO, CUBIERTA, largo))
			var cs := CollisionShape3D.new()
			cs.shape = forma
			cuerpo.add_child(cs)
			cs.position = (_origen(t, desde)
				+ _a_lo_largo(t, (largo - MODULO) * 0.5)
				+ Vector3.UP * (CUBIERTA * 0.5))
			desde = -1


# ---------------------------------------------------------------- el suelo

## Suelo desde `corredores` en datos: calzada, aceras y bordillos por calle.
const ANCHO_CALZADA := 4.8


func _construir_suelo() -> void:
	var caja: Dictionary = _datos.get("caja", {})
	var lx := Array(caja.get("x", [-60, 60]))
	var lz := Array(caja.get("z", [-40, 12]))
	var centro := Vector3((float(lx[0]) + float(lx[1])) * 0.5, -0.5,
		(float(lz[0]) + float(lz[1])) * 0.5)
	var tam := Vector3(float(lx[1]) - float(lx[0]) + 60.0, 1.0,
		float(lz[1]) - float(lz[0]) + 60.0)

	# base: única colisión del suelo; sobra 30 m por lado para el rayo del ratón
	var suelo := StaticBody3D.new()
	suelo.name = "Suelo"
	_calle.add_child(suelo)
	suelo.position = centro
	var forma := BoxShape3D.new()
	forma.size = tam
	var cs := CollisionShape3D.new()
	cs.shape = forma
	suelo.add_child(cs)
	# lo que se ve: más ancho que la colisión, y abierto sobre los fosos
	_f.xf = Transform3D.IDENTITY
	_f.trozo("suelo")
	var visto := Rect2(centro.x - tam.x * 0.5 - 70.0, centro.z - tam.z * 0.5 - 70.0, tam.x + 140.0, tam.z + 140.0)
	for q in FACHADAS.rellenar(visto, _f.fosos):
		_f.caja_ab("pintura", Vector3(q.position.x, -1.0, q.position.y), Vector3(q.end.x, 0.0, q.end.y),
			Color(0.34, 0.33, 0.28))

	# calles sin colisión (el personaje no tiene gravedad y se engancharía),
	# fundidas por trozos; la acera, agujereada donde hay foso de sótano
	_f.xf = Transform3D.IDENTITY
	for c_raw in Array(_datos.get("corredores", [])):
		var c: Dictionary = c_raw
		var eje_x := String(c.get("eje", "x")) == "x"
		var cen := Array(c.get("centro", [0, 0]))
		var p := Vector3(float(cen[0]), 0.0, float(cen[1]))
		var largo := float(c.get("largo", 100.0))
		var acera_a := float(c.get("acera_a", 2.6))
		var acera_b := float(c.get("acera_b", 2.6))
		var media := ANCHO_CALZADA * 0.5
		var piezas := maxi(1, int(ceil(largo / FACHADAS.TROZO)))
		for k in piezas:
			var a := -largo * 0.5 + largo * float(k) / float(piezas)
			var b := a + largo / float(piezas)
			_f.empezar(p + (Vector3.RIGHT if eje_x else Vector3.BACK) * ((a + b) * 0.5))
			_losa("calzada" if eje_x else "calzada_z", eje_x, p, a, b, -media, media, 0.04)
			_losa("acera", eje_x, p, a, b, -media - acera_a, -media, 0.1)
			_losa("acera", eje_x, p, a, b, media, media + acera_b, 0.1)
			for lado in LADOS:
				_losa("pintura", eje_x, p, a, b, lado * media - 0.11, lado * media + 0.11, 0.11,
					Color(0.69, 0.66, 0.61))
	_f.cerrar(_nodo("Pavimento", _calle))


## Losa de y = 0 a `alto`, de `a` a `b` a lo largo y de `l0` a `l1` de través;
## sin lo que caiga en un foso.
func _losa(k: String, eje_x: bool, p: Vector3, a: float, b: float, l0: float, l1: float,
		alto: float, col: Color = Color.WHITE) -> void:
	var r := (Rect2(p.x + a, p.z + l0, b - a, l1 - l0) if eje_x
		else Rect2(p.x + l0, p.z + a, l1 - l0, b - a))
	var huecos: Array = []
	if k == "acera":
		for h: Rect2 in _f.fosos:
			if h.intersects(r):
				huecos.append(h)
	for q in FACHADAS.rellenar(r, huecos):
		_f.caja_ab(k, Vector3(q.position.x, 0.0, q.position.y), Vector3(q.end.x, alto, q.end.y), col)


## Adoquín procedimental en coords. de mundo (no UV): sin saltos entre mallas.
func _material_de_suelo(cual: String) -> Material:
	if cual == "bordillo":
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.69, 0.66, 0.61)
		return m
	var s := ShaderMaterial.new()
	s.shader = load("res://materials/adoquin.gdshader") as Shader
	var es_calzada := cual == "calzada"
	s.set_shader_parameter("color_piedra",
		Color(0.44, 0.41, 0.37) if es_calzada else Color(0.58, 0.57, 0.5))
	s.set_shader_parameter("color_junta",
		Color(0.24, 0.22, 0.21) if es_calzada else Color(0.42, 0.41, 0.37))
	s.set_shader_parameter("celdas", 2.6 if es_calzada else 1.05)
	s.set_shader_parameter("proporcion", 1.0 if es_calzada else 1.7)
	s.set_shader_parameter("junta", 0.07 if es_calzada else 0.045)
	s.set_shader_parameter("variacion", 0.2 if es_calzada else 0.1)
	# matajunta en la calzada, a hueso en la acera
	s.set_shader_parameter("alabeo", 0.5 if es_calzada else 0.0)
	s.set_shader_parameter("rugosidad", 1.0)
	return s


# ---------------------------------------------------------------- puertas

## Puerta = cuerpo clicable + hoja + ocupante + número, de una entrada del JSON.
func _construir_puertas() -> void:
	var raiz := _nodo("Puertas", _calle)
	var numeros := _nodo("Numeros", _calle)
	var guion := load(INTERACTUABLE) as Script
	var hoja_escena := load(HOJA) as PackedScene
	var figura_escena := load(FIGURA) as PackedScene

	var k := 0
	for p_raw in Array(_datos.get("puertas", [])):
		var p: Dictionary = p_raw
		var t: Dictionary = _tramos.get(String(p.get("tramo", "")), {})
		if t.is_empty():
			push_warning("ConstructorCalle: la puerta " + String(p.get("numero", "?"))
				+ " apunta a un tramo que no existe.")
			continue
		k += 1
		var o := _origen(t, int(p.get("bahia", 0)))
		var giro: float = t["giro"]

		var cuerpo := StaticBody3D.new()
		cuerpo.name = "Puerta%d" % k
		cuerpo.set_script(guion)
		cuerpo.add_to_group(&"puertas")
		cuerpo.set("dialogue_id", String(p.get("dialogo", "")))
		cuerpo.set("display_name", String(p.get("nombre", "A door")))
		cuerpo.set("stop_distance", float(p.get("distancia", 2.2)))
		# se llama desde delante
		cuerpo.set("mirar_de_frente", true)
		cuerpo.set("requires", PackedStringArray(Array(p.get("requiere", []))))
		cuerpo.set("locked_dialogue_id", String(p.get("si_no", "")))
		if p.has("cerrada"):
			cuerpo.set_meta(&"cerrada", String(p["cerrada"]))
		if bool(p.get("no_abre", false)):
			cuerpo.set_meta(&"no_abre", true)
		raiz.add_child(cuerpo)
		cuerpo.position = o + _hacia_fuera(t, D_FACHADA) + Vector3.UP * 1.25
		cuerpo.basis = Basis(Vector3.UP, giro)

		var cs := CollisionShape3D.new()
		var caja := BoxShape3D.new()
		caja.size = Vector3(1.4, 2.5, 0.4)
		cs.shape = caja
		cuerpo.add_child(cs)

		# puertas de lado: zona de clic que sale 2 m a la acera (ver _zona_de_puerta)
		cuerpo.set_meta(&"numero", String(p.get("numero", "")))
		if absf((t["normal"] as Vector3).z) < 0.9:
			# y burbuja con su número (burbujas_de_puerta.gd)
			cuerpo.set_meta(&"lateral", true)
			var zona := Area3D.new()
			zona.name = "ZonaDeClic"
			zona.set_meta(&"puerta", true)
			zona.monitoring = false
			var zcs := CollisionShape3D.new()
			var zcaja := BoxShape3D.new()
			zcaja.size = Vector3(2.2, 2.6, 2.4)
			zcs.shape = zcaja
			zona.add_child(zcs)
			cuerpo.add_child(zona)
			zona.position = Vector3(0.0, 0.0, 1.2)

		if hoja_escena != null:
			var hoja := hoja_escena.instantiate()
			hoja.name = "Hoja"
			hoja.set("bisagras_a_la_izquierda", bool(p.get("bisagras_izquierda", true)))
			_pintar_hoja(hoja, t, int(p.get("bahia", 0)))
			# sin ropa = casa vacía, sin ocupante
			var ropa := Dictionary(p.get("ropa", {}))
			if not ropa.is_empty():
				hoja.set("ocupante", figura_escena)
				hoja.set("vestimenta", ropa)
			cuerpo.add_child(hoja)
			(hoja as Node3D).position = Vector3(0.0, -1.25, -0.375)

		var numero := String(p.get("numero", ""))
		if not numero.is_empty():
			# dorado sobre el montante oscuro, casi a ras: se lee desde arriba y en la vista de puerta
			var l := _rotulo("Numero" + numero, numero, 150,
				FACHADAS.ORO, 16, false)
			numeros.add_child(l)
			l.position = o + _hacia_fuera(t, D_FACHADA + FACHADAS.Z_NUMERO) + Vector3.UP * FACHADAS.Y_NUMERO
			l.basis = Basis(Vector3.UP, giro)


## La hoja del color de la puerta de su casa (antes de entrar al árbol).
func _pintar_hoja(hoja: Node, t: Dictionary, bahia: int) -> void:
	var ficha: Dictionary = Dictionary(t["casas"]).get(bahia, {})
	var pieza := hoja.get_node_or_null(^"Pivote/Hoja")
	if pieza != null and ficha.has("puerta_color"):
		pieza.set("color", ficha["puerta_color"])


## Nombre de calle: placa de hierro sobre la imposta del bajo, donde la cámara llega.
func _rotular() -> void:
	var raiz := _nodo("Rotulos", _calle)
	var k := 0
	for r_raw in Array(_datos.get("rotulos", [])):
		var r: Dictionary = r_raw
		var t: Dictionary = _tramos.get(String(r.get("tramo", "")), {})
		if t.is_empty():
			continue
		k += 1
		var b := int(r.get("bahia", 0))
		var c: Dictionary = Dictionary(t["casas"]).get(b, {})
		var y := (float(Array(c["pisos"])[0]) if not c.is_empty() else 3.4) + 0.42
		var texto := String(r.get("texto", ""))
		var ancho := 0.19 * float(texto.length()) + 0.4
		_f.xf = Transform3D(Basis(Vector3.UP, float(t["giro"])), _origen(t, b) + _hacia_fuera(t, D_FACHADA))
		_f.empezar(_f.xf.origin)
		_f.caja("pintura", Vector3(0.0, y, 0.02), Vector3(ancho + 0.08, 0.5, 0.04), Color(0.78, 0.75, 0.66))
		_f.caja("pintura", Vector3(0.0, y, 0.04), Vector3(ancho, 0.42, 0.04), Color(0.11, 0.11, 0.12))
		var l := _rotulo("Rotulo%d" % k, texto, 96, Color(0.92, 0.89, 0.8), 0, false)
		raiz.add_child(l)
		l.transform = _f.xf * Transform3D(Basis.IDENTITY, Vector3(0.0, y, 0.065))
	_f.xf = Transform3D.IDENTITY
	_f.cerrar(raiz)


# ---------------------------------------------------------------- esquinas

## Esquina: sitio interactuable; sin flecha, solo el rótulo de la pared.
func _construir_esquinas() -> void:
	_rotular()
	var raiz := _nodo("Esquinas", _calle)
	var guion := load(INTERACTUABLE) as Script
	var k := 0
	for e_raw in Array(_datos.get("esquinas", [])):
		var e: Dictionary = e_raw
		k += 1
		var pos := Array(e.get("pos", [0, 0]))
		var p := Vector3(float(pos[0]), 1.0, float(pos[1]))

		var cuerpo := StaticBody3D.new()
		cuerpo.name = "Esquina%d" % k
		cuerpo.set_script(guion)
		cuerpo.set("dialogue_id", String(e.get("dialogo", "")))
		cuerpo.set("display_name", String(e.get("nombre", "A corner")))
		cuerpo.set("stop_distance", float(e.get("distancia", 2.4)))
		# con `decision`: pensamiento y dos burbujas (opciones_en_el_mundo.gd)
		if e.has("decision"):
			cuerpo.set_meta(&"decision", e["decision"])
		raiz.add_child(cuerpo)
		cuerpo.position = p

		var cs := CollisionShape3D.new()
		var caja := BoxShape3D.new()
		caja.size = Vector3(1.4, 2.5, 1.4)
		cs.shape = caja
		cuerpo.add_child(cs)

		# con portal, la esquina es una puerta en la fachada
		var portal: Dictionary = Dictionary(e.get("portal", {}))
		var t: Dictionary = _tramos.get(String(portal.get("tramo", "")), {})
		if not t.is_empty():
			var giro: float = t["giro"]
			cuerpo.position = (_origen(t, int(portal.get("bahia", 0)))
				+ _hacia_fuera(t, D_FACHADA) + Vector3.UP * 1.25)
			cuerpo.basis = Basis(Vector3.UP, giro)
			cuerpo.set("mirar_de_frente", true)
			caja.size = Vector3(1.4, 2.5, 0.4)
			var hoja_escena := load(HOJA) as PackedScene
			if hoja_escena != null:
				var hoja := hoja_escena.instantiate()
				hoja.name = "Hoja"
				_pintar_hoja(hoja, t, int(portal.get("bahia", 0)))
				cuerpo.add_child(hoja)
				(hoja as Node3D).position = Vector3(0.0, -1.25, -0.375)

		if e.has("placa"):
			_placa(raiz, "Placa%d" % k, Dictionary(e["placa"]))

	# placas de calle sueltas
	var n := 0
	for pl in Array(_datos.get("placas", [])):
		n += 1
		_placa(raiz, "PlacaCalle%d" % n, Dictionary(pl))

	_poner_el_camino_a_casa()


## Placa de calle: hierro negro con filo claro, plana contra el muro.
func _placa(raiz: Node3D, nombre: String, d: Dictionary) -> void:
	var pos := Array(d.get("pos", [0, 2.3, 0]))
	var p := Vector3(float(pos[0]), float(pos[1]), float(pos[2]))
	var texto := String(d.get("texto", ""))

	# ancho según el texto
	var tam := Vector2(0.19 * float(texto.length()) + 0.4, 0.42)
	# filo claro detrás para que se recorte en la sombra
	_caja_plana(raiz, nombre + "Filo", p, tam + Vector2(0.08, 0.08), 0.04,
		Color(0.78, 0.75, 0.66))
	_caja_plana(raiz, nombre, p + Vector3.BACK * 0.01, tam, 0.04,
		Color(0.11, 0.11, 0.12))

	var l := _rotulo(nombre + "Texto", texto, 80, Color(0.92, 0.89, 0.8), 0, false)
	raiz.add_child(l)
	l.position = p + Vector3.BACK * 0.04


func _caja_plana(raiz: Node3D, nombre: String, p: Vector3, tam: Vector2,
		fondo: float, color: Color) -> void:
	var m := MeshInstance3D.new()
	m.name = nombre
	var caja := BoxMesh.new()
	caja.size = Vector3(tam.x, tam.y, fondo)
	m.mesh = caja
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.6
	m.material_override = mat
	raiz.add_child(m)
	m.position = p


## Rastro de luces a casa, solo hacia las esquinas con `"casa": true`.
func _poner_el_camino_a_casa() -> void:
	var salidas: Array[Vector3] = []
	for e_raw in Array(_datos.get("esquinas", [])):
		var e: Dictionary = e_raw
		if not bool(e.get("casa", false)):
			continue
		var pos := Array(e.get("pos", [0, 0]))
		salidas.append(Vector3(float(pos[0]), 0.0, float(pos[1])))
	if salidas.is_empty():
		return

	var camino := Node3D.new()
	camino.name = "CaminoACasa"
	camino.set_script(load(CAMINO) as Script)
	_calle.add_child(camino)
	camino.set("salidas", salidas)
	# se pasa tras add_child: el camino no resuelve nada en su _ready
	camino.set("jugador", get_node_or_null(jugador_path) as Node3D)


# ---------------------------------------------------------------- vecinos

func _construir_vecinos() -> void:
	var raiz := _nodo("Vecinos", _calle)
	var guion := load(INTERACTUABLE) as Script
	var figura_escena := load(FIGURA) as PackedScene
	var burbuja_escena := load(BURBUJA) as PackedScene
	var marcharse := load(MARCHARSE) as Script

	for v_raw in Array(_datos.get("vecinos", [])):
		var v: Dictionary = v_raw
		var pos := Array(v.get("pos", [0, 0]))
		var cuerpo := StaticBody3D.new()
		cuerpo.name = String(v.get("id", "Vecino"))
		cuerpo.set_script(guion)
		cuerpo.set("dialogue_id", String(v.get("dialogo", "")))
		cuerpo.set("display_name", String(v.get("nombre", "A neighbour")))
		cuerpo.set("stop_distance", float(v.get("distancia", 1.8)))
		cuerpo.set("requires", PackedStringArray(Array(v.get("requiere", []))))
		cuerpo.set("locked_dialogue_id", String(v.get("si_no", "")))
		raiz.add_child(cuerpo)
		cuerpo.position = Vector3(float(pos[0]), 0.0, float(pos[1]))

		var cs := CollisionShape3D.new()
		var capsula := CapsuleShape3D.new()
		capsula.radius = 0.34
		capsula.height = 1.75
		cs.shape = capsula
		cs.position = Vector3(0.0, 0.88, 0.0)
		cuerpo.add_child(cs)

		if figura_escena != null:
			var fig := figura_escena.instantiate()
			fig.name = "Figura"
			# vestir ANTES de add_child (se viste en su _ready)
			VESTUARIO.aplicar(fig, Dictionary(v.get("ropa", {})))
			cuerpo.add_child(fig)
			if v.has("mira"):
				(fig as Node3D).rotation.y = deg_to_rad(float(v["mira"]))

		# luz de cara para quien tiene diálogo, en vez de un icono
		if not String(v.get("dialogo", "")).is_empty():
			var luz := OmniLight3D.new()
			luz.name = "LuzDeCara"
			luz.light_color = Color(1.0, 0.86, 0.68)
			luz.light_energy = 0.7
			luz.light_specular = 0.0
			luz.omni_range = 2.4
			luz.omni_attenuation = 1.3
			cuerpo.add_child(luz)
			luz.position = Vector3(0.0, 1.9, 0.9)

		if bool(v.get("burbuja", false)) and burbuja_escena != null:
			var b := burbuja_escena.instantiate() as Node3D
			b.name = "Burbuja"
			# altura ANTES de add_child: su _ready guarda la altura de reposo
			b.position = Vector3(0.0, 2.25, 0.0)
			cuerpo.add_child(b)

		if v.has("se_marcha"):
			var m: Dictionary = v["se_marcha"]
			var d := Array(m.get("destino", [0, 0, 0]))
			var nodo := Node3D.new()
			nodo.name = "Marcharse"
			nodo.set_script(marcharse)
			nodo.set("bandera", String(m.get("bandera", "")))
			nodo.set("destino", Vector3(float(d[0]), 0.0, float(d[1])))
			nodo.set("velocidad", float(m.get("velocidad", 1.9)))
			nodo.set("espera", float(m.get("espera", 0.8)))
			cuerpo.add_child(nodo)


# ---------------------------------------------------------------- decorado

## Árboles/farolas que tapan una puerta se corren a la medianera más cercana.
const ANCHO_DE_PASO := 1.9   ## Medio hueco de puerta más el aire para llamar.
const FONDO_DE_PASO := 5.2   ## Hasta el bordillo. Más allá es calzada.

## Props de suelo: no se apartan de las puertas (p.ej. el cubo del nº 40).
const PROPS_DE_SUELO: PackedStringArray = ["cubo", "basura"]


## Medianeras ya usadas, para no amontonar dos props al apartarlos.
var _sitios_ocupados: Array[Dictionary] = []
const HUECO_MINIMO := 1.6


func _apartar_de_las_puertas(punto: Vector3, tipo: String) -> Vector3:
	if tipo in PROPS_DE_SUELO:
		return punto
	for intento in 2:
		var choque := false
		for p_raw in Array(_datos.get("puertas", [])):
			var p: Dictionary = p_raw
			var t: Dictionary = _tramos.get(String(p.get("tramo", "")), {})
			if t.is_empty():
				continue
			var o := _origen(t, int(p.get("bahia", 0)))
			var normal: Vector3 = t["normal"]
			var eje: Vector3 = (t["paso"] as Vector3).normalized()

			var d := punto - o
			d.y = 0.0
			# fondo: salida del plano de fachada; lado: desvío del eje de la puerta
			var fondo := d.dot(normal) - D_FACHADA
			var lado := d.dot(eje)
			if fondo < -0.5 or fondo > FONDO_DE_PASO or absf(lado) >= ANCHO_DE_PASO:
				continue

			# a la medianera más cercana; si está ocupada, a la del otro lado
			var hacia := 1.0 if lado >= 0.0 else -1.0
			var candidato := punto + eje * (hacia * MODULO * 0.5 - lado)
			if _esta_ocupado(candidato, tipo):
				candidato = punto + eje * (-hacia * MODULO * 0.5 - lado)
			punto = candidato
			choque = true
			if intento == 0:
				push_warning("ConstructorCalle: el prop '" + tipo
					+ "' tapaba la puerta " + String(p.get("numero", "?"))
					+ "; lo he corrido a la medianera.")
			break
		if not choque:
			break
	return punto


## Solo choca con un prop del mismo tipo.
func _esta_ocupado(p: Vector3, tipo: String) -> bool:
	for q in _sitios_ocupados:
		if String(q["tipo"]) != tipo:
			continue
		var o: Vector3 = q["pos"]
		if Vector2(p.x - o.x, p.z - o.z).length() < HUECO_MINIMO:
			return true
	return false


func _construir_props() -> void:
	_sitios_ocupados.clear()
	var raiz := _nodo("Mobiliario", _calle)
	var solidos := _nodo("Solidos", _calle)
	var k := 0

	for p_raw in Array(_datos.get("props", [])):
		var p: Dictionary = p_raw
		k += 1
		var tipo := String(p.get("tipo", ""))
		if not PROPS.has(tipo):
			push_warning("ConstructorCalle: prop desconocido '" + tipo + "'")
			continue
		var pos := Array(p.get("pos", [0, 0]))
		var punto := Vector3(float(pos[0]), float(p.get("y", 0.1)), float(pos[1]))
		punto = _apartar_de_las_puertas(punto, tipo)
		# todo prop de acera reserva su sitio, se haya movido o no
		if not (tipo in PROPS_DE_SUELO):
			# separa también solapes escritos a mano en el JSON
			if _esta_ocupado(punto, tipo):
				push_warning("ConstructorCalle: dos '" + tipo + "' pegados en "
					+ str(Vector2(punto.x, punto.z)) + "; los he separado.")
				punto += Vector3(HUECO_MINIMO, 0.0, 0.0)
			_sitios_ocupados.append({"tipo": tipo, "pos": punto})

		# la bomba va con el resto de props
		if tipo == "bomba":
			_construir_bomba(p, punto)
			continue

		var nodo := _cargar(PROPS[tipo])
		if nodo == null:
			continue
		nodo.name = "%s_%d" % [tipo, k]
		raiz.add_child(nodo)
		nodo.position = punto
		if p.has("giro"):
			nodo.basis = Basis(Vector3.UP, deg_to_rad(float(p["giro"])))
		if p.has("escala"):
			nodo.scale = Vector3.ONE * float(p["escala"])

		# los .glb de Kenney no traen colisión
		if p.has("solido"):
			var s := Array(p["solido"])
			var cuerpo := StaticBody3D.new()
			cuerpo.name = "Col_" + nodo.name
			solidos.add_child(cuerpo)
			cuerpo.position = punto + Vector3.UP * (float(s[1]) * 0.5)
			var cs := CollisionShape3D.new()
			var caja := BoxShape3D.new()
			caja.size = Vector3(float(s[0]), float(s[1]), float(s[2]))
			cs.shape = caja
			cuerpo.add_child(cs)


func _construir_bomba(p: Dictionary, punto: Vector3) -> void:
	var cuerpo := StaticBody3D.new()
	cuerpo.name = "Bomba"
	cuerpo.set_script(load(INTERACTUABLE) as Script)
	cuerpo.set("dialogue_id", String(p.get("dialogo", "")))
	cuerpo.set("display_name", String(p.get("nombre", "A pump")))
	_calle.add_child(cuerpo)
	cuerpo.position = Vector3(punto.x, 0.0, punto.z)

	var cil := CylinderShape3D.new()
	cil.height = 2.4
	cil.radius = 0.55
	var cs := CollisionShape3D.new()
	cs.shape = cil
	cs.position = Vector3(0.0, 1.2, 0.0)
	cuerpo.add_child(cs)

	var modelo := _cargar(PROPS["bomba"])
	if modelo != null:
		modelo.name = "Modelo"
		cuerpo.add_child(modelo)


# ---------------------------------------------------------------- ajustes

## Posición inicial: la guardada al cargar partida, si no la de defecto.
func _colocar_al_jugador() -> void:
	var jugador := get_node_or_null(jugador_path) as Node3D
	if jugador == null:
		return
	var punto := Array()
	if Barrio.entrada_por == Barrio.GUARDADA:
		punto = Barrio.posicion(String(_datos.get("id", "")))
	if punto.size() < 2:
		punto = Array(Dictionary(_datos.get("entradas", {})).get("defecto", []))
	if punto.size() < 2:
		return
	jugador.global_position = Vector3(
		float(punto[0]), jugador.global_position.y, float(punto[1]))


## Límites de la cámara en X y Z.
func _ajustar_la_camara() -> void:
	var cam := get_node_or_null(camara_path) as Camera3D
	if cam == null:
		return
	# la acera de enfrente y las manzanas de alrededor son solo para el cine
	cam.cull_mask &= ~FACHADAS.CAPA_CINE
	var lim: Dictionary = _datos.get("camara", {})
	var lx := Array(lim.get("x", []))
	var lz := Array(lim.get("z", []))
	if lx.size() == 2:
		cam.set("limite_x", Vector2(float(lx[0]), float(lx[1])))
	if lz.size() == 2:
		cam.set("limite_z", Vector2(float(lz[0]), float(lz[1])))


## Se hornea tras construir, si no la malla no tendría agujeros.
func _hornear_navegacion() -> void:
	var nav := get_node_or_null(nav_path) as NavigationRegion3D
	if nav == null or nav.navigation_mesh == null:
		push_error("ConstructorCalle: no hay NavigationRegion3D que hornear.")
		return
	var caja: Dictionary = _datos.get("caja", {})
	var lx := Array(caja.get("x", [-60, 60]))
	var lz := Array(caja.get("z", [-40, 12]))
	nav.navigation_mesh.filter_baking_aabb = AABB(
		Vector3(float(lx[0]), -1.0, float(lz[0])),
		Vector3(float(lx[1]) - float(lx[0]), 6.0, float(lz[1]) - float(lz[0])))
	nav.bake_navigation_mesh(false)


func _poner_el_rotulo_de_la_escena() -> void:
	var raiz := get_parent()
	if raiz != null:
		raiz.set("scene_id", String(_datos.get("scene_id", "")))


# ---------------------------------------------------------------- utilería

func _nodo(nombre: String, padre: Node) -> Node3D:
	var n := Node3D.new()
	n.name = nombre
	padre.add_child(n)
	return n


func _cargar(ruta: String) -> Node3D:
	var escena := load(ruta) as PackedScene
	if escena == null:
		push_warning("ConstructorCalle: no pude cargar " + ruta)
		return null
	return escena.instantiate() as Node3D


func _colocar(padre: Node, nombre: String, ruta: String, pos: Vector3,
		giro: float) -> Node3D:
	var n := _cargar(ruta)
	if n == null:
		return null
	n.name = nombre
	padre.add_child(n)
	n.position = pos
	n.basis = Basis(Vector3.UP, giro)
	return n


## cartel = billboard; si no, pintado en la fachada con la fuente de los números.
func _rotulo(nombre: String, texto: String, tam: int, color: Color,
		contorno: int, cartel: bool) -> Label3D:
	var l := Label3D.new()
	l.name = nombre
	l.text = texto
	l.double_sided = false
	l.shaded = false
	l.modulate = color
	l.outline_modulate = Color(0.14, 0.09, 0.05)
	l.outline_size = contorno
	l.font_size = tam
	if cartel:
		l.pixel_size = 0.0032
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	else:
		l.pixel_size = 0.003
		if _fuente != null:
			l.font = _fuente
	return l


# ---------------------------------------------------------------- cervecería y asilo

## La cervecería es ladrillo rojo y el asilo sillería gris (ver fachadas.gd); aquí, lo de delante.
const CARRO_CERVEZA := "res://art/models/Medieval/GLB format/cart.glb"
const BRINDIS := "res://scripts/world/brindis.gd"

## Bebedores ante la cervecería: [a lo largo desde la puerta, hacia fuera, ropa].
const BEBEDORES_CALLE := [
	[3.6, 3.45, {"abrigo": [0.78, 0.74, 0.64], "pantalon": [0.22, 0.2, 0.18], "sombrero": [0.3, 0.26, 0.2], "gorra": true}],
	[5.4, 3.4, {"abrigo": [0.5, 0.36, 0.2], "pantalon": [0.26, 0.23, 0.2], "sombrero": [0.22, 0.2, 0.18], "gorra": true}],
	[5.0, 4.75, {"abrigo": [0.38, 0.44, 0.55], "pantalon": [0.2, 0.2, 0.22], "sombrero": [0.25, 0.25, 0.28], "gorra": true}],
	[3.7, 4.7, {"abrigo": [0.7, 0.66, 0.58], "pantalon": [0.3, 0.26, 0.2], "gorra": false}],
	[2.9, 3.05, {"abrigo": [0.55, 0.4, 0.26], "pantalon": [0.24, 0.22, 0.2], "sombrero": [0.35, 0.3, 0.22], "gorra": true}],
]
## Barril de pie que hace de mesa, en el centro del corro.
const MESA_CALLE := Vector2(4.5, 4.05)


## Lo suyo delante de cada edificio grande; el rótulo ya lo pintó _pintar_rotulos_de_edificio.
func _vestir_edificios(raiz: Node3D, t: Dictionary, giro: float) -> void:
	for b in t["porte"]:
		var datos: Dictionary = t["porte"][b]
		var cual := String(datos.get("rotulo", "")).split(" ")[-1]
		var anchura := maxi(1, int(datos.get("bahias", 1)))
		if cual == "BREWERY":
			_cerveceria(raiz, t, int(b), anchura, giro)
		elif cual == "WORKHOUSE":
			_asilo(raiz, t, int(b), giro)


## Abierta de noche: luz cálida, farol, barriles, carro, un corro bebiendo fuera y la chimenea.
func _cerveceria(raiz: Node3D, t: Dictionary, b: int, anchura: int, giro: float) -> void:
	# todo a lo largo desde la puerta, hacia el fondo del edificio
	var puerta := _origen(t, b)
	var luz := OmniLight3D.new()
	luz.name = "LuzCerveceria"
	luz.light_color = Color(1.0, 0.72, 0.42)
	luz.light_energy = 2.8
	luz.omni_range = 7.5
	luz.shadow_enabled = false
	raiz.add_child(luz)
	# desde la calle, para que el corro no quede a contraluz
	luz.position = puerta + _a_lo_largo(t, 4.4) + _hacia_fuera(t, 5.6) + Vector3.UP * 2.7
	_farol_de_pared(raiz, puerta + _a_lo_largo(t, 4.4) + _hacia_fuera(t, 2.95) + Vector3.UP * 3.1, giro)
	_barriles(raiz, t, puerta, giro)
	_corro_de_la_calle(raiz, t, puerta)
	# chimenea de la sala de calderas, detrás: se ve desde lejos por encima de los tejados
	var mitad := puerta + _a_lo_largo(t, MODULO * float(anchura - 1) * 0.5)
	_f.xf = Transform3D(Basis(Vector3.UP, giro), mitad + _hacia_fuera(t, D_FACHADA))
	_f.empezar(_f.xf.origin)
	var col := FACHADAS.ladrillo(Color(1.0, 0.66, 0.55), 0.8)
	var zc := -FACHADAS.FONDO - 2.5
	_f.caja_ab("ladrillo", Vector3(-1.1, 0.0, zc - 1.1), Vector3(1.1, 4.0, zc + 1.1), col)
	_f.caja_ab("ladrillo", Vector3(-0.8, 4.0, zc - 0.8), Vector3(0.8, 24.0, zc + 0.8), col)
	for y in [4.0, 12.0, 20.0]:
		_f.caja_ab("pintura", Vector3(-0.9, y, zc - 0.9), Vector3(0.9, y + 0.25, zc + 0.9), FACHADAS.PIEDRA.darkened(0.2))
	_f.caja_ab("ladrillo", Vector3(-1.0, 23.4, zc - 1.0), Vector3(1.0, 24.4, zc + 1.0), col.darkened(0.2))
	_f.xf = Transform3D.IDENTITY


## Farol de brazo en la fachada: cristal encendido y tapa de hierro.
func _farol_de_pared(raiz: Node3D, pos: Vector3, giro: float) -> void:
	var cristal := StandardMaterial3D.new()
	cristal.albedo_color = Color(1.0, 0.8, 0.5)
	cristal.emission_enabled = true
	cristal.emission = Color(1.0, 0.72, 0.38)
	cristal.emission_energy_multiplier = 2.2
	var hierro := StandardMaterial3D.new()
	hierro.albedo_color = Color(0.08, 0.08, 0.09)
	for p in [[Vector3(0.26, 0.34, 0.26), Vector3.ZERO, cristal], [Vector3(0.34, 0.06, 0.34), Vector3(0.0, 0.2, 0.0), hierro],
			[Vector3(0.04, 0.04, 0.5), Vector3(0.0, 0.2, -0.25), hierro]]:
		var m := MeshInstance3D.new()
		var caja := BoxMesh.new()
		caja.size = p[0]
		m.mesh = caja
		m.material_override = p[2]
		raiz.add_child(m)
		m.basis = Basis(Vector3.UP, giro)
		m.position = pos + m.basis * (p[1] as Vector3)


func _tablero(raiz: Node3D, pos: Vector3, giro: float, ancho: float) -> void:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(ancho, 0.62, 0.06)
	m.mesh = b
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.12, 0.10, 0.09)
	mat.roughness = 1.0
	m.material_override = mat
	raiz.add_child(m)
	m.position = pos
	m.basis = Basis(Vector3.UP, giro)


func _barril_de_calle(raiz: Node3D, pos: Vector3, alto: float, madera: Material, aro: Material) -> void:
	var barril := Node3D.new()
	raiz.add_child(barril)
	barril.position = pos
	var c := CylinderMesh.new()
	c.top_radius = 0.3
	c.bottom_radius = 0.3
	c.height = alto
	var cuerpo := MeshInstance3D.new()
	cuerpo.mesh = c
	cuerpo.material_override = madera
	cuerpo.position.y = alto * 0.5
	barril.add_child(cuerpo)
	for y in [0.19 * alto, 0.81 * alto]:
		var a := CylinderMesh.new()
		a.top_radius = 0.315
		a.bottom_radius = 0.315
		a.height = 0.05
		var anillo := MeshInstance3D.new()
		anillo.mesh = a
		anillo.material_override = aro
		anillo.position.y = y
		barril.add_child(anillo)


## Barriles contra el muro, lejos de la puerta, y el carro de cerveza en la calzada.
func _barriles(raiz: Node3D, t: Dictionary, puerta: Vector3, giro: float) -> void:
	var madera := StandardMaterial3D.new()
	madera.albedo_color = Color(0.45, 0.30, 0.17)
	var aro := StandardMaterial3D.new()
	aro.albedo_color = Color(0.15, 0.14, 0.13)
	for s in [[6.3, 2.95, 0.0], [6.95, 2.95, 0.0], [6.62, 2.95, 0.78]]:
		_barril_de_calle(raiz, puerta + _a_lo_largo(t, float(s[0])) + _hacia_fuera(t, float(s[1]))
			+ Vector3.UP * float(s[2]), 0.78, madera, aro)
	# el del corro, de pie y más alto: es la mesa
	_barril_de_calle(raiz, puerta + _a_lo_largo(t, MESA_CALLE.x) + _hacia_fuera(t, MESA_CALLE.y), 1.0, madera, aro)
	var peltre := StandardMaterial3D.new()
	peltre.albedo_color = Color(0.55, 0.52, 0.47)
	for k in 2:
		var jarra := MeshInstance3D.new()
		var c := CylinderMesh.new()
		c.top_radius = 0.06
		c.bottom_radius = 0.065
		c.height = 0.15
		jarra.mesh = c
		jarra.material_override = peltre
		raiz.add_child(jarra)
		jarra.position = (puerta + _a_lo_largo(t, MESA_CALLE.x - 0.1 + 0.2 * float(k))
			+ _hacia_fuera(t, MESA_CALLE.y + 0.08 * float(k)) + Vector3.UP * 1.08)
	var carro := _colocar(raiz, "CarroDeCerveza", CARRO_CERVEZA,
		puerta + _a_lo_largo(t, 6.2) + _hacia_fuera(t, 7.2), giro + PI * 0.5)
	if carro != null:
		for k in 3:
			var c := CylinderMesh.new()
			c.top_radius = 0.28
			c.bottom_radius = 0.28
			c.height = 0.7
			var barril := MeshInstance3D.new()
			barril.mesh = c
			barril.material_override = madera
			carro.add_child(barril)
			barril.position = Vector3(-0.5 + 0.5 * k, 1.25, 0.0)


## Obreros brindando en la acera, apartados de la puerta; un solo cuerpo de colisión.
func _corro_de_la_calle(raiz: Node3D, t: Dictionary, puerta: Vector3) -> void:
	if Engine.is_editor_hint():
		return
	var guion := load(BRINDIS) as Script
	var mesa := puerta + _a_lo_largo(t, MESA_CALLE.x) + _hacia_fuera(t, MESA_CALLE.y)
	var k := 0
	for d in BEBEDORES_CALLE:
		var ropa := Dictionary(d[2]).duplicate()
		ropa["chistera"] = false
		ropa["alzacuellos"] = false
		ropa["mira_alrededor"] = false
		ropa["estatura"] = 0.95 + 0.04 * float(k % 3)
		var b := Node3D.new()
		b.name = "BebedorCalle%d" % k
		b.set_script(guion)
		b.set("ropa", ropa)
		b.set("corro", "calle_cerveceria")
		raiz.add_child(b)
		b.position = puerta + _a_lo_largo(t, float(d[0])) + _hacia_fuera(t, float(d[1]))
		var mira := mesa - b.position
		b.rotation.y = atan2(mira.x, mira.z)
		k += 1
	var cuerpo := StaticBody3D.new()
	cuerpo.name = "CorroCerveceria"
	raiz.add_child(cuerpo)
	var cs := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = Vector3(5.2, 2.0, 2.3)
	cs.shape = caja
	cuerpo.add_child(cs)
	cuerpo.position = puerta + _a_lo_largo(t, 5.1) + _hacia_fuera(t, 3.95) + Vector3.UP
	cuerpo.basis = Basis(Vector3.UP, (t["giro"] as float))


# ---------------------------------------------------------------- el asilo

## Edificio público, no casa: la sillería y las impostas las pone fachadas.gd;
## aquí el zócalo, las losas, la cornisa, el frontón con reloj y el farol.
func _asilo(raiz: Node3D, t: Dictionary, b: int, giro: float) -> void:
	var o := _origen(t, b)
	var c: Dictionary = Dictionary(t["casas"]).get(b, {})
	if c.is_empty():
		return
	var yt := FACHADAS.altura(c)
	_f.xf = Transform3D(Basis(Vector3.UP, giro), o + _hacia_fuera(t, D_FACHADA))
	_f.empezar(_f.xf.origin)
	var lisa := Color(0.66, 0.67, 0.69)
	var oscura := Color(0.42, 0.43, 0.45)
	# zócalo a los lados de la puerta y un escalón
	for lado in LADOS:
		_f.caja("pintura", Vector3(lado * 1.72, 0.36, 0.1), Vector3(1.56, 0.72, 0.2), oscura)
	_f.caja("pintura", Vector3(0.0, 0.07, 0.28), Vector3(2.4, 0.14, 0.56), oscura)
	# cornisa volada sobre el último piso
	_f.caja("pintura", Vector3(0.0, yt - 0.08, 0.12), Vector3(MODULO + 0.3, 0.3, 0.42), lisa)
	# frontón sobre el pretil, con el reloj de la parroquia
	var y_pret := yt + FACHADAS.pretil(c) + 0.1
	_f.extruir("pintura", PackedVector2Array([Vector2(-2.65, y_pret), Vector2(2.65, y_pret), Vector2(0.0, y_pret + 1.7)]),
		-0.4, 0.1, 2, lisa)
	_f.xf = Transform3D.IDENTITY
	_reloj(raiz, t, o + _hacia_fuera(t, D_FACHADA + 0.12) + Vector3.UP * (y_pret + 0.62), giro)

	# losas grandes y claras delante: desde arriba también se ve que es otra cosa
	var losas := _material_de_suelo("acera") as ShaderMaterial
	losas.set_shader_parameter("color_piedra", Color(0.68, 0.69, 0.71))
	losas.set_shader_parameter("color_junta", Color(0.4, 0.4, 0.42))
	losas.set_shader_parameter("celdas", 0.8)
	losas.set_shader_parameter("proporcion", 1.0)
	_sillar(raiz, t, o, giro, Vector3(0.0, 0.065, 3.8), Vector3(MODULO, 0.13, 2.5), losas)

	# farol de brazo junto a la portada y luz blanca, no la cálida de la cervecería
	var base := Transform3D(Basis(Vector3.UP, giro), o + _hacia_fuera(t, D_FACHADA))
	_farol_de_pared(raiz, base * Vector3(1.05, 3.1, 0.45), giro)
	var luz := OmniLight3D.new()
	luz.name = "LuzAsilo"
	luz.light_color = Color(0.95, 0.9, 0.8)
	luz.light_energy = 1.5
	luz.omni_range = 8.0
	luz.shadow_enabled = false
	raiz.add_child(luz)
	luz.position = o + _hacia_fuera(t, 3.6) + Vector3.UP * 3.3


## Caja de piedra en coordenadas de la bahía: x a lo largo, y arriba, z hacia fuera.
func _sillar(raiz: Node3D, t: Dictionary, o: Vector3, giro: float, p: Vector3, tam: Vector3,
		mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var caja := BoxMesh.new()
	caja.size = tam
	m.mesh = caja
	m.material_override = mat
	raiz.add_child(m)
	m.position = o + _a_lo_largo(t, p.x) + _hacia_fuera(t, p.z) + Vector3.UP * p.y
	m.basis = Basis(Vector3.UP, giro)
	return m


## Esfera blanca con aro y agujas, de cara a la calle.
func _reloj(raiz: Node3D, t: Dictionary, centro: Vector3, giro: float) -> void:
	var de_cara := Basis(Vector3.UP, giro) * Basis(Vector3.RIGHT, PI * 0.5)
	var aro := StandardMaterial3D.new()
	aro.albedo_color = Color(0.12, 0.12, 0.13)
	var esfera := StandardMaterial3D.new()
	esfera.albedo_color = Color(0.92, 0.9, 0.84)
	esfera.emission_enabled = true
	esfera.emission = Color(0.9, 0.86, 0.74)
	esfera.emission_energy_multiplier = 0.35
	for d in [[0.58, 0.06, 0.0, aro], [0.5, 0.06, 0.03, esfera]]:
		var disco := MeshInstance3D.new()
		var c := CylinderMesh.new()
		c.top_radius = float(d[0])
		c.bottom_radius = float(d[0])
		c.height = float(d[1])
		c.radial_segments = 24
		c.rings = 1
		disco.mesh = c
		disco.material_override = d[3]
		raiz.add_child(disco)
		disco.position = centro + _hacia_fuera(t, float(d[2]))
		disco.basis = de_cara
	# las diez y diez
	for a in [[0.3, -2.1], [0.42, 1.05]]:
		var aguja := MeshInstance3D.new()
		var caja := BoxMesh.new()
		caja.size = Vector3(0.05, float(a[0]), 0.02)
		aguja.mesh = caja
		aguja.material_override = aro
		raiz.add_child(aguja)
		var giro_aguja := Basis(Vector3.UP, giro) * Basis(Vector3.BACK, float(a[1]))
		aguja.basis = giro_aguja
		aguja.position = centro + _hacia_fuera(t, 0.08) + giro_aguja * (Vector3.UP * float(a[0]) * 0.5)
