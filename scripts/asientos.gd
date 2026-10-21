extends RefCounted
## Muertes por asentar en el mapa: libro, lista del sacristán y fichas selladas.

const LIBRO := "res://data/registro/ch1_libro_parroquia.json"

const PRUEBA_RACIMO := "broad_street_racimo"
## Se marca al asentar la 1ª tanda del libro; abre el 40 y Cambridge St.
const YA_COPIADO := "parish_book_read"
const ENTERRADA := "buried_frances_lewis"
## Asientos mínimos para trazar el cerco.
const SUFICIENTES := 20
const MIASMA_TRAS_EL_RACIMO := 0.84

static var _datos: Dictionary = {}


static func _libro() -> Dictionary:
	if _datos.is_empty():
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(LIBRO))
		if d is Dictionary:
			_datos = d
		else:
			push_error("Asientos: no puedo leer " + LIBRO)
	return _datos


static func _sin_asentar(lista: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for a in lista:
		if not Casefile.is_recorded(String(a.get("id", ""))):
			out.append(Dictionary(a))
	return out


static func primera_tanda() -> Array[Dictionary]:
	return _sin_asentar(Array(_libro().get("asientos", [])))


## Lista del sacristán: tras el entierro.
static func segunda_tanda() -> Array[Dictionary]:
	if not GameState.has_flag(ENTERRADA):
		return []
	return _sin_asentar(Array(_libro().get("segunda_tanda", [])))


## Muertes de fichas selladas aún sin asentar.
static func de_la_calle() -> Array[Dictionary]:
	return _sin_asentar(Cuaderno.registros_sellados())


## Lo que la vista de pájaro deja asentar: fichas y las listas del sacristán.
static func por_asentar() -> Array[Dictionary]:
	var out := de_la_calle()
	if GameState.has_flag("lista_1") or GameState.has_flag(YA_COPIADO):
		out.append_array(primera_tanda())
	if GameState.has_flag("lista_3"):
		out.append_array(segunda_tanda())
	return out


## Día cuya lista trae el carro y aún no se ha recogido (1 o 3), o 0.
static func lista_pendiente() -> int:
	if GameState.dia == 1 and GameState.has_flag("hablado_ch1_s3_tailor") and not GameState.has_flag("lista_1") and not GameState.has_flag(YA_COPIADO):
		return 1
	if GameState.dia >= 3 and GameState.has_flag(ENTERRADA) and not GameState.has_flag("lista_3"):
		return 3
	return 0


static func marcar_libro_leido() -> void:
	if GameState.has_flag(YA_COPIADO):
		return
	if primera_tanda().is_empty():
		GameState.set_flag(YA_COPIADO)


## Toca cercar el racimo: enterrada, bastantes y nada pendiente.
static func toca_cercar() -> bool:
	return not Casefile.has(PRUEBA_RACIMO) and GameState.has_flag(ENTERRADA) \
		and Casefile.record_count() >= SUFICIENTES and por_asentar().is_empty()
