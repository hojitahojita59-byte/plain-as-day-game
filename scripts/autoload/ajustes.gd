extends Node
## Ajustes del jugador (volumen) en user://ajustes.cfg, aparte de la partida.

const RUTA := "user://ajustes.cfg"

## Buses agrupados en tres mandos.
const GRUPOS := {
	"maestro": ["Master"],
	"musica": ["Musica"],
	"efectos": ["Ambiente", "Efectos", "Voz", "Interfaz"],
}

## Volumen 0-1 por grupo (se pasa a dB al aplicar).
var volumen: Dictionary = {"maestro": 1.0, "musica": 0.8, "efectos": 1.0}

## dB base de cada bus en default_bus_layout.tres; el máximo vuelve a él.
var _base: Dictionary = {}


func _ready() -> void:
	for grupo in GRUPOS:
		for bus in GRUPOS[grupo]:
			var i := AudioServer.get_bus_index(bus)
			if i >= 0:
				_base[bus] = AudioServer.get_bus_volume_db(i)
	cargar()


func poner_volumen(grupo: String, v: float) -> void:
	if not GRUPOS.has(grupo):
		return
	volumen[grupo] = clampf(v, 0.0, 1.0)
	_aplicar_volumen(grupo)
	guardar()


## 0-1 a dB con linear_to_db; 0 = mute (linear_to_db(0) es -inf).
func _aplicar_volumen(grupo: String) -> void:
	var v: float = float(volumen.get(grupo, 1.0))
	for bus in GRUPOS[grupo]:
		var i := AudioServer.get_bus_index(bus)
		if i < 0:
			continue
		if v <= 0.0:
			AudioServer.set_bus_mute(i, true)
			continue
		AudioServer.set_bus_mute(i, false)
		AudioServer.set_bus_volume_db(i, float(_base.get(bus, 0.0)) + linear_to_db(v))


func aplicar_todo() -> void:
	for grupo in GRUPOS:
		_aplicar_volumen(grupo)


func guardar() -> void:
	var c := ConfigFile.new()
	for grupo in volumen:
		c.set_value("audio", String(grupo), volumen[grupo])
	c.save(RUTA)


func cargar() -> void:
	var c := ConfigFile.new()
	if c.load(RUTA) == OK:
		for grupo in GRUPOS:
			volumen[grupo] = clampf(float(c.get_value("audio", grupo,
				volumen.get(grupo, 1.0))), 0.0, 1.0)
	aplicar_todo()
