extends Node3D
## Bebedor con jarra: bebe, charla y brinda con los de su corro. Padre de su figura.

const FIGURA := preload("res://scenes/world/props/figura.tscn")
const VESTUARIO := preload("res://scripts/world/vestuario.gd")

## Brazo y codo derechos de cada gesto.
const SOSTENER := Vector2(-0.5, -1.2)
const BEBER := Vector2(-1.0, -2.2)
const BRINDAR := Vector2(-2.75, -0.3)

## Segundos entre brindis del corro, y lo que dura cada uno.
const CICLO := 8.0
const DURA_BRINDIS := 1.7

## Se pasa antes de add_child.
var ropa: Dictionary = {}
## Corro: los del mismo brindan a la vez. Vacío = solo bebe.
var corro: String = ""
## Sin jarra: solo charla.
var sin_jarra: bool = false

var _fig: Node3D
var _jarra: Node3D
var _espera: float = 0.0
var _vida: float = 0.0
var _risa: float = 0.0
var _desfase: float = 0.0
var _brindando: bool = false


func _ready() -> void:
	_fig = FIGURA.instantiate() as Node3D
	VESTUARIO.aplicar(_fig, ropa)
	add_child(_fig)
	_vida = randf() * TAU
	_espera = randf_range(0.2, 2.5)
	_desfase = float(absi(corro.hash()) % 1000) / 1000.0 * CICLO
	if not sin_jarra:
		_jarra = _hacer_jarra()
		var codo := _fig.get_node_or_null(^"Cuerpo/HombroDer/Codo") as Node3D
		if codo != null:
			codo.add_child(_jarra)
			_jarra.position = Vector3(0.0, -0.31, 0.05)
		_postura(SOSTENER)


func _process(delta: float) -> void:
	_vida += delta
	# Vaivén de quien lleva un rato bebiendo.
	rotation.z = sin(_vida * 0.8) * 0.035
	# Risa: saltitos cortos tras brindar.
	_risa = maxf(_risa - delta, 0.0)
	_fig.position.y = absf(sin(_vida * 11.0)) * 0.03 * minf(_risa, 1.0)

	if _jarra != null:
		_gestos(delta)
		# La jarra siempre derecha, gire como gire el brazo.
		var z := _fig.global_basis.z
		_jarra.global_basis = Basis(Vector3.UP, atan2(z.x, z.z)).scaled(_fig.global_basis.get_scale())


func _gestos(delta: float) -> void:
	if not corro.is_empty():
		var t := fmod(Time.get_ticks_msec() / 1000.0 + _desfase, CICLO)
		var toca := t < DURA_BRINDIS
		if toca != _brindando:
			_brindando = toca
			if toca:
				_postura(BRINDAR)
			else:
				_risa = 1.4
				_postura(SOSTENER)
				_espera = randf_range(1.0, 2.5)
		if _brindando:
			return
	_espera -= delta
	if _espera > 0.0:
		return
	# Entre brindis: sostener o echar un trago.
	if randf() < 0.4:
		_postura(BEBER)
		_espera = randf_range(1.2, 2.0)
	else:
		_postura(SOSTENER)
		_espera = randf_range(1.5, 3.5)


func _postura(p: Vector2) -> void:
	_fig.set(&"brazo_derecho", p.x)
	_fig.set(&"codo_derecho", p.y)


## Jarra de peltre con espuma.
func _hacer_jarra() -> Node3D:
	var jarra := Node3D.new()
	jarra.name = "Jarra"
	var cuerpo := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.06
	c.bottom_radius = 0.065
	c.height = 0.15
	c.radial_segments = 10
	c.rings = 1
	cuerpo.mesh = c
	var peltre := StandardMaterial3D.new()
	peltre.albedo_color = Color(0.55, 0.52, 0.47)
	peltre.metallic = 0.5
	peltre.roughness = 0.5
	cuerpo.material_override = peltre
	jarra.add_child(cuerpo)
	var espuma := MeshInstance3D.new()
	var e := CylinderMesh.new()
	e.top_radius = 0.055
	e.bottom_radius = 0.06
	e.height = 0.03
	e.radial_segments = 10
	e.rings = 1
	espuma.mesh = e
	var blanco := StandardMaterial3D.new()
	blanco.albedo_color = Color(0.95, 0.92, 0.82)
	espuma.material_override = blanco
	espuma.position.y = 0.085
	jarra.add_child(espuma)
	return jarra
