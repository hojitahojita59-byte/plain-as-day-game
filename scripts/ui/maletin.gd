extends Control
## Icono de maletín dibujado a mano; se entreabre al pasar el ratón y el clic abre el expediente.

@export var cuero: Color = Color(0.29, 0.19, 0.13)
@export var herraje: Color = Color(0.62, 0.52, 0.34)
@export var papel: Color = Color(0.94, 0.91, 0.83)
@export var fuente: Font
@export var tamano_cifra: int = 40

## Clic: el HUD abre el expediente.
signal pulsado

var _cuenta: int = 0
## Papeles que asoman: fichas que ya se pueden rellenar.
var _papeles: int = 0
var _vaiven: float = 0.0
## 0 cerrada, 1 entreabierta (ratón encima).
var _abre: float = 0.0
## 0 en reposo, 1 recién guardado (engorda y brilla).
var _pulso: float = 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(108, 92)
	set_process(false)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	# Al pasar el ratón se entreabre: se puede abrir.
	mouse_entered.connect(func(): _abrir_tapa(1.0))
	mouse_exited.connect(func(): _abrir_tapa(0.0))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton \
			and (event as InputEventMouseButton).pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		pulsado.emit()
		accept_event()


func _abrir_tapa(hasta: float) -> void:
	var t := create_tween()
	t.tween_method(func(v: float):
		_abre = v
		queue_redraw(), _abre, hasta, 0.18).set_trans(Tween.TRANS_SINE)


func poner_papeles(n: int) -> void:
	n = clampi(n, 0, 4)
	if n == _papeles:
		return
	var mas := n > _papeles
	_papeles = n
	set_process(_papeles > 0)
	queue_redraw()
	if mas:
		destacar()


func _process(delta: float) -> void:
	_vaiven += delta
	queue_redraw()


func poner_cuenta(n: int) -> void:
	if n == _cuenta:
		return
	_cuenta = n
	queue_redraw()


## Animación al entrar una prueba (la llama el HUD).
func destacar() -> void:
	var t := create_tween()
	t.tween_method(_set_pulso, 0.0, 1.0, 0.18).set_trans(Tween.TRANS_BACK) \
		.set_ease(Tween.EASE_OUT)
	t.tween_interval(0.35)
	t.tween_method(_set_pulso, 1.0, 0.0, 0.5).set_trans(Tween.TRANS_SINE)


func _set_pulso(v: float) -> void:
	_pulso = v
	queue_redraw()


func _draw() -> void:
	var s := size
	var crece := 1.0 + _pulso * 0.12
	var c := s * 0.5

	# Cuerpo abajo, dejando sitio al asa.
	var ancho := s.x * 0.92 * crece
	var alto := s.y * 0.62 * crece
	var cuerpo := Rect2(c.x - ancho * 0.5, c.y - alto * 0.5 + s.y * 0.13, ancho, alto)

	# Papeles asomando por la tapa, detrás del cuero.
	for i in _papeles:
		var x := cuerpo.position.x + cuerpo.size.x * (0.5 - (0.17 * float(_papeles - 1) + 0.36) * 0.5 + 0.17 * float(i))
		var sube := 32.0 + 5.0 * sin(_vaiven * 3.0 + float(i) * 1.7)
		var hoja := Rect2(Vector2(x, cuerpo.position.y - sube), Vector2(cuerpo.size.x * 0.36, sube + 14.0))
		draw_set_transform(hoja.get_center(), (float(i) - float(_papeles - 1) * 0.5) * 0.18, Vector2.ONE)
		draw_rect(Rect2(-hoja.size * 0.5, hoja.size), papel, true)
		draw_rect(Rect2(-hoja.size * 0.5, hoja.size), cuero.darkened(0.3), false, 2.0)
		for k in 3:
			var y := -hoja.size.y * 0.5 + 7.0 + 6.0 * float(k)
			draw_line(Vector2(-hoja.size.x * 0.32, y), Vector2(hoja.size.x * 0.32, y), Color(0.35, 0.3, 0.25), 1.5)
		draw_set_transform(Vector2.ZERO)

	var y_junta := cuerpo.position.y + cuerpo.size.y * 0.3
	var bajo := Rect2(Vector2(cuerpo.position.x, y_junta), Vector2(cuerpo.size.x, cuerpo.end.y - y_junta))
	_rect_redondo(bajo, cuero, 7.0 * crece)
	# Abierta: se ve el hueco oscuro de dentro.
	if _abre > 0.01:
		draw_rect(Rect2(Vector2(cuerpo.position.x + 4.0, y_junta - 3.0), Vector2(cuerpo.size.x - 8.0, 6.0)), cuero.darkened(0.7), true)
	# Tapa con su asa: gira sobre la bisagra de atrás.
	draw_set_transform(Vector2(cuerpo.position.x + 2.0, y_junta), -_abre * 0.32, Vector2.ONE)
	var tapa := Rect2(Vector2(-2.0, cuerpo.position.y - y_junta), Vector2(cuerpo.size.x, y_junta - cuerpo.position.y + 2.0))
	var r := ancho * 0.17
	draw_arc(Vector2(cuerpo.size.x * 0.5 - 2.0, tapa.position.y), r, PI, TAU, 16, herraje.lerp(papel, _pulso * 0.5),
		5.0 * crece, true)
	_rect_redondo(tapa, cuero.lightened(0.05), 7.0 * crece)
	draw_line(Vector2(2.0, 0.0), Vector2(cuerpo.size.x - 6.0, 0.0), cuero.darkened(0.35), 2.0)
	var cierre := Vector2(7.0, 9.0) * crece
	for lado: float in [0.22, 0.78]:
		var x: float = cuerpo.size.x * lado - cierre.x * 0.5 - 2.0
		draw_rect(Rect2(Vector2(x, -cierre.y * 0.5), cierre), herraje.lerp(papel, _pulso * 0.6), true)
	draw_set_transform(Vector2.ZERO)


## Rect. redondeado: Godot no lo trae en el dibujo inmediato.
func _rect_redondo(r: Rect2, col: Color, radio: float) -> void:
	radio = minf(radio, minf(r.size.x, r.size.y) * 0.5)
	draw_rect(Rect2(r.position + Vector2(radio, 0), r.size - Vector2(radio * 2, 0)), col, true)
	draw_rect(Rect2(r.position + Vector2(0, radio), Vector2(radio, r.size.y - radio * 2)), col, true)
	draw_rect(Rect2(Vector2(r.end.x - radio, r.position.y + radio),
		Vector2(radio, r.size.y - radio * 2)), col, true)
	for e in [r.position + Vector2(radio, radio),
			Vector2(r.end.x - radio, r.position.y + radio),
			Vector2(r.position.x + radio, r.end.y - radio),
			r.end - Vector2(radio, radio)]:
		draw_circle(e, radio, col)
