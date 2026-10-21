extends Node
## Levanta cada calle y comprueba: puertas con hoja y número, sitios alcanzables,
## esquinas con destino y entrada, y nada metido en la fachada.

const CALLE := preload("res://scenes/world/calle.tscn")

## Distancia para dar por bueno que se llega.
const CERCA := 1.4


func _ready() -> void:
	var fallos := 0
	for id_raw in Barrio.ids():
		fallos += await _probar(String(id_raw))
	print("")
	if fallos == 0:
		print("[barrio] TODO EN PIE. Ni una puerta sin hoja, ni una esquina rota.")
	else:
		print("[barrio] %d COSAS QUE MIRAR (arriba, marcadas con !)." % fallos)
	get_tree().quit()


func _probar(id: String) -> int:
	var fallos := 0
	Barrio.actual = id
	Barrio.entrada_por = "defecto"

	var escena := CALLE.instantiate()
	add_child(escena)
	# La navmesh no está horneada en el mismo fotograma.
	for i in 25:
		await get_tree().process_frame

	var datos := Barrio.datos(id)
	print("")
	print("=== %s (%s) ===" % [Barrio.nombre(id), id])

	var calle := escena.get_node_or_null(^"Calle") as Node3D
	var jugador := escena.get_node_or_null(^"Whitehead") as Node3D
	var mapa: RID = escena.get_world_3d().navigation_map
	var desde: Vector3 = jugador.global_position
	print("  aparece en  %.1f, %.1f" % [desde.x, desde.z])
	for t_raw in Array(datos.get("tramos", [])):
		var t: Dictionary = t_raw
		var d0 := Array(t.get("desde", [0, 0]))
		print("  tramo %-18s %2d bahías  desde %6.1f,%6.1f  crece %-3s mira %s" % [
			String(t.get("id", "?")), int(t.get("bahias", 0)),
			float(d0[0]), float(d0[1]),
			String(t.get("eje", "?")), String(t.get("mira", "?"))])

	# --- Puertas: hoja, número y camino ---
	var puertas := calle.get_node_or_null(^"Puertas")
	var numeros := calle.get_node_or_null(^"Numeros")
	var esperadas := Array(datos.get("puertas", []))
	print("  puertas: %d en los datos, %d montadas, %d números" % [
		esperadas.size(),
		puertas.get_child_count() if puertas != null else 0,
		numeros.get_child_count() if numeros != null else 0])

	# El punto de aproximación lo da la propia puerta (vale para cualquier fachada).
	if puertas != null:
		for p in puertas.get_children():
			var cuerpo := p as Interactable
			var hoja := cuerpo.get_node_or_null(^"Hoja")
			var ocupante := hoja != null and hoja.get("ocupante") != null
			var camino := _se_llega(mapa, desde, cuerpo.approach_point(desde))
			var marca := "  " if (hoja != null and camino) else "! "
			if hoja == null or not camino:
				fallos += 1
			print("    %s%-10s %6.1f,%6.1f   hoja:%s  ocupante:%s  se llega:%s" % [
				marca, cuerpo.name, cuerpo.position.x, cuerpo.position.z,
				"sí" if hoja != null else "NO",
				"sí" if ocupante else "no",
				"sí" if camino else "NO"])

	# --- Esquinas: algo que decir o que decidir, y camino para llegar ---
	var esquinas := calle.get_node_or_null(^"Esquinas")
	if esquinas != null:
		for e in esquinas.get_children():
			if e is not StaticBody3D:
				continue
			var cuerpo := e as Interactable
			var dialogo := String(cuerpo.get("dialogue_id"))
			var decide := cuerpo.has_meta(&"decision")
			var camino := _se_llega(mapa, desde, cuerpo.approach_point(desde))
			var bien := camino and (decide or not dialogo.is_empty())
			if not bien:
				fallos += 1
			var que := dialogo if not dialogo.is_empty() else \
				("decisión: " + " / ".join(Array(Dictionary(
					cuerpo.get_meta(&"decision")).get("opciones", []))) if decide else "")
			print("    %s%-10s %6.1f,%6.1f   %-24s se llega:%s" % [
				"  " if bien else "! ", cuerpo.name, cuerpo.position.x,
				cuerpo.position.z, que, "sí" if camino else "NO"])

	# --- Qué puertas abren y cuándo (banderas en orden de juego) ---
	print("")
	print("  Puertas vivas según lo que sabes:")
	var momentos := [
		{"nombre": "al empezar", "banderas": []},
		{"nombre": "tras el hombre del bordillo", "banderas": ["knows_the_garment_womans_house"]},
		{"nombre": "tras la del 38", "banderas": ["spoke_to_the_garment_woman"]},
		{"nombre": "tras la carbonera", "banderas": ["spoke_to_the_coal_woman"]},
		{"nombre": "tras la mesa de la rectoría", "banderas": ["parish_book_read"]},
		{"nombre": "tras cercar el plano", "banderas": ["saw_the_cluster"]},
	]
	for m_raw in momentos:
		var m: Dictionary = m_raw
		for f in Array(m["banderas"]):
			GameState.set_flag(String(f))
		var vivas: Array[String] = []
		for p in puertas.get_children():
			var d: Interactable = p as Interactable
			if d.active_dialogue_id() != String(d.get("locked_dialogue_id")):
				vivas.append(_numero_de(numeros, d))
		print("    %-30s %2d  %s" % [m["nombre"], vivas.size(),
			", ".join(vivas) if not vivas.is_empty() else "(ninguna)"])

	# --- Huecos y nombres de calles: un hueco debe estar vacío de casa ---
	var rotulos := calle.get_node_or_null(^"Rotulos")
	var fachadas := calle.get_node_or_null(^"Fachadas")
	var huecos := 0
	for t_raw in Array(datos.get("tramos", [])):
		var t: Dictionary = t_raw
		var id_tramo := String(t.get("id", ""))
		for h in Array(t.get("huecos", [])):
			huecos += 1
			var i_h := int(h)
			if fachadas != null and fachadas.get_node_or_null(
					NodePath("%s/Bahia%d_0" % [id_tramo, i_h + 1])) != null:
				fallos += 1
				print("    ! el hueco %d de %s sigue teniendo casa" % [i_h, id_tramo])
	print("  huecos: %d   nombres de calle pintados: %d" % [
		huecos, rotulos.get_child_count() if rotulos != null else 0])
	if rotulos == null or rotulos.get_child_count() == 0:
		fallos += 1
		print("    ! el barrio no dice cómo se llama en ningún sitio")

	# --- Vecinos y props: que no estén metidos en la pared ---
	var vecinos := calle.get_node_or_null(^"Vecinos")
	if vecinos != null:
		for v in vecinos.get_children():
			var cuerpo := v as Node3D
			# La fachada llega a z = -5. Cualquiera detrás de eso está dentro.
			if cuerpo.position.z < -4.9:
				fallos += 1
				print("    ! %-14s está DENTRO de la fachada (z=%.2f)" % [
					cuerpo.name, cuerpo.position.z])

	escena.queue_free()
	await get_tree().process_frame
	return fallos


## Número pintado más cercano a la puerta; en blanco si no cuadra.
func _numero_de(numeros: Node, puerta: Node3D) -> String:
	if numeros == null:
		return "?"
	var mejor := "?"
	var cerca := 3.0
	for n in numeros.get_children():
		var l := n as Label3D
		var d := l.position.distance_to(puerta.position)
		if d < cerca:
			cerca = d
			mejor = l.text
	return mejor


## ¿Hay camino andando hasta ahí? (según la navmesh)
func _se_llega(mapa: RID, desde: Vector3, hasta: Vector3) -> bool:
	var ruta := NavigationServer3D.map_get_path(mapa, desde, hasta, true)
	if ruta.is_empty():
		return false
	var fin := ruta[ruta.size() - 1]
	return Vector2(fin.x - hasta.x, fin.z - hasta.z).length() < CERCA
