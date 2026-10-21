extends CanvasLayer
## La noche en la rectoría: fundido, el día siguiente y la campana por los muertos.

const DIAS := preload("res://scripts/dias.gd")
const CAMPANA := preload("res://scripts/campana.gd")
const SNOW := preload("res://scripts/world/llaman_a_la_puerta.gd")
const GARAMOND := preload("res://art/fonts/EB_Garamond/static/EBGaramond-Regular.ttf")
const GARAMOND_NOTA := preload("res://art/fonts/EB_Garamond/static/EBGaramond-Regular.ttf")

## Toques como mucho (los demás se dan por oídos).
const TOQUES_MAX := 6
## Espera a que Whitehead entre antes de hacerse de noche.
const ESPERA := 2.5

signal amanecido(dia: int)

var _negro: ColorRect
var _titulo: Label
var _manana: Label
var _saltar: bool = false


func _ready() -> void:
	layer = 25
	_negro = ColorRect.new()
	_negro.color = Color(0, 0, 0, 0)
	_negro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_negro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_negro)
	_titulo = _etiqueta(GARAMOND, 58, 0.40)
	_manana = _etiqueta(GARAMOND_NOTA, 28, 0.52)
	if DIAS.toca_dormir() and not SNOW.toca():
		await get_tree().create_timer(ESPERA).timeout
		await pasar_la_noche()


func _etiqueta(fuente: Font, tam: int, alto: float) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", fuente)
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", Color(0.90, 0.86, 0.76))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.anchor_left = 0.15
	l.anchor_right = 0.85
	l.anchor_top = alto
	l.anchor_bottom = alto
	l.modulate.a = 0.0
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func _input(event: InputEvent) -> void:
	if _negro.mouse_filter == Control.MOUSE_FILTER_STOP and (event is InputEventMouseButton \
			and (event as InputEventMouseButton).pressed or event.is_action_pressed("ui_accept")):
		_saltar = true
		get_viewport().set_input_as_handled()


func pasar_la_noche() -> void:
	_negro.mouse_filter = Control.MOUSE_FILTER_STOP
	var t := create_tween()
	t.tween_property(_negro, "color:a", 1.0, 1.4)
	await t.finished
	DIAS.dormir()
	SaveSystem.call(&"_pedir_guardado")
	var hoy := DIAS.hoy()
	_titulo.text = String(hoy.get("titulo", ""))
	_manana.text = String(hoy.get("manana", ""))
	_saltar = false
	var t2 := create_tween()
	t2.tween_property(_titulo, "modulate:a", 1.0, 1.2)
	await t2.finished
	var son := AudioStreamPlayer.new()
	son.stream = CAMPANA.sonido()
	son.volume_db = -6.0
	add_child(son)
	for i in mini(int(hoy.get("campana", 3)), TOQUES_MAX):
		if _saltar:
			break
		son.play()
		await get_tree().create_timer(1.25).timeout
	var t3 := create_tween()
	t3.tween_property(_manana, "modulate:a", 1.0, 1.0)
	await t3.finished
	var espera := 0.0
	while espera < 3.0 and not _saltar and is_inside_tree():
		await get_tree().process_frame
		espera += get_process_delta_time()
	var t4 := create_tween().set_parallel()
	t4.tween_property(_negro, "color:a", 0.0, 1.4)
	t4.tween_property(_titulo, "modulate:a", 0.0, 0.8)
	t4.tween_property(_manana, "modulate:a", 0.0, 0.8)
	await t4.finished
	_negro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	amanecido.emit(GameState.dia)


func activa() -> bool:
	return _negro.mouse_filter == Control.MOUSE_FILTER_STOP
