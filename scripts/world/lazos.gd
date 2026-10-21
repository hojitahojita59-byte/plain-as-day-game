extends Node3D
## Lazos negros de luto en las puertas de las casas con muertos (dias.json).

const DIAS := preload("res://scripts/dias.gd")
const LATERALES := preload("res://scripts/world/estelas_calle.gd")
const NEGRO := Color(0.03, 0.03, 0.035)


func _ready() -> void:
	# Las puertas se levantan en el mismo _ready del constructor.
	await get_tree().process_frame
	poner()


var _lazos: Array[Node3D] = []


func poner() -> void:
	for l in _lazos:
		if is_instance_valid(l):
			l.queue_free()
	_lazos.clear()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = NEGRO
	mat.roughness = 0.6
	var hay := DIAS.lazos()
	for p in get_tree().get_nodes_in_group(&"puertas"):
		var puerta := p as Node3D
		if puerta != null and String(puerta.get_meta(&"numero", "")) in hay:
			var lazo := _lazo(puerta, mat)
			var xf := lazo.transform
			# Colgado de la hoja: gira con ella al abrir la puerta.
			var hoja := puerta.get_node_or_null(^"Hoja")
			var pivote: Node3D = hoja.get(&"_pivote") if hoja != null else null
			if pivote != null:
				pivote.add_child(lazo)
				lazo.global_transform = xf
			else:
				add_child(lazo)
				lazo.global_transform = xf
			_lazos.append(lazo)


func _lazo(puerta: Node3D, mat: Material) -> Node3D:
	var p := puerta.global_position
	var fuera := Vector3(0, 0, 1)
	var eje := LATERALES._lateral(p)
	if not is_nan(eje):
		fuera = Vector3(signf(eje - p.x), 0, 0)
	var lazo := Node3D.new()
	lazo.name = "Lazo" + String(puerta.get_meta(&"numero", ""))
	lazo.set_meta(&"numero", puerta.get_meta(&"numero", ""))
	lazo.position = p + fuera * 0.16 + Vector3.UP * 0.05
	lazo.basis = Basis.looking_at(-fuera, Vector3.UP).scaled(Vector3.ONE * 1.6)
	# Nudo, dos lazadas y dos caídas.
	_pieza(lazo, mat, Vector3.ZERO, Vector3(0.1, 0.1, 0.05), 0.0)
	_pieza(lazo, mat, Vector3(-0.12, 0.02, 0), Vector3(0.16, 0.1, 0.03), 0.25)
	_pieza(lazo, mat, Vector3(0.12, 0.02, 0), Vector3(0.16, 0.1, 0.03), -0.25)
	_pieza(lazo, mat, Vector3(-0.05, -0.24, 0), Vector3(0.07, 0.42, 0.02), -0.18)
	_pieza(lazo, mat, Vector3(0.05, -0.24, 0), Vector3(0.07, 0.42, 0.02), 0.18)
	return lazo


func _pieza(padre: Node3D, mat: Material, pos: Vector3, tam: Vector3, giro: float) -> void:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = tam
	m.mesh = b
	m.material_override = mat
	m.position = pos
	m.rotation.z = giro
	padre.add_child(m)


func numeros() -> PackedStringArray:
	var out: PackedStringArray = []
	for c in _lazos:
		out.append(String(c.get_meta(&"numero", "")))
	return out
