extends Node3D
## El carro de los muertos: llega por el este cuando hay lista, el sacristán la da,
## se abre la vista de pájaro y el carro se va hacia el oeste.

const ASIENTOS := preload("res://scripts/asientos.gd")
const VESTUARIO := preload("res://scripts/world/vestuario.gd")
const CARRO := "res://art/models/Medieval/GLB format/cart.glb"
const FIGURA := "res://scenes/world/props/figura.tscn"
const INTERACTUABLE := "res://scripts/world/interactable.gd"

const ENTRA := Vector3(62.0, 0.0, 1.2)
const PARA := Vector3(12.0, 0.0, 1.2)
const SALE := Vector3(-64.0, 0.0, 1.2)
## m/s del carro.
const PASO := 3.2
const ROPA := {"abrigo": [0.12, 0.12, 0.13], "pantalon": [0.13, 0.13, 0.14],
	"sombrero": [0.07, 0.07, 0.08], "cuello": [0.7, 0.68, 0.62], "chistera": true,
	"estatura": 1.0, "inclinacion": 0.12, "alzacuellos": false}

var _lista: int = 0
var _moviendo: bool = false
var _sacristan: StaticBody3D


func _ready() -> void:
	DialogueRunner.dialogue_finished.connect(_al_terminar)
	visible = false
	position = ENTRA


func _process(_delta: float) -> void:
	if _lista == 0 and not _moviendo:
		var n := ASIENTOS.lista_pendiente()
		if n > 0:
			_llegar(n)


func _construir(n: int) -> void:
	for c in get_children():
		c.queue_free()
	var modelo := load(CARRO) as PackedScene
	if modelo != null:
		var carro := modelo.instantiate() as Node3D
		carro.basis = Basis(Vector3.UP, deg_to_rad(-90.0))
		add_child(carro)
	# Dos ataúdes de pino sobre el carro.
	var pino := StandardMaterial3D.new()
	pino.albedo_color = Color(0.30, 0.21, 0.14)
	for i in 2:
		var ataud := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(1.9, 0.38, 0.5)
		ataud.mesh = b
		ataud.material_override = pino
		ataud.position = Vector3(0.1, 1.05 + 0.4 * i, -0.28 + 0.56 * i - 0.28 * i)
		ataud.rotation.y = 0.06 * (1 - 2 * i)
		add_child(ataud)
	_sacristan = StaticBody3D.new()
	_sacristan.name = "Sacristan"
	_sacristan.set_script(load(INTERACTUABLE))
	_sacristan.set("dialogue_id", "ch1_s3_sacristan_%d" % n)
	_sacristan.set("display_name", "The sexton")
	_sacristan.set("stop_distance", 1.6)
	add_child(_sacristan)
	_sacristan.position = Vector3(0.0, 0.0, 1.5)
	var cs := CollisionShape3D.new()
	var capsula := CapsuleShape3D.new()
	capsula.radius = 0.34
	capsula.height = 1.75
	cs.shape = capsula
	cs.position = Vector3(0.0, 0.88, 0.0)
	_sacristan.add_child(cs)
	var escena := load(FIGURA) as PackedScene
	if escena != null:
		var fig := escena.instantiate() as Node3D
		VESTUARIO.aplicar(fig, ROPA)
		_sacristan.add_child(fig)
	var luz := OmniLight3D.new()
	luz.light_color = Color(1.0, 0.86, 0.68)
	luz.light_energy = 0.7
	luz.omni_range = 2.4
	_sacristan.add_child(luz)
	luz.position = Vector3(0.0, 1.9, 0.9)


func _llegar(n: int) -> void:
	_lista = n
	_construir(n)
	position = ENTRA
	visible = true
	_moviendo = true
	var t := create_tween()
	t.tween_property(self, "position", PARA, ENTRA.distance_to(PARA) / PASO) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await t.finished
	_moviendo = false


func _al_terminar(id: String) -> void:
	if _lista == 0 or id != "ch1_s3_sacristan_%d" % _lista:
		return
	if ASIENTOS.lista_pendiente() == _lista:
		return
	_lista = 0
	await get_tree().create_timer(0.6).timeout
	var vista := get_tree().get_first_node_in_group(&"vista_pajaro")
	if vista != null:
		vista.call(&"subir")
	_irse()


func _irse() -> void:
	_moviendo = true
	if _sacristan != null:
		_sacristan.queue_free()
		_sacristan = null
	var t := create_tween()
	t.tween_property(self, "position", SALE, PARA.distance_to(SALE) / PASO).set_trans(Tween.TRANS_SINE) \
		.set_ease(Tween.EASE_IN)
	await t.finished
	visible = false
	_moviendo = false
	for c in get_children():
		c.queue_free()


func esperando() -> int:
	return _lista if not _moviendo else 0
