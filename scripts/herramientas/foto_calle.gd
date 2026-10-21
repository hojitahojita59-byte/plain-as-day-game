extends Node
## Foto de una calle sin jugarla, en SubViewport de tamaño fijo.
## Uso: foto_calle.tscn -- salida.png [segundos] [x] [calle] [z]

const CALLE := preload("res://scenes/world/calle.tscn")
const TAM := Vector2i(1920, 1080)

## Espera antes de disparar: música, navmesh y personaje aún se están montando.
const ESPERA := 1.5


func _ready() -> void:
	var extra := OS.get_cmdline_user_args()
	var salida: String = extra[0] if extra.size() > 0 else "calle.png"
	var espera: float = float(extra[1]) if extra.size() > 1 else ESPERA
	## 3º arg: X donde mirar (mueve al jugador).
	var mirar_x: float = float(extra[2]) if extra.size() > 2 else NAN
	## 4º arg: qué calle.
	if extra.size() > 3:
		Barrio.actual = String(extra[3])
		Barrio.entrada_por = "defecto"

	var vp := SubViewport.new()
	vp.size = TAM
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.handle_input_locally = false
	add_child(vp)
	var calle := CALLE.instantiate()
	vp.add_child(calle)

	## 5º arg: Z (para calles hacia el fondo).
	var mirar_z: float = float(extra[4]) if extra.size() > 4 else NAN
	if not is_nan(mirar_x):
		var jugador := calle.get_node_or_null(^"Whitehead") as Node3D
		if jugador != null:
			jugador.position.x = mirar_x
			if not is_nan(mirar_z):
				jugador.position.z = mirar_z

	await get_tree().create_timer(espera).timeout
	await RenderingServer.frame_post_draw

	var img := vp.get_texture().get_image()
	var err := img.save_png(salida)
	print("[foto_calle] %s %dx%d (%s)" % [
		salida, img.get_width(), img.get_height(), "ok" if err == OK else str(err)])
	get_tree().quit()
