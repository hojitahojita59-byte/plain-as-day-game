extends Node
## Cuaderno: palabras oídas y fichas de cada casa con huecos que rellenar.
## Una ficha se sella con todo bien; su estado se guarda en Casefile.to_dict.

const DATOS := "res://data/cuaderno/ch1_cuaderno.json"
const PLANO_DE := preload("res://scripts/ui/plano_parroquia.gd")

signal palabra_aprendida(id: String)
signal ficha_abierta(id: String)
signal ficha_sellada(id: String)
## Cambio en una ficha (hueco puesto o quitado).
signal cambiado

## Resultado de comprobar una ficha.
enum { INCOMPLETA, SELLADA, UNA_MAL, VARIAS_MAL }

var _palabras_def: Dictionary = {}
var _tipos: Dictionary = {}
var _fichas_def: Array[Dictionary] = []

## Estado del jugador
var _sabidas: Dictionary = {}        # id de palabra -> quién se la dijo
var _abiertas: Array[String] = []    # ids de ficha, en el orden en que se abrieron
var _puestas: Dictionary = {}        # id de ficha -> {hueco: id de palabra}
var _selladas: Array[String] = []
## id de ficha -> huecos ya comprobados y bien.
var _fijas: Dictionary = {}
## Círculo trazado en el plano: [cx, cy, rx, ry] de 0 a 1.
var _circulo: Array = []


func _ready() -> void:
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATOS))
	if not (d is Dictionary):
		push_error("Cuaderno: no puedo leer " + DATOS)
		return
	_palabras_def = Dictionary(d.get("palabras", {}))
	_tipos = Dictionary(d.get("tipos", {}))
	for f in Array(d.get("fichas", [])):
		_fichas_def.append(Dictionary(f))


# --- Datos ---

func palabra(id: String) -> Dictionary:
	return Dictionary(_palabras_def.get(id, {}))


func existe_palabra(id: String) -> bool:
	return _palabras_def.has(id)


func tipos() -> Dictionary:
	return _tipos.duplicate(true)


func color_de(tipo: String) -> Color:
	return Color(String(Dictionary(_tipos.get(tipo, {})).get("color", "#333333")))


func ficha(id: String) -> Dictionary:
	for f in _fichas_def:
		if String(f.get("id", "")) == id:
			return f
	return {}


func todas_las_fichas() -> Array[Dictionary]:
	return _fichas_def.duplicate(true)


## Tipo del hueco = tipo de la palabra correcta.
func tipo_del_hueco(ficha_id: String, hueco: String) -> String:
	var correcta := String(Dictionary(ficha(ficha_id).get("huecos", {})).get(hueco, ""))
	return String(palabra(correcta).get("tipo", ""))


## Huecos en el orden en que salen en la frase.
func huecos_en_orden(ficha_id: String) -> Array[String]:
	var out: Array[String] = []
	var frase := String(ficha(ficha_id).get("frase", ""))
	var re := RegEx.new()
	re.compile("\\{([a-z0-9_]+)\\}")
	for m in re.search_all(frase):
		out.append(m.get_string(1))
	return out


# --- Acciones del jugador ---

## Aprende una palabra; `quien` es quién la dijo.
func aprender(id: String, quien: String = "") -> bool:
	if not _palabras_def.has(id):
		push_error("Cuaderno: palabra inexistente '%s'" % id)
		return false
	if _sabidas.has(id):
		return false
	_sabidas[id] = quien
	GameState.set_flag("palabra_" + id)
	palabra_aprendida.emit(id)
	return true


func sabe(id: String) -> bool:
	return _sabidas.has(id)


func de_quien(id: String) -> String:
	return String(_sabidas.get(id, ""))


func sabidas() -> Array[String]:
	var out: Array[String] = []
	for k in _sabidas:
		out.append(String(k))
	return out


## Abre la ficha de una casa.
func abrir(id: String) -> bool:
	if ficha(id).is_empty():
		push_error("Cuaderno: ficha inexistente '%s'" % id)
		return false
	if id in _abiertas:
		return false
	_abiertas.append(id)
	_puestas[id] = {}
	GameState.set_flag("ficha_" + id)
	ficha_abierta.emit(id)
	return true


func abierta(id: String) -> bool:
	return id in _abiertas


func abiertas() -> Array[String]:
	return _abiertas.duplicate()


func sellada(id: String) -> bool:
	return id in _selladas


func selladas() -> Array[String]:
	return _selladas.duplicate()


func puesta(ficha_id: String, hueco: String) -> String:
	return String(Dictionary(_puestas.get(ficha_id, {})).get(hueco, ""))


## Pone una palabra en un hueco ("" lo vacía); no si está sellada.
func poner(ficha_id: String, hueco: String, palabra_id: String) -> bool:
	if not abierta(ficha_id) or sellada(ficha_id) or fija(ficha_id, hueco):
		return false
	if not palabra_id.is_empty():
		if not sabe(palabra_id):
			return false
		if String(palabra(palabra_id).get("tipo", "")) != tipo_del_hueco(ficha_id, hueco):
			return false
	var p: Dictionary = _puestas.get(ficha_id, {})
	if palabra_id.is_empty():
		p.erase(hueco)
	else:
		p[hueco] = palabra_id
	_puestas[ficha_id] = p
	cambiado.emit()
	return true


func completa(ficha_id: String) -> bool:
	for h in huecos_en_orden(ficha_id):
		if puesta(ficha_id, h).is_empty():
			return false
	return true


## Huecos mal; solo con la ficha completa.
func errores(ficha_id: String) -> int:
	var n := 0
	var bien: Dictionary = Dictionary(ficha(ficha_id).get("huecos", {}))
	for h in bien:
		if puesta(ficha_id, String(h)) != String(bien[h]):
			n += 1
	return n


func correcta(ficha_id: String, hueco: String) -> bool:
	var bien := String(Dictionary(ficha(ficha_id).get("huecos", {})).get(hueco, ""))
	return not bien.is_empty() and puesta(ficha_id, hueco) == bien


## Hueco ya comprobado y bien: no se puede cambiar.
func fija(ficha_id: String, hueco: String) -> bool:
	return hueco in Array(_fijas.get(ficha_id, []))


## Ya no sirve: sus huecos están en tinta (o, si no es de ninguno, los de su tipo).
func gastada(id: String) -> bool:
	var tipo := String(palabra(id).get("tipo", ""))
	var pedida := false
	var abiertos := 0
	var pendientes := 0
	for f in _fichas_def:
		var fid := String(f.get("id", ""))
		var huecos: Dictionary = f.get("huecos", {})
		for h in huecos:
			var hecho := sellada(fid) or fija(fid, h)
			if String(huecos[h]) == id:
				pedida = true
				if not hecho:
					return false
			elif abierta(fid) and tipo_del_hueco(fid, h) == tipo:
				abiertos += 1
				if not hecho:
					pendientes += 1
	return pedida or (abiertos > 0 and pendientes == 0)


func _fijar(ficha_id: String, hueco: String) -> void:
	var l: Array = _fijas.get(ficha_id, [])
	if not hueco in l:
		l.append(hueco)
	_fijas[ficha_id] = l


## Comprueba una ficha; si está bien la sella y recoge su prueba.
func comprobar(ficha_id: String) -> int:
	if sellada(ficha_id):
		return SELLADA
	if not completa(ficha_id):
		return INCOMPLETA
	var mal := errores(ficha_id)
	# Lo acertado queda fijo (en tinta); lo malo sigue suelto.
	for h in huecos_en_orden(ficha_id):
		if correcta(ficha_id, h):
			_fijar(ficha_id, h)
	if mal == 1:
		return UNA_MAL
	if mal > 1:
		return VARIAS_MAL
	_selladas.append(ficha_id)
	GameState.set_flag("sellada_" + ficha_id)
	var prueba := String(ficha(ficha_id).get("prueba", ""))
	if not prueba.is_empty() and EvidenceDB.has(prueba):
		Casefile.collect(prueba)
	ficha_sellada.emit(ficha_id)
	return SELLADA


## Se pierde el papel de una ficha sellada: vuelve a estar vacía y sus palabras hay que oírlas otra vez.
func perder(ficha_id: String) -> void:
	if not sellada(ficha_id):
		return
	_selladas.erase(ficha_id)
	GameState.set_flag("sellada_" + ficha_id, false)
	_puestas[ficha_id] = {}
	_fijas.erase(ficha_id)
	for w in Dictionary(ficha(ficha_id).get("huecos", {})).values():
		_sabidas.erase(String(w))
		GameState.set_flag("palabra_" + String(w), false)
	cambiado.emit()


## True si ya se oyeron todas las palabras de la ficha.
func se_puede_completar(ficha_id: String) -> bool:
	for h in Dictionary(ficha(ficha_id).get("huecos", {})).values():
		if not sabe(String(h)):
			return false
	return true


## Frase de la ficha con "____" en los huecos vacíos.
func frase_con_lo_puesto(ficha_id: String) -> String:
	var frase := String(ficha(ficha_id).get("frase", ""))
	for h in huecos_en_orden(ficha_id):
		var p := puesta(ficha_id, h)
		frase = frase.replace("{%s}" % h, "____" if p.is_empty() else String(palabra(p).get("texto", "?")))
	return frase


# --- Hacia el registro y la guía ---

## Muertes de fichas selladas, con su punto ("To add" del escritorio).
func registros_sellados() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id in _selladas:
		for r in Array(ficha(id).get("registros", [])):
			out.append(Dictionary(r))
	return out


func selladas_de_tipo(tipo: String) -> Array[String]:
	var out: Array[String] = []
	for id in _selladas:
		if String(ficha(id).get("tipo", "")) == tipo:
			out.append(id)
	return out


# --- Estelas de agua ---

const FUENTES := "res://data/barrio/fuentes.json"
var _fuentes: Array[Dictionary] = []
## Estelas ya dibujadas (no se repite la animación).
var _estelas_vistas: Dictionary = {}


func estela_vista(id: String) -> bool:
	return _estelas_vistas.has(id)


func ver_estela(id: String) -> void:
	_estelas_vistas[id] = true


## Bombas y pozos: {id, palabra, p: Vector2 del plano, tipo}.
func fuentes() -> Array[Dictionary]:
	if _fuentes.is_empty():
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(FUENTES))
		for f in Array(Dictionary(d).get("fuentes", [])) if d is Dictionary else []:
			var p: Array = f.get("p", [0.5, 0.5])
			_fuentes.append({"id": String(f["id"]), "palabra": String(f.get("palabra", "")),
				"p": PLANO_DE.de_mundo(Vector2(float(p[0]), float(p[1]))), "tipo": String(f.get("tipo", "bomba"))})
	return _fuentes


func fuente(id: String) -> Dictionary:
	for f in fuentes():
		if f["id"] == id:
			return f
	return {}


## Estela de una ficha sellada: {id, desde: Vector2, hasta: Vector2, fuente, clase}, o {}.
func estela(ficha_id: String) -> Dictionary:
	var f := ficha(ficha_id)
	var e: Dictionary = f.get("estela", {})
	if e.is_empty() or not sellada(ficha_id):
		return {}
	var palabra_id := String(Dictionary(f.get("huecos", {})).get(String(e.get("hueco", "")), ""))
	var fu: Dictionary = {}
	for x in fuentes():
		if x["palabra"] == palabra_id:
			fu = x
	if fu.is_empty():
		return {}
	var desde := Vector2.INF
	var d: Variant = e.get("desde", null)
	if d is Array and Array(d).size() == 2:
		desde = PLANO_DE.de_mundo(Vector2(float(d[0]), float(d[1])))
	elif d is String:
		desde = PLANO_DE.punto_de(String(d))
	else:
		var regs: Array = f.get("registros", [])
		if not regs.is_empty():
			desde = PLANO_DE.punto_de_asiento(Dictionary(regs[0]))
	if desde == Vector2.INF:
		return {}
	return {"id": ficha_id, "desde": desde, "hasta": fu["p"], "fuente": fu["id"],
		"clase": String(e.get("clase", "muerte"))}


func estelas() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id in _selladas:
		var e := estela(id)
		if not e.is_empty():
			out.append(e)
	return out


# --- Círculo del plano ---

func circulo() -> Array:
	return _circulo.duplicate()


func poner_circulo(centro: Vector2, radio: Vector2) -> void:
	_circulo = [centro.x, centro.y, radio.x, radio.y]


# --- Guardado ---

func to_dict() -> Dictionary:
	return {
		"sabidas": _sabidas.duplicate(),
		"abiertas": _abiertas.duplicate(),
		"puestas": _puestas.duplicate(true),
		"selladas": _selladas.duplicate(),
		"fijas": _fijas.duplicate(true),
		"circulo": _circulo.duplicate(),
		"estelas_vistas": _estelas_vistas.keys(),
	}


func from_dict(d: Dictionary) -> void:
	reset()
	_sabidas = Dictionary(d.get("sabidas", {}))
	for id in Array(d.get("abiertas", [])):
		_abiertas.append(String(id))
	_puestas = Dictionary(d.get("puestas", {}))
	for id in Array(d.get("selladas", [])):
		_selladas.append(String(id))
	_circulo = Array(d.get("circulo", []))
	_fijas = Dictionary(d.get("fijas", {}))
	for id in Array(d.get("estelas_vistas", [])):
		_estelas_vistas[String(id)] = true
	cambiado.emit()


func reset() -> void:
	_sabidas.clear()
	_abiertas.clear()
	_puestas.clear()
	_selladas.clear()
	_circulo.clear()
	_fijas.clear()
	_estelas_vistas.clear()
	cambiado.emit()
