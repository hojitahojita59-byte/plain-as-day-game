extends CanvasLayer
## Flechas de la vista de puerta (ratón y teclado) y clic para llamar.

## Segundos con la puerta abierta tras hablar antes de que la cierren.
const ESPERA_ANTES_DE_CERRAR := 6.0

## Galones dibujados, no texturas (nítidos a cualquier tamaño).
const BEIGE := Color(0.91, 0.86, 0.74)
const BORDE := Color(0.24, 0.19, 0.14)

var _izq: Button
var _der: Button
var _salir: Button
var _aviso: Label


func _ready() -> void:
	layer = 15
	_construir()
	visible = false

	DoorMode.entrado.connect(_al_entrar)
	DoorMode.cambiada.connect(_al_cambiar)
	DoorMode.salido.connect(_al_salir)
	DialogueRunner.line_shown.connect(_al_hablar)
	DialogueRunner.dialogue_finished.connect(_al_callar)


func _construir() -> void:
	var raiz := Control.new()
	raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(raiz)

	_izq = _flecha(raiz, -1.0, Control.PRESET_CENTER_LEFT, 56.0, 168.0)
	_izq.pressed.connect(_ir.bind(-1))
	_der = _flecha(raiz, 1.0, Control.PRESET_CENTER_RIGHT, -168.0, -56.0)
	_der.pressed.connect(_ir.bind(1))

	_salir = Button.new()
	_salir.text = "Step back"
	raiz.add_child(_salir)
	_salir.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_salir.offset_left = -130.0
	_salir.offset_right = 130.0
	_salir.offset_top = -120.0
	_salir.offset_bottom = -50.0
	_salir.pressed.connect(DoorMode.salir)

	_aviso = Label.new()
	_aviso.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Se vacía mientras se llama.
	_aviso.text = "Knock"
	_aviso.add_theme_color_override("font_color", Color(0.95, 0.93, 0.86))
	_aviso.add_theme_color_override("font_outline_color", Color(0.08, 0.07, 0.06))
	_aviso.add_theme_constant_override("outline_size", 8)
	raiz.add_child(_aviso)
	_aviso.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_aviso.offset_left = -400.0
	_aviso.offset_right = 400.0
	_aviso.offset_top = -190.0
	_aviso.offset_bottom = -140.0


## Ambos márgenes explícitos: anclado a la derecha, los dos son negativos.
func _flecha(raiz: Control, sentido: float, sitio: int, izq: float, der: float) -> Button:
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.draw.connect(_pintar_galon.bind(b, sentido))
	raiz.add_child(b)
	b.set_anchors_and_offsets_preset(sitio)
	b.offset_left = izq
	b.offset_right = der
	b.offset_top = -56
	b.offset_bottom = 56
	return b


## Galón con borde oscuro debajo, legible sobre cualquier fondo.
func _pintar_galon(b: Button, sentido: float) -> void:
	var c := b.size * 0.5
	var w := b.size.x * 0.22
	var h := b.size.y * 0.26
	# Vértice hacia el lado al que se va.
	var puntos := PackedVector2Array([
		c + Vector2(-w * sentido, -h),
		c + Vector2(w * sentido, 0.0),
		c + Vector2(-w * sentido, h)])
	b.draw_polyline(puntos, BORDE, 13.0, true)
	b.draw_polyline(puntos, BEIGE, 7.0, true)


func _ir(paso: int) -> void:
	if DialogueRunner.active:
		return
	# Cerrar la casa que se deja atrás.
	var antes := DoorMode.puerta_actual()
	if antes != null:
		var hoja := antes.get_node_or_null(^"Hoja")
		if hoja != null and hoja.has_method("cerrar"):
			hoja.cerrar()
	await DoorMode.mover(paso)
	_refrescar()


func _al_entrar(_p) -> void:
	visible = true
	_refrescar()


func _al_cambiar(_p) -> void:
	_refrescar()


func _al_salir() -> void:
	visible = false


## Oculta durante el diálogo.
func _al_hablar(_n: Dictionary) -> void:
	if DoorMode.activo:
		visible = false


func _al_callar(_id: String) -> void:
	if DoorMode.activo:
		visible = true
		DoorMode.refrescar_fila()
		_refrescar()


func _refrescar() -> void:
	var hay_izq := DoorMode.hay_puerta(-1)
	var hay_der := DoorMode.hay_puerta(1)
	_izq.disabled = not hay_izq
	_der.disabled = not hay_der
	_izq.queue_redraw()
	_der.queue_redraw()
	_izq.modulate.a = 1.0 if hay_izq else 0.25
	_der.modulate.a = 1.0 if hay_der else 0.25

	var p := DoorMode.puerta_actual()
	_aviso.visible = p != null and not DialogueRunner.active
	if not _llamando:
		_aviso.text = "Go in" if not _interior_de(p).is_empty() else "Knock"


func _unhandled_input(event: InputEvent) -> void:
	if not DoorMode.activo or DialogueRunner.active:
		return

	if event.is_action_pressed("ui_left"):
		get_viewport().set_input_as_handled()
		_ir(-1)
	elif event.is_action_pressed("ui_right"):
		get_viewport().set_input_as_handled()
		_ir(1)
	elif event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		DoorMode.salir()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_llamar(mb.position)


## Cerrojo: ignora clics mientras se llama (si no, la secuencia se reinicia).
var _llamando: bool = false


func _llamar(pos: Vector2) -> void:
	if _llamando:
		return
	var puerta := DoorMode.puerta_actual()
	if puerta == null:
		return

	# Vale un clic en cualquier sitio; no hace falta acertar a la hoja.
	if pos.y < 0.0:
		return

	var id: String = puerta.active_dialogue_id()
	if id.is_empty():
		return
	get_viewport().set_input_as_handled()

	# Casa abierta (la cervecería): se entra, no se llama.
	var interior := _interior_de(puerta)
	if not interior.is_empty():
		_entrar(puerta, interior)
		return

	_llamando = true
	_izq.visible = false
	_der.visible = false
	_salir.visible = false
	_aviso.text = ""

	var hoja := puerta.get_node_or_null(^"Hoja")

	# Los golpes suenan siempre, abra o no.
	if hoja != null and hoja.has_method("llamar"):
		await hoja.llamar()

	# Solo abre si no es el diálogo de reserva ni una casa donde nadie contesta.
	if id == puerta.dialogue_id and not puerta.get_meta(&"no_abre", false):
		if hoja != null and hoja.has_method("abrir"):
			await hoja.abrir()

	_llamando = false
	_aviso.text = "Knock"
	_izq.visible = true
	_der.visible = true
	_salir.visible = true
	DialogueRunner.start(id)
	await DialogueRunner.dialogue_finished
	_cerrar_si_se_queda(puerta)


## Si Whitehead se queda delante sin hacer nada, cierran la puerta.
func _cerrar_si_se_queda(puerta: Node3D) -> void:
	await get_tree().create_timer(ESPERA_ANTES_DE_CERRAR).timeout
	if DoorMode.activo and DoorMode.puerta_actual() == puerta and not DialogueRunner.active and not _llamando:
		var hoja := puerta.get_node_or_null(^"Hoja")
		if hoja != null and hoja.has_method("esta_abierta") and bool(hoja.call("esta_abierta")):
			hoja.call("cerrar")


## Escena de dentro si la puerta la tiene en los datos y hay conversación de verdad.
func _interior_de(puerta: Node3D) -> String:
	if puerta == null or not puerta.has_method("active_dialogue_id"):
		return ""
	var id := String(puerta.get("dialogue_id"))
	if id.is_empty() or String(puerta.call("active_dialogue_id")) != id:
		return ""
	for p_raw in Array(Barrio.datos(Barrio.actual).get("puertas", [])):
		var p: Dictionary = p_raw
		if String(p.get("dialogo", "")) == id:
			return String(p.get("interior", ""))
	return ""


## Abre sin nadie en el umbral y pasa dentro; al salir, de pie ante esta puerta.
func _entrar(puerta: Node3D, escena: String) -> void:
	_llamando = true
	_izq.visible = false
	_der.visible = false
	_salir.visible = false
	_aviso.text = ""
	var hoja := puerta.get_node_or_null(^"Hoja")
	if hoja != null and hoja.has_method("abrir"):
		hoja.set(&"_figura", null)
		await hoja.abrir()
	var fuera: Vector3 = puerta.call("approach_point", puerta.global_position)
	Barrio.anotar_posicion(Barrio.actual, fuera.x, fuera.z)
	# La vista de puerta se queda en esta escena.
	DoorMode.activo = false
	SceneRouter.change_scene(escena, SceneRouter.Kind.SHORT_FADE)
