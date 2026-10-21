extends Node
## ¿Lleva el rastro de luces a casa desde el extremo este (junto al 9)?
## Copia la partida guardada y la restaura al terminar. Uso: --headless

const CALLE := preload("res://scenes/world/calle.tscn")

## Salida: delante del número 9.
const DESDE := Vector3(36.0, 0.0, -2.0)


func _ready() -> void:
	var copia: Variant = null
	if FileAccess.file_exists(SaveSystem.SAVE_PATH):
		copia = FileAccess.get_file_as_bytes(SaveSystem.SAVE_PATH)
	var bien := await _probar()
	await get_tree().process_frame
	if copia == null:
		SaveSystem.delete_save()
	else:
		FileAccess.open(SaveSystem.SAVE_PATH, FileAccess.WRITE).store_buffer(copia)
	get_tree().quit(0 if bien else 1)


func _probar() -> bool:
	Casefile.reset()
	# Vuelve a casa: sábado cerrado y nada por asentar.
	GameState.dia = 2
	GameState.set_flag("dia_2")
	for f in ["hablado_ch1_s3_tailor", "parish_book_read", "hablado_ch1_s3_puerta_40",
			"hablado_ch1_s3_cambridge_lavandera", "hablado_ch1_s3_cambridge_nadie",
			"hablado_ch1_s3_cambridge_cervecero"]:
		GameState.set_flag(f)
	for a in preload("res://scripts/asientos.gd").por_asentar():
		Casefile.record(a)

	var calle := CALLE.instantiate()
	add_child(calle)
	var jugador := calle.get_node_or_null(^"Whitehead") as Node3D
	if jugador != null:
		jugador.global_position = DESDE

	# Navmesh horneada; el camino se recalcula cada 0,35 s.
	await get_tree().create_timer(1.5).timeout

	var camino := calle.find_child("CaminoACasa", true, false) as Node3D
	var casas := _esquinas_de_casa(calle)
	var bien := camino != null and not casas.is_empty()
	var ultima := Vector3.INF
	if bien:
		for luz in camino.get_children():
			if luz is MeshInstance3D and (luz as MeshInstance3D).visible:
				ultima = (luz as Node3D).global_position
		bien = ultima != Vector3.INF

	var cerca := INF
	for c in casas:
		cerca = minf(cerca, Vector2(ultima.x, ultima.z).distance_to(Vector2(c.x, c.z)))
	# A menos de 4 m de la esquina: el camino va al callejón.
	bien = bien and cerca < 4.0

	# Fallo a vigilar: que el rastro acabe más cerca de una puerta que de casa.
	var puerta_cerca := INF
	for p in get_tree().get_nodes_in_group(&"puertas"):
		var q := (p as Node3D).global_position
		puerta_cerca = minf(puerta_cerca, Vector2(ultima.x, ultima.z).distance_to(Vector2(q.x, q.z)))
	bien = bien and cerca < puerta_cerca

	print("[camino] salidas a casa: %d   última luz: %s   a %.1f m de casa, a %.1f m de la puerta más cercana   %s" % [
		casas.size(), str(ultima.round()), cerca, puerta_cerca, "SI" if bien else "! NO"])
	Casefile.reset()
	return bien


func _esquinas_de_casa(calle: Node) -> Array[Vector3]:
	var fuera: Array[Vector3] = []
	var camino := calle.find_child("CaminoACasa", true, false)
	if camino != null:
		for s in camino.get("salidas"):
			fuera.append(s)
	return fuera
