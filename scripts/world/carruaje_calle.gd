extends Node3D
## Domingo: el carro de los Eley en Broad Street. Su carretero lleva a Whitehead a Hampstead.

const CARRUAJE := preload("res://scripts/world/carruaje.gd")
const VESTUARIO := preload("res://scripts/world/vestuario.gd")
const FIGURA := "res://scenes/world/props/figura.tscn"
const INTERACTUABLE := "res://scripts/world/interactable.gd"
const CAMINO := "res://scenes/world/camino.tscn"
const DIALOGO := "ch1_s3_carretero"
const SITIO := Vector3(24.0, 0.0, 2.6)
const ROPA := {"abrigo": [0.30, 0.24, 0.17], "pantalon": [0.22, 0.2, 0.17], "gorra": true,
	"chistera": false, "alzacuellos": false, "mira_alrededor": false}
const WHITEHEAD := {"chistera": true, "alzacuellos": true, "mira_alrededor": false}

var _carro: Node3D
var _carretero: StaticBody3D


func _ready() -> void:
	if GameState.dia < 3 or GameState.has_flag("heard_about_hampstead"):
		queue_free()
		return
	_carro = Node3D.new()
	_carro.name = "Carro"
	_carro.set_script(CARRUAJE)
	add_child(_carro)
	_carro.position = SITIO
	_carretero = StaticBody3D.new()
	_carretero.name = "Carretero"
	_carretero.set_script(load(INTERACTUABLE))
	_carretero.set("dialogue_id", DIALOGO)
	_carretero.set("locked_dialogue_id", "ch1_s3_carretero_ocupado")
	_carretero.set("requires", PackedStringArray(["sabe_de_hampstead", "!heard_about_hampstead"]))
	_carretero.set("display_name", "The carter")
	_carretero.set("stop_distance", 1.6)
	add_child(_carretero)
	_carretero.position = SITIO + Vector3(0.6, 0.0, -1.6)
	var cs := CollisionShape3D.new()
	var capsula := CapsuleShape3D.new()
	capsula.radius = 0.34
	capsula.height = 1.75
	cs.shape = capsula
	cs.position = Vector3(0.0, 0.88, 0.0)
	_carretero.add_child(cs)
	_carretero.add_child(_figura(ROPA))
	var luz := OmniLight3D.new()
	luz.light_color = Color(1.0, 0.86, 0.68)
	luz.light_energy = 0.7
	luz.omni_range = 2.4
	_carretero.add_child(luz)
	luz.position = Vector3(0.0, 1.9, 0.9)
	DialogueRunner.dialogue_finished.connect(_al_terminar)


func _al_terminar(id: String) -> void:
	if id != DIALOGO or not GameState.has_flag("al_carro"):
		return
	GameState.set_flag("al_carro", false)
	_irse()


## Whitehead sube al pescante y el carro se va calle abajo; la cámara no se mueve.
func _irse() -> void:
	var jugador := get_tree().get_first_node_in_group(&"jugador") as Node3D
	if jugador != null:
		jugador.set(&"speed", 0.0)
	HUD.hide()
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		cam.set_physics_process(false)
	var wh := _figura(WHITEHEAD)
	add_child(wh)
	if jugador != null:
		wh.global_position = jugador.global_position * Vector3(1, 0, 1)
		jugador.visible = false
	var estribo := SITIO + Vector3(-0.55, 0.0, -1.0)
	var t := create_tween()
	t.tween_property(wh, "global_position", estribo, wh.global_position.distance_to(estribo) / 1.4)
	await t.finished
	wh.reparent(_carro)
	wh.rotation.y = -PI * 0.5
	var subir := create_tween()
	subir.tween_property(wh, "position", CARRUAJE.ASIENTO_2 + CARRUAJE.SENTADO, 0.7) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await subir.finished
	wh.get_child(0).set(&"sentado", true)
	_carretero.reparent(_carro)
	_carretero.position = CARRUAJE.ASIENTO_1 + CARRUAJE.SENTADO
	_carretero.rotation.y = -PI * 0.5
	# La figura del carretero va dentro de su padre, hijo del cuerpo.
	for padre in _carretero.get_children():
		if padre.get_child_count() > 0 and padre.get_child(0) is Node3D and padre.get_child(0).get(&"sentado") != null:
			padre.get_child(0).set(&"sentado", true)
	await get_tree().create_timer(0.6).timeout
	_carro.set(&"andando", true)
	var irse := create_tween()
	irse.tween_property(_carro, "position", SITIO + Vector3(-40.0, 0.0, 0.0), 8.0) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await get_tree().create_timer(3.6).timeout
	SceneRouter.change_scene(CAMINO, SceneRouter.Kind.SHORT_FADE)


## Dentro de un padre: la figura anda cuando se mueve el padre.
func _figura(ropa: Dictionary) -> Node3D:
	var fig := (load(FIGURA) as PackedScene).instantiate() as Node3D
	VESTUARIO.aplicar(fig, ropa)
	var padre := Node3D.new()
	padre.add_child(fig)
	return padre
