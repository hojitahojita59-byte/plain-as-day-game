extends Node
## ¿Cumple el guion sus reglas? Todos los caminos dan lo esencial, refs válidas,
## hablantes conocidos, muertes sobre su calle. Uso: --headless --quit-after 300

const DIR := "res://data/dialogue/"
const LIBRO := "res://data/registro/ch1_libro_parroquia.json"
const PLANO := preload("res://scripts/ui/plano_parroquia.gd")

## Banderas de tono: pueden depender del camino.
const DE_TONO := ["heard_the_miasma_theory",
	# Snow: una ficha que no sirve lleva por otro camino.
	"aire_explicado", "lejos_explicado"]

const CUADERNO := "res://data/cuaderno/ch1_cuaderno.json"

## Palabras y fichas que da cada diálogo.
var _palabras_dadas: Dictionary = {}
var _fichas_abiertas: Dictionary = {}

var _fallos := 0


func _ready() -> void:
	print("")
	print("=== EL GUION, CAMINO A CAMINO ===")
	var personajes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/characters.json"))
	var plano := PLANO.new()
	for archivo in DirAccess.get_files_at(DIR):
		if archivo.ends_with(".json"):
			_revisar(archivo, personajes, plano)
	_revisar_libro(plano)
	_revisar_cuaderno(plano)
	plano.free()
	print("")
	print("[guion] %s" % ("TODO CUMPLE." if _fallos == 0 else "! %d FALLOS." % _fallos))
	get_tree().quit()


func _revisar(archivo: String, personajes: Dictionary, plano: Control) -> void:
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIR + archivo))
	var nodos: Dictionary = d.get("nodos", {})
	var inicio := String(d.get("inicio", ""))

	# Referencias y hablantes.
	var alcanzados := {}
	for id in nodos:
		var n: Dictionary = nodos[id]
		var hablante := String(n.get("hablante", ""))
		if not personajes.has(hablante):
			_fallo("%s: «%s» habla y no está en characters.json" % [archivo, hablante])
		for sig in _siguientes(n):
			if not nodos.has(sig):
				_fallo("%s: el nodo %s apunta a «%s», que no existe" % [archivo, id, sig])
			alcanzados[sig] = true
	for id in nodos:
		if id != inicio and id != "otra_vez" and not alcanzados.has(id):
			_fallo("%s: el nodo «%s» no se alcanza desde ningún sitio" % [archivo, id])

	# Cada palabra debe salir en el texto de su línea (para resaltarla).
	var cuaderno: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CUADERNO))
	var palabras: Dictionary = cuaderno.get("palabras", {})
	var fichas_ids := {}
	for f in Array(cuaderno.get("fichas", [])):
		fichas_ids[String(f.get("id", ""))] = true
	for id in nodos:
		var n: Dictionary = nodos[id]
		for w in Array(n.get("palabras", [])):
			if not palabras.has(String(w)):
				_fallo("%s/%s: la palabra «%s» no está en el cuaderno" % [archivo, id, w])
				continue
			_palabras_dadas[String(w)] = archivo
			var def: Dictionary = palabras[String(w)]
			var formas: Array = Array(def.get("formas", [def.get("texto", "")]))
			var esta := false
			for f in formas:
				var re := RegEx.new()
				re.compile("\\b" + String(f) + "\\b")
				if re.search(String(n.get("texto", ""))) != null:
					esta = true
			if not esta:
				_fallo("%s/%s: «%s» no sale en el texto de la línea" % [archivo, id, w])
		var fi: Variant = n.get("ficha", null)
		for f in ([fi] if fi is String else Array(fi if fi != null else [])):
			if not fichas_ids.has(String(f)):
				_fallo("%s/%s: la ficha «%s» no existe" % [archivo, id, f])
			_fichas_abiertas[String(f)] = archivo

	# Banderas propias del archivo; las de fuera se prueban con y sin.
	var propias := {}
	for id in nodos:
		var n: Dictionary = nodos[id]
		for b in Array(n.get("marca", [])):
			propias[String(b)] = true
		for w in Array(n.get("palabras", [])):
			propias["palabra_" + String(w)] = true

	# Todos los caminos, con lo que se lleva cada uno.
	var caminos: Array = []
	_propias = propias
	_recorrer(nodos, inicio, {}, [], caminos)
	if caminos.is_empty():
		_fallo("%s: no hay ningún camino que termine" % archivo)
		return
	# Lo que una 1ª visita salta vale si se puede preguntar al volver (otra_vez).
	var de_nuevo := {}
	if nodos.has("otra_vez"):
		var otros: Array = []
		_recorrer(nodos, "otra_vez", {}, [], otros)
		for c in otros:
			de_nuevo.merge(Dictionary(c))
	var referencia: Dictionary = {}
	for c in caminos:
		referencia.merge(Dictionary(c))
	var mal := false
	for c in caminos:
		for k in referencia:
			if not c.has(k) and not de_nuevo.has(k) and not DE_TONO.has(String(k).trim_prefix("bandera:")):
				_fallo("%s: hay un camino que pierde «%s»" % [archivo, k])
				mal = true
		if mal:
			break


	print("  %-34s %2d caminos  %s" % [archivo.get_basename(), caminos.size(),
		"todos se llevan lo mismo" if not mal else "! NO"])


func _revisar_libro(plano: Control) -> void:
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(LIBRO))
	var n := 0
	for tanda in ["asientos", "segunda_tanda"]:
		for a in Array(d.get(tanda, [])):
			_sobre_su_calle("libro parroquial", a, plano)
			n += 1
	print("  %-34s %2d asientos sobre su calle" % ["libro parroquial", n])


## Cuaderno: cada ficha se abre y completa; cada muerte cae sobre su calle.
func _revisar_cuaderno(plano: Control) -> void:
	# El entierro (cementerio.gd) abre la ficha del 40 y da sus palabras.
	_fichas_abiertas["f_40"] = "cementerio.gd"
	for w in preload("res://scripts/world/cementerio.gd").PALABRAS:
		_palabras_dadas[String(w)] = "cementerio.gd"
	var cuaderno: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CUADERNO))
	var palabras: Dictionary = cuaderno.get("palabras", {})
	var n := 0
	for f in Array(cuaderno.get("fichas", [])):
		var id := String(f.get("id", ""))
		n += 1
		if not _fichas_abiertas.has(id):
			_fallo("cuaderno: ninguna conversación abre la ficha «%s»" % id)
		var huecos: Dictionary = f.get("huecos", {})
		var frase := String(f.get("frase", ""))
		for h in huecos:
			if not frase.contains("{%s}" % h):
				_fallo("cuaderno: la ficha «%s» tiene el hueco «%s» y su frase no" % [id, h])
			var w := String(huecos[h])
			if not palabras.has(w):
				_fallo("cuaderno: la ficha «%s» pide «%s», que no existe" % [id, w])
			elif not _palabras_dadas.has(w):
				_fallo("cuaderno: nadie dice «%s», y la ficha «%s» lo necesita" % [w, id])
		for r in Array(f.get("registros", [])):
			_sobre_su_calle("ficha " + id, Dictionary(r), plano)
	print("  %-34s %2d fichas, %d palabras" % ["cuaderno", n, palabras.size()])


## Una muerte se puede clavar si su punto cae sobre SU calle en el plano.
func _sobre_su_calle(donde: String, a: Dictionary, plano: Control) -> void:
	var punto: Vector2 = PLANO.punto_de_asiento(a)
	if punto == Vector2.INF:
		_fallo("%s: «%s» no tiene sitio en el plano" % [donde, a.get("nombre", a.get("id", "?"))])
		return
	var calle := String(a.get("calle", ""))
	for nombre in plano.calles_en(punto):
		if calle.ends_with(nombre):
			return
	_fallo("%s: «%s» (%s) no se puede clavar: su punto no cae sobre su calle" % [
		donde, a.get("nombre", "?"), calle])


func _recorrer(nodos: Dictionary, id: String, lleva: Dictionary, vistos: Array, out: Array) -> void:
	if id.is_empty() or not nodos.has(id):
		out.append(lleva)
		return
	# Un bucle no da camino nuevo: se corta.
	if vistos.count(id) >= 2:
		return
	var n: Dictionary = nodos[id]
	var ahora := lleva.duplicate()
	for a in _anotas(n):
		ahora["apunte:" + String(a.get("id", "?"))] = true
	for b in Array(n.get("marca", [])):
		ahora["bandera:" + String(b)] = true
	for p in Array(n.get("otorga", [])):
		ahora["prueba:" + String(p)] = true
	for w in Array(n.get("palabras", [])):
		ahora["palabra:" + String(w)] = true
	var fi: Variant = n.get("ficha", null)
	for f in ([fi] if fi is String else Array(fi if fi != null else [])):
		ahora["ficha:" + String(f)] = true
	var siguientes := _siguientes(n, ahora)
	if siguientes.is_empty():
		out.append(ahora)
		return
	for s in siguientes:
		_recorrer(nodos, s, ahora, vistos + [id], out)


var _propias: Dictionary = {}


## ¿Se ve la opción en este camino? Solo cuentan las banderas propias.
func _se_ve(o: Dictionary, lleva: Dictionary) -> bool:
	for c in Array(o.get("requiere", [])):
		var cond := String(c)
		var negada := cond.begins_with("!")
		var bandera := cond.trim_prefix("!")
		if not _propias.has(bandera):
			continue
		var tiene: bool = lleva.has("bandera:" + bandera) or (bandera.begins_with("palabra_") \
			and lleva.has("palabra:" + bandera.trim_prefix("palabra_")))
		if tiene == negada:
			return false
	return true


## Sin `lleva`, todas las opciones; con él, las visibles en ese camino.
func _siguientes(n: Dictionary, lleva = null) -> Array:
	var out: Array = []
	if n.has("pide"):
		var pide: Dictionary = n["pide"]
		for v in Dictionary(pide.get("fichas", {})).values():
			out.append(String(v))
		out.append(String(pide.get("otra", "")))
		return out
	for o in Array(n.get("opciones", [])):
		if lleva == null or _se_ve(Dictionary(o), Dictionary(lleva)):
			out.append(String(o.get("va_a", "")))
	if out.is_empty() and not String(n.get("siguiente", "")).is_empty():
		out.append(String(n["siguiente"]))
	return out


func _anotas(n: Dictionary) -> Array:
	var a: Variant = n.get("anota", null)
	if a is Dictionary:
		return [a]
	if a is Array:
		return a
	return []


func _fallo(t: String) -> void:
	_fallos += 1
	print("    ! " + t)
