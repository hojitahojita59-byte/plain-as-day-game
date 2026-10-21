extends Node3D
## Whitehead como sprite PNG en 3D. Sin PNG se oculta y queda la figura de cajas.
## No gira con el personaje: cambia de dibujo según la dirección.


## Rutas por defecto si no se asignan en el Inspector.
const RUTA_FRENTE := "res://art/actors/whitehead/frente.png"
const RUTA_ESPALDA := "res://art/actors/whitehead/espalda.png"
const RUTA_LADO := "res://art/actors/whitehead/lado.png"

## Cuadros del andar (p.ej. frente_1.png...), por patrón: el editor borra listas.
const PATRON_CUADROS := "res://art/actors/whitehead/%s_%d.png"
const CUADROS_MAX := 12

## Interruptor: false = usar la figura de cajas.
@export var usar_dibujo: bool = true

## Px de dibujo por metro de mundo. Ajustar esto, no la escala del nodo.
@export var px_por_metro: float = 250.0

## Altura en m. Si > 0, manda sobre `px_por_metro`.
@export var altura_metros: float = 0.0

## Ajuste vertical en m para cuadrar los pies.
@export var ajuste_altura: float = 0.0

## Recibe la luz de la escena (sin ella brilla demasiado).
@export var iluminado: bool = true

## Inclinar hacia la cámara para no verlo achatado (cos 42° = 74%).
@export var mirar_a_camara: bool = true

@export_group("Vida")
## Zancadas por metro (la fase avanza con la distancia).
@export var cadencia: float = 2.1
## Rebote por paso, en m.
@export var rebote: float = 0.035
## Balanceo lateral en rad (0,035 ≈ 2°).
@export var vaiven: float = 0.035
## Respiración parado, en m.
@export var respiracion: float = 0.012
## Achatamiento al apoyar el pie.
@export var aplastado: float = 0.022
## Velocidad de paso normal (m/s); por debajo se atenúa.
@export var velocidad_normal: float = 3.0

@export_group("Dibujos")
## Vacías = cargar de las rutas. Solo el frontal es obligatorio.
@export var textura_frente: Texture2D
@export var textura_espalda: Texture2D
@export var textura_lado: Texture2D

## Nodo hermano con la figura de cajas, a ocultar.
@export var figura_de_cajas: String = "Figura"

var _pivote: Node3D
var _dibujo: Sprite3D
var _padre: Node3D = null
var _actor: CharacterBody3D = null
var _pos_anterior: Vector3 = Vector3.ZERO
var _fase: float = 0.0
var _base_y: float = 0.0
var _alto_m: float = 1.85

## Cuadros del andar por dirección.
var _cuadros: Dictionary = {"frente": [], "espalda": [], "lado": []}

## Se guardan para seguir mirando igual al pararse.
var _direccion: String = "frente"
var _volteado: bool = false


func _ready() -> void:
	_pivote = get_node_or_null(^"Pivote") as Node3D
	_dibujo = get_node_or_null(^"Pivote/Dibujo") as Sprite3D
	if _pivote == null or _dibujo == null:
		push_warning("FiguraSprite: me faltan los nodos Pivote/Dibujo.")
		visible = false
		return

	if not usar_dibujo:
		visible = false
		set_process(false)
		return

	_cargar_dibujos()

	if textura_frente == null:
		# Avisar si el PNG existe pero Godot no lo ha importado.
		if FileAccess.file_exists(RUTA_FRENTE):
			push_warning(
				"FiguraSprite: %s existe pero Godot no lo ha importado. " % RUTA_FRENTE
				+ "Sale el muñeco de cajas en su lugar. "
				+ "Selecciona el PNG en el panel FileSystem y pulsa Reimportar.")
		visible = false
		set_process(false)
		return

	_esconder_las_cajas()
	_colocar()

	_padre = get_parent() as Node3D
	_actor = _padre as CharacterBody3D
	if _padre != null:
		_pos_anterior = _padre.global_position


## Carga lo no asignado; `exists` evita errores si aún no hay PNG.
func _cargar_dibujos() -> void:
	if textura_frente == null and ResourceLoader.exists(RUTA_FRENTE):
		textura_frente = load(RUTA_FRENTE) as Texture2D
	if textura_espalda == null and ResourceLoader.exists(RUTA_ESPALDA):
		textura_espalda = load(RUTA_ESPALDA) as Texture2D
	if textura_lado == null and ResourceLoader.exists(RUTA_LADO):
		textura_lado = load(RUTA_LADO) as Texture2D

	for direccion in _cuadros.keys():
		_cuadros[direccion] = _buscar_cuadros(String(direccion))
	var n: int = (_cuadros["frente"] as Array).size()
	if n > 0:
		print("[FiguraSprite] %d cuadros de andar de frente." % n)


## Carga 1, 2, 3... hasta el primer hueco.
func _buscar_cuadros(direccion: String) -> Array[Texture2D]:
	var lista: Array[Texture2D] = []
	for i in range(1, CUADROS_MAX + 1):
		var ruta := PATRON_CUADROS % [direccion, i]
		if not ResourceLoader.exists(ruta):
			break
		var t := load(ruta) as Texture2D
		if t == null:
			break
		lista.append(t)
	return lista


func _esconder_las_cajas() -> void:
	var padre := get_parent()
	if padre == null:
		return
	var cajas := padre.get_node_or_null(NodePath(figura_de_cajas)) as Node3D
	if cajas != null:
		cajas.visible = false


## Escala a metros midiendo la parte opaca (no el lienzo) y apoya los pies.
func _colocar() -> void:
	_dibujo.texture = textura_frente
	_dibujo.shaded = iluminado
	_dibujo.centered = true

	var lienzo_px := float(textura_frente.get_height())
	var caja := _recuadro_util(textura_frente)
	var figura_px: float = maxf(caja.y, 1.0)
	var margen_abajo_px: float = maxf(caja.z, 0.0)

	if altura_metros > 0.0:
		_dibujo.pixel_size = altura_metros / figura_px
	else:
		_dibujo.pixel_size = 1.0 / maxf(px_por_metro, 1.0)

	_alto_m = figura_px * _dibujo.pixel_size

	# Pivote en los pies: inclina, aplasta y rebota sobre el suelo.
	_base_y = ajuste_altura
	_pivote.position.y = _base_y
	_dibujo.position.y = (lienzo_px * 0.5 - margen_abajo_px) * _dibujo.pixel_size

	print("[FiguraSprite] Lienzo %d px, figura %d px = %.2f m de alto." % [
		int(lienzo_px), int(figura_px), _alto_m])


## (alto lienzo, alto figura, aire por debajo), en px.
func _recuadro_util(t: Texture2D) -> Vector3:
	var img := t.get_image()
	if img == null:
		return Vector3(float(t.get_height()), float(t.get_height()), 0.0)
	if img.is_compressed():
		img.decompress()

	var alto := img.get_height()
	var ancho := img.get_width()
	var arriba := -1
	var abajo := -1
	for y in alto:
		var hay := false
		for x in ancho:
			if img.get_pixel(x, y).a > 0.02:
				hay = true
				break
		if not hay:
			continue
		if arriba < 0:
			arriba = y
		abajo = y

	if arriba < 0:
		# Todo transparente: evitar división por cero.
		return Vector3(float(alto), float(alto), 0.0)

	return Vector3(float(alto), float(abajo - arriba + 1), float(alto - 1 - abajo))


func _process(delta: float) -> void:
	if _dibujo == null:
		return

	_encarar_camara()

	# Velocidad del CharacterBody3D o, si no, medida por desplazamiento.
	var vel := Vector3.ZERO
	if _actor != null:
		vel = _actor.velocity
	elif _padre != null and delta > 0.0:
		vel = (_padre.global_position - _pos_anterior) / delta
		_pos_anterior = _padre.global_position

	var rapidez := Vector2(vel.x, vel.z).length()

	# Parado: solo respira.
	if rapidez < 0.05:
		_fase += delta * 1.1
		_pivote.position.y = _base_y + sin(_fase) * respiracion
		_pivote.rotation.z = lerpf(_pivote.rotation.z, 0.0, 1.0 - exp(-7.0 * delta))
		_pivote.scale = _pivote.scale.lerp(Vector3.ONE, 1.0 - exp(-9.0 * delta))
		_dibujo.texture = _quieto(_direccion)
		return

	if rapidez > 0.08:
		_direccion = _hacia_donde(vel)

	_fase += rapidez * cadencia * delta
	var fuerza := clampf(rapidez / maxf(velocidad_normal, 0.01), 0.0, 1.0)

	# Rebote al doble de frecuencia que el vaivén.
	var alzada := absf(sin(_fase))
	_pivote.position.y = _base_y + alzada * rebote * fuerza
	_pivote.rotation.z = sin(_fase * 0.5) * vaiven * fuerza

	# Aplasta al tocar el pie (alzada = 0); ^4 = golpe seco.
	var golpe := pow(1.0 - alzada, 4.0) * aplastado * fuerza
	_pivote.scale = Vector3(1.0 + golpe * 0.5, 1.0 - golpe, 1.0)

	_dibujo.texture = _cuadro_del_paso(_direccion)
	_dibujo.flip_h = _volteado


## Inclina el sprite hacia la cámara, solo en picado (no gira en horizontal).
func _encarar_camara() -> void:
	if not mirar_a_camara:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var eje := global_transform.basis.inverse() * cam.global_transform.basis.z
	_pivote.rotation.x = -atan2(eje.y, eje.z)


## Dirección del dibujo. Supone cámara fija: Z hacia ella, X a lo largo de la calle.
func _hacia_donde(vel: Vector3) -> String:
	if not (_cuadros["lado"] as Array).is_empty() or textura_lado != null:
		if absf(vel.x) > absf(vel.z) * 1.3:
			_volteado = vel.x < 0.0  # el lateral mira a la derecha
			return "lado"

	_volteado = false
	if vel.z < 0.0 and (not (_cuadros["espalda"] as Array).is_empty() or textura_espalda != null):
		return "espalda"
	return "frente"


## Dibujo quieto de una dirección; si falta, el frontal.
func _quieto(direccion: String) -> Texture2D:
	match direccion:
		"espalda":
			if textura_espalda != null:
				return textura_espalda
		"lado":
			if textura_lado != null:
				return textura_lado
	return textura_frente


## Cuadro según la fase: una zancada (2π) recorre todos los cuadros.
func _cuadro_del_paso(direccion: String) -> Texture2D:
	var lista: Array = _cuadros.get(direccion, [])
	if lista.is_empty():
		return _quieto(direccion)
	var n := lista.size()
	var i := int(floor(_fase / TAU * float(n))) % n
	if i < 0:
		i += n
	return lista[i] as Texture2D
