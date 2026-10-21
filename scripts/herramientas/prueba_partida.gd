extends Node
## Juega el Acto I en las escenas reales con clics reales, siguiendo la guía.
## Uso: prueba_partida.tscn -- carpeta_fotos [etapa]. Con ventana, no --headless.

const CALLE := "res://scenes/world/calle.tscn"
const RECTORIA := "res://scenes/world/rectoria.tscn"
const CEMENTERIO := "res://scenes/world/cementerio.tscn"
const GUIA := preload("res://scripts/guia.gd")
const LLEGADA := preload("res://scripts/world/llegada_a_casa.gd")
const SNOW := preload("res://scripts/world/llaman_a_la_puerta.gd")
const ASIENTOS := preload("res://scripts/asientos.gd")
const DIAS := preload("res://scripts/dias.gd")
const MAQUETA := preload("res://scripts/world/maqueta.gd")
const PLANO := preload("res://scripts/ui/plano_parroquia.gd")

## Más pasos de la guía: da vueltas.
const MAXIMO := 110
## Distancia por clic cuando el objetivo está lejos.
const TRAMO := 9.0

var _fotos: String = ""
var _n_foto: int = 0
var _fallos: PackedStringArray = []
var _paso: int = 0
## 2º arg: etapa desde la que empezar (lo anterior se pone sin escenas).
var _desde: String = ""


func _ready() -> void:
	await get_tree().process_frame
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		_fotos = String(a[0]).replace("\\", "/")
		DirAccess.make_dir_recursive_absolute(_fotos)
	if a.size() > 1:
		_desde = String(a[1])

	var copia: Variant = null
	if FileAccess.file_exists(SaveSystem.SAVE_PATH):
		copia = FileAccess.get_file_as_bytes(SaveSystem.SAVE_PATH)
	# Apaga el autoguardado; copia y restaura la partida guardada.
	SaveSystem.set("_pendiente", true)

	GameState.reset()
	Casefile.reset()
	Barrio.reset()
	Cronometro.reset()
	LLEGADA.ya_llegamos = false
	HUD.show()

	print("")
	print("=== LA PARTIDA, JUGADA ===")
	var bien := await _jugar()

	print("")
	if _fallos.is_empty() and bien:
		print("[partida] EL ACTO I SE JUEGA ENTERO, DE LA CALLE A SNOW, CON CLICS.")
	else:
		print("[partida] ! %d SITIOS DONDE LA PARTIDA SE ATASCA:" % _fallos.size())
		for f in _fallos:
			print("    - " + f)

	await get_tree().process_frame
	var cron := Cronometro.CARPETA + "partida_%s.json" % Cronometro.inicio
	if FileAccess.file_exists(cron):
		DirAccess.remove_absolute(cron)
	if copia == null:
		SaveSystem.delete_save()
	else:
		FileAccess.open(SaveSystem.SAVE_PATH, FileAccess.WRITE).store_buffer(copia)
	get_tree().quit(0 if _fallos.is_empty() and bien else 1)


# --- Bucle: leer la esquina y hacer lo que dice ---

func _jugar() -> bool:
	if not _desde.is_empty():
		_avanzar_sin_jugar(_desde)
	if _desde.is_empty() and OS.get_environment("SIN_APERTURA") == "":
		GameState.set_flag("probar_apertura")
	var escena := (load(CALLE) as PackedScene).instantiate()
	get_tree().root.add_child(escena)
	get_tree().current_scene = escena
	if not await _hasta(func(): return _jugador() != null and _jugador().get("_agent") != null, 5.0):
		return _fallo("la calle no arranca")
	_jugador().set("debug", true)
	if GameState.has_flag("probar_apertura"):
		await _segundos(4.0)
		await _foto("apertura")
		if not await _hasta(func(): return GameState.has_flag("apertura_vista"), 15.0):
			return _fallo("la apertura no termina")
	await _segundos(2.0)
	await _foto("calle_inicio")

	var anterior := ""
	var repetidas := 0
	for i in MAXIMO:
		_paso = i + 1
		await get_tree().process_frame
		var e := GUIA.etapa()
		var id := String(e["id"])
		var linea := String(e["linea"])
		var aqui := "casa " if GUIA.en_casa() else "calle"
		print("  %2d  %s  %-22s %s" % [_paso, aqui, id, linea])

		if id == "fin":
			print("  -> fin del acto en %d pasos" % _paso)
			await _segundos(1.0)
			await _foto("fin")
			return true
		# Callan a propósito: la puerta la señala un vecino, el maletín, el punto verde o el entierro.
		if linea.is_empty() and not bool(e["a_casa"]) and Array(e["puertas"]).is_empty() 				and not id in ["cuaderno", "al_plano", "al_entierro"]:
			return _fallo("la esquina está vacía")
		repetidas = repetidas + 1 if id == anterior else 0
		anterior = id
		if repetidas > 14:
			return _fallo("quince pasos en la misma etapa: da vueltas")

		if id == "cuaderno":
			if not await _cuaderno():
				return false
			continue

		if GUIA.en_casa():
			if id == "a_snow":
				if not await _snow():
					return false
			elif id == "en_la_mesa":
				if not await _en_la_mesa():
					return false
			else:
				if not await _salir_a_la_calle():
					return false
			continue

		if id in ["al_plano", "cercar"]:
			if not await _desde_arriba():
				return false
			continue

		if id == "carro":
			if not await _al_carro():
				return false
			continue

		if bool(e["a_casa"]):
			if not await _ir_a_casa():
				return false
			continue

		var puertas: Array = e["puertas"]
		if puertas.is_empty():
			return _fallo("la línea no manda a ningún sitio")
		if id == "a_hampstead":
			if not await _hablar_con("Carretero", "carretero"):
				return false
			if not await _viaje():
				return false
			continue
		if String(puertas[0]) == "ch1_s1_lewis":
			if not await _hablar_con("BroadSarahLewis", "sarah_lewis"):
				return false
			continue
		if not await _llamar(String(puertas[0])):
			return false
	return _fallo("más de %d pasos" % MAXIMO)


# --- La calle ---

func _jugador() -> Node3D:
	return get_tree().get_first_node_in_group(&"jugador") as Node3D


func _escena() -> String:
	var s := get_tree().current_scene
	return "" if s == null else s.scene_file_path


## Llamar a la puerta que lleva este diálogo (o hablar con el hombre del bordillo).
func _llamar(dialogo: String) -> bool:
	if dialogo == "ch1_s3_murmurer":
		return await _hablar_con("BroadMurmurador", "bordillo")

	var puerta: Node3D = null
	for p in get_tree().get_nodes_in_group(&"puertas"):
		if String(p.get("dialogue_id")) == dialogo:
			puerta = p as Node3D
	if puerta == null:
		return _fallo("no hay puerta con el diálogo " + dialogo)
	var numero := String(puerta.get("display_name"))

	if not await _andar_hasta(puerta):
		return _fallo("no se llega a la puerta " + numero)
	if not await _hasta(func(): return DoorMode.activo and not bool(DoorMode.get("_moviendo")), 10.0):
		await _foto("sin_vista_de_puerta")
		return _fallo("la cámara no baja a la puerta " + numero)
	await _segundos(0.4)
	await _foto("puerta_" + dialogo.trim_prefix("ch1_s3_"))

	# Llamar: un clic en la vista de puerta.
	await _clic(get_viewport().get_visible_rect().size * 0.5)
	if not await _hasta(func(): return DialogueRunner.active, 8.0):
		await _foto("no_abren_" + dialogo.trim_prefix("ch1_s3_"))
		return _fallo("llamo a la puerta %s y no abre nadie" % numero)
	await _segundos(0.4)
	await _foto("habla_" + dialogo.trim_prefix("ch1_s3_"))
	await _conversar()

	# Vuelta a la vista de arriba, por el botón.
	await _segundos(0.5)
	if DoorMode.activo:
		var barra := get_tree().current_scene.find_child("BarraPuertas", true, false)
		var salir := barra.get("_salir") as Button if barra != null else null
		if salir != null and salir.is_visible_in_tree():
			salir.pressed.emit()
		else:
			DoorMode.salir()
		if not await _hasta(func(): return not DoorMode.activo, 5.0):
			return _fallo("no se vuelve a la vista de arriba desde " + numero)
	# Esperar a que la cámara vuelva arriba.
	await _hasta(func(): return not bool(DoorMode.get("volviendo")), 3.0)
	await _segundos(0.4)
	return true


## Hablar con alguien de la calle, clicándole.
func _hablar_con(nombre: String, foto: String) -> bool:
	var quien := get_tree().current_scene.find_child(nombre, true, false) as Node3D
	if quien == null:
		return _fallo("no está " + nombre)
	if not await _andar_hasta(quien):
		return _fallo("no se llega hasta " + nombre)
	if not await _hasta(func(): return DialogueRunner.active, 6.0):
		await _foto("no_habla_" + foto)
		return _fallo(nombre + " no dice nada")
	await _segundos(0.4)
	await _foto("habla_" + foto)
	await _conversar()
	await _segundos(0.3)
	return true


## Andar a clics hasta algo; true cuando se para delante.
func _andar_hasta(objetivo: Node3D) -> bool:
	var jugador := _jugador()
	if jugador == null:
		return false
	for tramo in 20:
		var d := objetivo.global_position - jugador.global_position
		d.y = 0.0
		# Entre calles distintas, primero a la boca de la calle (por Broad).
		var d_paso := _paso_intermedio(jugador.global_position, objetivo.global_position) - jugador.global_position
		d_paso.y = 0.0
		var cam := get_viewport().get_camera_3d()
		# Las puertas de lado se llaman por su burbuja.
		if OS.get_environment("PARTIDA_TRAZA") != "":
			print("      tramo %d: jugador %s cámara %s" % [tramo, str(jugador.global_position.round()), str(cam.global_position.round())])
			await _foto("tramo")
		if objetivo.has_meta(&"lateral"):
			var capa := get_tree().current_scene.find_child("BurbujasDePuerta", true, false)
			var b: Control = Dictionary(capa.get("_burbujas")).get(objetivo) if capa != null else null
			if b != null and b.visible and b.modulate.a > 0.9:
				await _foto("burbuja_" + String(objetivo.get_meta(&"numero", "")))
				await _clic(b.get_global_rect().get_center())
				var controlador := jugador
				if not await _hasta(func(): return not bool(controlador.get("_has_target")), 20.0):
					return _fallo("se queda andando hacia la burbuja de " + objetivo.name)
				print("      por la burbuja: %s" % objetivo.get_meta(&"numero", ""))
				return true
			elif d.length() < 6.0:
				await _segundos(0.4)
				continue
		# Se clica el cuerpo, no los pies (el rayo a los pies daba en la bomba).
		var blanco := objetivo.global_position
		if blanco.y < 0.5:
			blanco.y += 1.15
		if d.length() < 12.0 and _en_pantalla(cam, blanco) and not objetivo.has_meta(&"lateral"):
			var punto := cam.unproject_position(blanco)
			await _clic(punto)
			var controlador := jugador
			if not await _hasta(func(): return not bool(controlador.get("_has_target")), 20.0):
				return _fallo("se queda andando hacia " + objetivo.name)
			return true
		var cuanto := minf(TRAMO, maxf(d_paso.length(), 4.0) - 1.0)
		var paso := _por_la_calzada(jugador.global_position + d_paso.normalized() * cuanto)
		while not _en_pantalla(cam, paso) and cuanto > 2.0:
			cuanto -= 2.0
			paso = _por_la_calzada(jugador.global_position + d_paso.normalized() * cuanto)
		var antes := jugador.global_position
		print("      tramo: jugador %s  cámara %s (%s)  paso %s" % [str(antes.round()), str(cam.global_position.round()), cam.name, str(paso.round())])
		if _en_pantalla(cam, paso) and paso.distance_to(antes) > 2.5:
			await _clic(cam.unproject_position(paso))
		else:
			# Destino detrás de la cámara: clicar abajo del todo.
			var r := get_viewport().get_visible_rect()
			var hacia := jugador.global_position + d_paso.normalized() * 6.0
			var donde := cam.unproject_position(hacia)
			await _clic(Vector2(clampf(donde.x, 60.0, r.size.x - 60.0), r.size.y - 30.0))
		if not await _hasta(func(): return not bool(jugador.get("_has_target")), 12.0):
			return _fallo("se queda andando por la calle")
		await _segundos(0.3)
		# Si el clic cae en puerta o persona, se deshace y se sigue.
		if DoorMode.activo:
			print("      (el clic de andar abrió una puerta; se vuelve atrás)")
			await _hasta(func(): return not bool(DoorMode.get("_moviendo")), 3.0)
			DoorMode.salir()
			await _hasta(func(): return not DoorMode.activo and not bool(DoorMode.get("volviendo")), 4.0)
			await _segundos(0.4)
			continue
		if DialogueRunner.active:
			print("      (el clic de andar abrió una conversación)")
			await _conversar()
			continue
		if jugador.global_position.distance_to(antes) < 0.5:
			await _foto("atascado")
			return _fallo("no avanza hacia %s (en %.1f, %.1f)" % [objetivo.name,
				jugador.global_position.x, jugador.global_position.z])
	return _fallo("demasiados tramos hasta " + objetivo.name)


## Tramos por la calzada (Broad z = 0; laterales x = -35, -15, 35), no por la acera.
func _por_la_calzada(p: Vector3) -> Vector3:
	# A ras de suelo, para que el rayo no llegue a la puerta.
	var y := 0.0
	# En Broad, al borde de la calzada (z = -4), que se ve desde las laterales.
	if p.z > -9.0:
		return Vector3(p.x, y, clampf(p.z, -4.0, 1.5))
	return Vector3(_eje(p), y, p.z)


const EJES_LATERALES := [-35.0, -15.0, 35.0]


func _eje(p: Vector3) -> float:
	var mejor: float = EJES_LATERALES[0]
	for x in EJES_LATERALES:
		if absf(p.x - x) < absf(p.x - mejor):
			mejor = x
	return mejor


## Si origen y destino están en calles distintas, la boca de la que toca.
func _paso_intermedio(desde: Vector3, hasta: Vector3) -> Vector3:
	var en_lateral := desde.z < -9.0
	var va_a_lateral := hasta.z < -9.0
	if en_lateral and (not va_a_lateral or absf(_eje(desde) - _eje(hasta)) > 1.0):
		return Vector3(_eje(desde), 0.0, -2.0)
	if va_a_lateral and (not en_lateral) and absf(desde.x - _eje(hasta)) > 3.0:
		return Vector3(_eje(hasta), 0.0, -2.0)
	return hasta


func _en_pantalla(cam: Camera3D, p: Vector3) -> bool:
	if cam == null or cam.is_position_behind(p):
		return false
	var s := cam.unproject_position(p)
	var r := get_viewport().get_visible_rect()
	return r.grow(-40.0).has_point(s)


## Volver a casa: puerta, burbujas y lo que venga hasta sentarse.
func _ir_a_casa() -> bool:
	var esquina: Node3D = null
	for n in get_tree().get_nodes_in_group(&"puertas") + get_tree().current_scene.find_children("Esquina*", "", true, false):
		if n.has_meta(&"decision"):
			esquina = n as Node3D
	if esquina == null:
		return _fallo("no hay puerta de casa en la calle")
	if not await _andar_hasta(esquina):
		return _fallo("no se llega a la puerta de casa")
	var opciones := HUD.get("_opciones") as Control
	if not await _hasta(func(): return bool(opciones.get("_abierto")), 6.0):
		await _foto("sin_burbujas")
		return _fallo("en la puerta de casa no salen las burbujas")
	await _segundos(0.5)
	await _foto("burbujas_casa")
	var burbujas: Array = opciones.get("_burbujas")
	(burbujas[0] as Button).pressed.emit()
	# La última vuelta pasa antes por la imagen del mapa entero.
	if SNOW.toca():
		await _segundos(6.5)
		await _foto("el_mapa_entero")
	if not await _hasta(func(): return _escena() != CALLE and not _escena().is_empty(), 18.0):
		return _fallo("'Go home' no cambia de escena")

	if not await _hasta(func(): return _escena() == RECTORIA, 8.0):
		return _fallo("se vuelve a casa y se acaba en " + _escena())
	return await _esperar_sentado()


func _esperar_sentado() -> bool:
	var sentado := get_tree().current_scene.find_child("Sentado", true, false)
	if sentado == null:
		return _fallo("la rectoría no tiene mesa")
	await _segundos(2.0)
	await _foto("rectoria_llegada")
	if not await _hasta(func(): return bool(sentado.get("_listo")) or SNOW.toca(), 16.0):
		await _foto("no_se_sienta")
		return _fallo("Whitehead no llega a sentarse")
	await _segundos(0.6)
	await _foto("rectoria_sentado")
	# Si el día está cerrado, pasa la noche.
	var noche := get_tree().get_first_node_in_group(&"noche")
	if DIAS.toca_dormir() and not SNOW.toca() and noche != null:
		var dia := GameState.dia
		if not await _hasta(func(): return bool(noche.call(&"activa")), 6.0):
			return _fallo("el día está cerrado y no se hace de noche")
		await _segundos(4.0)
		await _foto("noche_%d" % (dia + 1))
		if not await _hasta(func(): return GameState.dia == dia + 1 and not bool(noche.call(&"activa")), 30.0):
			return _fallo("la noche no termina")
		print("      noche: amanece el día %d" % GameState.dia)
		await _segundos(0.8)
	return true


## A Hampstead en el carro y vuelta: camino, la hija, la calle.
func _viaje() -> bool:
	if not await _hasta(func(): return _escena().ends_with("camino.tscn"), 20.0):
		return _fallo("el carretero no se va con Whitehead")
	await _segundos(20.0)
	await _foto("camino")
	if not await _hasta(func(): return _escena().ends_with("hampstead.tscn"), 40.0):
		return _fallo("el camino no llega a Hampstead")
	if not await _hasta(func(): return DialogueRunner.active, 15.0):
		return _fallo("en Hampstead nadie habla")
	await _foto("hampstead")
	await _conversar()
	if not await _hasta(func(): return _escena() == CALLE and _jugador() != null, 20.0):
		return _fallo("de Hampstead no se vuelve a la calle")
	if not GameState.has_flag("heard_about_hampstead"):
		return _fallo("en Hampstead no se oye lo del agua")
	await _segundos(2.0)
	return true


## El entierro: solo se mira; acaba en la calle con la ficha del 40.
func _entierro() -> bool:
	await _segundos(12.0)
	await _foto("cementerio")
	await _segundos(10.0)
	await _foto("entierro_ataud")
	if not await _hasta(func(): return _escena() == CALLE, 30.0):
		return _fallo("del cementerio no se sale a la calle")
	if not Cuaderno.abierta("f_40"):
		return _fallo("el entierro no abre la ficha del 40")
	return true


# --- Desde arriba (M) ---

var _probo_mal_mapa := false

## Sube con M, asienta a mano lo que pida (un fallo aposta), espera la cascada,
## traza el cerco si toca (uno demasiado grande primero) y baja con M.
func _desde_arriba() -> bool:
	var vista := get_tree().get_first_node_in_group(&"vista_pajaro")
	if vista == null:
		return _fallo("no hay vista de pájaro")
	if not bool(vista.get(&"activa")):
		_tecla(KEY_M)
	if not await _hasta(func(): return bool(vista.get(&"activa")) and not bool(vista.get(&"_ocupada")), 6.0):
		return _fallo("M no sube a la vista de pájaro")
	await _segundos(0.8)
	await _foto("arriba")
	var maqueta: Node3D = vista.call(&"maqueta")
	var tira: Control = vista.get(&"_tira")
	for vuelta in 8:
		await get_tree().process_frame
		if tira.get_child_count() == 0:
			break
		var b := tira.get_child(0) as Button
		var id := String(b.get_meta(&"asiento", ""))
		var a := {}
		for x in ASIENTOS.por_asentar():
			if String(x.get("id", "")) == id:
				a = x
		if a.is_empty():
			return _fallo("un nombre de la tira no está por asentar: " + id)
		await _clic(b.get_global_rect().get_center())
		await _segundos(0.3)
		if not _probo_mal_mapa:
			_probo_mal_mapa = true
			await _clic(vista.call(&"pantalla_de", Vector2(0.14, 0.15), 0.0))
			await _segundos(0.4)
			await _foto("mapa_fallo")
			print("      clic en otra calle: «%s»" % String(vista.get(&"_voz").text))
			if Casefile.is_recorded(id) or String(vista.get(&"_voz").text).is_empty():
				return _fallo("un clic en otra calle se acepta o no dice nada")
		var sitio := MAQUETA.sitio(a)
		await _clic(vista.call(&"pantalla_de", sitio, float(maqueta.call(&"alto_en", sitio))))
		if not await _hasta(func(): return Casefile.is_recorded(id), 2.0):
			await _foto("mapa_no_acepta")
			return _fallo("no acepta el tejado de " + String(a.get("calle", "?")))
		await _segundos(0.6)
	if not await _hasta(func(): return ASIENTOS.por_asentar().is_empty() and not bool(vista.get(&"_cayendo")), 30.0):
		return _fallo("quedan muertes sin caer en el mapa")
	await _segundos(0.5)
	if bool(vista.get(&"_trazando")):
		await _foto("antes_del_cerco")
		var c: Vector2 = vista.call(&"pantalla_de", PLANO.BOMBA, 0.0)
		await _arrastrar_en(c, vista.call(&"pantalla_de", PLANO.BOMBA + Vector2(0.4, 0.0), 0.0))
		print("      cerco enorme: «%s»" % String(vista.get(&"_voz").text))
		if Casefile.has(ASIENTOS.PRUEBA_RACIMO):
			return _fallo("acepta un cerco que abarca la parroquia")
		await _arrastrar_en(c, vista.call(&"pantalla_de", PLANO.BOMBA + Vector2(0.23, 0.0), 0.0))
		if not await _hasta(func(): return Casefile.has(ASIENTOS.PRUEBA_RACIMO), 2.0):
			await _foto("cerco_rechazado")
			return _fallo("no acepta el cerco alrededor de la bomba: " + String(vista.get(&"_voz").text))
		await _segundos(0.8)
		await _foto("cercado")
	await _segundos(2.4)
	await _foto("mapa_" + str(Casefile.record_count()))
	_tecla(KEY_M)
	if not await _hasta(func(): return not bool(vista.get(&"activa")), 4.0):
		return _fallo("M no baja de la vista de pájaro")
	await _segundos(0.4)
	return true


func _arrastrar_en(desde: Vector2, hasta: Vector2) -> void:
	for paso in [[desde, true], [desde.lerp(hasta, 0.5), null], [hasta, null], [hasta, false]]:
		var pos: Vector2 = paso[0]
		if paso[1] == null:
			var m := InputEventMouseMotion.new()
			m.position = pos
			m.global_position = pos
			get_tree().root.push_input(m, true)
		else:
			var ev := InputEventMouseButton.new()
			ev.button_index = MOUSE_BUTTON_LEFT
			ev.pressed = bool(paso[1])
			ev.position = pos
			ev.global_position = pos
			get_tree().root.push_input(ev, true)
		await get_tree().process_frame
	await _segundos(0.3)


## El carro del sacristán: esperar a que pare, hablarle; la vista sube sola.
func _al_carro() -> bool:
	var carro := get_tree().get_first_node_in_group(&"carro_de_muertos")
	if carro == null:
		return _fallo("no hay carro de muertos")
	if not await _hasta(func(): return int(carro.call(&"esperando")) > 0, 30.0):
		return _fallo("el carro no llega")
	await _foto("carro")
	if not await _hablar_con("Sacristan", "sacristan"):
		return false
	var vista := get_tree().get_first_node_in_group(&"vista_pajaro")
	if not await _hasta(func(): return bool(vista.get(&"activa")), 6.0):
		return _fallo("tras la lista no sube la vista")
	return await _desde_arriba()


# --- La mesa ---

## Clica papeles, clava cada nombre en su hueco y baja la hoja.
func _en_la_mesa() -> bool:
	var sentado := get_tree().current_scene.find_child("Sentado", true, false)
	if sentado == null or not bool(sentado.get("_listo")):
		return _fallo("en la mesa sin estar sentado")

	var libro: Node3D = null
	for n in get_tree().current_scene.find_children("*", "StaticBody3D", true, false) \
			+ get_tree().current_scene.find_children("*", "Area3D", true, false):
		if n.has_meta(&"accion") and String(n.get_meta(&"accion")) == "libro":
			libro = n as Node3D
	if libro == null:
		return _fallo("no hay nada que clicar en la mesa")
	var cam := get_viewport().get_camera_3d()
	await _clic(cam.unproject_position(libro.global_position))
	if not await _hasta(func(): return sentado.get("_hoja") != null, 3.0):
		await _foto("mesa_sin_hoja")
		return _fallo("clico los papeles y la hoja no sube")
	await _segundos(0.8)
	await _foto("hoja")

	var marco: Control = sentado.get("_hoja")
	var hoja: Control = marco.get_child(0)
	var plano: Control = hoja.get("_plano")
	var PLANO_GD: Script = plano.get_script()
	var clavados := 0
	var voz: Label = hoja.get("_voz")
	for vuelta in 60:
		var pendientes: Array = hoja.call("_por_clavar")
		if pendientes.is_empty():
			break
		var cuaderno: Control = hoja.get("_cuaderno")
		var fila := cuaderno.get_child(0) as Button
		if fila == null:
			return _fallo("la lista 'To add' no tiene filas que coger")
		await _clic(fila.get_global_rect().get_center())
		if hoja.get("_en_la_mano").is_empty():
			return _fallo("clico un nombre de 'To add' y no se coge")
		var en_la_mano: Dictionary = hoja.get("_en_la_mano")
		var direccion := String(en_la_mano.get("calle", ""))
		# Busca la dirección en el plano; la primera vez se equivoca aposta.
		var verdadero: Vector2 = PLANO_GD.punto_de_asiento(en_la_mano)
		if clavados == 0:
			await _segundos(0.4)
			await _foto("nombre_en_la_mano")
			var mal := Vector2(0.80, 0.30) if not direccion.contains("Poland") else Vector2(0.14, 0.30)
			await _clic(plano.get_screen_transform() * (mal * plano.size))
			await _segundos(0.3)
			print("      clic en la calle equivocada: «%s»" % voz.text)
			if Casefile.is_recorded(String(en_la_mano.get("id", ""))) or voz.text.is_empty():
				return _fallo("clicar en la calle equivocada no dice nada o clava igual")
			await _foto("calle_equivocada")
		var antes := Casefile.record_count()
		await _clic(plano.get_screen_transform() * (verdadero * plano.size))
		if not await _hasta(func(): return Casefile.record_count() > antes, 2.0):
			await _foto("no_se_clava")
			return _fallo("clico %s en el plano y no se clava: «%s»" % [direccion, voz.text])
		clavados += 1
		if clavados % 4 == 0:
			await _foto("plano_%02d" % Casefile.record_count())
	print("      clavados a mano %d, en el plano %d" % [clavados, Casefile.record_count()])

	# La lista del sacristán, de golpe.
	var copiar := _boton_con(hoja, "The sexton's list")
	if copiar != null:
		var antes := Casefile.record_count()
		await _clic(copiar.get_global_rect().get_center())
		if not await _hasta(func(): return hoja.call("_lista_del_sacriston").is_empty() and not bool(hoja.get("_copiando")), 8.0):
			return _fallo("la lista del sacristán no se copia")
		print("      lista del sacristán: %d nombres" % (Casefile.record_count() - antes))
		await _segundos(0.4)
		await _foto("lista_del_sacristan")

	if GameState.has_flag("buried_frances_lewis") and Casefile.record_count() >= GUIA.SUFICIENTES:
		if not await _hasta(func(): return bool(plano.call("trazando")), 3.0):
			await _foto("sin_circulo")
			return _fallo("con todo clavado no se pide trazar el círculo")
		await _foto("pide_circulo")
		# Primero un cerco de toda la parroquia: debe decir que no.
		await _arrastrar(plano, Vector2(0.5, 0.5), 0.45)
		print("      círculo enorme: «%s»" % voz.text)
		if Casefile.has("broad_street_racimo"):
			return _fallo("un círculo que coge toda la parroquia vale")
		# Luego uno bueno, alrededor del racimo.
		var pts: Array = plano.call("puntos")
		var centro := Vector2.ZERO
		for q in pts:
			centro += q
		centro /= float(pts.size())
		var radio := 0.13
		await _arrastrar(plano, centro, radio)
		if not await _hasta(func(): return Casefile.has("broad_street_racimo"), 3.0):
			await _foto("circulo_no_vale")
			return _fallo("el círculo alrededor del racimo no vale: «%s»" % voz.text)
		print("      círculo: «%s»" % voz.text)
		await _segundos(0.6)
		await _foto("racimo")
		# La hoja baja y la cámara sube al plano.
		await _segundos(6.0)
		await _foto("plano_de_pared")
		if not await _hasta(func(): return bool(sentado.get("_listo")) and sentado.get("_hoja") == null, 20.0):
			return _fallo("tras mirar el plano de la pared no se vuelve a la mesa")
		return true

	await _segundos(0.6)
	await _foto("plano_%02d" % Casefile.record_count())
	var bajar := _boton_con(hoja, "Set it down")
	if bajar == null:
		return _fallo("la hoja no tiene 'Set it down'")
	bajar.pressed.emit()
	if not await _hasta(func(): return sentado.get("_hoja") == null, 3.0):
		return _fallo("'Set it down' no baja la hoja")
	await _segundos(0.5)
	await _foto("hoja_bajada")
	return true


func _salir_a_la_calle() -> bool:
	var sentado := get_tree().current_scene.find_child("Sentado", true, false)
	var salir := sentado.get("_salir") as Button if sentado != null else null
	if salir == null or not salir.is_visible_in_tree():
		await _foto("sin_salida")
		return _fallo("sentado, con la hoja bajada, no hay botón para salir")
	salir.pressed.emit()
	# El domingo, salir de casa pasa por el entierro.
	if await _hasta(func(): return _escena() == CEMENTERIO, 3.0):
		if not await _entierro():
			return false
	if not await _hasta(func(): return _escena() == CALLE and _jugador() != null, 6.0):
		return _fallo("'Out to the street' no lleva a la calle")
	if not await _hasta(func(): return _jugador().get("_agent") != null, 5.0):
		return _fallo("la calle no arranca al volver")
	_jugador().set("debug", true)
	await _segundos(2.5)
	await _foto("de_vuelta_en_la_calle")
	return true


## Snow: en casa, con el cerco y las dos casas raras, llama.
func _snow() -> bool:
	if not SNOW.toca():
		return _fallo("la línea dice que Snow va a llamar y el juego no lo cree")
	# Whitehead va a la puerta; se abre con un clic en el pomo.
	var snow := get_tree().current_scene.find_child("Snow", true, false)
	if snow == null or not await _hasta(func(): return bool(snow.get(&"_esperando_pomo")), 20.0):
		return _fallo("Whitehead no llega a la puerta")
	var pomo := get_tree().current_scene.find_child("PomoClic", true, false) as Node3D
	var cam := get_viewport().get_camera_3d()
	if pomo != null and cam != null:
		await _foto("snow_pomo")
		await _clic(cam.unproject_position(pomo.global_position))
	if not await _hasta(func(): return not bool(snow.get(&"_esperando_pomo")), 3.0):
		return _fallo("el clic en el pomo no abre la puerta")
	if not await _hasta(func(): return DialogueRunner.active, 15.0):
		await _foto("snow_no_llama")
		return _fallo("Snow no llama")
	await _segundos(0.5)
	await _foto("snow")
	await _conversar()
	if not GameState.has_flag("aire_explicado") or not GameState.has_flag("lejos_explicado"):
		return _fallo("a Snow no se le pudo enseñar lo que pedía")
	await _segundos(1.0)
	await _foto("snow_final")
	return true


# --- La conversación ---

## Pasa líneas con Enter; en un nodo que vuelve, la opción siguiente.
func _conversar() -> void:
	var opciones := HUD.get("_choices") as Control
	var vueltas := 0
	var vistas := {}
	while DialogueRunner.active and vueltas < 80:
		vueltas += 1
		await _segundos(0.2)
		if not DialogueRunner.active:
			break
		if OS.get_environment("PARTIDA_TRAZA") != "":
			print("        nodo: ", DialogueRunner.get("_node_id"), "  opciones: ", (HUD.get("_choices") as Control).get_child_count(), "  cuaderno abierto: ", (HUD.get("_expediente") as Control).visible)
		if opciones.get_child_count() > 0:
			var nodo := String(DialogueRunner.get("_node_id"))
			var k := int(vistas.get(nodo, 0))
			vistas[nodo] = k + 1
			var b := opciones.get_child(k % opciones.get_child_count()) as Button
			if vueltas == 1 or vueltas % 7 == 0:
				await _foto("opciones_" + DialogueRunner.get("_current_id"))
			var pide: Dictionary = Dictionary(DialogueRunner.nodo_actual().get("pide", {}))
			await _clic(b.get_global_rect().get_center())
			if not pide.is_empty():
				await _ensenar(pide)
		else:
			_tecla(KEY_ENTER)
		await get_tree().process_frame
	if DialogueRunner.active:
		_fallo("la conversación %s no termina" % DialogueRunner.get("_current_id"))


# --- El cuaderno ---

## Abre el cuaderno (TAB) y rellena la ficha de la guía; la 1ª vez falla aposta.
var _probo_un_error := false

func _cuaderno() -> bool:
	var id := GUIA.ficha_mal()
	if id.is_empty():
		id = GUIA.ficha_lista()
	if id.is_empty():
		return _fallo("la esquina manda al cuaderno y no hay ficha")
	_tecla(KEY_TAB)
	var exp: Control = HUD.get("_expediente")
	if not await _hasta(func(): return exp.visible, 2.0):
		return _fallo("TAB no abre el cuaderno")
	await _segundos(0.4)
	var pagina: Control = exp.get("_pag_cuaderno")
	pagina.call(&"mostrar_ficha", id)
	await get_tree().process_frame
	if not _probo_un_error:
		await _foto("cuaderno_" + id)
	var huecos: Dictionary = Dictionary(Cuaderno.ficha(id).get("huecos", {}))
	for h in Cuaderno.huecos_en_orden(id):
		var poner := String(huecos[h])
		# El error aposta: palabra del mismo tipo pero equivocada.
		if not _probo_un_error:
			for w in Cuaderno.sabidas():
				if w != poner and String(Cuaderno.palabra(w).get("tipo", "")) == String(Cuaderno.palabra(poner).get("tipo", "")):
					poner = w
					break
		if not await _clic_meta(pagina, &"hueco", id + "/" + h):
			return _fallo("no encuentro el hueco %s de la ficha %s" % [h, id])
		if not await _clic_meta(pagina, &"palabra", poner):
			return _fallo("no encuentro la palabra %s en el cuaderno" % poner)
		if not _probo_un_error and String(huecos[h]) != poner:
			_probo_un_error = true
			# Las demás bien: queda exactamente una mal.
			for h2 in Cuaderno.huecos_en_orden(id):
				if h2 == h:
					continue
				await _clic_meta(pagina, &"hueco", id + "/" + h2)
				await _clic_meta(pagina, &"palabra", String(huecos[h2]))
			await _segundos(0.3)
			await _foto("ficha_con_un_error")
			var malas := int(pagina.call(&"malas", id))
			print("      ficha con un error: %d subrayada en rojo, el resto en tinta" % malas)
			if malas != 1 or Cuaderno.sellada(id):
				return _fallo("una ficha con un error se sella o no marca la mala")
			# Clicar el hueco malo lo vacía; se pone la buena.
			await _clic_meta(pagina, &"hueco", id + "/" + h)
			await _clic_meta(pagina, &"palabra", String(huecos[h]))
			break
	if not await _hasta(func(): return Cuaderno.sellada(id), 1.0):
		await _foto("ficha_no_sella")
		return _fallo("la ficha %s, bien rellena, no se sella" % id)
	await _segundos(0.3)
	await _foto("sellada_" + id)
	_tecla(KEY_TAB)
	await _hasta(func(): return not exp.visible, 2.0)
	await _segundos(0.3)
	return true


func _clic_meta(raiz: Node, clave: StringName, valor: String) -> bool:
	for n in raiz.find_children("*", "Button", true, false):
		var b := n as Button
		if b.has_meta(clave) and String(b.get_meta(clave)) == valor and b.is_visible_in_tree():
			# Si está fuera de la vista, baja la lista.
			var scroll := b.get_parent()
			while scroll != null and not (scroll is ScrollContainer):
				scroll = scroll.get_parent()
			if scroll != null:
				(scroll as ScrollContainer).ensure_control_visible(b)
				await get_tree().process_frame
				await get_tree().process_frame
			await _clic(b.get_global_rect().get_center())
			await get_tree().process_frame
			return true
	return false


## Enseña a Snow la primera ficha sellada que sirva.
func _ensenar(pide: Dictionary) -> void:
	var exp: Control = HUD.get("_expediente")
	if not await _hasta(func(): return exp.visible, 2.0):
		_fallo("'Show him a card' no abre el cuaderno")
		return
	await _segundos(0.4)
	await _foto("ensenar_a_snow")
	for f in Dictionary(pide.get("fichas", {})):
		if Cuaderno.sellada(String(f)):
			if await _clic_meta(exp, &"ensenar", String(f)):
				print("      a Snow se le enseña: %s" % f)
				return
	_fallo("no hay ficha sellada que enseñarle a Snow")


## Arrastra en el plano desde el centro hasta `radio`.
func _arrastrar(plano: Control, centro: Vector2, radio: float) -> void:
	var desde: Vector2 = plano.get_screen_transform() * (centro * plano.size)
	var hasta: Vector2 = desde + Vector2(radio * plano.size.x, 0.0)
	for paso in [[desde, true], [desde.lerp(hasta, 0.5), null], [hasta, null], [hasta, false]]:
		var pos: Vector2 = paso[0]
		if paso[1] == null:
			var m := InputEventMouseMotion.new()
			m.position = pos
			m.global_position = pos
			get_tree().root.push_input(m, true)
		else:
			var ev := InputEventMouseButton.new()
			ev.button_index = MOUSE_BUTTON_LEFT
			ev.pressed = bool(paso[1])
			ev.position = pos
			ev.global_position = pos
			get_tree().root.push_input(ev, true)
		await get_tree().process_frame
	await _segundos(0.3)


# --- Manos y ojos ---

func _clic(pos: Vector2) -> void:
	var m := InputEventMouseMotion.new()
	m.position = pos
	m.global_position = pos
	get_tree().root.push_input(m, true)
	await get_tree().process_frame
	for apretado in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = apretado
		ev.position = pos
		ev.global_position = pos
		get_tree().root.push_input(ev, true)
		await get_tree().process_frame


func _tecla(k: Key) -> void:
	for apretada in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = k
		ev.physical_keycode = k
		ev.pressed = apretada
		get_tree().root.push_input(ev, true)


func _boton_con(raiz: Node, texto: String) -> Button:
	for n in raiz.find_children("*", "Button", true, false):
		if String((n as Button).text).contains(texto):
			return n as Button
	return null


func _hasta(cond: Callable, segundos: float) -> bool:
	var limite := Time.get_ticks_msec() + int(segundos * 1000.0)
	while Time.get_ticks_msec() < limite:
		if bool(cond.call()):
			return true
		await get_tree().process_frame
	return bool(cond.call())


func _segundos(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _foto(nombre: String) -> void:
	if _fotos.is_empty():
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img == null:
		return
	_n_foto += 1
	var salida := "%s/%02d_%s.png" % [_fotos, _n_foto, nombre]
	img.save_png(salida)


func _fallo(por_que: String) -> bool:
	print("  ! FALLA (paso %d): %s" % [_paso, por_que])
	_fallos.append("paso %d: %s" % [_paso, por_que])
	return false


# --- Saltar a una etapa sin jugar (como prueba_guia) ---

const LIBRO := "res://data/registro/ch1_libro_parroquia.json"
var _dummy: Node


func _avanzar_sin_jugar(hasta: String) -> void:
	print("  (saltando hasta la etapa '%s' sin jugar)" % hasta)
	_dummy_en(CALLE)
	for paso in 160:
		var e := GUIA.etapa()
		var id := String(e["id"])
		if id == hasta or id == "fin":
			break
		if id == "cuaderno":
			var f := GUIA.ficha_mal()
			if f.is_empty():
				f = GUIA.ficha_lista()
			var hs: Dictionary = Dictionary(Cuaderno.ficha(f).get("huecos", {}))
			for h in hs:
				Cuaderno.poner(f, String(h), String(hs[h]))
			Cuaderno.comprobar(f)
			continue
		if id == "en_la_mesa":
			_clavar_sin_jugar()
			continue
		if bool(e["a_casa"]) or id == "a_snow":
			if GUIA.en_casa() and DIAS.toca_dormir():
				DIAS.dormir()
				if GameState.dia >= 3 and not GameState.has_flag("buried_frances_lewis"):
					preload("res://scripts/world/cementerio.gd").asentar()
				_dummy_en(CALLE)
				continue
			_dummy_en(RECTORIA)
			continue
		var puertas: Array = e["puertas"]
		if puertas.is_empty():
			break
		if GUIA.en_casa():
			_dummy_en(CALLE)
			continue
		_hablar_sin_jugar(String(puertas[0]))
	if _dummy != null:
		_dummy.queue_free()
		_dummy = null
	LLEGADA.ya_llegamos = false
	print("  (en la etapa '%s': %d apuntes, %d asientos)" % [String(GUIA.etapa()["id"]),
		Casefile.note_count(), Casefile.record_count()])


func _dummy_en(ruta: String) -> void:
	if _dummy != null:
		_dummy.queue_free()
	_dummy = Node.new()
	_dummy.scene_file_path = ruta
	get_tree().root.add_child(_dummy)
	get_tree().current_scene = _dummy


func _hablar_sin_jugar(dialogo: String) -> void:
	DialogueRunner.start(dialogo)
	var vueltas := 0
	while DialogueRunner.active and vueltas < 80:
		vueltas += 1
		var nodos: Dictionary = DialogueRunner._current.get("nodos", {})
		var opciones: Array = DialogueRunner._visible_choices(nodos.get(DialogueRunner._node_id, {}))
		if opciones.is_empty():
			DialogueRunner.advance()
		else:
			DialogueRunner.choose(0)


func _clavar_sin_jugar() -> void:
	var datos: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(LIBRO))
	var tandas: Array = Array(datos.get("asientos", []))
	if GameState.has_flag("buried_frances_lewis"):
		tandas += Array(datos.get("segunda_tanda", []))
	var todo: Array = tandas.duplicate()
	for r in Cuaderno.registros_sellados():
		todo.append(r)
	for a in todo:
		Casefile.record(Dictionary(a))
	var libro_entero := true
	for a in Array(datos.get("asientos", [])):
		libro_entero = libro_entero and Casefile.is_recorded(String(a.get("id", "")))
	if libro_entero:
		GameState.set_flag("parish_book_read")
	var cerco := GameState.has_flag("buried_frances_lewis") and Casefile.record_count() >= GUIA.SUFICIENTES
	if cerco and GUIA.pendientes_del_libro() + GUIA.pendientes_de_la_calle() == 0:
		Casefile.collect("broad_street_racimo")
		GameState.set_flag("saw_the_cluster")
