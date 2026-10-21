extends Node3D
## Estelas a ras de suelo: de la puerta a la bomba, o hacia el extremo si bebía en otra.
## La calle es un decorado: el recorrido es simbólico, el mapa de verdad es la maqueta.

const ESTELAS := preload("res://scripts/estelas.gd")

const ANCHO := 0.6
const Y := 0.13
## Acera de las casas en Broad St y eje de Cambridge St.
const Z_ACERA := -3.7
## Ejes de las calles laterales (New, Cambridge, Peter).
const LATERALES := [-35.0, -15.0, 35.0]
const BOMBA := Vector3(-3.0, 0.0, 0.6)
## Fuentes fuera del decorado: la estela se va por un extremo.
const SALIDAS := {"marshall": -58.0}
## La bomba de Peter Street, al fondo de su calle.
const BOMBA_PETER := Vector3(35.0, 0.0, -21.0)

var _pendientes: Array[Dictionary] = []
var _luz: OmniLight3D


func _ready() -> void:
	# Las líneas a las fuentes se ven desde el final del capítulo I.
	if not GameState.has_flag("poster_visto"):
		queue_free()
		return
	Cuaderno.ficha_sellada.connect(_al_sellar)
	_luz = OmniLight3D.new()
	_luz.light_color = ESTELAS.C_MUERTE
	_luz.omni_range = 5.0
	_luz.light_energy = 0.0
	_luz.position = BOMBA + Vector3(0, 0.5, 0)
	add_child(_luz)
	# Las puertas se levantan en el mismo _ready del constructor.
	await get_tree().process_frame
	for e in Cuaderno.estelas():
		_dibujar(e, false)
	_brillo()


func _al_sellar(id: String) -> void:
	var e := Cuaderno.estela(id)
	if not e.is_empty():
		_pendientes.append(e)


## Se dibujan al cerrar el cuaderno, para que se vean.
func _process(_delta: float) -> void:
	if _pendientes.is_empty() or DialogueRunner.active or get_tree().paused:
		return
	if HUD.has_method(&"_hay_expediente_abierto") and bool(HUD.call(&"_hay_expediente_abierto")):
		return
	var e: Dictionary = _pendientes.pop_front()
	var m := _dibujar(e, true)
	if m != null:
		var son := AudioStreamPlayer3D.new()
		son.stream = preload("res://audio/sfx/goteo.wav")
		son.volume_db = -4.0
		m.add_child(son)
		son.play()
	_brillo()


func _puerta(numero: String) -> Node3D:
	for p in get_tree().get_nodes_in_group(&"puertas"):
		if String((p as Node).get_meta(&"numero", "")) == numero:
			return p as Node3D
	return null


## Nº de puerta de la ficha: su "desde" con número o su primer registro.
func _numero(ficha_id: String) -> String:
	var f := Cuaderno.ficha(ficha_id)
	var desde: Variant = Dictionary(f.get("estela", {})).get("desde", null)
	var calle := ""
	if desde is String:
		calle = String(desde)
	elif not Array(f.get("registros", [])).is_empty():
		calle = String(Dictionary(f["registros"][0]).get("calle", ""))
	var n := calle.split(" ")[0]
	return n if n.is_valid_int() else ""


func recorrido(e: Dictionary) -> PackedVector3Array:
	var puerta := _puerta(_numero(String(e["id"])))
	if puerta == null:
		return PackedVector3Array()
	var p := puerta.global_position
	var pts := PackedVector3Array()
	var eje := _lateral(p)
	# En su propia calle: directo a la bomba del fondo.
	if String(e["fuente"]) == "peter" and is_equal_approx(eje, BOMBA_PETER.x):
		return PackedVector3Array([Vector3(p.x + signf(eje - p.x), Y, p.z), Vector3(eje, Y, p.z), BOMBA_PETER + Vector3(0, Y, 0.8)])
	if not is_nan(eje):
		pts.append(Vector3(p.x + signf(eje - p.x) * 1.0, Y, p.z))
		pts.append(Vector3(eje, Y, p.z))
		pts.append(Vector3(eje, Y, Z_ACERA))
	else:
		pts.append(Vector3(p.x, Y, p.z + 1.0))
		pts.append(Vector3(p.x, Y, Z_ACERA))
	var fuente := String(e["fuente"])
	if fuente == "broad":
		pts.append(Vector3(BOMBA.x, Y, Z_ACERA))
		pts.append(Vector3(BOMBA.x, Y, BOMBA.z - 0.7))
	elif fuente == "peter":
		pts.append(Vector3(BOMBA_PETER.x, Y, Z_ACERA))
		pts.append(BOMBA_PETER + Vector3(0, Y, 0.8))
	elif SALIDAS.has(fuente):
		pts.append(Vector3(float(SALIDAS[fuente]), Y, Z_ACERA))
	else:
		return PackedVector3Array()
	return pts


func _dibujar(e: Dictionary, animar: bool) -> MeshInstance3D:
	var pts := recorrido(e)
	if pts.size() < 2:
		return null
	var m := MeshInstance3D.new()
	m.mesh = ESTELAS.cinta(pts, ANCHO)
	var metros := 0.0
	for i in range(1, pts.size()):
		metros += pts[i - 1].distance_to(pts[i])
	m.material_override = ESTELAS.material(String(e["clase"]), metros)
	m.set_meta(&"ficha", e["id"])
	add_child(m)
	if animar:
		ESTELAS.animar(m, clampf(metros / 14.0, 1.2, 3.5))
	return m


## La bomba se ilumina con cada estela de muerte que llega.
func _brillo() -> void:
	var n := 0
	for e in Cuaderno.estelas():
		if e["clase"] == "muerte" and e["fuente"] == "broad":
			n += 1
	_luz.light_energy = 0.35 * n


func dibujadas() -> int:
	var n := 0
	for c in get_children():
		if c is MeshInstance3D:
			n += 1
	return n


## Eje de la calle lateral de una puerta, o NAN si está en Broad Street.
static func _lateral(p: Vector3) -> float:
	if p.z > -9.0:
		return NAN
	var mejor := NAN
	for x in LATERALES:
		if is_nan(mejor) or absf(p.x - x) < absf(p.x - mejor):
			mejor = x
	return mejor
