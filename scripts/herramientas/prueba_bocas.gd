extends Node
## Ninguna casa de la maqueta tapa una calle que se anda.

const MAQUETA := preload("res://scripts/world/maqueta.gd")
const PLANO := preload("res://scripts/ui/plano_parroquia.gd")

func _ready() -> void:
	var m := Node3D.new()
	m.set_script(MAQUETA)
	add_child(m)
	await get_tree().process_frame
	var mal := 0
	for c in PLANO.CALLES:
		if bool(c.get("contexto", false)):
			continue
		var calle: Rect2 = MAQUETA.rect_calle(c).grow(-0.004)
		for casa in m.get(&"_casas"):
			var r: Rect2 = casa["r"]
			if r.intersects(calle):
				mal += 1
				print("[bocas] ! %s tapada por casa en %s (m)" % [c["n"], str(PLANO.a_mundo(r.get_center()).round())])
	print("[bocas] %s" % ("NINGUNA CALLE TAPADA." if mal == 0 else "! %d CASAS EN MEDIO DE UNA CALLE." % mal))
	get_tree().quit()
