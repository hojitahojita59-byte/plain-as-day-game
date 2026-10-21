extends Node
## Nuestras figuras junto a las de Quaternius, misma luz y escala.
## Uso: foto_comparacion.tscn -- salida.png

const FIGURA := preload("res://scenes/world/props/figura.tscn")
const ESTILO := preload("res://scripts/world/art_style.gd")
const CARPETA := "res://art/models/_prueba_personajes/"
const NUESTRAS := preload("res://scripts/herramientas/foto_figuras.gd")
const ALTO := 1.85


func _ready() -> void:
	HUD.hide()
	var a := OS.get_cmdline_user_args()
	var salida := String(a[0]) if a.size() > 0 else "comparacion.png"

	var raiz := Node3D.new()
	add_child(raiz)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.36, 0.36, 0.38)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.6, 0.6, 0.62)
	e.ambient_light_energy = 0.6
	env.environment = e
	raiz.add_child(env)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-40, 30, 0)
	sol.light_energy = 1.1
	raiz.add_child(sol)

	var x := -3.9
	for ropa in NUESTRAS.REPARTO:
		var padre := Node3D.new()
		var f := FIGURA.instantiate()
		Vestuario.aplicar(f, Dictionary(ropa))
		f.set(&"mira_alrededor", false)
		padre.add_child(f)
		padre.position = Vector3(x, 0, 0)
		raiz.add_child(padre)
		x += 0.72

	x += 0.5
	for archivo in DirAccess.get_files_at(CARPETA):
		if not archivo.ends_with(".gltf"):
			continue
		var esc := load(CARPETA + archivo) as PackedScene
		if esc == null:
			continue
		var m := esc.instantiate() as Node3D
		raiz.add_child(m)
		var caja := _envolvente(m)
		if caja.size.y > 0.0:
			m.scale = Vector3.ONE * (ALTO / caja.size.y)
		m.position = Vector3(x, 0, 0)
		var ap := m.find_child("*", true, false) as Node
		for n in m.find_children("*", "AnimationPlayer", true, false):
			var jugador := n as AnimationPlayer
			for nombre in jugador.get_animation_list():
				if String(nombre).to_lower().ends_with("idle"):
					jugador.play(nombre)
					break
		x += 0.9

	var cam := Camera3D.new()
	cam.fov = 38
	raiz.add_child(cam)
	cam.position = Vector3((-3.9 + x - 0.9) * 0.5, 1.4, 6.6)
	cam.look_at(Vector3((-3.9 + x - 0.9) * 0.5, 1.0, 0), Vector3.UP)
	cam.current = true
	raiz.add_child(ESTILO.new())

	await get_tree().create_timer(1.2).timeout
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	print("[foto_comparacion] %s (%s)" % [salida, "ok" if img.save_png(salida) == OK else "error"])
	get_tree().quit()


func _envolvente(n: Node3D) -> AABB:
	var out := AABB()
	var primera := true
	for mm in n.find_children("*", "MeshInstance3D", true, false):
		var mi := mm as MeshInstance3D
		var a := mi.global_transform * mi.get_aabb()
		if primera:
			out = a
			primera = false
		else:
			out = out.merge(a)
	return out
