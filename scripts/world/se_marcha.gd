extends Node3D
## Hijo de un NPC: lo hace irse andando cuando ya ha dicho lo suyo.

## Bandera que arma la marcha; se va al cerrarse el diálogo. Si ya está, no aparece.
@export var bandera: String = ""

## Destino en coords. del mundo (fuera de cuadro). No usa navegación.
@export var destino: Vector3 = Vector3(-15.0, 0.0, 2.0)

## m/s.
@export var velocidad: float = 1.9

## Segundos de pausa antes de echar a andar.
@export var espera: float = 0.8

var _npc: Node3D = null
var _armado: bool = false
var _andando: bool = false
var _cuenta: float = 0.0


func _ready() -> void:
	_npc = get_parent() as Node3D
	if _npc == null or bandera.is_empty():
		set_process(false)
		return

	if GameState.has_flag(bandera):
		# Ya se fue en esta partida.
		_npc.queue_free()
		return

	GameState.flag_changed.connect(_al_cambiar_bandera)
	# La bandera se pone a mitad de diálogo: esperar a que se cierre.
	DialogueRunner.dialogue_finished.connect(_al_cerrarse_el_dialogo)
	set_process(false)


func _al_cambiar_bandera(nombre: String, valor: bool) -> void:
	if nombre != bandera or not valor or _armado:
		return
	_armado = true
	# Fuera de conversación (p.ej. al cargar), no hay que esperar.
	if not DialogueRunner.active:
		_echar_a_andar()


func _al_cerrarse_el_dialogo(_id: String) -> void:
	if _armado and not _andando:
		_echar_a_andar()


func _echar_a_andar() -> void:
	_andando = true
	_cuenta = espera
	# Deja de ser clicable al irse.
	if _npc is CollisionObject3D:
		(_npc as CollisionObject3D).input_ray_pickable = false
		(_npc as CollisionObject3D).set_collision_layer_value(1, false)
	set_process(true)


func _process(delta: float) -> void:
	if not _andando or _npc == null:
		return

	if _cuenta > 0.0:
		_cuenta -= delta
		return

	var paso := destino - _npc.global_position
	paso.y = 0.0
	if paso.length() < 0.3:
		_npc.queue_free()
		return

	_npc.global_position += paso.normalized() * velocidad * delta
