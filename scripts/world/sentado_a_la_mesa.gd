extends Node3D
## Sentado a la mesa de la rectoría: cabeceo con el ratón, abrir el libro, salir.

const ESCRITORIO := "res://scenes/ui/escritorio.tscn"
const BOTON_WHITEHEAD := preload("res://scripts/ui/boton_whitehead.gd")

## Cabeceo máx. con el ratón, en rad (~6°).
const CABECEO := 0.105
## Suavizado del cabeceo.
const SUAVE := 4.5

@export var camara_path: NodePath = ^"../Camera3D"
@export var llegada_path: NodePath = ^"../Llegada"

var _camara: Camera3D
var _listo: bool = false
var _quieta: Basis
var _raton: Vector2 = Vector2.ZERO
var _salir: Button


func _ready() -> void:
	_camara = get_node_or_null(camara_path) as Camera3D
	var llegada := get_node_or_null(llegada_path)
	if _camara == null or llegada == null:
		push_error("SentadoALaMesa: falta la cámara o la llegada.")
		return
	set_process(false)
	llegada.connect(&"sentado", _al_sentarse)


func _al_sentarse() -> void:
	_listo = true
	# Orientación de reposo: se toma al sentarse, no en _ready.
	_quieta = _camara.global_basis
	set_process(true)
	_mostrar_la_salida()


## Otra escena toma la cámara (p.ej. Snow); no se vuelve.
func ceder() -> void:
	_listo = false
	set_process(false)
	_mostrar_la_salida()
	_bajar_la_hoja()


func _process(delta: float) -> void:
	if not _listo or _camara == null:
		return
	var v := get_viewport()
	var tam := v.get_visible_rect().size
	if tam.x <= 0.0 or tam.y <= 0.0:
		return
	# -1..1 desde el centro de la pantalla.
	var p := (v.get_mouse_position() / tam) * 2.0 - Vector2.ONE
	_raton = _raton.lerp(p.clamp(-Vector2.ONE, Vector2.ONE),
		1.0 - exp(-SUAVE * delta))
	# Sobre la orientación de reposo, sin acumular deriva.
	_camara.global_basis = _quieta \
		* Basis(Vector3.UP, -_raton.x * CABECEO) \
		* Basis(Vector3.RIGHT, -_raton.y * CABECEO * 0.6)


## Clic en la mesa (meta "accion" = "libro") abre el libro.
func _unhandled_input(event: InputEvent) -> void:
	if not _listo:
		return
	if event is not InputEventMouseButton:
		return
	var mb := event as InputEventMouseButton
	if not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return

	var desde := _camara.project_ray_origin(mb.position)
	var dir := _camara.project_ray_normal(mb.position)
	var q := PhysicsRayQueryParameters3D.create(desde, desde + dir * 12.0)
	var golpe := get_world_3d().direct_space_state.intersect_ray(q)
	if golpe.is_empty():
		return
	var cuerpo = golpe.get("collider")
	if cuerpo == null or not cuerpo.has_meta(&"accion"):
		return
	if String(cuerpo.get_meta(&"accion")) == "libro":
		get_viewport().set_input_as_handled()
		_levantar_la_hoja()


## Segundos que tarda la hoja en subir/bajar sobre el cuarto.
const HOJA_SUBE := 0.42

var _capa: CanvasLayer
var _hoja: Control


func _levantar_la_hoja() -> void:
	if _hoja != null and is_instance_valid(_hoja):
		return
	# El mapa 3D (el de la tecla M), no el plano de papel.
	var vista := get_tree().get_first_node_in_group(&"vista_pajaro")
	if vista != null:
		vista.call(&"subir")
		return
	var esc := load(ESCRITORIO) as PackedScene
	if esc == null:
		push_error("SentadoALaMesa: no encuentro el expediente.")
		return

	if _capa == null:
		_capa = CanvasLayer.new()
		# Bajo el HUD (capa 20).
		_capa.layer = 10
		add_child(_capa)

	var marco := Control.new()
	marco.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	marco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_capa.add_child(marco)
	_hoja = marco
	_mostrar_la_salida()
	# La esquina del HUD se aparta con la hoja arriba.
	HUD.esquina(false)

	var dentro := esc.instantiate() as Control
	marco.add_child(dentro)
	dentro.bajar.connect(_bajar_la_hoja)
	if dentro.has_signal(&"racimo_cercado"):
		dentro.racimo_cercado.connect(_mirar_el_plano)

	var alto := float(get_viewport().get_visible_rect().size.y)
	marco.position.y = alto
	var t := create_tween()
	t.tween_property(marco, "position:y", 0.0, HOJA_SUBE) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## Si se sale con la hoja arriba, devolver la esquina del HUD.
func _exit_tree() -> void:
	HUD.esquina(true)


func _bajar_la_hoja() -> void:
	if _hoja == null or not is_instance_valid(_hoja):
		return
	var marco := _hoja
	_hoja = null
	var alto := float(get_viewport().get_visible_rect().size.y)
	var t := create_tween()
	t.tween_property(marco, "position:y", alto, HOJA_SUBE) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	await t.finished
	marco.queue_free()
	_mostrar_la_salida()
	HUD.esquina(true)


## I.5: tras cercar el racimo, la cámara sube al plano de pared (segundos).
const SUBIDA := 3.2

func _mirar_el_plano(_cuantos: int) -> void:
	var plano: Node3D = null
	if get_tree().current_scene != null:
		plano = get_tree().current_scene.find_child("PlanoDePared", true, false) as Node3D
	_listo = false
	set_process(false)
	_mostrar_la_salida()
	await _bajar_la_hoja()
	if plano == null or _camara == null:
		_listo = true
		set_process(true)
		_mostrar_la_salida()
		return
	var desde := _camara.global_transform
	var hacia := Transform3D(Basis(), _camara.global_position + Vector3(0.0, 0.1, 0.0))
	hacia = hacia.looking_at(plano.global_position, Vector3.UP)
	var t := create_tween()
	t.tween_property(_camara, "global_transform", hacia, SUBIDA) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await t.finished
	HUD.pensar("Most of the deaths are around the corner of Broad Street.")
	await get_tree().create_timer(3.4).timeout
	HUD.pensar("That is where the drain is. The bad air must collect there.")
	await get_tree().create_timer(5.0).timeout
	var vuelta := create_tween()
	vuelta.tween_property(_camara, "global_transform", desde, 1.6) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await vuelta.finished
	_listo = true
	set_process(true)
	_mostrar_la_salida()


## Botón de salir: solo sentado y con la hoja bajada (la hoja tiene el suyo).
func _mostrar_la_salida() -> void:
	if _salir == null:
		if _capa == null:
			_capa = CanvasLayer.new()
			_capa.layer = 10
			add_child(_capa)
		_salir = BOTON_WHITEHEAD.crear("Out to the street")
		_salir.pressed.connect(func(): Barrio.volver())
		_capa.add_child(_salir)
		BOTON_WHITEHEAD.a_la_esquina(_salir)
	var hoja_arriba := _hoja != null and is_instance_valid(_hoja)
	_salir.visible = _listo and not hoja_arriba
