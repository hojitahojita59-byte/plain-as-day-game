extends Node3D
## Apertura del Acto I (una vez): campana, sacan un ataúd del 38, la mujer llora.
## Bandas negras y sin control hasta el primer pensamiento de Whitehead.

const CAMPANA := preload("res://scripts/campana.gd")
const VESTUARIO := preload("res://scripts/world/vestuario.gd")
const FIGURA := "res://scenes/world/props/figura.tscn"
const GARAMOND_SEMI := preload("res://art/fonts/EB_Garamond/static/EBGaramond-SemiBold.ttf")
## Cámara fija respecto a la puerta.
const PLANO_CAM := Vector3(2.5, 2.1, 7.0)

const VISTA := "apertura_vista"
const PUERTA := "38"
const PASO := 1.15
## Segundos de calle antes de la primera indicación.
const ANTES_DE_LA_GUIA := 3.5
const PORTEADOR := {"abrigo": [0.16, 0.15, 0.15], "pantalon": [0.18, 0.17, 0.16], "gorra": true,
	"chistera": false, "alzacuellos": false, "inclinacion": 0.1}

signal terminada

var _bandas: CanvasLayer
var _saltar: bool = false


func _ready() -> void:
	# Las pruebas cargan la calle de cero: solo la ven si la piden.
	var en_prueba := String(get_tree().current_scene.scene_file_path).contains("herramientas") \
		if get_tree().current_scene != null else false
	if GameState.has_flag(VISTA) or GameState.dia != 1 or Casefile.record_count() > 0 \
			or (en_prueba and not GameState.has_flag("probar_apertura")):
		queue_free()
		return
	await get_tree().process_frame
	# Que se vaya la cortina de carga.
	await _esperar(SceneRouter.FADE_SECONDS + 0.2)
	await correr()


func _input(event: InputEvent) -> void:
	if _bandas != null and (event.is_action_pressed("ui_accept") \
			or event is InputEventMouseButton and (event as InputEventMouseButton).pressed):
		_saltar = true
		get_viewport().set_input_as_handled()


func correr() -> void:
	var puerta := _puerta(PUERTA)
	var jugador := get_tree().get_first_node_in_group(&"jugador") as Node3D
	if puerta == null or jugador == null:
		GameState.set_flag(VISTA)
		queue_free()
		return
	# Quieto y fuera de cuadro; los clics los tapan las bandas.
	var velocidad: float = jugador.get(&"speed")
	jugador.set(&"speed", 0.0)
	jugador.visible = false
	_poner_bandas()
	HUD.hide()

	# Cámara fija delante del 38.
	var previa := get_viewport().get_camera_3d()
	var cam := Camera3D.new()
	add_child(cam)
	var puerta_pos := puerta.global_position * Vector3(1, 0, 1)
	cam.fov = 48.0
	cam.global_position = puerta_pos + PLANO_CAM
	cam.look_at(puerta_pos + Vector3(-2.6, 1.3, 2.0))
	cam.current = true

	var son := AudioStreamPlayer.new()
	son.stream = CAMPANA.sonido()
	son.volume_db = -4.0
	add_child(son)
	son.play()

	var frente := puerta_pos + Vector3(0, 0, 1.2)
	var mujer := _figura(Dictionary(_ropa_del_38()).merged({"inclinacion": 0.35, "brazo_izquierdo": -1.0, "brazo_derecho": -1.0,
		"codo_izquierdo": -2.2, "codo_derecho": -2.2}, true))
	mujer.position = frente + Vector3(0.0, 0, -0.9)
	var grupo := Node3D.new()
	add_child(grupo)
	grupo.position = frente + Vector3(0, 0, -0.4)
	var p1 := _figura(PORTEADOR, grupo)
	p1.position = Vector3(-1.1, 0, 0)
	var p2 := _figura(PORTEADOR, grupo)
	p2.position = Vector3(1.1, 0, 0)
	# El ataúd: caja de pino con tapa.
	var pino := StandardMaterial3D.new()
	pino.albedo_color = Color(0.30, 0.21, 0.14)
	for pieza in [[Vector3(1.9, 0.36, 0.52), 0.98], [Vector3(1.8, 0.07, 0.44), 1.19]]:
		var m := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = pieza[0]
		m.mesh = b
		m.material_override = pino
		m.position = Vector3(0, float(pieza[1]), 0)
		grupo.add_child(m)

	await _esperar(1.2)
	# Sale a la calle y se va calle abajo; la cámara no se mueve.
	var t := grupo.create_tween()
	t.tween_property(grupo, "position", grupo.position + Vector3(0, 0, 2.6), 2.2)
	t.tween_property(grupo, "position", grupo.position + Vector3(-60.0, 0, 2.6), 60.0 / PASO)
	_sollozos(mujer)
	await _esperar(8.0)
	HUD.pensar("Number 38. Another one in the night.")
	await _esperar(3.0)
	_quitar_bandas()
	if is_instance_valid(previa):
		previa.current = true
	cam.queue_free()
	jugador.visible = true
	jugador.set(&"speed", velocidad)
	GameState.set_flag(VISTA)
	terminada.emit()
	# Un rato en la calle antes de la primera indicación.
	var esquina: Variant = HUD.get(&"_esquina")
	if esquina is CanvasItem:
		(esquina as CanvasItem).visible = false
	HUD.show()
	await get_tree().create_timer(ANTES_DE_LA_GUIA).timeout
	if esquina is CanvasItem and is_instance_valid(esquina):
		(esquina as CanvasItem).visible = true
	await get_tree().create_timer(0.5).timeout
	if is_instance_valid(mujer):
		mujer.queue_free()
	await t.finished
	queue_free()


## Letras de cómic pequeñas sobre la mujer mientras dure la escena.
func _sollozos(quien: Node3D) -> void:
	var i := 0
	while _bandas != null and is_instance_valid(quien):
		var l := Label3D.new()
		l.text = "sob" if i % 3 != 2 else "sob..."
		l.font = GARAMOND_SEMI
		l.font_size = 60
		l.pixel_size = 0.0045
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.outline_size = 10
		l.outline_modulate = Color(0.05, 0.05, 0.05)
		l.rotation.z = deg_to_rad(randf_range(-14.0, 14.0))
		var x := -0.55 if i % 2 == 0 else 0.55
		l.position = Vector3(x, 1.8, 0.2)
		quien.add_child(l)
		var tw := l.create_tween()
		tw.set_parallel(true)
		tw.tween_property(l, "position:y", 2.25, 1.3)
		tw.tween_property(l, "modulate:a", 0.0, 1.3).set_delay(0.5)
		tw.chain().tween_callback(l.queue_free)
		i += 1
		await _esperar(0.65 if i % 3 != 0 else 1.1)


func _esperar(s: float) -> void:
	var c := 0.0
	while c < s and not _saltar and is_inside_tree():
		await get_tree().process_frame
		c += minf(get_process_delta_time(), 0.1)


func _puerta(numero: String) -> Node3D:
	for p in get_tree().get_nodes_in_group(&"puertas"):
		if String((p as Node).get_meta(&"numero", "")) == numero:
			return p as Node3D
	return null


func _ropa_del_38() -> Dictionary:
	for p in Array(Barrio.datos(Barrio.actual).get("puertas", [])):
		if String(p.get("numero", "")) == PUERTA:
			return Dictionary(p.get("ropa", {}))
	return {}


func _figura(ropa: Dictionary, padre: Node3D = self) -> Node3D:
	var raiz := Node3D.new()
	padre.add_child(raiz)
	var escena := load(FIGURA) as PackedScene
	if escena != null:
		var fig := escena.instantiate() as Node3D
		var r := {"alzacuellos": false, "mira_alrededor": false}
		r.merge(ropa, true)
		VESTUARIO.aplicar(fig, r)
		raiz.add_child(fig)
	return raiz


func _poner_bandas() -> void:
	_bandas = CanvasLayer.new()
	_bandas.layer = 24
	add_child(_bandas)
	var tapa := ColorRect.new()
	tapa.color = Color(0, 0, 0, 0)
	tapa.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tapa.mouse_filter = Control.MOUSE_FILTER_STOP
	_bandas.add_child(tapa)
	for arriba in [true, false]:
		var banda := ColorRect.new()
		banda.color = Color.BLACK
		banda.anchor_right = 1.0
		banda.anchor_top = 0.0 if arriba else 1.0
		banda.anchor_bottom = 0.0 if arriba else 1.0
		banda.offset_top = 0.0 if arriba else -90.0
		banda.offset_bottom = 90.0 if arriba else 0.0
		banda.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_bandas.add_child(banda)


func _quitar_bandas() -> void:
	if _bandas != null:
		_bandas.queue_free()
		_bandas = null


func activa() -> bool:
	return _bandas != null
