extends Node
## Foto del menú en un estado. estado: 0 INTRO 1 TITLE 2 MENU 3 EVENTS 4 SETTINGS 5 CINE (globo y todas las marcas)
## Uso: foto_menu.tscn -- salida.png [estado] [ficha=1] [esquina=1] [recorte=x,y,an,al] [foco=n] [espera=s]
## ficha y esquina valen como 3º y 4º argumento sueltos ("1") o como clave=valor.

const MENU := preload("res://scenes/ui/menu_space.tscn")
const TAM := Vector2i(1920, 1080)


func _ready() -> void:
	var extra := OS.get_cmdline_user_args()
	var salida: String = extra[0] if extra.size() > 0 else "menu.png"
	var estado: int = int(extra[1]) if extra.size() > 1 else 3
	var op := {}
	for i in range(2, extra.size()):
		var a: String = extra[i]
		if "=" in a:
			op[a.get_slice("=", 0)] = a.get_slice("=", 1)
		elif i == 2:
			op["ficha"] = a
		elif i == 3:
			op["esquina"] = a
	var abrir_ficha: bool = op.get("ficha", "0") == "1"
	var abrir_esquina: bool = op.get("esquina", "0") == "1"
	print("[foto_menu] estado=%d opciones=%s" % [estado, str(op)])

	var vp := SubViewport.new()
	vp.size = TAM
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.handle_input_locally = false
	add_child(vp)

	var menu := MENU.instantiate()
	vp.add_child(menu)
	await get_tree().process_frame

	if estado == 5:
		menu.call("cine_preparar")
		menu.call("cine_mirar", 30.0, 20.0, 0.0)
		for i in int(menu.call("cine_num_pistas")):
			menu.call("cine_mostrar_pista", i)
		menu.call("cine_mostrar_soho")
	else:
		menu.call("_enter", estado)
	if abrir_ficha:
		menu.set("_selected", 0)
		menu.call("_fill_tab", 0)
		(menu.get("_tab") as Control).visible = true
		if abrir_esquina:
			(menu.get("_restart") as Control).visible = true
	if op.has("foco"):
		var botones: Array = menu.get("_buttons")
		await get_tree().create_timer(0.6).timeout
		(botones[int(op["foco"])] as Control).grab_focus()

	# Margen para los tweens de cámara y panel.
	await get_tree().create_timer(float(op.get("espera", "1.6"))).timeout
	await RenderingServer.frame_post_draw

	var img := vp.get_texture().get_image()
	if op.has("recorte"):
		var r: PackedStringArray = String(op["recorte"]).split(",")
		img = img.get_region(Rect2i(int(r[0]), int(r[1]), int(r[2]), int(r[3])))
	var err := img.save_png(salida)
	print("[foto_menu] %s (%s)" % [salida, "ok" if err == OK else str(err)])
	get_tree().quit()
