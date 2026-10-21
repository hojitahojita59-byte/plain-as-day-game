extends Node
## Retrata al vecino con la cámara del juego, un PNG por giro (SubViewport).
## Uso: foto_npc.tscn -- carpeta_salida

const FIGURA := preload("res://scenes/world/props/figura.tscn")

## Copiado de broad_street.tscn: si cambia allí, cambiar aquí.
const PICADO := -42.0      ## Transform3D(...0.743145, 0.669131...) = 42° abajo
const FOV := 52.0
const ALTO_CAMARA := 9.9   ## 9 sobre el nodo del personaje, que está a 0,9
const LEJOS_CAMARA := 10.0

## 16:9 como el juego (KEEP_HEIGHT: la proporción cambia la escala).
const TAM := Vector2i(2560, 1440)

## Giros del vecino en cada foto.
const GIROS: Array[float] = [0.0, 30.0, 90.0]

## Gris plano para recortar la silueta.
const FONDO := Color(0.18, 0.18, 0.20)


func _ready() -> void:
	# Oculta el HUD: estropea el recorte.
	HUD.hide()

	var salida := "npc"
	var extra := OS.get_cmdline_user_args()
	if extra.size() > 0:
		salida = extra[0]

	var vp := SubViewport.new()
	vp.size = TAM
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = FONDO
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.65, 0.72)
	env.ambient_light_energy = 1.0
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)

	# Luz alta y frontal para que se lean las aristas.
	var sol := DirectionalLight3D.new()
	sol.light_energy = 1.5
	sol.rotation_degrees = Vector3(-50.0, 25.0, 0.0)
	vp.add_child(sol)

	var figura := FIGURA.instantiate() as Node3D
	vp.add_child(figura)

	var cam := Camera3D.new()
	cam.fov = FOV
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.position = Vector3(0.0, ALTO_CAMARA, LEJOS_CAMARA)
	cam.rotation_degrees = Vector3(PICADO, 0.0, 0.0)
	cam.current = true
	vp.add_child(cam)

	# Dos fotogramas para que el árbol termine de montarse.
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw

	for g in GIROS:
		figura.rotation_degrees = Vector3(0.0, g, 0.0)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		var ruta := "%s_%03d.png" % [salida, int(g)]
		var err := img.save_png(ruta)
		print("[foto_npc] %s %dx%d (%s)" % [
			ruta, img.get_width(), img.get_height(), "ok" if err == OK else str(err)])

	get_tree().quit()
