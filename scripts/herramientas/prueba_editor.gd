extends Node
## ¿Se ve la calle en el editor? Construye cada calle como el editor
## y comprueba que ninguna pieza levantada tenga dueño (se guardaría en el .tscn).

const CALLE := preload("res://scenes/world/calle.tscn")


func _ready() -> void:
	var fallos := 0
	for id_raw in Barrio.ids():
		fallos += await _probar(String(id_raw))
	print("")
	print("[editor] %s" % ("LAS CUATRO SE VEN EN EL EDITOR."
		if fallos == 0 else "%d PROBLEMAS (arriba, con !)." % fallos))
	get_tree().quit()


func _probar(id: String) -> int:
	var escena := CALLE.instantiate()
	add_child(escena)
	await get_tree().process_frame

	var constructor := escena.get_node_or_null(^"Constructor")
	var calle := escena.get_node_or_null(^"Calle") as Node3D

	# Vacía lo del arranque y usa la construcción del editor (lee el JSON sin autoload).
	constructor.set("calle_en_el_editor", id)
	constructor.call("_rehacer_para_el_editor")
	await get_tree().process_frame

	var piezas := 0
	var con_dueno := 0
	var pila: Array[Node] = [calle]
	while not pila.is_empty():
		var n: Node = pila.pop_back()
		for h in n.get_children():
			# Suelo y pavimento sí tienen dueño: vienen en calle.tscn.
			piezas += 1
			# Solo cuenta dueño = raíz editada (las tripas de un prop tienen el suyo).
			if h.owner == escena:
				con_dueno += 1
			pila.append(h)

	var partes := {
		"fachadas": calle.get_node_or_null(^"Fachadas"),
		"suelo": calle.get_node_or_null(^"Pavimento"),
		"puertas": calle.get_node_or_null(^"Puertas"),
		"números": calle.get_node_or_null(^"Numeros"),
		"esquinas": calle.get_node_or_null(^"Esquinas"),
		"vecinos": calle.get_node_or_null(^"Vecinos"),
		"mobiliario": calle.get_node_or_null(^"Mobiliario"),
	}

	var fallos := 0
	var linea := ""
	for k in partes:
		var nodo: Node = partes[k]
		var n := nodo.get_child_count() if nodo != null else 0
		if n == 0:
			fallos += 1
			linea += "  !%s:0" % k
		else:
			linea += "  %s:%d" % [k, n]

	if con_dueno > 0:
		fallos += 1

	print("%-18s %4d piezas %s   se guardarían en el .tscn: %s" % [
		id, piezas, linea, "NINGUNA" if con_dueno == 0 else "! %d" % con_dueno])

	escena.queue_free()
	await get_tree().process_frame
	return fallos
