extends Node
## Clic en una tarjeta (no en "Show this") al enseñar a Snow.

func _ready() -> void:
	SaveSystem.set(&"_pendiente", true)
	Cuaderno.reset()
	Cuaderno.abrir("f_cerveceria")
	var hs: Dictionary = Cuaderno.ficha("f_cerveceria")["huecos"]
	for h in hs:
		Cuaderno.aprender(String(hs[h]), "x")
		Cuaderno.poner("f_cerveceria", h, hs[h])
	Cuaderno.comprobar("f_cerveceria")
	HUD.show()
	var exp: Control = HUD.get(&"_expediente")
	var elegida := [""]
	exp.presentada.connect(func(id): elegida[0] = id)
	exp.presentar()
	await get_tree().create_timer(0.6).timeout
	var t: Control = null
	for n in exp.find_children("*", "PanelContainer", true, false):
		if (n as Control).mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND:
			t = n
	if t == null:
		print("[tarjeta] ! no hay tarjeta")
		get_tree().quit()
		return
	var c := t.get_global_rect().get_center()
	print("[tarjeta] rect ", t.get_global_rect(), " visible ", t.is_visible_in_tree(), " canvas ", t.get_viewport().get_visible_rect())
	for p in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = p
		e.position = c
		e.global_position = c
		get_viewport().push_input(e, true)
		await get_tree().process_frame
	var m := InputEventMouseMotion.new()
	m.position = c
	m.global_position = c
	get_viewport().push_input(m, true)
	await get_tree().process_frame
	var h := get_viewport().gui_get_hovered_control()
	print("[tarjeta] encima: %s %s filtro=%d" % [h.name if h else "-", h.get_class() if h else "", h.mouse_filter if h else -1])
	var q: Node = h
	while q != null and q != t:
		q = q.get_parent()
	print("[tarjeta] dentro de la tarjeta: ", q == t)
	await get_tree().create_timer(0.3).timeout
	print("[tarjeta] elegida: '%s'" % elegida[0])
	get_tree().quit()
