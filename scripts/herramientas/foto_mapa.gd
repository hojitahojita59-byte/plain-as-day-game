extends Node
## Foto del mapa (M) con las primeras muertes. Uso: -- <archivo.png>

func _ready() -> void:
	var out := OS.get_cmdline_user_args()[0]
	SaveSystem.set(&"_pendiente", true)
	GameState.set_flag("apertura_vista")
	GameState.set_flag("lista_1")
	add_child((load("res://scenes/world/calle.tscn") as PackedScene).instantiate())
	await get_tree().create_timer(1.5).timeout
	for a in preload("res://scripts/asientos.gd").por_asentar():
		Casefile.record(a)
	get_tree().get_first_node_in_group(&"vista_pajaro").call(&"subir")
	await get_tree().create_timer(3.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out)
	get_tree().quit()
