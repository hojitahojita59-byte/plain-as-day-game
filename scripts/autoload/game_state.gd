extends Node
## Estado global: capítulo, banderas y miasma. Sin contenido (va en res://data/).

signal flag_changed(flag: String, value: bool)
signal miasma_changed(value: float)

## Valor inicial: el jugador también cree en el miasma.
const MIASMA_INICIAL := 0.90
## Nunca llega a cero.
const MIASMA_MINIMO := 0.15

var chapter: int = 1
## Día del acto (1 = viernes 1 sept.); ver scripts/dias.gd.
var dia: int = 1
var scene_id: String = "ch1_s1_calle"

var _flags: Dictionary = {}
var _miasma: float = MIASMA_INICIAL


func has_flag(flag: String) -> bool:
	return _flags.get(flag, false)


func set_flag(flag: String, value: bool = true) -> void:
	if _flags.get(flag, false) == value:
		return
	_flags[flag] = value
	flag_changed.emit(flag, value)


## Condiciones = nombres de bandera; "!" niega.
func conditions_met(conditions: Array) -> bool:
	for c in conditions:
		var condition := String(c)
		if condition.begins_with("!"):
			if has_flag(condition.substr(1)):
				return false
		elif not has_flag(condition):
			return false
	return true


func get_miasma() -> float:
	return _miasma


## Limitado a [MIASMA_MINIMO, 1].
func set_miasma(value: float) -> void:
	var clamped := clampf(value, MIASMA_MINIMO, 1.0)
	if is_equal_approx(clamped, _miasma):
		return
	_miasma = clamped
	miasma_changed.emit(_miasma)


func to_dict() -> Dictionary:
	return {
		"chapter": chapter,
		"dia": dia,
		"scene_id": scene_id,
		"flags": _flags.duplicate(),
		"miasma": _miasma,
	}


func from_dict(d: Dictionary) -> void:
	chapter = int(d.get("chapter", 1))
	dia = int(d.get("dia", 1))
	scene_id = String(d.get("scene_id", "ch1_s1_calle"))
	_flags = Dictionary(d.get("flags", {}))
	# Partidas de antes de los días: se deduce el día por lo hecho.
	if not d.has("dia"):
		if has_flag("buried_frances_lewis") or has_flag("saw_the_cluster"):
			dia = 3
		elif has_flag("parish_book_read") or has_flag("hablado_ch1_s3_puerta_40"):
			dia = 2
		for n in range(2, dia + 1):
			_flags["dia_%d" % n] = true
		_flags["apertura_vista"] = true
		if dia > 1:
			_flags["lista_1"] = true
	_miasma = float(d.get("miasma", MIASMA_INICIAL))
	miasma_changed.emit(_miasma)


## Nueva partida: este autoload conserva las banderas entre escenas.
func reset() -> void:
	chapter = 1
	dia = 1
	scene_id = "ch1_s1_calle"
	_flags.clear()
	_miasma = MIASMA_INICIAL
	miasma_changed.emit(_miasma)
