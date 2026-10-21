extends Node3D
## Vecinos en la calle: pasean, y los del cubo van a la bomba de vez en cuando.
## En la bomba de uno en uno (cola), bombeando; sin colisión ni diálogo.

const DATOS := "res://data/barrio/aguadores.json"
const VESTUARIO := preload("res://scripts/world/vestuario.gd")
const FIGURA := "res://scenes/world/props/figura.tscn"
const CUBO := "res://scenes/world/props/cubo.tscn"

const BOMBA := Vector3(-3.0, 0.0, 0.6)
## Sitio para bombear y sitios de espera.
const EN_LA_BOMBA := Vector3(-1.9, 0.0, -0.4)
const COLA := [Vector3(-0.2, 0.0, -1.6), Vector3(1.3, 0.0, -2.4), Vector3(-4.8, 0.0, -1.9)]
const SALIDAS := {"marshall": -60.0}
const BOMBA_PETER := Vector3(35.0, 0.0, -20.6)
## Aceras andables: x, y bandas de z (norte y sur).
const X := Vector2(-48.0, 48.0)
const ACERAS := [Vector2(-4.4, -3.0), Vector2(3.4, 6.5)]
## m/s; segundos de pausa al pasear; entre viajes al agua; bombeando.
const PASO := 1.25
const PAUSA := Vector2(3.0, 9.0)
const ENTRE_VIAJES := Vector2(45.0, 100.0)
const BOMBEO := 3.6
const SONIDOS := preload("res://scripts/sonidos_bomba.gd")

var _rng := RandomNumberGenerator.new()
var _bomba_ocupada: Node3D = null
var _cola: Array[Node3D] = []
var _palanca: Node3D
var _son: AudioStreamPlayer3D
var _son_agua: AudioStreamPlayer3D


func _ready() -> void:
	_rng.seed = 1854 + GameState.dia
	await get_tree().process_frame
	var bomba := get_tree().current_scene.find_child("Bomba", true, false) if get_tree().current_scene != null else null
	if bomba != null:
		_palanca = bomba.find_child("Palanca", true, false) as Node3D
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATOS))
	if not (d is Dictionary):
		return
	var i := 0
	for a in Array((d as Dictionary).get("aguadores", [])):
		if GameState.dia in Array(a.get("dias", [])).map(func(x): return int(x)):
			var q := _figura(Dictionary(a.get("ropa", {})), true)
			q.position = _inicio(a)
			_vivir(q, String(a.get("fuente", "broad")), _rng.randf_range(4.0, 40.0) + i * 9.0)
		i += 1
	for r in Array((d as Dictionary).get("paseantes", [])):
		var q := _figura(Dictionary(r), false)
		q.position = _punto_de_acera()
		_vivir(q, "", 0.0)


func _inicio(a: Dictionary) -> Vector3:
	var desde: Variant = a.get("desde")
	if desde is String:
		var puerta := _puerta(String(desde))
		if puerta != null:
			var p := puerta.global_position
			return Vector3(clampf(p.x, X.x, X.y), 0.0, -3.6)
	elif desde != null:
		return Vector3(float(desde), 0.0, -3.6)
	return _punto_de_acera()


func _puerta(numero: String) -> Node3D:
	for p in get_tree().get_nodes_in_group(&"puertas"):
		if String((p as Node).get_meta(&"numero", "")) == numero:
			return p as Node3D
	return null


func _punto_de_acera() -> Vector3:
	var banda: Vector2 = ACERAS[_rng.randi() % ACERAS.size()]
	return Vector3(_rng.randf_range(X.x, X.y), 0.0, _rng.randf_range(banda.x, banda.y))


func _figura(ropa: Dictionary, con_cubo: bool) -> Node3D:
	var raiz := Node3D.new()
	raiz.name = "Aguador" if con_cubo else "Paseante"
	raiz.set_meta(&"cubo", con_cubo)
	add_child(raiz)
	var escena := load(FIGURA) as PackedScene
	if escena != null:
		var fig := escena.instantiate() as Node3D
		fig.name = "Figura"
		var r := {"alzacuellos": false, "mira_alrededor": true}
		r.merge(ropa, true)
		VESTUARIO.aplicar(fig, r)
		raiz.add_child(fig)
		if con_cubo:
			var cubo_escena := load(CUBO) as PackedScene
			if cubo_escena != null:
				var cubo := cubo_escena.instantiate() as Node3D
				cubo.name = "Cubo"
				cubo.scale = Vector3.ONE * 0.55
				cubo.position = Vector3(0.34, 0.22, 0.0)
				fig.add_child(cubo)
	return raiz


## Pasear, y si lleva cubo, cada tanto ir a por agua.
func _vivir(quien: Node3D, fuente: String, primer_viaje: float) -> void:
	var proximo_viaje := Time.get_ticks_msec() / 1000.0 + primer_viaje
	while is_instance_valid(quien):
		var ahora := Time.get_ticks_msec() / 1000.0
		if not fuente.is_empty() and ahora >= proximo_viaje:
			if fuente == "broad":
				await _a_la_bomba(quien)
			elif fuente == "peter":
				await _andar(quien, Vector3(BOMBA_PETER.x, 0.0, -3.6))
				await _andar(quien, BOMBA_PETER)
				await get_tree().create_timer(BOMBEO).timeout
				await _andar(quien, Vector3(BOMBA_PETER.x, 0.0, -3.6))
			elif SALIDAS.has(fuente):
				await _andar(quien, Vector3(float(SALIDAS[fuente]), 0.0, -3.6))
				if not is_instance_valid(quien):
					return
				quien.visible = false
				await get_tree().create_timer(12.0).timeout
				quien.visible = true
			proximo_viaje = Time.get_ticks_msec() / 1000.0 + _rng.randf_range(ENTRE_VIAJES.x, ENTRE_VIAJES.y)
		else:
			await _andar(quien, _punto_de_acera())
			await get_tree().create_timer(_rng.randf_range(PAUSA.x, PAUSA.y)).timeout


func _a_la_bomba(quien: Node3D) -> void:
	_cola.append(quien)
	var sitio: Vector3 = COLA[mini(_cola.size() - 1, COLA.size() - 1)]
	await _andar(quien, sitio)
	while is_instance_valid(quien) and (_bomba_ocupada != null or _cola.front() != quien):
		await get_tree().create_timer(0.5).timeout
	if not is_instance_valid(quien):
		_cola.erase(quien)
		return
	_cola.erase(quien)
	_bomba_ocupada = quien
	await _andar(quien, EN_LA_BOMBA)
	await _bombear(quien)
	_bomba_ocupada = null


## Sube y baja el brazo y la palanca mientras cae el agua.
func _bombear(quien: Node3D) -> void:
	var fig := quien.get_node_or_null(^"Figura")
	if fig != null:
		(fig as Node3D).look_at(Vector3(BOMBA.x, (fig as Node3D).global_position.y, BOMBA.z), Vector3.UP, true)
	var reposo: float = fig.get(&"brazo_derecho") if fig != null else 0.0
	var giro0 := _palanca.rotation.z if _palanca != null else 0.0
	_sonar(SONIDOS.cubo(), -6.0)
	var t := 0.0
	var antes := 0.0
	while t < BOMBEO and is_instance_valid(quien) and is_inside_tree():
		var v := sin(t * 6.0)
		# Cada bajada de la palanca: chirrido y golpe, y sale el chorro.
		if antes > 0.0 and v <= 0.0:
			_sonar(SONIDOS.palanca(), -8.0)
			_sonar(SONIDOS.chorro(), -10.0, true)
		antes = v
		if fig != null:
			fig.set(&"brazo_derecho", -1.1 + 0.45 * v)
		if _palanca != null:
			_palanca.rotation.z = giro0 + 0.28 * v
		await get_tree().process_frame
		t += get_process_delta_time()
	if fig != null and is_instance_valid(fig):
		fig.set(&"brazo_derecho", reposo)
	if _palanca != null:
		_palanca.rotation.z = giro0


## Sonido en la bomba; el agua va por su propio reproductor para no cortar la palanca.
func _sonar(s: AudioStream, db: float, agua: bool = false) -> void:
	if _son == null:
		_son = AudioStreamPlayer3D.new()
		_son_agua = AudioStreamPlayer3D.new()
		for p in [_son, _son_agua]:
			p.bus = &"Efectos"
			p.unit_size = 4.0
			p.max_distance = 30.0
			# Fuera del grupo: sus hijos son solo los aguadores.
			get_parent().add_child(p)
			p.global_position = BOMBA + Vector3(0, 1.0, 0)
	var r := _son_agua if agua else _son
	r.stream = s
	r.volume_db = db
	r.pitch_scale = randf_range(0.92, 1.06)
	r.play()


func _andar(quien: Node3D, a: Vector3) -> void:
	if not is_instance_valid(quien):
		return
	var t := quien.create_tween()
	t.tween_property(quien, "position", a, quien.position.distance_to(a) / PASO)
	await t.finished


func cuantos() -> int:
	var n := 0
	for c in get_children():
		if bool(c.get_meta(&"cubo", false)):
			n += 1
	return n
