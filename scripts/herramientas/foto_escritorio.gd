extends Node
## Foto de la rectoría con el registro lleno. `cercar` = 1 pulsa cercar antes.
## Uso: foto_escritorio.tscn -- salida.png [cercar]

const ESCRITORIO := preload("res://scenes/ui/escritorio.tscn")
const CARPETA := "res://data/dialogue"


func _ready() -> void:
	var extra := OS.get_cmdline_user_args()
	var salida: String = extra[0] if extra.size() > 0 else "escritorio.png"
	var cercar: bool = extra.size() > 1 and extra[1] == "1"

	_llenar()
	var pantalla := ESCRITORIO.instantiate()
	add_child(pantalla)
	await get_tree().create_timer(0.4).timeout

	if cercar:
		# Asienta las muertes pendientes; sin siete, cercar no da nada.
		for n in Casefile.notes():
			if bool(n.get("muerte", false)):
				Casefile.record(n)
		pantalla.call("_refrescar")
		pantalla.call("_al_cercar")
		await get_tree().create_timer(0.3).timeout

	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var err := img.save_png(salida)
	print("[foto_escritorio] %s (%s) registro=%d pruebas=%d" % [
		salida, "ok" if err == OK else str(err),
		Casefile.record_count(), Casefile.count()])
	get_tree().quit()


## Aplica todas las anotaciones de los diálogos.
func _llenar() -> void:
	var dir := DirAccess.open(CARPETA)
	if dir == null:
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
