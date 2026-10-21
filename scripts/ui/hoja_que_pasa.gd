extends Control
## Esquina doblada al pasar el ratón y hoja que se voltea al cambiar de página.

signal a_medias

const PAPEL := Color(0.93, 0.89, 0.80)
const REVES := Color(0.86, 0.81, 0.70)
const BORDE := Color(0.55, 0.47, 0.36, 0.6)
const DOBLEZ_MAX := 46.0
const DURACION := 0.55
const SONIDOS := ["res://audio/sfx/ui/hoja_1.ogg", "res://audio/sfx/ui/hoja_2.ogg",
	"res://audio/sfx/ui/hoja_3.ogg"]

## -1 izq., 1 der.
var _lado: int = 1
var _doblez: float = 0.0
var _giro: float = -1.0
var _tw: Tween
var _son: AudioStreamPlayer


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_son = AudioStreamPlayer.new()
	_son.bus = &"Interfaz"
	add_child(_son)


func doblar(lado: int, si: bool) -> void:
	if _giro >= 0.0:
		return
	_lado = lado
	if _tw != null:
		_tw.kill()
	_tw = create_tween()
	_tw.tween_method(_poner_doblez, _doblez, 1.0 if si else 0.0, 0.18)


## Voltea; emite a_medias cuando la hoja tapa el lomo.
func pasar(lado: int) -> void:
	_lado = lado
	if _tw != null:
		_tw.kill()
	_son.stream = load(SONIDOS[randi() % SONIDOS.size()]) as AudioStream
	_son.pitch_scale = randf_range(0.95, 1.05)
	_son.play()
	var dio_medias := false
	var t := 0.0
	while t < DURACION and is_inside_tree():
		t += minf(get_process_delta_time(), 0.05)
		_giro = clampf(t / DURACION, 0.0, 1.0)
		_doblez = maxf(0.0, _doblez - 0.2)
		if not dio_medias and _giro >= 0.5:
			dio_medias = true
			a_medias.emit()
		queue_redraw()
		await get_tree().process_frame
	_giro = -1.0
	_doblez = 0.0
	queue_redraw()


func _poner_doblez(v: float) -> void:
	_doblez = v
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	if _doblez > 0.001:
		_dibujar_doblez(r, DOBLEZ_MAX * _doblez)
	if _giro >= 0.0:
		_dibujar_giro(r)


## Triángulo de la esquina de abajo, con el revés del papel.
func _dibujar_doblez(r: Rect2, d: float) -> void:
	var esquina := Vector2(r.end.x if _lado > 0 else r.position.x, r.end.y)
	var hacia := -1.0 if _lado > 0 else 1.0
	var a := esquina + Vector2(hacia * d, 0)
	var b := esquina + Vector2(0, -d)
	# Hueco que deja la esquina (fondo oscuro).
	draw_colored_polygon(PackedVector2Array([a, esquina, b]), Color(0, 0, 0, 0.55))
	var pico := esquina + Vector2(hacia * d, -d)
	draw_colored_polygon(PackedVector2Array([a, pico, b]), REVES)
	draw_polyline(PackedVector2Array([a, pico, b, a]), BORDE, 1.5, true)


## La hoja gira sobre el lomo: ancho = mitad * cos(ángulo).
func _dibujar_giro(r: Rect2) -> void:
	var lomo := r.position.x + r.size.x * 0.5
	var mitad := r.size.x * 0.5
	var ang := _giro * PI
	var ancho := mitad * cos(ang)
	if absf(ancho) < 2.0:
		return
	# Desde la derecha va a la izquierda; desde la izquierda, al revés.
	var x := lomo + ancho * float(_lado)
	var alza := sin(ang) * 26.0
	var arriba := r.position.y
	var abajo := r.end.y
	var borde_lomo := [Vector2(lomo, arriba), Vector2(lomo, abajo)]
	var borde_libre := [Vector2(x, abajo + alza * 0.4), Vector2(x, arriba - alza)]
	var poli := PackedVector2Array(borde_lomo + borde_libre)
	var cara := PAPEL if _giro < 0.5 else REVES
	cara = cara.darkened(0.18 * sin(ang))
	draw_colored_polygon(poli, cara)
	draw_polyline(PackedVector2Array(borde_lomo + borde_libre + [borde_lomo[0]]), BORDE, 1.5, true)
	# Sombra en la página de debajo.
	var s := minf(absf(ancho), 60.0)
	var hacia := float(_lado) if _giro < 0.5 else -float(_lado)
	var sombra := PackedVector2Array([Vector2(x, arriba), Vector2(x + hacia * s * 0.5, arriba),
		Vector2(x + hacia * s * 0.5, abajo), Vector2(x, abajo)])
	draw_colored_polygon(sombra, Color(0, 0, 0, 0.12 * sin(ang)))
