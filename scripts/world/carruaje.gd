extends Node3D
## Carro con caballo; el caballo mira a -x. andando = patas en marcha.

const CARRO := "res://art/models/Medieval/GLB format/cart-high.glb"
const PELO := Color(0.36, 0.24, 0.16)
const CRIN := Color(0.12, 0.09, 0.07)

## Asientos del pescante, en local.
const ASIENTO_1 := Vector3(-0.55, 1.15, -0.28)
const ASIENTO_2 := Vector3(-0.55, 1.15, 0.28)
## Del asiento al padre de una figura sentada (la cadera está a 0,8).
const SENTADO := Vector3(0.0, -0.78, 0.0)

var andando: bool = false
var _patas: Array[Node3D] = []
var _t: float = 0.0


func _ready() -> void:
	var modelo := load(CARRO) as PackedScene
	if modelo != null:
		var carro := modelo.instantiate() as Node3D
		# Las varas del modelo, hacia el caballo.
		carro.basis = Basis(Vector3.UP, deg_to_rad(90.0))
		add_child(carro)
	_caballo()


func _process(delta: float) -> void:
	if not andando:
		return
	_t += delta * 9.0
	for i in _patas.size():
		_patas[i].rotation.z = sin(_t + (PI if i % 2 == 0 else 0.0) + (0.0 if i < 2 else PI * 0.5)) * 0.45


func _caballo() -> void:
	var caballo := Node3D.new()
	caballo.name = "Caballo"
	caballo.position = Vector3(-2.6, 0.0, 0.0)
	add_child(caballo)
	_caja(caballo, Vector3(1.7, 0.7, 0.62), Vector3(0, 1.35, 0), PELO)
	# Cuello, cabeza y crin.
	var cuello := _caja(caballo, Vector3(0.42, 0.9, 0.36), Vector3(-0.95, 1.75, 0), PELO)
	cuello.rotation.z = 0.55
	_caja(caballo, Vector3(0.7, 0.32, 0.3), Vector3(-1.35, 2.05, 0), PELO)
	_caja(caballo, Vector3(0.5, 0.12, 0.1), Vector3(-0.9, 2.05, 0), CRIN).rotation.z = 0.55
	_caja(caballo, Vector3(0.12, 0.6, 0.12), Vector3(0.9, 1.25, 0), CRIN).rotation.z = -0.35
	# Patas: pivote arriba para que se balanceen.
	for p in [Vector3(-0.65, 1.0, -0.22), Vector3(-0.65, 1.0, 0.22), Vector3(0.65, 1.0, -0.22), Vector3(0.65, 1.0, 0.22)]:
		var cadera := Node3D.new()
		cadera.position = p
		caballo.add_child(cadera)
		_caja(cadera, Vector3(0.16, 1.0, 0.16), Vector3(0, -0.5, 0), PELO)
		_caja(cadera, Vector3(0.19, 0.1, 0.19), Vector3(0, -0.98, 0), CRIN)
		_patas.append(cadera)
	# Varas hasta el carro.
	for z in [-0.42, 0.42]:
		_caja(self, Vector3(2.2, 0.07, 0.07), Vector3(-1.75, 1.05, z), Color(0.3, 0.22, 0.15))


func _caja(padre: Node3D, tam: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = tam
	m.mesh = b
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	m.material_override = mat
	m.position = pos
	padre.add_child(m)
	return m
