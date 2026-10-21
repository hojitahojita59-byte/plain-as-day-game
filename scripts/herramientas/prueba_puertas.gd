extends Node
## Vista de puerta: las flechas no salen de su fachada y la cadena crece
## según lo que sabe el jugador. Uso: --headless --quit-after 400

const CALLE := preload("res://scenes/world/calle.tscn")

## Mismas etapas que prueba_barrio.gd, en orden.
const MOMENTOS := [
	{"nombre": "al empezar", "banderas": []},
	{"nombre": "tras el hombre del bordillo", "banderas": ["knows_the_garment_womans_house"]},
	{"nombre": "tras la del 38", "banderas": ["spoke_to_the_garment_woman"]},
	{"nombre": "tras la carbonera", "banderas": ["spoke_to_the_coal_woman"]},
	{"nombre": "tras la mesa de la rectoría", "banderas": ["parish_book_read"]},
	{"nombre": "tras cercar el plano", "banderas": ["saw_the_cluster"]},
]


func _ready() -> void:
	add_child(CALLE.instantiate())
	await get_tree().create_timer(1.2).timeout

	var todas := get_tree().get_nodes_in_group(DoorMode.GRUPO)
	var malas := 0

	print("\n=== VISTA DE PUERTA ===")
	for m_raw in MOMENTOS:
		var m: Dictionary = m_raw
		for f in Array(m["banderas"]):
			GameState.set_flag(String(f))
		print("\n  %s" % m["nombre"])
		var vistas := {}
		for n in todas:
			var d := n as Node3D
			if not bool(d.call("hay_conversacion_de_verdad")):
				continue
			DoorMode._recoger_puertas(d)
			var cadena: Array[String] = []
			for p in DoorMode._puertas:
				cadena.append(_nombre(p))
			var clave := " > ".join(cadena)
			if vistas.has(clave):
				continue
			vistas[clave] = true
			print("      %s" % clave)
			malas += _mirar_camaras()
	print("")
	print("[puertas] %s" % ("NINGUNA CAMARA DENTRO DE UN MURO."
		if malas == 0 else "%d CAMARAS DENTRO DEL MURO." % malas))
	get_tree().quit()


## La cámara tiene que quedar por delante de la fachada, nunca detrás.
func _mirar_camaras() -> int:
	var malas := 0
	for i in DoorMode._puertas.size():
		var d := DoorMode._puertas[i]
		var normal := d.global_transform.basis.orthonormalized().z
		normal.y = 0.0
		var fuera := (DoorMode._sitio(i).origin - d.global_position) \
			.dot(normal.normalized())
		if fuera <= 1.0:
			malas += 1
			print("        <<< %s planta la camara a %.1f m: DENTRO DEL MURO"
				% [_nombre(d), fuera])
	return malas


func _nombre(d: Node) -> String:
	var t := String(d.get("display_name"))
	return t if not t.is_empty() else String(d.name)
