extends Node
## Cambios de escena y transiciones; ninguna escena llama a change_scene_to_file().

signal transition_started(kind: String)
signal transition_finished(kind: String)

enum Kind {
	CAMERA_FLY,   ## 1. Vuelo de cámara — dentro de un mismo sitio. Coste: cero.
	SHORT_FADE,   ## 2. Fundido corto con el sonido continuo — sitios cercanos.
	SOHO_MAP,     ## 3. El mapa de Soho — entre zonas del barrio.
	JOURNAL,      ## 4. Página del diario — saltos de tiempo o de capítulo.
}

const FADE_SECONDS := 0.5


## Mueve la cámara a `destination` (normalmente un Marker3D) sin cortar.
func camera_fly(camera: Camera3D, destination: Node3D, seconds: float = 1.2) -> void:
	if camera == null or destination == null:
		push_error("SceneRouter.camera_fly: cámara o destino nulos")
		return
	transition_started.emit("camera_fly")
	var tw := create_tween()
	tw.set_parallel(true)
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(camera, "global_position", destination.global_position, seconds)
	tw.tween_property(camera, "global_rotation", destination.global_rotation, seconds)
	await tw.finished
	transition_finished.emit("camera_fly")


## Cambio de escena; el tipo solo cambia lo que se ve encima.
func change_scene(scene_path: String, kind: int = Kind.SHORT_FADE) -> void:
	var kind_names: PackedStringArray = ["camera_fly", "short_fade", "soho_map", "journal"]
	var kind_name: String = kind_names[kind]
	transition_started.emit(kind_name)
	# TODO: reproducir aquí la cortina correspondiente (fundido / mapa / diario).
	# El audio ambiente NO se corta durante short_fade: es lo que oculta el salto.
	# Cortina pintada antes de cargar: en web la carga congela la página.
	var cortina := _cortina()
	# Un momento girando antes del parón, para que se vea el aro.
	await get_tree().create_timer(0.35).timeout
	await RenderingServer.frame_post_draw
	var err := get_tree().change_scene_to_file(scene_path)
	if err != OK:
		push_error("SceneRouter: no se pudo cargar " + scene_path)
	# El 1er fotograma compila shaders; que pase tapado.
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var tw := cortina.create_tween()
	tw.tween_property(cortina.get_child(0), "modulate:a", 0.0, FADE_SECONDS)
	tw.tween_callback(cortina.queue_free)
	transition_finished.emit(kind_name)


func _cortina() -> CanvasLayer:
	var capa := CanvasLayer.new()
	capa.layer = 100
	var fondo := ColorRect.new()
	fondo.color = Color(0.03, 0.035, 0.03)
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fondo.mouse_filter = Control.MOUSE_FILTER_STOP
	var aro := Aro.new()
	aro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fondo.add_child(aro)
	capa.add_child(fondo)
	add_child(capa)
	return capa


## Aro mágico de carga: anillo de luz que gira con chispas.
class Aro extends Control:
	var _t: float = 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		_t += minf(delta, 0.1)
		queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var r := 34.0
		var oro := Color(0.98, 0.88, 0.62)
		# Halo suave.
		for k in 4:
			draw_arc(c, r, 0.0, TAU, 64, Color(oro, 0.05), 10.0 + k * 7.0, true)
		# Cola que gira y se apaga.
		var cabeza := _t * 4.2
		for k in 24:
			var a := cabeza - k * 0.11
			draw_arc(c, r, a - 0.12, a, 6, Color(oro, 0.9 * (1.0 - k / 24.0)), 3.0, true)
		# Chispas en órbita.
		for k in 6:
			var a := -_t * 1.7 + k * TAU / 6.0
			var rr := r + 12.0 + 4.0 * sin(_t * 3.0 + k)
			var p := c + Vector2(cos(a), sin(a)) * rr
			draw_circle(p, 1.6 + 1.2 * (0.5 + 0.5 * sin(_t * 5.0 + k * 1.3)), Color(1, 0.97, 0.85, 0.85))
		draw_circle(c + Vector2(cos(cabeza), sin(cabeza)) * r, 4.0, Color(1, 1, 0.95))
