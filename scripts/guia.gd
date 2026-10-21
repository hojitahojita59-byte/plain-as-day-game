extends RefCounted
## Guía: qué hace Whitehead ahora y qué le falta (nunca qué significa).
## Sale del estado de la partida; las etapas se miran de la última a la 1ª.

const ASIENTOS := preload("res://scripts/asientos.gd")
const DIAS := preload("res://scripts/dias.gd")

## Igual que SUFICIENTES en escritorio.gd.
const SUFICIENTES := 20

## Casas raras necesarias para que llame Snow.
const RARAS_PARA_SNOW := 2

## Fichas de casas que el aire no explica; cuentan al estar selladas.
const RARAS := ["f_asilo", "f_hampstead", "f_casera"]

## Puertas de Cambridge St, por orden de número.
const CAMBRIDGE := ["ch1_s3_cambridge_lavandera", "ch1_s3_cambridge_nadie",
	"ch1_s3_cambridge_cervecero"]


static func etapa() -> Dictionary:
	var dentro := en_casa()
	var fuera := "Go out. " if dentro else ""
	var pend := ASIENTOS.por_asentar().size()

	if GameState.has_flag("met_snow"):
		return _e("fin", "")

	# Domingo antes del entierro: nada en la esquina; al salir, el cementerio.
	if GameState.dia >= 3 and not GameState.has_flag("buried_frances_lewis"):
		return _e("al_entierro", "")

	# Primero el cuaderno: una ficha completable o llena y mal.
	var mal := ficha_mal()
	if not mal.is_empty():
		return _e("cuaderno", ("A card in your notebook is not right yet: %s. Press TAB and look again." % String(Cuaderno.ficha(mal).get("titulo", ""))) if aprendiendo() else "")
	var lista := ficha_lista()
	if not lista.is_empty():
		# Tras el primer día lo dicen los papeles del maletín.
		return _e("cuaderno", ("You have heard enough to fill in the card for %s. Press TAB." % String(Cuaderno.ficha(lista).get("titulo", ""))) if aprendiendo() else "")

	# Una palabra que no se preguntó en una puerta ya visitada: volver a llamar.
	var falta := falta_preguntar()
	if not falta.is_empty():
		return _e("volver_a_llamar", "I did not ask everything at number %s. I should knock there again." % _numeros([falta["dialogo"]], true),
			false, [falta["dialogo"]])

	# Luego el mapa.
	if pend > 0:
		# Tras el primer día basta el punto verde del botón del mapa.
		return _e("al_plano", ("Press M and put %s on the map." % _muertes(pend)) if aprendiendo() else "")
	if ASIENTOS.toca_cercar():
		return _e("cercar", fuera + "Press M and draw a circle round the place where the deaths crowd together.")

	# El carro del sacristán, con la lista del día.
	var carro := ASIENTOS.lista_pendiente()
	if carro > 0:
		return _e("carro", "The sexton's cart is in Broad Street. I should ask him for the names.",
			false, ["ch1_s3_sacristan_%d" % carro])

	# Día cerrado: a casa.
	if DIAS.toca_dormir():
		# Sin texto: basta el camino de puntos a casa.
		return _e("a_dormir", "", true)

	if GameState.dia <= 1:
		if not GameState.has_flag("hablado_ch1_s3_garment_woman"):
			return _e("a_38", "There is a black ribbon on number 38. I should knock and ask who has died.",
				false, ["ch1_s3_garment_woman"])
		if not GameState.has_flag("hablado_ch1_s3_coal_woman"):
			return _e("a_41", "",
				false, ["ch1_s3_coal_woman"])
		if not GameState.has_flag("hablado_ch1_s3_tailor"):
			return _e("a_39", "",
				false, ["ch1_s3_tailor"])
		return _e("a_lewis", "There is a woman sitting on the step of number 40. I should speak to her.",
			false, ["ch1_s1_lewis"])

	if GameState.dia == 2:
		if not GameState.has_flag("hablado_ch1_s3_puerta_40"):
			return _e("a_40", "I wonder how Mrs Lewis's baby is. I will go to number 40 and ask.",
				false, ["ch1_s3_puerta_40"])
		return _e("cambridge", "I should visit Cambridge Street: %s." % _numeros(CAMBRIDGE),
			false, _abiertas(CAMBRIDGE))

	# Hampstead: el carro de la fábrica de los Eley sube cada día.
	if GameState.has_flag("sabe_de_hampstead") and not GameState.has_flag("heard_about_hampstead"):
		return _e("a_hampstead", "Find Eley's carter in Broad Street.",
			false, ["ch1_s3_carretero"])

	var calles_nuevas := _abiertas(["ch1_s3_new_hampstead", "ch1_s3_peter_asilo", "ch1_s3_peter_casera",
		"ch1_s3_new_tendero", "ch1_s3_peter_viuda", "ch1_s3_new_cerrada"])
	if not GameState.has_flag("saw_the_cluster"):
		return _e("faltan",
			"I need more names. I will ask in New Street and Peter Street. (%d of %d deaths on the map)" % [
				Casefile.record_count(), SUFICIENTES], false, calles_nuevas)
	var raras := raras_oidas()
	if raras >= RARAS_PARA_SNOW:
		return _e("a_snow", "" if dentro
			else "Go home and look at the map again.", true)
	return _e("lo_que_no_encaja",
		"Is there a house the bad air does not explain? I will ask in New Street and Peter Street. (%d of %d)" % [raras, RARAS_PARA_SNOW], false, calles_nuevas)


## El primer día (38, 41 y 39) la guía enseña el cuaderno y el mapa; luego, no.
static func aprendiendo() -> bool:
	return GameState.dia <= 1


static func _e(id: String, linea: String, a_casa: bool = false, puertas: Array = []) -> Dictionary:
	return {"id": id, "linea": linea, "a_casa": a_casa, "puertas": puertas}


## "1 death", "7 deaths".
static func _muertes(n: int) -> String:
	return "1 death" if n == 1 else "%d deaths" % n


## Si Whitehead está en la rectoría (cambia el texto de las líneas).
static func en_casa() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.current_scene == null:
		return false
	return tree.current_scene.scene_file_path.contains("rectoria")


## Muertes de fichas selladas aún sin poner en el plano.
static func pendientes_de_la_calle() -> int:
	var n := 0
	for r in Cuaderno.registros_sellados():
		if not Casefile.is_recorded(String(r.get("id", ""))):
			n += 1
	return n


## La primera ficha llena y mal, o "".
static func ficha_mal() -> String:
	for id in Cuaderno.abiertas():
		if not Cuaderno.sellada(id) and Cuaderno.completa(id) and Cuaderno.errores(id) > 0:
			return id
	return ""


## La primera ficha sin sellar de la que ya se ha oído todo, o "".
static func ficha_lista() -> String:
	for id in Cuaderno.abiertas():
		if not Cuaderno.sellada(id) and not Cuaderno.completa(id) and Cuaderno.se_puede_completar(id):
			return id
	return ""


## Nombres del libro sin poner en el plano (2ª tanda tras el entierro).
static func pendientes_del_libro() -> int:
	return ASIENTOS.primera_tanda().size() + ASIENTOS.segunda_tanda().size()


static func raras_oidas() -> int:
	var n := 0
	for f in RARAS:
		if Cuaderno.sellada(String(f)):
			n += 1
	return n


## De una lista de diálogos de puerta, los que todavía no se han llamado.
static func _abiertas(dialogos: Array) -> Array:
	var out: Array = []
	for d in dialogos:
		if not GameState.has_flag("hablado_" + String(d)):
			out.append(d)
	return out


## "12, 14, 16": números de las puertas que quedan, sacados del barrio.
static func _numeros(dialogos: Array, aunque_hablado: bool = false) -> String:
	var por_dialogo := {}
	for p in Array(Barrio.datos(Barrio.actual).get("puertas", [])):
		por_dialogo[String(p.get("dialogo", ""))] = String(p.get("numero", "?"))
	var out: PackedStringArray = []
	for d in (dialogos if aunque_hablado else _abiertas(dialogos)):
		out.append(String(por_dialogo.get(d, "?")))
	return ", ".join(out) if not out.is_empty() else "every door called at"




static var _dialogo_de: Dictionary = {}


## Puerta (diálogo) que dice cada palabra; de los diálogos de las puertas.
static func dialogo_de_palabra(w: String) -> String:
	if _dialogo_de.is_empty():
		for p in Array(Barrio.datos(Barrio.actual).get("puertas", [])):
			var id := String(p.get("dialogo", ""))
			var d: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue/%s.json" % id))
			if not (d is Dictionary):
				continue
			for n in Dictionary(d.get("nodos", {})).values():
				for x in Array(Dictionary(n).get("palabras", [])):
					if not _dialogo_de.has(String(x)):
						_dialogo_de[String(x)] = id
	return String(_dialogo_de.get(w, ""))


## Ficha sin sellar a la que le falta una palabra de una puerta ya llamada, o {}.
static func falta_preguntar() -> Dictionary:
	for id in Cuaderno.abiertas():
		if Cuaderno.sellada(id) or Cuaderno.se_puede_completar(id):
			continue
		for w in Dictionary(Cuaderno.ficha(id).get("huecos", {})).values():
			if Cuaderno.sabe(String(w)):
				continue
			var d := dialogo_de_palabra(String(w))
			if not d.is_empty() and GameState.has_flag("hablado_" + d):
				return {"ficha": id, "dialogo": d}
	return {}
