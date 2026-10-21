extends Camera3D
## Cámara que sigue a Whitehead. Nunca gira: solo se mueve la posición.

## Si está vacío, sigue al primer CharacterBody3D de la escena.
@export var objetivo_path: NodePath

## Debe casar con la rotación del nodo: (0, 8, 10) => unos -38,6° en X.
@export var desplazamiento: Vector3 = Vector3(0, 8, 10)

## Alto = pegada; bajo = blanda. 4-6 va bien.
@export var suavidad: float = 5.0

@export_group("Límites de la calle")
## Límites de la cámara (no del personaje), para no ver el borde del mundo.
@export var limite_x: Vector2 = Vector2(-6.0, 6.0)
@export var limite_z: Vector2 = Vector2(-2.0, 4.0)

var _objetivo: Node3D = null


func _ready() -> void:
	if not objetivo_path.is_empty():
		_objetivo = get_node_or_null(objetivo_path) as Node3D

	if _objetivo == null:
		_objetivo = _buscar_personaje(get_tree().current_scene)

	if _objetivo == null:
		push_warning("CamaraSeguimiento: no encuentro a quién seguir; me quedo quieta.")
		return

	# Empezar ya colocada, sin viajar desde la posición del editor.
	global_position = _posicion_deseada()


func _buscar_personaje(nodo: Node) -> Node3D:
	if nodo == null:
		return null
	if nodo is CharacterBody3D:
		return nodo as Node3D
	for hijo in nodo.get_children():
		var encontrado := _buscar_personaje(hijo)
		if encontrado != null:
			return encontrado
	return null


func _posicion_deseada() -> Vector3:
	var p := _objetivo.global_position + desplazamiento
	p.x = clampf(p.x, limite_x.x + desplazamiento.x, limite_x.y + desplazamiento.x)
	p.z = clampf(p.z, limite_z.x + desplazamiento.z, limite_z.y + desplazamiento.z)
	p.y = desplazamiento.y
	return p


func _physics_process(delta: float) -> void:
	if _objetivo == null:
		return
	# exp(): suavizado independiente de los fps.
	var t := 1.0 - exp(-suavidad * delta)
	global_position = global_position.lerp(_posicion_deseada(), t)
