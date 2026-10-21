extends Node3D
## Retrata piezas del kit de muebles.
## Uso: foto_muebles.tscn -- salida.png

const CUALES := ["desk", "chairDesk", "bookcaseClosed", "bookcaseOpen",
	"table", "chair", "rugRectangle", "lampSquareTable", "books", "coatRack"]
const RUTA := "res://art/models/Furniture/%s.glb"


func _ready() -> void:
	var extra := OS.get_cmdline_user_args()
	var salida: String = extra[0] if extra.size() > 0 else "muebles.png"

	var vp := SubViewport.new()
	vp.size = Vector2i(1600, 700)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)

	var mundo := Node3D.new()
	vp.add_child(mundo)

	var luz := DirectionalLight3D.new()
	luz.rotation = Vector3(deg_to_rad(-48), deg_to_rad(-38), 0)
	luz.light_energy = 1.25
	mundo.add_child(luz)

	var amb := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.16, 0.14, 0.12)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.5, 0.47, 0.42)
	e.ambient_light_energy = 0.8
	amb.environment = e
	mundo.add_child(amb)

	var x := -4.5
	for nombre in CUALES:
		var esc := load(RUTA % nombre) as PackedScene
		if esc == null:
			print("[muebles] NO CARGA: ", nombre)
			continue
		var pieza := esc.instantiate() as Node3D
		mundo.add_child(pieza)
		pieza.position = Vector3(x, 0, 0)
		x += 1.0

	var cam := Camera3D.new()
	mundo.add_child(cam)
	cam.position = Vector3(0, 2.2, 5.2)
	cam.rotation = Vector3(deg_to_rad(-16), 0, 0)
	cam.fov = 55
	cam.current = true

	await get_tree().create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	print("[muebles] %s (%s)" % [salida, "ok" if img.save_png(salida) == OK else "error"])
	get_tree().quit()
