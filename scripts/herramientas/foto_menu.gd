extends Node
## Foto del menú en un estado. estado: 0 INTRO 1 TITLE 2 MENU 3 EVENTS 4 SETTINGS
## Uso: foto_menu.tscn -- salida.png [estado] [ficha=1] [esquina=1]

const MENU := preload("res://scenes/ui/menu_space.tscn")
const TAM := Vector2i(1920, 1080)


func _ready() -> void:
	var extra := OS.get_cmdline_user_args()
	var salida: String = extra[0] if extra.size() > 0 else "menu.png"
	var estado: int = int(extra[1]) if extra.size() > 1 else 3
	var abrir_ficha: bool = extra.size() > 2 and extra[2] == "1"
	## 4º arg: despliega el menú de la esquina.
	var abrir_esquina: bool = extra.size() > 3 and extra[3] == "1"

	var vp := SubViewport.new()
	vp.size = TAM
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.handle_input_locally = false
	add_child(vp)

	var menu := MENU.instantiate()
	vp.add_child(menu)
	await get_tree().process_frame

	menu.call("_enter", estado)
	if abrir_ficha:
		menu.set("_selected", 0)
		menu.call("_fill_tab", 0)
		(menu.get("_tab") as Control).visible = true
		if abrir_esquina:
			(menu.get("_restart") as Control).visible = true

	# Margen para los tweens de cámara y panel.
	await get_tree().create_timer(1.6).timeout
	await RenderingServer.frame_post_draw

	var img := vp.get_texture().get_image()
	var err := img.save_png(salida)
	print("[foto_menu] %s (%s)" % [salida, "ok" if err == OK else str(err)])
	get_tree().quit()
