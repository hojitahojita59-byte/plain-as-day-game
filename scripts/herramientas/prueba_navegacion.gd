extends Node
## ¿Se puede andar hasta ahí? Pregunta a la navmesh desde el inicio de Whitehead.

const CALLE := preload("res://scenes/world/calle.tscn")

const SITIOS := {
	"la esquina de Marshall": Vector3(-9.2, 0.9, -1.4),
	"cruzar la calle (norte)": Vector3(2.0, 0.9, -3.5),
	"cruzar la calle (sur)": Vector3(2.0, 0.9, 4.5),
	"delante del 38": Vector3(-7.5, 0.9, -2.8),
	"delante del 40": Vector3(12.5, 0.9, -2.8),
	"el extremo oeste": Vector3(-18.0, 0.9, 0.0),
}


func _ready() -> void:
	var calle := CALLE.instantiate()
	add_child(calle)
	# La malla se hornea en nav_region.gd: dejar pasar fotogramas.
	for i in 20:
		await get_tree().process_frame

	var jugador := calle.get_node_or_null(^"Whitehead") as Node3D
	var desde: Vector3 = jugador.global_position
	var mapa: RID = calle.get_world_3d().navigation_map
	print("[nav] arranca en %.1f, %.1f" % [desde.x, desde.z])

	for nombre in SITIOS:
		var hasta: Vector3 = SITIOS[nombre]
		var ruta := NavigationServer3D.map_get_path(mapa, desde, hasta, true)
		var fin := ruta[ruta.size() - 1] if ruta.size() > 0 else desde
		var lejos := Vector2(fin.x - hasta.x, fin.z - hasta.z).length()
		var veredicto := "SI" if lejos < 1.2 else "NO"
		print("[nav] %-26s %s  (%d tramos, se queda a %.1f m)" % [
			nombre, veredicto, ruta.size(), lejos])
	await _probar_camara(calle, jugador)
	get_tree().quit()


## ¿Hasta dónde acompaña la cámara? Lleva al personaje a un extremo.
func _probar_camara(calle: Node, jugador: Node3D) -> void:
	var cam := calle.get_node_or_null(^"Camera3D") as Camera3D
	if cam == null:
		print("[cam] no encuentro la camara")
		return
	for x in [-11.0, -9.2, 0.0, 7.5, 12.5, 16.0]:
		jugador.global_position.x = x
		for i in 40:
			await get_tree().process_frame
		var desfase: float = absf(cam.global_position.x - x)
		print("[cam] jugador en %6.1f  ->  camara en %6.1f  (%s)" % [
			x, cam.global_position.x, "le sigue" if desfase < 0.6 else "SE QUEDA A %.1f m" % desfase])
