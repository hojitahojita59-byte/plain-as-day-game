extends Node
## Cronómetro oculto de playtests: tiempo jugado, inactivo, por escena e hitos.
## Se guarda en la partida y en user://cronometro/partida_<inicio>.json.

const CARPETA := "user://cronometro/"
## Segundos sin input a partir de los cuales el tiempo cuenta como inactivo.
const INACTIVO := 90.0
## Cada cuántos s se escribe el archivo, aunque no haya progreso.
const CADA := 30.0

var inicio: String = ""
var jugado: float = 0.0
var inactivo: float = 0.0
var leyendo: float = 0.0
var por_escena: Dictionary = {}
var hitos: Array[Dictionary] = []

var _vistos: Dictionary = {}
var _quieto: float = 0.0
var _con_foco: bool = true
var _en_dialogo: bool = false
var _desde_escritura: float = 0.0


func _ready() -> void:
	GameState.flag_changed.connect(func(f: String, v: bool):
		if v: _hito("bandera", f))
	Casefile.evidence_collected.connect(func(id: String): _hito("prueba", id))
	Casefile.recorded.connect(func(e: Dictionary): _hito("asiento", String(e.get("id", ""))))
	DialogueRunner.line_shown.connect(func(_n: Dictionary): _en_dialogo = true)
	DialogueRunner.dialogue_finished.connect(func(id: String):
		_en_dialogo = false
		_hito("dialogo", id))


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			_con_foco = false
		NOTIFICATION_APPLICATION_FOCUS_IN:
			_con_foco = true
		NOTIFICATION_WM_CLOSE_REQUEST:
			escribir()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton or event is InputEventKey or event is InputEventMouseMotion:
		_quieto = 0.0


func _process(delta: float) -> void:
	if not _con_foco or inicio.is_empty():
		return
	var escena := _escena()
	if escena.is_empty() or escena.begins_with("menu"):
		return

	_quieto += delta
	if _quieto > INACTIVO:
		inactivo += delta
		return

	jugado += delta
	por_escena[escena] = float(por_escena.get(escena, 0.0)) + delta
	if _en_dialogo:
		leyendo += delta

	_desde_escritura += delta
	if _desde_escritura >= CADA:
		escribir()


## Nueva partida (lo llama el menú).
func reset() -> void:
	inicio = Time.get_datetime_string_from_system().replace(":", "-")
	jugado = 0.0
	inactivo = 0.0
	leyendo = 0.0
	por_escena = {}
	hitos = []
	_vistos = {}
	_quieto = 0.0
	_en_dialogo = false


func to_dict() -> Dictionary:
	return {
		"inicio": inicio,
		"jugado": snappedf(jugado, 0.1),
		"inactivo": snappedf(inactivo, 0.1),
		"leyendo": snappedf(leyendo, 0.1),
		"por_escena": _redondeado(por_escena),
		"hitos": hitos.duplicate(),
	}


func from_dict(d: Dictionary) -> void:
	reset()
	# Partidas sin cronómetro: empieza a contar desde aquí.
	if d.is_empty():
		return
	inicio = String(d.get("inicio", inicio))
	jugado = float(d.get("jugado", 0.0))
	inactivo = float(d.get("inactivo", 0.0))
	leyendo = float(d.get("leyendo", 0.0))
	por_escena = Dictionary(d.get("por_escena", {}))
	for h in Array(d.get("hitos", [])):
		hitos.append(Dictionary(h))
		_vistos[String(h.get("que", ""))] = true


## Escribe el archivo (desde SaveSystem y cada CADA s).
func escribir() -> void:
	_desde_escritura = 0.0
	if inicio.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CARPETA))
	var f := FileAccess.open(CARPETA + "partida_%s.json" % inicio, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(to_dict(), "\t"))


func _hito(tipo: String, id: String) -> void:
	if inicio.is_empty() or id.is_empty():
		return
	var que := tipo + ":" + id
	if _vistos.has(que):
		return
	_vistos[que] = true
	hitos.append({"que": que, "segundo": snappedf(jugado, 0.1), "escena": _escena()})


func _escena() -> String:
	var actual := get_tree().current_scene
	if actual == null:
		return ""
	return actual.scene_file_path.get_file().get_basename()


func _redondeado(d: Dictionary) -> Dictionary:
	var out := {}
	for k in d:
		out[k] = snappedf(float(d[k]), 0.1)
	return out
