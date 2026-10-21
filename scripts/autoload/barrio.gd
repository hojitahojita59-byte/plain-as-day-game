extends Node
## Barrio: calles que hay (de _indice.json), en cuál estamos y por dónde se entró.
## Índice y no listar la carpeta: listar falla en el juego exportado.

const CARPETA := "res://data/barrio/"
const INDICE := CARPETA + "_indice.json"

## Escena única que construye cualquier calle a partir de sus datos.
const ESCENA_CALLE := "res://scenes/world/calle.tscn"
const CEMENTERIO := "res://scenes/world/cementerio.tscn"

## Entrada especial: donde lo dejaste.
const GUARDADA := "guardada"

signal calle_cambiada(id: String)

var actual: String = "soho"

## Id de la calle de la que se viene, o "defecto" (elige la esquina de llegada).
var entrada_por: String = "defecto"

## Última posición en cada calle: id -> [x, z].
var _posiciones: Dictionary = {}

var _calles: Dictionary = {}


func _ready() -> void:
	_cargar()


func _cargar() -> void:
	var ids: Variant = _leer(INDICE)
	if typeof(ids) != TYPE_ARRAY:
		push_error("Barrio: " + INDICE + " tiene que ser una lista de ids.")
		return
	for id_raw in Array(ids):
		var id := String(id_raw)
		var d = _leer(CARPETA + id + ".json")
		if typeof(d) != TYPE_DICTIONARY:
			push_error("Barrio: la calle '" + id + "' no se pudo leer.")
			continue
		var datos: Dictionary = d
		# El id lo pone el índice: una copia mal renombrada no pisa a otra.
		datos["id"] = id
		_calles[id] = datos
	print("Barrio: %d calles cargadas" % _calles.size())


func _leer(ruta: String) -> Variant:
	var f := FileAccess.open(ruta, FileAccess.READ)
	if f == null:
		push_error("Barrio: no se pudo abrir " + ruta)
		return null
	return JSON.parse_string(f.get_as_text())


func hay(id: String) -> bool:
	return _calles.has(id)


func datos(id: String) -> Dictionary:
	return _calles.get(id, {})


func nombre(id: String) -> String:
	return String(datos(id).get("nombre", id))


func ids() -> Array:
	return _calles.keys()


## Vuelve a la calle en que se estaba.
func volver() -> void:
	# GUARDADA: al metro donde se dejó la calle.
	entrada_por = GUARDADA
	# Domingo: al salir de casa, el entierro de Frances.
	if GameState.dia >= 3 and not GameState.has_flag("buried_frances_lewis"):
		SceneRouter.change_scene(CEMENTERIO, SceneRouter.Kind.SHORT_FADE)
		return
	SceneRouter.change_scene(ESCENA_CALLE, SceneRouter.Kind.SHORT_FADE)


## Guarda dónde está de pie (al pararse de andar).
func anotar_posicion(id: String, x: float, z: float) -> void:
	_posiciones[id] = [x, z]


## Posición guardada, o [] si no se ha pisado.
func posicion(id: String) -> Array:
	return Array(_posiciones.get(id, []))


func to_dict() -> Dictionary:
	return {
		"actual": actual,
		"entrada_por": entrada_por,
		"posiciones": _posiciones.duplicate(true),
	}


func from_dict(d: Dictionary) -> void:
	actual = String(d.get("actual", "soho"))
	# Cargar siempre reanuda donde se estaba de pie.
	entrada_por = GUARDADA
	_posiciones = Dictionary(d.get("posiciones", {}))


func reset() -> void:
	actual = "soho"
	entrada_por = "defecto"
	_posiciones.clear()
