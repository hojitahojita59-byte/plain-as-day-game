extends Control
## Botón de salida del expediente: un libro que se cierra al pasar el ratón.

signal pulsado

@export var cuero: Color = Color(0.30, 0.20, 0.14)
@export var papel: Color = Color(0.90, 0.87, 0.79)
@export var papel_sombra: Color = Color(0.74, 0.70, 0.61)
@export var tinta: Color = Color(0.13, 0.10, 0.08)
@export var fuente: Font

## 0 = libro abierto de par en par. 1 = cerrado del todo.
var _cerrado: float = 0.0
var _encima: bool = false


func _ready() -> void:
	custom_minimum_size = Vector2(132, 104)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(func(): _encima = true)
	mouse_exited.connect(func(): _encima = false)


func _process(delta: float) -> void:
	var meta := 1.0 if _encima else 0.0
	if is_equal_approx(_cerrado, meta):
		return
	# Suavizado exponencial.
	_cerrado = lerpf(_cerrado, meta, 1.0 - exp(-13.0 * delta))
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton \
			and (event as InputEventMouseButton).pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		pulsado.emit()
		accept_event()


func _draw() -> void:
	var s := size
	var cx := s.x * 0.5
	var arriba := s.y * 0.16
	var abajo := s.y * 0.70
	var ancho := s.x * 0.38

	# La hoja izq. gira PI sobre el lomo; el seno levanta el borde libre.
	var a := _cerrado * PI
	var borde := cx - ancho * cos(a)
	var alza := ancho * 0.30 * sin(a)

	# Tapa: encoge hacia el lomo al cerrarse.
	var tapa_izq := cx - ancho * (1.0 - _cerrado) - 4.0
	draw_rect(Rect2(
		Vector2(tapa_izq, arriba - 4.0),
		Vector2(cx + ancho + 4.0 - tapa_izq, abajo - arriba + 8.0)), cuero)

	# Hoja derecha, quieta.
	var derecha := PackedVector2Array([
		Vector2(cx, arriba),
		Vector2(cx + ancho, arriba + 3.0),
		Vector2(cx + ancho, abajo - 3.0),
		Vector2(cx, abajo)])
	draw_colored_polygon(derecha, papel)

	draw_polyline(derecha + PackedVector2Array([derecha[0]]), tinta, 1.0, true)

	# Renglones antes de la hoja que gira, para que esta los tape.
	var visto := 1.0 - smoothstep(0.45, 0.95, _cerrado)
	if visto > 0.02:
		var c := Color(tinta.r, tinta.g, tinta.b, 0.30 * visto)
		for i in 3:
			var y := arriba + (abajo - arriba) * (0.30 + 0.17 * float(i))
			draw_line(Vector2(cx + 7.0, y), Vector2(cx + ancho - 7.0, y), c, 1.0)

	# Hoja que gira: se pinta la última para que lo tape todo.
	if absf(borde - cx) > 0.6:
		var abre := (borde < cx)
		var hoja := PackedVector2Array([
			Vector2(cx, arriba),
			Vector2(borde, arriba - alza + 3.0),
			Vector2(borde, abajo - alza - 3.0),
			Vector2(cx, abajo)])
		# Antes del lomo se ve papel; pasado el lomo, el dorso (cuero).
		var sombreado := sin(a)
		var cara := papel.lerp(papel_sombra, sombreado * 0.55)
		if not abre:
			cara = cuero.lerp(cuero.lightened(0.10), 1.0 - sombreado)
		draw_colored_polygon(hoja, cara)
		draw_polyline(hoja + PackedVector2Array([hoja[0]]), tinta, 1.0, true)
		# Renglones solo mientras se ve la cara escrita.
		if abre:
			var c2 := Color(tinta.r, tinta.g, tinta.b, 0.30 * (1.0 - sombreado))
			for i in 3:
				var y2 := arriba + (abajo - arriba) * (0.30 + 0.17 * float(i)) - alza
				draw_line(Vector2(borde + 7.0, y2), Vector2(cx - 7.0, y2), c2, 1.0)

	# El lomo, encima de las dos hojas.
	draw_rect(Rect2(Vector2(cx - 2.0, arriba - 4.0),
		Vector2(4.0, abajo - arriba + 8.0)), cuero)

	if fuente == null:
		return
	var texto := "Close"
	var tam := 19
	var ancho_texto := fuente.get_string_size(
		texto, HORIZONTAL_ALIGNMENT_LEFT, -1.0, tam).x
	var color := Color(0.90, 0.87, 0.80, 0.55 + 0.45 * _cerrado)
	draw_string(fuente, Vector2(cx - ancho_texto * 0.5, s.y - 6.0),
		texto, HORIZONTAL_ALIGNMENT_LEFT, -1.0, tam, color)
