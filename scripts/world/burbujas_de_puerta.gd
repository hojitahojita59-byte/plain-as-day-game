extends CanvasLayer
## Burbuja con nº sobre puertas laterales cercanas; clicarla = clicar la puerta.

const GARAMOND_SEMI := preload("res://art/fonts/EB_Garamond/static/EBGaramond-SemiBold.ttf")

## Metros para aparecer / desaparecer (margen para que no parpadee).
const CERCA := 6.5
const LEJOS := 7.5

var _burbujas: Dictionary = {}   # puerta -> Burbuja


func _ready() -> void:
	layer = 12


func _process(delta: float) -> void:
	var jugador := get_tree().get_first_node_in_group(&"jugador") as Node3D
	var cam := get_viewport().get_camera_3d()
	if jugador == null or cam == null:
		return
	var vista := get_tree().get_first_node_in_group(&"vista_pajaro")
	var callado := DoorMode.activo or DoorMode.volviendo or DialogueRunner.active \
		or get_tree().paused or (vista != null and bool(vista.get(&"activa")))
	for n in get_tree().get_nodes_in_group(&"puertas"):
		var puerta := n as Node3D
		if puerta == null or not puerta.has_meta(&"lateral"):
			continue
		var b: Burbuja = _burbujas.get(puerta)
		if b == null:
			b = Burbuja.new()
			b.numero = String(puerta.get_meta(&"numero", ""))
			b.fuente = GARAMOND_SEMI
			b.pulsada.connect(_llamar.bind(puerta))
			add_child(b)
			_burbujas[puerta] = b
		var d := Vector2(puerta.global_position.x - jugador.global_position.x,
			puerta.global_position.z - jugador.global_position.z).length()
		var quiere: bool = not callado and (d < CERCA or (b.mostrada and d < LEJOS)) \
			and not cam.is_position_behind(puerta.global_position)
		b.mostrada = quiere
		b.modulate.a = move_toward(b.modulate.a, 1.0 if quiere else 0.0, delta * 5.0)
		b.visible = b.modulate.a > 0.01
		b.mouse_filter = Control.MOUSE_FILTER_STOP if quiere else Control.MOUSE_FILTER_IGNORE
		if b.visible:
			# La punta de la colita, en la puerta; la burbuja, por encima.
			b.punta = cam.unproject_position(puerta.global_position + Vector3.UP * 0.4)
			b.position = b.punta - Vector2(b.size.x * 0.5, b.size.y + 34.0)


## Clicar la burbuja es clicar la puerta.
func _llamar(puerta: Node3D) -> void:
	var jugador := get_tree().get_first_node_in_group(&"jugador")
	if jugador != null and jugador.has_method(&"ir_a"):
		jugador.call(&"ir_a", puerta)


## Una burbuja de papel con un número y una colita hacia abajo.
class Burbuja extends Control:
	signal pulsada

	const PAPEL := Color(0.94, 0.90, 0.80)
	const PAPEL_ENCIMA := Color(0.99, 0.96, 0.88)
	const BORDE := Color(0.28, 0.21, 0.15)
	const TINTA := Color(0.16, 0.12, 0.09)

	var numero: String = ""
	var fuente: Font
	var punta: Vector2 = Vector2.ZERO
	var mostrada: bool = false
	var _encima: bool = false

	func _ready() -> void:
		size = Vector2(76, 58)
		modulate.a = 0.0
		visible = false
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		mouse_entered.connect(func():
			_encima = true
			queue_redraw())
		mouse_exited.connect(func():
			_encima = false
			queue_redraw())

	func _process(_delta: float) -> void:
		if visible:
			queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
				and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			accept_event()
			pulsada.emit()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var fondo := PAPEL_ENCIMA if _encima else PAPEL
		# La colita: de la base de la burbuja a la puerta.
		var base := Vector2(size.x * 0.5, size.y)
		var hacia := punta - global_position
		var cola := PackedVector2Array([base + Vector2(-11, -2), base + Vector2(11, -2), hacia])
		draw_colored_polygon(cola, fondo)
		draw_polyline(PackedVector2Array([base + Vector2(-11, 0), hacia, base + Vector2(11, 0)]), BORDE, 2.0, true)
		var sb := StyleBoxFlat.new()
		sb.bg_color = fondo
		sb.border_color = BORDE
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(14)
		sb.shadow_color = Color(0, 0, 0, 0.35)
		sb.shadow_size = 5
		draw_style_box(sb, r)
		if fuente != null:
			var tam := 34
			var ancho := fuente.get_string_size(numero, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x
			draw_string(fuente, Vector2((size.x - ancho) * 0.5, size.y * 0.5 + tam * 0.34),
				numero, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, TINTA)
