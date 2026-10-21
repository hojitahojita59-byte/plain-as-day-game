extends Node
## Juega el Acto I haciendo solo lo que dice la guía (estrategias: primera, última,
## impaciente, a_medias). Copia y restaura la partida guardada. Uso: --headless

const GUIA := preload("res://scripts/guia.gd")
const CEMENTERIO := preload("res://scripts/world/cementerio.gd")
const SNOW := preload("res://scripts/world/llaman_a_la_puerta.gd")
const LIBRO := "res://data/registro/ch1_libro_parroquia.json"
const ASIENTOS := preload("res://scripts/asientos.gd")
const DIAS := preload("res://scripts/dias.gd")

const CALLE := "res://scenes/world/calle.tscn"
const RECTORIA := "res://scenes/world/rectoria.tscn"

## Más pasos: da vueltas.
const MAXIMO := 160

var _donde: Node


func _ready() -> void:
	# Esperar a que el árbol termine de montarse.
	await get_tree().process_frame
	var copia: Variant = null
	if FileAccess.file_exists(SaveSystem.SAVE_PATH):
		copia = FileAccess.get_file_as_bytes(SaveSystem.SAVE_PATH)

	var bien := true
	for estrategia in ["primera", "última", "impaciente", "a_medias"]:
		bien = await _jugar(estrategia) and bien

	print("")
	print("[guia] %s" % ("SE LLEGA A SNOW LEYENDO SOLO LA ESQUINA, DE LAS CUATRO MANERAS." if bien
		else "! HAY UN SITIO DONDE LA GUÍA DEJA AL JUGADOR A CIEGAS."))
	await get_tree().process_frame
	if copia == null:
		SaveSystem.delete_save()
	else:
		FileAccess.open(SaveSystem.SAVE_PATH, FileAccess.WRITE).store_buffer(copia)
	get_tree().quit(0 if bien else 1)


func _jugar(estrategia: String) -> bool:
	print("")
	print("=== EL ACTO I, RESPONDIENDO SIEMPRE LA %s ===" % estrategia.to_upper())
	GameState.reset()
	Casefile.reset()
	_ir_a(CALLE)

	var anterior := ""
	var repetidas := 0
	for paso in MAXIMO:
		await get_tree().process_frame
		var e := GUIA.etapa()
		var id := String(e["id"])
		var linea := String(e["linea"])
		var aqui := "casa " if GUIA.en_casa() else "calle"
		print("  %2d  %s  %-22s %s" % [paso + 1, aqui, id, linea])

		if id == "fin":
			print("  -> fin del acto en %d pasos" % (paso + 1))
			return true
		# Callan a propósito: la puerta ya la señala un vecino, el maletín, el punto verde o el entierro.
		if linea.is_empty() and not bool(e["a_casa"]) and Array(e["puertas"]).is_empty() 				and not id in ["cuaderno", "al_plano", "al_entierro"]:
			return _fallo("la esquina está vacía")
		if id == "al_entierro":
			if GUIA.en_casa():
				_ir_a(CALLE)
			CEMENTERIO.asentar()
			_ir_a(CALLE)
			continue

		repetidas = repetidas + 1 if id == anterior else 0
		anterior = id
		if repetidas > 12:
			return _fallo("trece pasos en la misma etapa: da vueltas")

		# --- Lo que haría quien solo lee la guía ---
		if id == "cuaderno":
			if not _rellenar_ficha():
				return _fallo("la línea manda al cuaderno y no hay ficha que rellenar")
			continue

		if id == "en_la_mesa":
			_clavar_todo(1 if estrategia == "a_medias" else 1000)
			if estrategia == "a_medias":
				_ir_a(CALLE)
			continue

		# "Press M": vista de pájaro desde la calle.
		if id in ["al_plano", "cercar"] and not GUIA.en_casa():
			if GUIA.aprendiendo() and not linea.contains("Press M"):
				return _fallo("etapa de mapa sin decir Press M")
			_desde_arriba(1 if estrategia == "a_medias" else 1000)
			continue

		if estrategia == "impaciente" and not GUIA.en_casa() \
				and GUIA.pendientes_de_la_calle() > 0:
			if not _a_casa(estrategia):
				return false
			continue

		if bool(e["a_casa"]):
			if not GUIA.en_casa():
				if not _a_casa(estrategia):
					return false
				continue
			return _fallo("en casa, con la línea mandando a casa y nada que hacer")

		# Hampstead: el carretero lleva; allí se habla con la hija.
		if id == "a_hampstead":
			_hablar("ch1_s3_carretero", "primera")
			if not GameState.has_flag("al_carro"):
				return _fallo("el carretero no lleva a Hampstead")
			GameState.set_flag("al_carro", false)
			_hablar("ch1_s4_hampstead", estrategia)
			continue

		var puertas: Array = e["puertas"]
		if puertas.is_empty():
			return _fallo("la línea no manda a ningún sitio")
		if GUIA.en_casa():
			_ir_a(CALLE)
			continue
		var cual := String(puertas[0])
		if not _puerta_abierta(cual):
			return _fallo("la línea manda a una puerta cerrada: " + cual)
		_hablar(cual, "primera" if id == "volver_a_llamar" else estrategia)

	return _fallo("más de %d pasos" % MAXIMO)


## Vuelta a casa como el juego: cementerio si toca, y Snow llama si toca.
func _a_casa(estrategia: String) -> bool:
	var linea_decia_snow := String(GUIA.etapa()["id"]) == "a_snow"
	_ir_a(RECTORIA)
	if SNOW.toca():
		_hablar("ch1_s6_snow", estrategia)
	elif linea_decia_snow:
		return _fallo("la línea dice que Snow va a llamar y no llama")
	elif DIAS.toca_dormir():
		DIAS.dormir()
		print("        noche: amanece el día %d" % GameState.dia)
		# Al salir de casa el domingo, el entierro.
		if GameState.dia >= 3 and not GameState.has_flag("buried_frances_lewis"):
			CEMENTERIO.asentar()
			_ir_a(CALLE)
	return true


func _fallo(por_que: String) -> bool:
	print("  ! FALLA: " + por_que)
	return false


## Nodo vacío con la ruta de la escena: es lo único que mira la guía.
func _ir_a(ruta: String) -> void:
	if _donde != null:
		_donde.queue_free()
	_donde = Node.new()
	_donde.scene_file_path = ruta
	get_tree().root.add_child(_donde)
	get_tree().current_scene = _donde


func _puerta_abierta(dialogo: String) -> bool:
	for p in Array(Barrio.datos("soho").get("puertas", [])):
		if String(p.get("dialogo", "")) == dialogo:
			return GameState.conditions_met(Array(p.get("requiere", []))) and not DialogueRunner.resolve(dialogo).is_empty()
	# El hombre del bordillo: siempre se puede hablar.
	return true


var _mala_ensenada := false


func _hablar(dialogo: String, estrategia: String) -> void:
	DialogueRunner.start(dialogo)
	var vueltas := 0
	# Un nodo que vuelve ("¿algo más?") toma la opción siguiente.
	var vistas := {}
	while DialogueRunner.active and vueltas < 80:
		vueltas += 1
		var nodos: Dictionary = DialogueRunner._current.get("nodos", {})
		var nodo: Dictionary = nodos.get(DialogueRunner._node_id, {})
		# Snow pide ficha: "primera" enseña una válida, "última" una que no sirve.
		if nodo.has("pide"):
			var sirve := ""
			for f in Dictionary(nodo["pide"].get("fichas", {})):
				if sirve.is_empty() and Cuaderno.sellada(String(f)):
					sirve = String(f)
			if estrategia != "última" and not sirve.is_empty():
				DialogueRunner.presentar(sirve)
			elif not _mala_ensenada:
				_mala_ensenada = true
				DialogueRunner.presentar("f_38")
			else:
				DialogueRunner.presentar(sirve)
			continue
		var opciones: Array = DialogueRunner._visible_choices(nodo)
		if opciones.is_empty():
			DialogueRunner.advance()
		else:
			var k := int(vistas.get(DialogueRunner._node_id, 0))
			vistas[DialogueRunner._node_id] = k + 1
			var n := opciones.size()
			DialogueRunner.choose(k % n if estrategia == "primera" else posmod(n - 1 - k, n))


## Clava todo con las reglas de escritorio.gd.
func _clavar_todo(cuantos: int) -> void:
	var datos: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(LIBRO))
	var tandas: Array = Array(datos.get("asientos", []))
	var todo: Array = tandas.duplicate()
	# Fichas selladas.
	for r in Cuaderno.registros_sellados():
		todo.append(r)
	# La lista del sacristán cuenta como una cosa.
	if GameState.has_flag("buried_frances_lewis"):
		var faltaba := false
		for a in Array(datos.get("segunda_tanda", [])):
			faltaba = faltaba or not Casefile.is_recorded(String(a.get("id", "")))
		if faltaba and cuantos > 0:
			for a in Array(datos.get("segunda_tanda", [])):
				Casefile.record(Dictionary(a))
			cuantos -= 1
	# Primero lo de la calle; el libro, después.
	todo.reverse()
	for a in todo:
		if cuantos <= 0:
			break
		if Casefile.record(Dictionary(a)):
			cuantos -= 1

	var libro_entero := true
	for a in Array(datos.get("asientos", [])):
		libro_entero = libro_entero and Casefile.is_recorded(String(a.get("id", "")))
	if libro_entero:
		GameState.set_flag("parish_book_read")
	if GameState.has_flag("buried_frances_lewis") \
			and Casefile.record_count() >= GUIA.SUFICIENTES \
			and GUIA.pendientes_del_libro() + GUIA.pendientes_de_la_calle() == 0:
		# El círculo que trazaría el jugador.
		Casefile.collect("broad_street_racimo")
		GameState.set_flag("saw_the_cluster")


## Lo que hace vista_pajaro.gd: asienta lo pendiente o traza el cerco.
func _desde_arriba(cuantos: int) -> void:
	if ASIENTOS.toca_cercar():
		Casefile.collect(ASIENTOS.PRUEBA_RACIMO)
		GameState.set_flag("saw_the_cluster")
		return
	# Tras las tres primeras a mano, el resto cae solo (vista_pajaro.A_MANO).
	if Casefile.record_count() >= 3:
		cuantos = 1000
	for a in ASIENTOS.por_asentar():
		if cuantos <= 0:
			break
		Casefile.record(a)
		cuantos -= 1
	ASIENTOS.marcar_libro_leido()


## Rellena la primera ficha que nombra la guía; false si no hay ninguna.
func _rellenar_ficha() -> bool:
	var id := GUIA.ficha_mal()
	if id.is_empty():
		id = GUIA.ficha_lista()
	if id.is_empty():
		return false
	var huecos: Dictionary = Dictionary(Cuaderno.ficha(id).get("huecos", {}))
	for h in huecos:
		Cuaderno.poner(id, String(h), String(huecos[h]))
	return Cuaderno.comprobar(id) == Cuaderno.SELLADA
