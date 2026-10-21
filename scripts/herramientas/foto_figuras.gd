extends Node
## Los personajes en fila con luz de estudio. «caras» baja la cámara.
## Uso: foto_figuras.tscn -- salida.png [caras]

const FIGURA := preload("res://scenes/world/props/figura.tscn")
const ESTILO := preload("res://scripts/world/art_style.gd")

const REPARTO := [
	{"chistera": true, "alzacuellos": true},
	{"abrigo": [0.13, 0.13, 0.15], "pantalon": [0.15, 0.15, 0.16], "sombrero": [0.08, 0.08, 0.09],
		"cuello": [0.9, 0.9, 0.86], "chistera": true, "alzacuellos": false, "estatura": 1.04, "cara": "h01", "pelo": [0.14, 0.1, 0.08]},
	{"abrigo": [0.26, 0.21, 0.24], "pantalon": [0.74, 0.71, 0.64], "sombrero": [0.3, 0.26, 0.26],
		"cuello": [0.7, 0.66, 0.6], "chistera": false, "chal": true, "alzacuellos": false, "estatura": 0.94},
	{"abrigo": [0.24, 0.24, 0.2], "pantalon": [0.2, 0.19, 0.17], "sombrero": [0.18, 0.18, 0.15],
		"cuello": [0.68, 0.64, 0.54], "chistera": false, "gorra": true, "alzacuellos": false},
	{"abrigo": [0.3, 0.42, 0.34], "pantalon": [0.28, 0.3, 0.27], "sombrero": [0.22, 0.32, 0.26],
		"cuello": [0.84, 0.82, 0.74], "chistera": false, "chal": true, "alzacuellos": false, "estatura": 0.92},
]

const POR_FILA := 9


func _ready() -> void:
	HUD.hide()
	var a := OS.get_cmdline_user_args()
	var salida := String(a[0]) if a.size() > 0 else "figuras.png"
	var caras := a.size() > 1 and String(a[1]) in ["caras", "esfera"]
	var esfera := a.size() > 1 and String(a[1]) == "esfera"

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
	sol.rotation_degrees = Vector3(-35, 20, 0)
	sol.light_energy = 1.1
	raiz.add_child(sol)

	# Los tres principales y luego todo el barrio.
	var gente: Array = REPARTO.slice(0, 3)
	var barrio: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/barrio/soho.json"))
	for v in Array(barrio.get("vecinos", [])):
		gente.append(Dictionary(v.get("ropa", {})))
	for p in Array(barrio.get("puertas", [])):
		if Dictionary(p.get("ropa", {})).size() > 0:
			gente.append(Dictionary(p["ropa"]))

	# Forma de cabeza: caja, redondeada y esfera, de tres en tres.
	if esfera:
		var parejas := []
		var vecino := {"chistera": false, "gorra": false, "alzacuellos": false}
		for p in [REPARTO[0].merged({"chistera": false}, true),
				vecino.merged({"cara": "h03", "abrigo": [0.3, 0.26, 0.2]}),
				vecino.merged({"cara": "h06", "abrigo": [0.22, 0.26, 0.3]}), REPARTO[2]]:
			for r in [0.0, 4.5, 2.0]:
				parejas.append(Dictionary(p).merged({"redondez": r}, true))
		gente = parejas

	for i in gente.size():
		var padre := Node3D.new()
		var f := FIGURA.instantiate()
		Vestuario.aplicar(f, Dictionary(gente[i]))
		f.set(&"mira_alrededor", false)
		f.set(&"inclinacion", 0.0)
		padre.add_child(f)
		raiz.add_child(padre)
		@warning_ignore("integer_division")
		var fila := i / POR_FILA
		padre.position = Vector3((i % POR_FILA - (POR_FILA - 1) * 0.5) * 0.72, 0, -fila * 1.7)

	var cam := Camera3D.new()
	raiz.add_child(cam)
	if esfera:
		cam.fov = 26
		cam.position = Vector3(-0.36 + (gente.size() - POR_FILA) * 0.36, 1.7, 6.2)
		cam.look_at(cam.position + Vector3(0, -0.12, -6.2), Vector3.UP)
	elif caras:
		cam.fov = 22
		cam.position = Vector3(0, 1.72, 7.0)
		cam.look_at(Vector3(0, 1.6, 0), Vector3.UP)
	else:
		cam.fov = 42
		cam.position = Vector3(0, 3.6, 8.6)
		cam.look_at(Vector3(0, 0.8, -1.7), Vector3.UP)
	cam.current = true
	raiz.add_child(ESTILO.new())

	await get_tree().create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	print("[foto_figuras] %s (%s) %d personas" % [salida, "ok" if img.save_png(salida) == OK else "error", gente.size()])
	get_tree().quit()
