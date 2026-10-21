extends Node
## Fotos de una escena a ciertos segundos. Uso: -- <escena> <carpeta> <s1,s2,...> [nodo a mirar]

func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	SaveSystem.set(&"_pendiente", true)
	DirAccess.make_dir_recursive_absolute(a[1])
	add_child((load(a[0]) as PackedScene).instantiate())
	var t0 := Time.get_ticks_msec() / 1000.0
	for s in a[2].split(","):
		while Time.get_ticks_msec() / 1000.0 - t0 < float(s):
			await get_tree().process_frame
		if a.size() > 3:
			var n := get_tree().root.find_child(a[3], true, false) as Node3D
			var cam := get_viewport().get_camera_3d()
			if n != null and cam != null:
				cam.set_process(false)
				cam.global_position = n.global_position + n.global_basis.z * float(a[4] if a.size() > 4 else "1.6") + Vector3.UP * 2.0
				cam.look_at(n.global_position)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(a[1].path_join("t%s.png" % s))
	get_tree().quit()
