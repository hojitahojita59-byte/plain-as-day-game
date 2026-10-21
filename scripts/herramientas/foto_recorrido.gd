extends Node
## Fotos de la calle desde varios puntos. Uso: -- <carpeta> [x,z;x,z...]

const PUNTOS := [Vector3(-48, 0, -3), Vector3(-30, 0, -3), Vector3(-15, 0, -3), Vector3(0, 0, -3),
	Vector3(15, 0, -3), Vector3(32, 0, -3), Vector3(-15, 0, -20), Vector3(-35, 0, -18), Vector3(35, 0, -18)]

func _ready() -> void:
	var out := OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	SaveSystem.set(&"_pendiente", true)
	GameState.set_flag("apertura_vista")
	for d in ["dia_2", "dia_3"]:
		GameState.set_flag(d)
	add_child((load("res://scenes/world/calle.tscn") as PackedScene).instantiate())
	await get_tree().create_timer(1.5).timeout
	var yo := get_tree().get_first_node_in_group(&"jugador") as Node3D
	var puntos: Array = PUNTOS
	if OS.get_cmdline_user_args().size() > 1:
		puntos = []
		for par in OS.get_cmdline_user_args()[1].split(";"):
			var xz := par.split(",")
			puntos.append(Vector3(float(xz[0]), 0, float(xz[1])))
	for i in puntos.size():
		yo.global_position = puntos[i] + Vector3.UP
		await get_tree().create_timer(1.6).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out.path_join("p%d.png" % i))
	get_tree().quit()
