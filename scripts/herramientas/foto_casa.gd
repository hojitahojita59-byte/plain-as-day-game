extends Node
## Fotos de la rectoría desde cámaras fijas. Copia y restaura la partida guardada.
## Uso: -- <carpeta> nombre:px,py,pz:mx,my,mz [nombre:...]

const RECTORIA := "res://scenes/world/rectoria.tscn"
const LLEGADA := preload("res://scripts/world/llegada_a_casa.gd")


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	var copia: Variant = null
	if FileAccess.file_exists(SaveSystem.SAVE_PATH):
		copia = FileAccess.get_file_as_bytes(SaveSystem.SAVE_PATH)
	SaveSystem.set(&"_pendiente", true)
	DirAccess.make_dir_recursive_absolute(a[0])
	LLEGADA.ya_llegamos = true
	var escena := (load(RECTORIA) as PackedScene).instantiate()
	add_child(escena)
	await get_tree().create_timer(1.2).timeout
	var sentado := escena.get_node_or_null(^"Sentado")
	if sentado != null:
		sentado.set_process(false)
	var cam := get_viewport().get_camera_3d()
	for i in range(1, a.size()):
		var partes := a[i].split(":")
		var p := partes[1].split_floats(",")
		var m := partes[2].split_floats(",")
		cam.global_position = Vector3(p[0], p[1], p[2])
		cam.look_at(Vector3(m[0], m[1], m[2]), Vector3.UP)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(a[0].path_join(partes[0] + ".png"))
	if copia != null:
		FileAccess.open(SaveSystem.SAVE_PATH, FileAccess.WRITE).store_buffer(copia)
	get_tree().quit()
