extends Control
## Barra de miasma: cuánto cree Whitehead en el aire; nunca llega a 0.

## Verde de las láminas de la época.
@export var lleno: Color = Color(0.24, 0.44, 0.16)
## Canal vacío, color papel.
@export var vacio: Color = Color(0.82, 0.79, 0.71, 0.55)
@export var borde: Color = Color(0.16, 0.13, 0.10, 0.65)

var _valor: float = 1.0


func _ready() -> void:
	custom_minimum_size = Vector2(180, 20)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Valor 0-1, con animación lenta.
func poner(v: float) -> void:
	var t := create_tween()
	t.tween_method(_set_valor, _valor, clampf(v, 0.0, 1.0), 0.9) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _set_valor(v: float) -> void:
	_valor = v
	queue_redraw()


func _draw() -> void:
	var s := size
	var r := s.y * 0.5
	var canal := Rect2(Vector2.ZERO, s)

	draw_rect(canal, vacio, true)
	_capsula(canal, vacio)

	var ancho := maxf(s.y, s.x * _valor)
	_capsula(Rect2(Vector2.ZERO, Vector2(ancho, s.y)), lleno)

	# Filo alrededor del canal.
	draw_arc(Vector2(r, r), r, PI * 0.5, PI * 1.5, 12, borde, 1.5, true)
	draw_arc(Vector2(s.x - r, r), r, -PI * 0.5, PI * 0.5, 12, borde, 1.5, true)
	draw_line(Vector2(r, 0.5), Vector2(s.x - r, 0.5), borde, 1.5, true)
	draw_line(Vector2(r, s.y - 0.5), Vector2(s.x - r, s.y - 0.5), borde, 1.5, true)


## Cápsula: rectángulo y dos círculos.
func _capsula(r: Rect2, c: Color) -> void:
	var radio := r.size.y * 0.5
	if r.size.x <= r.size.y:
		draw_circle(r.position + Vector2(radio, radio), radio, c)
		return
	draw_rect(Rect2(r.position + Vector2(radio, 0.0),
		Vector2(r.size.x - r.size.y, r.size.y)), c, true)
	draw_circle(r.position + Vector2(radio, radio), radio, c)
	draw_circle(r.position + Vector2(r.size.x - radio, radio), radio, c)
