extends Node3D
## I.4 El entierro (dom. 3 sep.), en silencio: Whitehead llega, Sarah apenas habla, bajan el ataúd.

const FIGURA := preload("res://scenes/world/props/figura.tscn")
const GARAMOND := preload("res://art/fonts/EB_Garamond/static/EBGaramond-Regular.ttf")
const GARAMOND_SEMI := preload("res://art/fonts/EB_Garamond/static/EBGaramond-SemiBold.ttf")
const ENTERRADA := "buried_frances_lewis"
## Lo que Whitehead asienta en el registro de entierros.
const PALABRAS := ["frances_lewis", "sabado", "cinco"]

## Inicio y parada de Whitehead (junto a Sarah).
const DESDE := Vector3(2.2, 0.0, 6.0)
const HASTA := Vector3(1.55, 0.0, -0.05)
## m/s
const PASO := 0.9
const HOYO := Vector3(0.0, 0.0, -0.2)

## Misma ropa que en la calle, para reconocerla.
const SARAH := {"abrigo": [0.26, 0.21, 0.24], "pantalon": [0.74, 0.71, 0.64], "sombrero": [0.3, 0.26, 0.26],
	"cuello": [0.7, 0.66, 0.6], "chistera": false, "chal": true, "alzacuellos": false,
	"estatura": 0.94, "inclinacion": 0.22, "brazo_izquierdo": -0.42, "brazo_derecho": -0.5, "mira_alrededor": false,
	"quien": "sarah_lewis"}
const DOLIENTES := [
	{"pos": [-0.75, -0.55], "ropa": {"abrigo": [0.16, 0.15, 0.16], "pantalon": [0.15, 0.14, 0.15], "sombrero": [0.14, 0.13, 0.14],
		"cuello": [0.6, 0.58, 0.54], "chistera": false, "chal": true, "alzacuellos": false, "estatura": 0.9, "inclinacion": 0.18, "mira_alrededor": false}},
	{"pos": [-1.2, 0.45], "ropa": {"abrigo": [0.22, 0.22, 0.2], "pantalon": [0.2, 0.19, 0.17], "sombrero": [0.18, 0.18, 0.15],
		"cuello": [0.68, 0.64, 0.54], "chistera": false, "gorra": true, "alzacuellos": false, "estatura": 1.0, "inclinacion": 0.12, "mira_alrededor": false}},
	{"pos": [0.2, -1.35], "ropa": {"abrigo": [0.3, 0.27, 0.22], "pantalon": [0.25, 0.22, 0.18], "sombrero": [0.2, 0.18, 0.15],
		"cuello": [0.55, 0.5, 0.42], "chistera": false, "gorra": true, "alzacuellos": false, "estatura": 1.04,
		"inclinacion": 0.1, "brazo_derecho": -0.9, "mira_alrededor": false}},
]

var _whitehead: Node3D
var _sarah: Node3D
var _ataud: Node3D
var _cam: Camera3D
var _capa: CanvasLayer
var _llorando: bool = false


func _ready() -> void:
	HUD.esquina(false)
	HUD.hide()
	_suelo()
	_alrededor()
	_camino()
	_tumbas()
	_hoyo()
	_gente()
	_ataud = _ataudito()
	_whitehead = _figura({"chistera": true, "alzacuellos": true})
	_whitehead.position = DESDE
	_whitehead.look_at(Vector3(HASTA.x, 0.0, HASTA.z) + (HASTA - DESDE), Vector3.UP)
	# el _ready del estilo corre antes (hijo); repintar contorno
	var estilo := get_node_or_null(^"EstiloArtistico")
	if estilo != null and estilo.has_method(&"_apply_outline"):
		estilo.call(&"_apply_outline", self)
	_cam = get_node_or_null(^"Camera3D") as Camera3D
	if _cam != null:
		_cam.look_at(Vector3(0.2, 0.7, 1.2), Vector3.UP)
	_capa = CanvasLayer.new()
	_capa.layer = 30
	add_child(_capa)
	_correr()


func _exit_tree() -> void:
	HUD.esquina(true)
	HUD.show()


func _correr() -> void:
	await _fecha("Sunday, the 3rd of September.")
	_llorando = true
	_sollozos(_sarah)
	await _andar()
	_whitehead.look_at(Vector3(SARAH_POS.x, 0.0, SARAH_POS.z), Vector3.UP)
	await _esperar(0.8)
	await _burbuja(_whitehead, "Mrs Lewis?")
	await _esperar(1.4)
	await _burbuja(_sarah, "Reverend...  m- my daughter...  Reverend...")
	await _esperar(1.2)
	await _cubrirse()
	await _esperar(1.6)
	await _bajar_ataud()
	await _negro()
	_llorando = false
	asentar()
	Barrio.volver()


## Lo que deja el entierro: la bandera y la ficha del 40 con sus palabras.
static func asentar() -> void:
	GameState.set_flag(ENTERRADA)
	Cuaderno.abrir("f_40")
	for w in PALABRAS:
		Cuaderno.aprender(w, "the burial register")


func _esperar(s: float) -> void:
	await get_tree().create_timer(s).timeout


## Fecha sobre negro y fundido de entrada.
func _fecha(texto: String) -> void:
	var negro := ColorRect.new()
	negro.color = Color(0.03, 0.03, 0.03)
	negro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	negro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_capa.add_child(negro)
	var fecha := Label.new()
	fecha.text = texto
	fecha.add_theme_font_override("font", GARAMOND)
	fecha.add_theme_font_size_override("font_size", 46)
	fecha.add_theme_color_override("font_color", Color(0.86, 0.82, 0.72))
	fecha.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fecha.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	fecha.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	negro.add_child(fecha)
	var t := create_tween()
	t.tween_interval(2.4)
	t.tween_property(negro, "modulate:a", 0.0, 1.6)
	t.tween_callback(negro.queue_free)
	await get_tree().create_timer(2.8).timeout


func _andar() -> void:
	while is_inside_tree():
		var d := HASTA - _whitehead.position
		d.y = 0.0
		var paso := PASO * minf(get_process_delta_time(), 0.05)
		if d.length() <= paso:
			_whitehead.position = HASTA
			return
		_whitehead.position += d.normalized() * paso
		await get_tree().process_frame


## Bocadillo sobre la cabeza; el texto sale letra a letra, con pausas.
func _burbuja(quien: Node3D, texto: String) -> void:
	var caja := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.95, 0.92, 0.85)
	sb.border_color = Color(0.2, 0.16, 0.12)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	caja.add_theme_stylebox_override("panel", sb)
	var l := Label.new()
	l.add_theme_font_override("font", GARAMOND_SEMI)
	l.add_theme_font_size_override("font_size", 26)
	l.add_theme_color_override("font_color", Color(0.14, 0.11, 0.08))
	l.text = texto
	l.visible_characters = 0
	caja.add_child(l)
	_capa.add_child(caja)
	var sigue := func():
		if is_instance_valid(caja) and _cam != null:
			var p := _cam.unproject_position(quien.global_position + Vector3(0, 2.25, 0))
			caja.position = p - Vector2(caja.size.x * 0.5, caja.size.y)
	get_tree().process_frame.connect(sigue)
	for i in texto.length():
		l.visible_characters = i + 1
		var c := texto[i]
		var pausa := 0.07
		if c == ".":
			pausa = 0.32
		elif c == "-":
			pausa = 0.45
		elif c == " " and i > 0 and texto[i - 1] == " ":
			pausa = 0.5
		await get_tree().create_timer(pausa).timeout
	await get_tree().create_timer(1.6).timeout
	var t := caja.create_tween()
	t.tween_property(caja, "modulate:a", 0.0, 0.5)
	await t.finished
	get_tree().process_frame.disconnect(sigue)
	caja.queue_free()


## Whitehead se da la vuelta, se aparta un paso y se cubre la cara.
func _cubrirse() -> void:
	var fig := _whitehead.get_child(0)
	var lejos := _whitehead.position + (_whitehead.position - SARAH_POS).normalized() * 0.45
	lejos.y = 0.0
	var giro := create_tween().set_parallel(true)
	giro.tween_property(_whitehead, "rotation:y", _whitehead.rotation.y + PI * 0.85, 1.0).set_trans(Tween.TRANS_SINE)
	giro.tween_property(_whitehead, "position", lejos, 1.0).set_trans(Tween.TRANS_SINE)
	await giro.finished
	var t := create_tween().set_parallel(true)
	for p in [["brazo_izquierdo", -1.0], ["brazo_derecho", -1.0], ["codo_izquierdo", -2.2],
			["codo_derecho", -2.2], ["inclinacion", 0.35]]:
		t.tween_property(fig, p[0], p[1], 1.2).set_trans(Tween.TRANS_SINE)


## Cámara a la fosa y el ataúd baja.
func _bajar_ataud() -> void:
	if _cam != null:
		var desde := _cam.global_transform
		var hasta := Transform3D(Basis(), HOYO + Vector3(-0.8, 4.0, 2.8)).looking_at(HOYO + Vector3(0, 0.3, 0), Vector3.UP)
		var t := create_tween()
		t.tween_method(func(v: float): _cam.global_transform = desde.interpolate_with(hasta, v),
			0.0, 1.0, 2.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		await t.finished
	var b := create_tween()
	b.tween_property(_ataud, "position:y", -0.45, 4.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await b.finished
	await _esperar(0.8)


## Letras de cómic pequeñas sobre Sarah mientras dure el entierro.
func _sollozos(quien: Node3D) -> void:
	var i := 0
	while _llorando and is_inside_tree() and is_instance_valid(quien):
		var l := Label3D.new()
		l.text = "sob" if i % 3 != 2 else "sob..."
		l.font = GARAMOND_SEMI
		l.font_size = 60
		l.pixel_size = 0.0045
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.outline_size = 10
		l.outline_modulate = Color(0.05, 0.05, 0.05)
		l.rotation.z = deg_to_rad(randf_range(-14.0, 14.0))
		l.position = Vector3(-0.5 if i % 2 == 0 else 0.5, 1.75, 0.0)
		quien.add_child(l)
		var tw := l.create_tween()
		tw.set_parallel(true)
		tw.tween_property(l, "position:y", 2.2, 1.3)
		tw.tween_property(l, "modulate:a", 0.0, 1.3).set_delay(0.5)
		tw.chain().tween_callback(l.queue_free)
		i += 1
		await get_tree().create_timer(0.7 if i % 3 != 0 else 1.2).timeout


func _negro() -> void:
	var negro := ColorRect.new()
	negro.color = Color.BLACK
	negro.modulate.a = 0.0
	negro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_capa.add_child(negro)
	var t := create_tween()
	t.tween_property(negro, "modulate:a", 1.0, 1.2)
	await t.finished
	await _esperar(3.0)


# --- Lo que se levanta ---------------------------------------------------------

const SARAH_POS := Vector3(0.8, 0.0, 0.3)


func _gente() -> void:
	_sarah = _figura(SARAH)
	_sarah.position = SARAH_POS
	_sarah.look_at(Vector3(0.0, 0.0, -0.2), Vector3.UP)
	for d in DOLIENTES:
		var f := _figura(Dictionary(d["ropa"]))
		f.position = Vector3(float(d["pos"][0]), 0.0, float(d["pos"][1]))
		f.look_at(Vector3(0.0, 0.0, -0.2), Vector3.UP)


## Ataúd pequeño, de pino, sobre la fosa.
func _ataudito() -> Node3D:
	var raiz := Node3D.new()
	raiz.position = HOYO + Vector3(0, 0.55, 0)
	add_child(raiz)
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(0.7, 0.22, 0.3)
	m.mesh = b
	m.material_override = _mate(Color(0.42, 0.31, 0.2))
	raiz.add_child(m)
	return raiz


## Figura dentro de un padre: se mueve el padre (la figura anima al moverse).
func _figura(ropa: Dictionary) -> Node3D:
	var padre := Node3D.new()
	var f := FIGURA.instantiate()
	Vestuario.aplicar(f, ropa)
	padre.add_child(f)
	add_child(padre)
	return padre


func _suelo() -> void:
	var m := MeshInstance3D.new()
	var p := PlaneMesh.new()
	p.size = Vector2(40, 40)
	m.mesh = p
	m.material_override = _mate(Color(0.24, 0.26, 0.19))
	add_child(m)
	# tapia del fondo
	var tapia := MeshInstance3D.new()
	var caja := BoxMesh.new()
	caja.size = Vector3(24, 2.2, 0.5)
	tapia.mesh = caja
	tapia.material_override = _mate(Color(0.36, 0.32, 0.29))
	tapia.position = Vector3(0, 1.1, -7.5)
	add_child(tapia)


## Entorno: [modelo, posición, giro Y]. Casas, torre, árboles y verja.
const CASAS := [
	["building-sample-house-a", Vector3(-11.0, 0, -15.0), 0.0],
	["building-sample-house-b", Vector3(-1.5, 0, -15.5), 0.0],
	["building-sample-house-c", Vector3(8.5, 0, -15.0), 0.0],
	["building-sample-house-b", Vector3(-17.0, 0, -3.0), PI * 0.5],
	["building-sample-house-a", Vector3(17.5, 0, -4.0), -PI * 0.5],
	["building-sample-house-c", Vector3(17.5, 0, 6.0), -PI * 0.5],
]
## Al otro lado de la calle de la entrada, de espaldas a la cámara del entierro.
const CASAS_FRENTE := [
	["building-sample-house-c", Vector3(-11.5, 0, 17.0), PI],
	["building-sample-house-a", Vector3(-2.0, 0, 17.5), PI],
	["building-sample-house-b", Vector3(8.0, 0, 17.0), PI],
	["building-sample-house-a", Vector3(-17.0, 0, 8.0), PI * 0.5],
]
const TORRE := ["building-sample-tower-a", Vector3(-15.5, 0, -12.5), PI * 0.25]
const MODULAR := "res://art/models/Modular/GLB format/%s.glb"
const ARBOL := preload("res://scenes/world/props/arbol.tscn")


func _alrededor() -> void:
	var piedra_sucia := Color(0.5, 0.46, 0.42)
	for c in CASAS + CASAS_FRENTE + [TORRE]:
		var esc := load(MODULAR % String(c[0])) as PackedScene
		if esc == null:
			continue
		var casa := esc.instantiate() as Node3D
		add_child(casa)
		casa.position = c[1]
		casa.rotation.y = float(c[2])
		_ennegrecer(casa, piedra_sucia)

	# árboles en los bordes (LCG fijo) y tras la tapia
	var semilla := 3
	for lado in [-1.0, 1.0]:
		for i in 5:
			semilla = (semilla * 1103515245 + 12345) & 0x7fffffff
			var r := float(semilla % 1000) / 1000.0
			var a := ARBOL.instantiate() as Node3D
			add_child(a)
			a.position = Vector3(lado * (10.5 + r * 1.5), 0, -6.5 + i * 3.6 + r)
			a.scale = Vector3.ONE * (0.85 + r * 0.35)
	for x in [-6.0, 1.5, 7.0]:
		var a := ARBOL.instantiate() as Node3D
		add_child(a)
		a.position = Vector3(x, 0, -9.5)
	# y en la acera de la entrada, sin tapar el camino
	for x in [-7.5, -3.0, 6.5]:
		var a := ARBOL.instantiate() as Node3D
		add_child(a)
		a.position = Vector3(x, 0, 13.0)

	# verja de hierro: barrotes y pasamanos a los lados
	var hierro := Color(0.10, 0.10, 0.11)
	for lado in [-1.0, 1.0]:
		var x: float = lado * 9.0
		var z := -7.0
		while z < 11.0:
			_caja_simple(Vector3(x, 0.7, z), Vector3(0.05, 1.4, 0.05), hierro)
			z += 0.45
		_caja_simple(Vector3(x, 1.38, 2.0), Vector3(0.06, 0.06, 18.0), hierro)
	_entrada(hierro)


## Verja de la entrada con la cancela abierta, pilares y la acera de fuera: una malla por color.
func _entrada(hierro: Color) -> void:
	var lote := {}
	var piedra := Color(0.40, 0.37, 0.34)
	var z := 11.0
	var x := -9.0
	while x <= 9.0:
		if absf(x - 2.0) > 0.9:
			_al_lote(lote, Vector3(x, 0.7, z), Vector3(0.05, 1.4, 0.05), hierro)
		x += 0.45
	for tramo in [[-9.0, 1.1], [2.9, 9.0]]:
		var a: float = tramo[0]
		var b: float = tramo[1]
		_al_lote(lote, Vector3((a + b) * 0.5, 1.38, z), Vector3(b - a, 0.06, 0.06), hierro)
		_al_lote(lote, Vector3((a + b) * 0.5, 0.15, z), Vector3(b - a, 0.3, 0.3), piedra)
	# pilares de la cancela y las dos hojas abiertas hacia dentro
	for px in [1.0, 3.0]:
		_al_lote(lote, Vector3(px, 1.0, z), Vector3(0.45, 2.0, 0.45), piedra)
		_al_lote(lote, Vector3(px, 2.08, z), Vector3(0.55, 0.16, 0.55), piedra * Color(0.85, 0.85, 0.85))
	for lado in [-1.0, 1.0]:
		var bx: float = 2.0 + lado * 0.71
		var k := 0.0
		while k < 0.8:
			_al_lote(lote, Vector3(bx, 0.75, z - 0.2 - k), Vector3(0.04, 1.4, 0.04), hierro)
			k += 0.2
		_al_lote(lote, Vector3(bx, 1.4, z - 0.6), Vector3(0.05, 0.05, 0.85), hierro)
	# acera, adoquines y bordillo al otro lado
	_al_lote(lote, Vector3(0.0, 0.015, 12.6), Vector3(40.0, 0.03, 2.6), Color(0.36, 0.35, 0.32))
	_al_lote(lote, Vector3(0.0, 0.01, 15.2), Vector3(40.0, 0.02, 2.6), Color(0.22, 0.22, 0.21))
	_al_lote(lote, Vector3(0.0, 0.06, 13.95), Vector3(40.0, 0.12, 0.25), piedra)
	var am := ArrayMesh.new()
	for c in lote:
		(lote[c] as SurfaceTool).commit(am)
		am.surface_set_material(am.get_surface_count() - 1, _mate(c))
	var m := MeshInstance3D.new()
	m.name = "Entrada"
	m.mesh = am
	add_child(m)


func _al_lote(lote: Dictionary, pos: Vector3, tam: Vector3, color: Color) -> void:
	if not lote.has(color):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		lote[color] = st
	var b := BoxMesh.new()
	b.size = tam
	(lote[color] as SurfaceTool).append_from(b, 0, Transform3D(Basis(), pos))


## Oscurece los materiales del kit (hollín).
func _ennegrecer(n: Node, tinte: Color) -> void:
	for m in n.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		for i in mi.get_surface_override_material_count():
			var mat := mi.get_active_material(i)
			if mat is StandardMaterial3D:
				var copia := (mat as StandardMaterial3D).duplicate() as StandardMaterial3D
				copia.albedo_color = copia.albedo_color * tinte
				mi.set_surface_override_material(i, copia)


func _caja_simple(pos: Vector3, tam: Vector3, color: Color) -> void:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = tam
	m.mesh = b
	m.material_override = _mate(color)
	add_child(m)
	m.position = pos


## Lápidas en filas, algo torcidas (semilla fija).
func _tumbas() -> void:
	var piedra := _mate(Color(0.52, 0.51, 0.48))
	var semilla := 7
	for fila in 7:
		for col in 9:
			semilla = (semilla * 1103515245 + 12345) % 2147483648
			var r := float(semilla % 1000) / 1000.0
			var x := -8.0 + col * 2.0 + (r - 0.5) * 0.6
			var z := -6.0 + fila * 1.9
			# sin lápidas en el claro ni en el camino
			if absf(x) < 2.6 and z > -2.4 and z < 1.2:
				continue
			if x > 0.6 and x < 3.6 and z > 0.0:
				continue
			# ~1 de cada 6 es cruz
			if r < 0.17:
				_cruz(Vector3(x, 0, z), r)
				continue
			var l := MeshInstance3D.new()
			var b := BoxMesh.new()
			b.size = Vector3(0.55, 0.7 + r * 0.35, 0.12)
			l.mesh = b
			l.material_override = piedra
			l.position = Vector3(x, b.size.y * 0.5, z)
			l.rotation = Vector3((r - 0.5) * 0.12, (r - 0.5) * 0.3, (r - 0.5) * 0.08)
			add_child(l)


func _cruz(pos: Vector3, r: float) -> void:
	var piedra := Color(0.5, 0.49, 0.46)
	_caja_simple(pos + Vector3(0, 0.55, 0), Vector3(0.12, 1.1, 0.12), piedra)
	_caja_simple(pos + Vector3(0, 0.8, 0), Vector3(0.5, 0.12, 0.12), piedra)
	_caja_simple(pos + Vector3(0, 0.06, 0), Vector3(0.36, 0.12, 0.3), piedra * Color(0.85, 0.85, 0.85))


## Camino de grava de la verja al hoyo.
func _camino() -> void:
	var grava := Color(0.42, 0.40, 0.36)
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(1.3, 0.02, 9.0)
	m.mesh = b
	m.material_override = _mate(grava)
	add_child(m)
	m.position = Vector3(2.0, 0.01, 4.6)
	m.rotation.y = 0.06


## Hoyo pequeño: el de una niña de cinco meses.
func _hoyo() -> void:
	var hueco := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(0.95, 0.04, 0.5)
	hueco.mesh = b
	hueco.material_override = _mate(Color(0.07, 0.06, 0.05))
	hueco.position = Vector3(0.0, 0.01, -0.2)
	add_child(hueco)
	var tierra := MeshInstance3D.new()
	var t := BoxMesh.new()
	t.size = Vector3(0.9, 0.22, 0.55)
	tierra.mesh = t
	tierra.material_override = _mate(Color(0.3, 0.22, 0.15))
	tierra.position = Vector3(-0.05, 0.11, -0.85)
	tierra.rotation.x = 0.08
	add_child(tierra)


func _mate(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 1.0
	return m
