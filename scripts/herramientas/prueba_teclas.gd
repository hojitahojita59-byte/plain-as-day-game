extends Node
## ¿Anda Whitehead con flechas y WASD hacia donde toca?
## Copia la partida guardada y la restaura al terminar.

const CALLE := preload("res://scenes/world/calle.tscn")
const TECLAS := {
	"flecha arriba": [KEY_UP, Vector3.FORWARD],
	"flecha abajo": [KEY_DOWN, Vector3.BACK],
	"flecha izquierda": [KEY_LEFT, Vector3.LEFT],
	"flecha derecha": [KEY_RIGHT, Vector3.RIGHT],
	"W": [KEY_W, Vector3.FORWARD],
	"S": [KEY_S, Vector3.BACK],
	"A": [KEY_A, Vector3.LEFT],
	"D": [KEY_D, Vector3.RIGHT],
}


func _ready() -> void:
	await get_tree().process_frame
	var copia: Variant = null
	if FileAccess.file_exists(SaveSystem.SAVE_PATH):
		copia = FileAccess.get_file_as_bytes(SaveSystem.SAVE_PATH)

	var calle := CALLE.instantiate()
	get_tree().root.add_child(calle)
	get_tree().current_scene = calle
	await get_tree().create_timer(1.5).timeout
	var yo := calle.get_node(^"Whitehead") as Node3D

	var fallos := 0
	print("")
	print("=== TECLAS ===")
	for nombre in TECLAS:
		var tecla: Key = TECLAS[nombre][0]
		var hacia: Vector3 = TECLAS[nombre][1]
		yo.global_position = Vector3(2.0, yo.global_position.y, 1.0)
		await get_tree().physics_frame
		var antes := yo.global_position
		_tecla(tecla, true)
		await get_tree().create_timer(0.5).timeout
		_tecla(tecla, false)
		await get_tree().physics_frame
		var paso := yo.global_position - antes
		paso.y = 0.0
		# Al soltar, quieto (sin piernas moviéndose en el sitio).
		await get_tree().physics_frame
		var quieto := (yo as CharacterBody3D).velocity.length() < 0.01
		var bien := paso.length() > 0.5 and paso.normalized().dot(hacia) > 0.9 and quieto
		if not quieto:
			print("  ! sigue con velocidad después de soltar %s" % nombre)
		fallos += 0 if bien else 1
		print("  %-17s se movió %.2f m   %s" % [nombre, paso.length(),
			"bien" if bien else "! MAL (%s)" % str(paso.snapped(Vector3.ONE * 0.01))])

	print("[teclas] %s" % ("LAS OCHO ANDAN." if fallos == 0 else "%d TECLAS FALLAN." % fallos))

	# Puertas de lado: clic en la acera delante de cada una de Cambridge Street.
	print("")
	print("=== PUERTAS DE LADO ===")
	yo.global_position = Vector3(-15.0, yo.global_position.y, -22.0)
	await get_tree().create_timer(1.0).timeout
	var cam := get_viewport().get_camera_3d()
	for p in get_tree().get_nodes_in_group(&"puertas"):
		var puerta := p as Node3D
		var fuera := puerta.global_basis * Vector3.BACK
		if absf(fuera.z) > 0.9:
			continue
		var acera := puerta.global_position + fuera * 1.0
		acera.y = 0.3
		var pantalla := cam.unproject_position(acera)
		yo.set("_pending", null)
		yo.call("_pick_target", pantalla)
		var tomada = yo.get("_pending")
		var bien: bool = tomada == puerta
		fallos += 0 if bien else 1
		print("  %-18s %s" % [String(puerta.get("display_name")),
			"se coge clicando la acera" if bien else "! NO SE COGE"])
		yo.call("_stop")
	if copia == null:
		SaveSystem.delete_save()
	else:
		FileAccess.open(SaveSystem.SAVE_PATH, FileAccess.WRITE).store_buffer(copia)
	get_tree().quit(0 if fallos == 0 else 1)


func _tecla(tecla: Key, apretada: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = tecla
	ev.physical_keycode = tecla
	ev.pressed = apretada
	Input.parse_input_event(ev)
