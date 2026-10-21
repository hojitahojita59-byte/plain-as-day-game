extends Node
## Retrata la llegada a la rectoría a los segundos pedidos.
## Uso: foto_rectoria.tscn -- prefijo 1.0 3.0 5.5 9.0

const RECTORIA := preload("res://scenes/world/rectoria.tscn")
const TAM := Vector2i(1600, 900)


func _ready() -> void:
	var extra := OS.get_cmdline_user_args()
	var prefijo: String = extra[0] if extra.size() > 0 else "rectoria"
	var tiempos: Array = []
	for i in range(1, extra.size()):
		tiempos.append(float(extra[i]))
	if tiempos.is_empty():
		tiempos = [1.0, 3.0, 5.5, 9.0]

	var vp := SubViewport.new()
	vp.size = TAM
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.handle_input_locally = false
	add_child(vp)
	vp.add_child(RECTORIA.instantiate())

	var ultimo := 0.0
	for t in tiempos:
		await get_tree().create_timer(maxf(0.05, float(t) - ultimo)).timeout
		ultimo = float(t)
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		var ruta := "%s_%.1f.png" % [prefijo, float(t)]
		print("[rectoria] %s (%s)" % [ruta, "ok" if img.save_png(ruta) == OK else "error"])
	get_tree().quit()
