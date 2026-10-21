extends Node
## Motor de diálogo: lee un JSON de nodos y emite señales (sin UI).

signal line_shown(node: Dictionary)
signal choices_offered(choices: Array)
signal dialogue_finished(dialogue_id: String)
## Un nodo pide enseñar una ficha (Snow); la UI responde con presentar().
signal ficha_pedida(pide: Dictionary)

const DIALOGUE_DIR := "res://data/dialogue/"

## True con una conversación abierta (el jugador no se mueve).
var active: bool = false

## Escena a la que viajar al terminar la conversación, si hay.
var _escena_al_salir: String = ""

var _current: Dictionary = {}
var _current_id: String = ""
var _node_id: String = ""

## Caché de cabeceras de diálogo.
var _cabeceras: Dictionary = {}


## Diálogo que toca: si no cumple su "requiere", el de "si_no".
func resolve(dialogue_id: String) -> String:
	if dialogue_id.is_empty():
		return ""
	var cab := _cabecera(dialogue_id)
	var requiere := Array(cab.get("requiere", []))
	if requiere.is_empty() or GameState.conditions_met(requiere):
		return dialogue_id
	return String(cab.get("si_no", ""))


func _cabecera(dialogue_id: String) -> Dictionary:
	if _cabeceras.has(dialogue_id):
		return _cabeceras[dialogue_id]
	var f = FileAccess.open(DIALOGUE_DIR + dialogue_id + ".json", FileAccess.READ)
	var out: Dictionary = {}
	if f != null:
		var parsed = JSON.parse_string(f.get_as_text())
		if typeof(parsed) == TYPE_DICTIONARY:
			out = {
				"requiere": parsed.get("requiere", []),
				"si_no": parsed.get("si_no", ""),
			}
	_cabeceras[dialogue_id] = out
	return out


func start(dialogue_id: String) -> void:
	var path := DIALOGUE_DIR + dialogue_id + ".json"
	var f = FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("DialogueRunner: no se pudo abrir " + path)
		return
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("DialogueRunner: " + path + " no contiene un objeto JSON")
		return
	_current = parsed
	_current_id = dialogue_id
	active = true
	# Segunda visita: si hay "otra_vez", no se repite todo.
	var inicio := String(_current.get("inicio", ""))
	if GameState.has_flag("hablado_" + dialogue_id):
		if _repaso():
			inicio = "_repaso"
		elif Dictionary(_current.get("nodos", {})).has("otra_vez"):
			inicio = "otra_vez"
	_goto(inicio)


## Otra visita: si una rama no dio algo que una ficha necesita, se vuelve a contar.
func _repaso() -> bool:
	var nodos: Dictionary = _current.get("nodos", {})
	var orden: Array[String] = []
	var cola: Array[String] = [String(_current.get("inicio", ""))]
	var antes: Dictionary = {}
	while not cola.is_empty():
		var id: String = cola.pop_front()
		if id.is_empty() or orden.has(id) or not nodos.has(id):
			continue
		orden.append(id)
		var n: Dictionary = nodos[id]
		var hijos: Array[String] = [String(n.get("siguiente", ""))]
		for c in Array(n.get("opciones", [])):
			if c is Dictionary:
				hijos.append(String(c.get("va_a", "")))
		for h in hijos:
			if not h.is_empty() and not antes.has(h):
				antes[h] = id
				cola.append(h)
	var faltan := _palabras_que_hacen_falta()
	# También lo que piden las fichas de esta puerta aún sin abrir.
	for id in orden:
		var f: Variant = Dictionary(nodos[id]).get("ficha", null)
		if f is String and not Cuaderno.abierta(String(f)):
			for w in Dictionary(Cuaderno.ficha(String(f)).get("huecos", {})).values():
				faltan[String(w)] = true
	var lista: Array[String] = []
	for id in orden:
		var n: Dictionary = nodos[id]
		if n.has("pide"):
			continue
		var util := false
		for p in Array(n.get("palabras", [])):
			if faltan.has(String(p)) and not Cuaderno.sabe(String(p)):
				util = true
		var f: Variant = n.get("ficha", null)
		if f is String and not Cuaderno.abiertas().has(String(f)):
			util = true
		if not util:
			continue
		# La pregunta de Whitehead que lo trajo, para que se entienda.
		var previo := String(antes.get(id, ""))
		if not previo.is_empty() and String(Dictionary(nodos[previo]).get("hablante", "")) == "whitehead" \
				and not lista.has(previo) and not Dictionary(nodos[previo]).has("opciones"):
			lista.append(previo)
		if not lista.has(id):
			lista.append(id)
	if lista.is_empty():
		return false
	nodos["_repaso"] = {"hablante": "whitehead", "retrato": "neutro",
		"texto": "Forgive me. There is something I did not ask you before.", "siguiente": "_repaso_0"}
	for i in lista.size():
		var copia := Dictionary(nodos[lista[i]]).duplicate()
		copia.erase("opciones")
		copia["siguiente"] = "_repaso_%d" % (i + 1) if i + 1 < lista.size() else ""
		nodos["_repaso_%d" % i] = copia
	return true


## Palabras que piden los huecos de las fichas abiertas sin sellar.
func _palabras_que_hacen_falta() -> Dictionary:
	var out := {}
	for id in Cuaderno.abiertas():
		if Cuaderno.sellada(id):
			continue
		for w in Dictionary(Cuaderno.ficha(id).get("huecos", {})).values():
			out[String(w)] = true
	return out


func _finish() -> void:
	active = false
	# Bandera "hablado_<id>" por conversación terminada.
	if not _current_id.is_empty():
		GameState.set_flag("hablado_" + _current_id)
	dialogue_finished.emit(_current_id)

	# El viaje va después de emitir dialogue_finished.
	if not _escena_al_salir.is_empty():
		var destino := _escena_al_salir
		_escena_al_salir = ""
		SceneRouter.change_scene(destino, SceneRouter.Kind.SHORT_FADE)


func _goto(node_id: String) -> void:
	if node_id.is_empty():
		_finish()
		return
	var nodes: Dictionary = _current.get("nodos", {})
	if not nodes.has(node_id):
		push_error("DialogueRunner: nodo desconocido '" + node_id + "' en " + _current_id)
		_finish()
		return

	_node_id = node_id
	var node: Dictionary = nodes[node_id]

	# Efectos declarados en el contenido.
	for id in Array(node.get("otorga", [])):
		Casefile.collect(String(id))
	for flag in Array(node.get("marca", [])):
		GameState.set_flag(String(flag))
	# "anota" puede ser un apunte o una lista (varias muertes en una frase).
	var anota: Variant = node.get("anota", null)
	if anota is Dictionary:
		Casefile.note(anota)
	elif anota is Array:
		for n in anota:
			Casefile.note(Dictionary(n))

	# Palabras que aprende el cuaderno y fichas que se abren.
	var quien_lo_dice := _nombre_de(String(node.get("hablante", "")))
	for p in Array(node.get("palabras", [])):
		Cuaderno.aprender(String(p), quien_lo_dice)
	var ficha: Variant = node.get("ficha", null)
	if ficha is String:
		Cuaderno.abrir(String(ficha))
	elif ficha is Array:
		for f in ficha:
			Cuaderno.abrir(String(f))

	# El cambio de escena espera al final de la conversación.
	if node.has("escena"):
		_escena_al_salir = String(node["escena"])
	if node.has("miasma"):
		GameState.set_miasma(float(node["miasma"]))

	# "estilo" (persona/cosa): del nodo o del archivo; manda el nodo.
	var linea := node.duplicate()
	linea["estilo"] = String(node.get("estilo", _current.get("estilo", "persona")))
	# `variantes`: lista de {requiere, texto}; gana la primera que se cumpla.
	for v in Array(node.get("variantes", [])):
		if v is Dictionary and GameState.conditions_met(Array(v.get("requiere", []))):
			linea["texto"] = String(v.get("texto", linea.get("texto", "")))
			break
	line_shown.emit(linea)

	var choices := _visible_choices(node)
	if not choices.is_empty():
		choices_offered.emit(choices)


func _visible_choices(node: Dictionary) -> Array:
	# Nodo con "pide": solo enseñar una ficha; no hay salida sin elegir.
	if node.has("pide"):
		var pide: Dictionary = node["pide"]
		return [{"texto": String(pide.get("boton", "Show a card from your notebook.")), "presentar": true}]
	var out: Array = []
	for c in Array(node.get("opciones", [])):
		if typeof(c) != TYPE_DICTIONARY:
			continue
		if GameState.conditions_met(Array(c.get("requiere", []))):
			out.append(c)
	return out


func advance() -> void:
	var nodes: Dictionary = _current.get("nodos", {})
	var node: Dictionary = nodes.get(_node_id, {})
	if not _visible_choices(node).is_empty():
		return  # hay que elegir, no se puede avanzar sin más
	_goto(String(node.get("siguiente", "")))


func choose(index: int) -> void:
	var nodes: Dictionary = _current.get("nodos", {})
	var choices := _visible_choices(nodes.get(_node_id, {}))
	if index < 0 or index >= choices.size():
		push_error("DialogueRunner: opción fuera de rango")
		return
	if bool(choices[index].get("presentar", false)):
		ficha_pedida.emit(Dictionary(nodes.get(_node_id, {}).get("pide", {})))
		return
	_goto(String(choices[index].get("va_a", "")))


## Enseña una ficha: va al nodo de esa ficha o a "otra"; marca la bandera.
func presentar(ficha_id: String) -> void:
	var nodes: Dictionary = _current.get("nodos", {})
	var pide: Dictionary = Dictionary(nodes.get(_node_id, {}).get("pide", {}))
	if pide.is_empty():
		return
	GameState.set_flag("presentada_" + ficha_id)
	var sirven: Dictionary = Dictionary(pide.get("fichas", {}))
	_goto(String(sirven.get(ficha_id, pide.get("otra", ""))))


## Vuelve a ofrecer las opciones (cuaderno cerrado sin elegir).
func reofrecer() -> void:
	var nodes: Dictionary = _current.get("nodos", {})
	var choices := _visible_choices(nodes.get(_node_id, {}))
	if not choices.is_empty():
		choices_offered.emit(choices)


func nodo_actual() -> Dictionary:
	return Dictionary(Dictionary(_current.get("nodos", {})).get(_node_id, {}))


## Caché de characters.json para el nombre de quien habla.
var _personajes: Dictionary = {}

func _nombre_de(hablante: String) -> String:
	if _personajes.is_empty():
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/characters.json"))
		if d is Dictionary:
			_personajes = d
	return String(Dictionary(_personajes.get(hablante, {})).get("nombre", hablante))
