extends Control
## Plano de la parroquia: calles, nº de casa, bomba y un punto por muerte.
## Coordenadas de 0 a 1, escaladas al tamaño del control.

const TINTA := Color(0.16, 0.12, 0.09)
const TINTA_PALIDA := Color(0.46, 0.39, 0.31)
const CALLE := Color(0.80, 0.76, 0.66)
const PUNTO := Color(0.13, 0.10, 0.08)

@export var fuente: Font

## El plano es la calle 3D vista desde arriba: plano = mundo / ESCALA + ORIGEN.
const ESCALA := 150.0
const ORIGEN := Vector2(0.5, 0.62)
const BARRIO := "res://data/barrio/soho.json"

## Calles en metros (x, z del mundo): horizontal?, eje, de/a, ancho; contexto = no se anda.
const CALLES_M := [
	{"n": "Broad Street", "h": true, "en": 1.75, "de": -72.0, "a": 72.0, "w": 13.5},
	{"n": "Cambridge Street", "h": false, "en": -15.0, "de": -40.0, "a": 1.75, "w": 10.0},
	{"n": "New Street", "h": false, "en": -35.0, "de": -25.0, "a": 1.75, "w": 10.0},
	{"n": "Peter Street", "h": false, "en": 35.0, "de": -25.0, "a": 1.75, "w": 10.0},
	{"n": "Marshall Street", "h": false, "en": -72.0, "de": -62.0, "a": 32.0, "w": 9.0, "contexto": true},
	{"n": "Poland Street", "h": false, "en": 72.0, "de": -62.0, "a": 32.0, "w": 9.0, "contexto": true},
	{"n": "Great Marlborough Street", "h": true, "en": -62.0, "de": -72.0, "a": 72.0, "w": 9.0, "contexto": true},
	{"n": "Silver Street", "h": true, "en": 32.0, "de": -72.0, "a": 72.0, "w": 9.0, "contexto": true},
]

## Calle de cada tramo de la calle 3D (por el principio del id).
const CALLE_DE_TRAMO := {"broad": "Broad Street", "cambridge": "Cambridge Street",
	"new": "New Street", "peter": "Peter Street"}

## Margen del clic a lo largo de la calle (algo menos de una casa).
const HOLGURA := 0.025

static var CALLES: Array = _calles()
## "38 Broad Street" -> {punto: en la acera, casa: centro de la casa} (plano).
static var DIRECCIONES: Dictionary = _direcciones()
static var BOMBA: Vector2 = de_mundo(Vector2(-3.0, 0.6))


static func de_mundo(p: Vector2) -> Vector2:
	return p / ESCALA + ORIGEN


static func a_mundo(p: Vector2) -> Vector2:
	return (p - ORIGEN) * ESCALA


static func _calles() -> Array:
	var out: Array = []
	for c in CALLES_M:
		var d: Dictionary = c.duplicate()
		var eje := 1 if bool(c["h"]) else 0
		d["en"] = float(c["en"]) / ESCALA + ORIGEN[eje]
		d["de"] = float(c["de"]) / ESCALA + ORIGEN[1 - eje]
		d["a"] = float(c["a"]) / ESCALA + ORIGEN[1 - eje]
		d["w"] = float(c["w"]) / ESCALA
		out.append(d)
	return out


## Las casas con número: las puertas de soho.json y su tabla "direcciones".
static func _direcciones() -> Dictionary:
	var datos: Variant = JSON.parse_string(FileAccess.get_file_as_string(BARRIO))
	if not (datos is Dictionary):
		return {}
	var tramos := {}
	for t in Array(datos.get("tramos", [])):
		tramos[String(t["id"])] = t
	var out := {}
	for p in Array(datos.get("puertas", [])):
		var t: Dictionary = tramos.get(String(p.get("tramo", "")), {})
		var calle := _calle_de_tramo(String(p.get("tramo", "")))
		if not t.is_empty() and not calle.is_empty():
			out["%s %s" % [String(p["numero"]), calle]] = _casa_de_bahia(t, int(p.get("bahia", 0)))
	for k in Dictionary(datos.get("direcciones", {})):
		var v: Variant = datos["direcciones"][k]
		if v is Array:
			var t: Dictionary = tramos.get(String(v[0]), {})
			if not t.is_empty():
				out[String(k)] = _casa_de_bahia(t, int(v[1]))
		elif v is Dictionary:
			var c: Array = v["casa"]
			var q: Array = v["punto"]
			out[String(k)] = {"casa": de_mundo(Vector2(float(c[0]), float(c[1]))),
				"punto": de_mundo(Vector2(float(q[0]), float(q[1])))}
	return out


static func _calle_de_tramo(id: String) -> String:
	for prefijo in CALLE_DE_TRAMO:
		if id.begins_with(String(prefijo)):
			return String(CALLE_DE_TRAMO[prefijo])
	return ""


## Bahía de un tramo: centro de la casa y un punto en la acera, delante.
static func _casa_de_bahia(t: Dictionary, b: int) -> Dictionary:
	var desde: Array = t.get("desde", [0, 0])
	var paso := {"+x": Vector2(5, 0), "-x": Vector2(-5, 0), "+z": Vector2(0, 5), "-z": Vector2(0, -5)}
	var fuera := {"+x": Vector2(1, 0), "-x": Vector2(-1, 0), "+z": Vector2(0, 1), "-z": Vector2(0, -1)}
	var casa := Vector2(float(desde[0]), float(desde[1])) + Vector2(paso[String(t.get("eje", "+x"))]) * b
	var punto := casa + Vector2(fuera[String(t.get("mira", "+z"))]) * 3.5
	return {"casa": de_mundo(casa), "punto": de_mundo(punto)}


var _puntos: Array[Vector2] = []
var _cercado: bool = false

signal sitio_elegido(donde: Vector2)
## Centro y radios del círculo trazado, en coords 0-1.
signal circulo_trazado(centro: Vector2, radio: Vector2)

var _colocando: bool = false
var _raton: Vector2 = Vector2.ZERO
var _raton_dentro: bool = false
var _fresco: Vector2 = Vector2.ZERO
var _tinta: float = 0.0
var _destino: Vector2 = Vector2.INF

# Trazado del círculo
var _trazando: bool = false
var _arrastrando: bool = false
var _centro_px: Vector2 = Vector2.ZERO
var _radio_px: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


# --- Direcciones ---

static func _calle(nombre: String) -> Dictionary:
	for c in CALLES:
		if String(c["n"]) == nombre:
			return c
	return {}


## Punto de "38 Broad Street" en la acera, o INF si no existe esa casa.
static func punto_de(direccion: String) -> Vector2:
	var d: Dictionary = DIRECCIONES.get(direccion.strip_edges(), {})
	return d["punto"] if not d.is_empty() else Vector2.INF


## Centro de la casa de una dirección, o INF.
static func casa_de(direccion: String) -> Vector2:
	var d: Dictionary = DIRECCIONES.get(direccion.strip_edges(), {})
	return d["casa"] if not d.is_empty() else Vector2.INF


## Punto de un asiento por su dirección (o su "punto", si lo trae).
static func punto_de_asiento(a: Dictionary) -> Vector2:
	var p := punto_de(String(a.get("calle", "")))
	if p != Vector2.INF:
		var d: Array = Array(a.get("desvio", []))
		if d.size() == 2:
			p += Vector2(float(d[0]), float(d[1]))
		return p
	var escrito: Array = Array(a.get("punto", []))
	if escrito.size() == 2:
		return Vector2(float(escrito[0]), float(escrito[1]))
	return Vector2.INF


## Calles bajo un sitio del plano (dos en un cruce).
static func calles_en(sitio: Vector2, margen: float = 0.02) -> PackedStringArray:
	var out: PackedStringArray = []
	for c in CALLES:
		var a_lo_largo := sitio.x if bool(c["h"]) else sitio.y
		var a_traves := sitio.y if bool(c["h"]) else sitio.x
		var medio := float(c["w"]) * 0.5 + margen
		if absf(a_traves - float(c["en"])) <= medio \
				and a_lo_largo >= float(c["de"]) - 0.02 and a_lo_largo <= float(c["a"]) + 0.02:
			out.append(String(c["n"]))
	return out


## "" si el clic vale; si no, pista (calle o dirección), nunca el sitio exacto.
## margen: cuánto fuera del borde vale (la maqueta deja clicar el tejado).
static func juzgar(direccion: String, clic: Vector2, verdadero: Vector2, margen: float = 0.02) -> String:
	var nombre := direccion
	var partes := direccion.split(" ", false, 1)
	if partes.size() == 2 and partes[0].is_valid_int():
		nombre = String(partes[1])
	var c := _calle(nombre)
	if c.is_empty():
		return "" if clic.distance_to(verdadero) < 0.06 else "That is not where it is."
	if not (nombre in calles_en(clic, margen)):
		return "%s is not there. Find %s on the map." % [direccion, nombre]
	var a_lo_largo := clic.x if bool(c["h"]) else clic.y
	var debe := verdadero.x if bool(c["h"]) else verdadero.y
	if absf(a_lo_largo - debe) <= HOLGURA:
		return ""
	var mas := debe > a_lo_largo
	var hacia := ("to the right" if mas else "to the left") if bool(c["h"]) else ("further down" if mas else "further up")
	return "That is %s, but number %s is %s. Look at the house numbers." % [nombre, partes[0], hacia]


# --- Modos ---

## Modo clavar un punto; `destino` no se dibuja.
func colocar(si: bool, destino: Vector2 = Vector2.INF) -> void:
	_colocando = si
	_destino = destino
	_trazando = false
	set_process(_colocando)
	mouse_filter = Control.MOUSE_FILTER_STOP if _colocando else Control.MOUSE_FILTER_IGNORE
	mouse_default_cursor_shape = Control.CURSOR_CROSS if _colocando else Control.CURSOR_ARROW
	queue_redraw()


func trazar(si: bool) -> void:
	_trazando = si
	_arrastrando = false
	_radio_px = 0.0
	_colocando = false
	mouse_filter = Control.MOUSE_FILTER_STOP if si else Control.MOUSE_FILTER_IGNORE
	mouse_default_cursor_shape = Control.CURSOR_CROSS if si else Control.CURSOR_ARROW
	queue_redraw()


func trazando() -> bool:
	return _trazando


func _process(_delta: float) -> void:
	queue_redraw()


func celebrar(donde: Vector2) -> void:
	_fresco = donde
	_tinta = 1.0
	var t := create_tween()
	t.tween_method(func(v: float):
		_tinta = v
		queue_redraw(), 1.0, 0.0, 0.55).set_trans(Tween.TRANS_CUBIC)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_raton = (event as InputEventMouseMotion).position
		_raton_dentro = true
		if _trazando and _arrastrando:
			_radio_px = _raton.distance_to(_centro_px)
		queue_redraw()
		return
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if _colocando and mb.pressed:
		accept_event()
		_raton = mb.position
		if size.x > 0.0 and size.y > 0.0:
			sitio_elegido.emit(mb.position / size)
	elif _trazando:
		accept_event()
		if mb.pressed:
			_arrastrando = true
			_centro_px = mb.position
			_radio_px = 0.0
		elif _arrastrando:
			_arrastrando = false
			_radio_px = mb.position.distance_to(_centro_px)
			if _radio_px > 6.0 and size.x > 0.0 and size.y > 0.0:
				circulo_trazado.emit(_centro_px / size, Vector2(_radio_px / size.x, _radio_px / size.y))
		queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_raton_dentro = false
		queue_redraw()


func poner(asientos: Array) -> void:
	_puntos.clear()
	for a in asientos:
		var p := punto_de_asiento(Dictionary(a))
		if p != Vector2.INF:
			_puntos.append(p)
	queue_redraw()


func puntos() -> Array[Vector2]:
	return _puntos.duplicate()


## Puntos dentro de un círculo (coords 0-1).
func dentro(centro: Vector2, radio: Vector2) -> int:
	var n := 0
	for p in _puntos:
		var d := Vector2((p.x - centro.x) / maxf(radio.x, 0.0001), (p.y - centro.y) / maxf(radio.y, 0.0001))
		if d.length() <= 1.0:
			n += 1
	return n


func cercar() -> void:
	_cercado = true
	queue_redraw()


# --- Dibujo ---

func _draw() -> void:
	var s := size

	for c in CALLES:
		draw_rect(_rect_calle(c, s), CALLE)
		draw_rect(_rect_calle(c, s), TINTA_PALIDA, false, 1.0)

	# Los números de casa, donde está cada casa.
	if fuente != null:
		var t_num := clampi(int(s.y * 0.022), 9, 14)
		for k in DIRECCIONES:
			var casa: Vector2 = DIRECCIONES[k]["casa"] * s
			draw_string(fuente, casa + Vector2(-5.0, t_num * 0.35), String(k).split(" ")[0],
				HORIZONTAL_ALIGNMENT_LEFT, -1.0, t_num, TINTA)

	# Nombres de calle, centrados sobre su calle.
	if fuente != null:
		var t_nombre := clampi(int(s.y * 0.036), 12, 21)
		for c in CALLES:
			var r := _rect_calle(c, s)
			var texto := String(c["n"])
			var ancho := fuente.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1.0, t_nombre).x
			# En un tramo libre, sin cruces ni números.
			if bool(c["h"]):
				var x := (float(c["de"]) + float(c["a"])) * 0.5 * s.x - ancho * 0.5
				draw_string(fuente, Vector2(x, r.position.y - 5.0), texto,
					HORIZONTAL_ALIGNMENT_LEFT, -1.0, t_nombre, TINTA_PALIDA)
			else:
				# Girado, a lo largo de la calle vertical.
				draw_set_transform(Vector2(r.position.x - 5.0, (float(c["de"]) + float(c["a"])) * 0.5 * s.y + ancho * 0.5), -PI * 0.5)
				draw_string(fuente, Vector2.ZERO, texto, HORIZONTAL_ALIGNMENT_LEFT, -1.0, t_nombre, TINTA_PALIDA)
				draw_set_transform(Vector2.ZERO)

	var b := BOMBA * s
	draw_circle(b, 5.0, TINTA_PALIDA)
	draw_arc(b, 9.0, 0.0, TAU, 20, TINTA_PALIDA, 1.0)
	if fuente != null:
		# Encima de la calle: debajo la tapaban los puntos.
		draw_string(fuente, Vector2(b.x - 14.0, (BOMBA.y - 0.03) * s.y - 5.0), "pump",
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, clampi(int(s.y * 0.03), 11, 17), TINTA_PALIDA)

	for p in _puntos:
		draw_circle(p * s, 5.5, PUNTO)

	if _tinta > 0.001:
		var c2 := _fresco * s
		draw_circle(c2, 5.5 + 22.0 * _tinta, Color(PUNTO.r, PUNTO.g, PUNTO.b, 0.40 * _tinta))
		draw_arc(c2, 9.0 + 30.0 * _tinta, 0.0, TAU, 28,
			Color(PUNTO.r, PUNTO.g, PUNTO.b, 0.55 * _tinta), 2.0, true)

	# Con un nombre en la mano, un punto hueco sigue al ratón.
	if _colocando and _raton_dentro:
		draw_arc(_raton, 6.0, 0.0, TAU, 18, Color(PUNTO, 0.6), 1.6, true)

	if _trazando and (_arrastrando or _radio_px > 0.0):
		_trazo(_centro_px, Vector2(_radio_px, _radio_px), Color(TINTA, 0.75))

	if _cercado:
		var cir := Cuaderno.circulo()
		if cir.size() == 4:
			_trazo(Vector2(float(cir[0]), float(cir[1])) * s,
				Vector2(float(cir[2]) * s.x, float(cir[3]) * s.y), Color(TINTA, 0.85))
		elif not _puntos.is_empty():
			# Partidas antiguas sin círculo guardado: se rodea el centro de los puntos.
			var centro := Vector2.ZERO
			for p in _puntos:
				centro += p
			centro /= float(_puntos.size())
			var d: Array[float] = []
			for p in _puntos:
				d.append((p - centro).length())
			d.sort()
			var r: float = d[int(floor(float(d.size()) * 0.75))] * 1.55
			_trazo(centro * s, Vector2(maxf(r * s.x, 26.0), maxf(r * s.y, 26.0)), Color(TINTA, 0.85))


func _rect_calle(c: Dictionary, s: Vector2) -> Rect2:
	var grosor: float = float(c["w"]) * (s.y if bool(c["h"]) else s.x)
	if bool(c["h"]):
		return Rect2(Vector2(float(c["de"]) * s.x, float(c["en"]) * s.y - grosor * 0.5),
			Vector2((float(c["a"]) - float(c["de"])) * s.x, grosor))
	return Rect2(Vector2(float(c["en"]) * s.x - grosor * 0.5, float(c["de"]) * s.y),
		Vector2(grosor, (float(c["a"]) - float(c["de"])) * s.y))


## Círculo a mano alzada: radio ondulado con dos senos.
func _trazo(c: Vector2, r: Vector2, color: Color) -> void:
	if r.x < 2.0:
		return
	var puntos := PackedVector2Array()
	var pasos := 96
	for i in range(pasos + 12):
		var t := float(i) / float(pasos) * TAU
		var temblor := 1.0 + 0.030 * sin(t * 3.0 + 1.1) + 0.017 * sin(t * 5.0 + 2.7)
		puntos.append(c + Vector2(cos(t) * r.x, sin(t) * r.y) * temblor)
	draw_polyline(puntos, color, 2.0, true)
