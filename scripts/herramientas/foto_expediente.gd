extends Node
## Foto del expediente abierto. Retrata la ventana: el HUD no sale en SubViewport.
## Uso: foto_expediente.tscn -- salida.png [1 = libro cerrado]

const CARPETA := "res://data/dialogue"

## Prueba citable para que la columna derecha no salga vacía.
const PRUEBA := "broad_street_racimo"


func _ready() -> void:
	var extra := OS.get_cmdline_user_args()
	var salida: String = extra[0] if extra.size() > 0 else "expediente.png"

	HUD.show()
	_llenar()

	await get_tree().process_frame
	HUD.alternar_expediente()

	# Espera a que la interfaz se mida.
	await get_tree().create_timer(0.5).timeout

	# 2º arg "tinta": completa la ficha del 40 y dispara a media animación.
	if extra.size() > 1 and extra[1] == "tinta":
		var pag: Control = HUD.get(&"_expediente").get(&"_pag_cuaderno")
		pag.call(&"mostrar_ficha", "f_40")
		var h40: Dictionary = Cuaderno.ficha("f_40")["huecos"]
		var hs: Array = h40.keys()
		for i in hs.size() - 1:
			Cuaderno.poner("f_40", hs[i], h40[hs[i]])
		pag.call(&"_poner", "f_40", hs[-1], h40[hs[-1]])
		await get_tree().create_timer(0.38).timeout
	# 2º arg "2": segunda página de casas.
	if extra.size() > 1 and extra[1] == "2":
		var exp: Control = HUD.get(&"_expediente")
		exp.get(&"_pag_cuaderno").call(&"_pasar", 1)
		await get_tree().create_timer(0.3).timeout
	# 2º arg "1": finge hover en la esquina para ver el libro cerrado.
	if extra.size() > 1 and extra[1] == "1":
		var esquina: Node = _buscar(get_tree().root, "cierre_libro.gd")
		if esquina != null:
			esquina.set("_encima", true)
			await get_tree().create_timer(0.8).timeout

	await RenderingServer.frame_post_draw

	var img := get_viewport().get_texture().get_image()
	var err := img.save_png(salida)
	print("[foto_expediente] %s %dx%d (%s)" % [
		salida, img.get_width(), img.get_height(), "ok" if err == OK else str(err)])
	get_tree().quit()


## Primer nodo del árbol con ese guion (el HUD se monta por código).
func _buscar(nodo: Node, guion: String) -> Node:
	var s: Variant = nodo.get_script()
	if s is Script and String((s as Script).resource_path).ends_with(guion):
		return nodo
	for hijo in nodo.get_children():
		var e := _buscar(hijo, guion)
		if e != null:
			return e
	return null


func _llenar() -> void:
	var dir := DirAccess.open(CARPETA)
	if dir == null:
		push_warning("foto_expediente: no puedo abrir " + CARPETA)
		return
	for archivo in dir.get_files():
		if not archivo.ends_with(".json"):
			continue
		var datos: Variant = JSON.parse_string(
			FileAccess.get_file_as_string(CARPETA + "/" + archivo))
		if not (datos is Dictionary):
			continue
		for nodo in Dictionary(datos).get("nodos", {}).values():
			if nodo is Dictionary and (nodo as Dictionary).has("anota"):
				# Una línea puede apuntar una cosa o varias.
				var anota: Variant = (nodo as Dictionary)["anota"]
				for n in (anota if anota is Array else [anota]):
					Casefile.note(Dictionary(n))
	Casefile.collect(PRUEBA)
	# Cuaderno: una sellada, una con un error, otras a medias (más de una página).
	Cuaderno.reset()
	for f in ["f_38", "f_39", "f_cerveceria", "f_12c", "f_40"]:
		Cuaderno.abrir(f)
		for w in Dictionary(Cuaderno.ficha(f).get("huecos", {})).values():
			Cuaderno.aprender(String(w), "a neighbour")
	for w in ["thomas_carr", "miercoles", "agua_marshall"]:
		Cuaderno.aprender(w, "a neighbour")
	var h38: Dictionary = Cuaderno.ficha("f_38")["huecos"]
	for h in h38:
		Cuaderno.poner("f_38", h, h38[h])
	Cuaderno.comprobar("f_38")
	var h39: Dictionary = Cuaderno.ficha("f_39")["huecos"]
	for h in h39:
		Cuaderno.poner("f_39", h, "miercoles" if h == "c" else h39[h])
	Cuaderno.comprobar("f_39")
	Cuaderno.poner("f_cerveceria", "a", "setenta")
	print("[foto_expediente] %d apuntes, %d pruebas" % [
		Casefile.note_count(), Casefile.count()])
