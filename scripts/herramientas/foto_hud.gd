extends Node
## Foto de la calle con el HUD encima (montada en el viewport raíz).
## Uso: foto_hud.tscn -- salida.png [seg]

const CALLE := preload("res://scenes/world/calle.tscn")


func _ready() -> void:
	var extra := OS.get_cmdline_user_args()
	var salida: String = extra[0] if extra.size() > 0 else "hud.png"
	var espera: float = float(extra[1]) if extra.size() > 1 else 2.0

	add_child(CALLE.instantiate())

	# Cuaderno con algo dentro para que la esquina tenga cifras.
	Casefile.note({"id": "prueba_a", "que": "A death at 40", "quien": "Sarah Lewis",
		"donde": "40 Broad Street", "muerte": true, "nombre": "Frances Lewis",
		"calle": "40 Broad Street", "dia": "2 September"})
	Casefile.note({"id": "prueba_b", "que": "Three from one house", "quien": "A laundress",
		"donde": "12 Cambridge Street", "muerte": true, "nombre": "Mary Doyle",
		"calle": "12 Cambridge Street", "dia": "1 September"})
	Casefile.note({"id": "prueba_c", "que": "Nobody off sick at the brewery",
		"quien": "A brewery man", "donde": "16 Cambridge Street"})
	HUD.refresh_evidence()

	await get_tree().create_timer(espera).timeout
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	print("[foto_hud] %s (%s)" % [salida, "ok" if img.save_png(salida) == OK else "error"])
	get_tree().quit()
