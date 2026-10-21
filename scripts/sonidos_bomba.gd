extends RefCounted
## Sonidos de la bomba generados (no hay muestras): palanca que chirría, chorro de agua y cubo de hierro.

const HZ := 22050

static var _palanca: AudioStreamWAV
static var _chorro: AudioStreamWAV
static var _cubo: AudioStreamWAV


## Chirrido de hierro seco y golpe sordo al llegar abajo.
static func palanca() -> AudioStreamWAV:
	if _palanca == null:
		var rng := RandomNumberGenerator.new()
		rng.seed = 18
		_palanca = _hacer(0.62, func(t: float) -> float:
			var chirrido := 0.0
			if t < 0.42:
				var f := 520.0 + 260.0 * sin(t * 9.0) + 90.0 * sin(t * 61.0)
				var raspa := 0.6 + 0.4 * sin(TAU * 38.0 * t)
				chirrido = sin(TAU * f * t + 2.0 * sin(TAU * f * 1.5 * t)) * raspa * 0.22 * minf(1.0, t * 30.0) * (1.0 - t / 0.42)
			var golpe := 0.0
			if t > 0.42:
				var u := t - 0.42
				golpe = (sin(TAU * 95.0 * u) * 0.7 + sin(TAU * 233.0 * u) * 0.3 + rng.randf_range(-0.3, 0.3)) * exp(-u * 26.0) * 0.8
			return chirrido + golpe)
	return _palanca


## Chorro: ruido filtrado que crece y se corta, con borboteo.
static func chorro() -> AudioStreamWAV:
	if _chorro == null:
		var rng := RandomNumberGenerator.new()
		rng.seed = 54
		var previo := [0.0, 0.0]
		_chorro = _hacer(0.75, func(t: float) -> float:
			previo[0] = previo[0] * 0.82 + rng.randf_range(-1.0, 1.0) * 0.18
			previo[1] = previo[1] * 0.5 + previo[0] * 0.5
			var env := minf(1.0, t * 12.0) * clampf((0.75 - t) * 5.0, 0.0, 1.0)
			var burbuja := 0.25 * sin(TAU * (300.0 + 120.0 * sin(t * 40.0)) * t) * maxf(0.0, sin(t * 47.0))
			return (previo[1] * 1.6 + burbuja) * env * 0.55)
	return _chorro


## Cubo de hierro que se deja en el suelo: parciales metálicos que se apagan.
static func cubo() -> AudioStreamWAV:
	if _cubo == null:
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		_cubo = _hacer(0.6, func(t: float) -> float:
			var v := 0.0
			for p in [[410.0, 0.5, 9.0], [1130.0, 0.3, 14.0], [1870.0, 0.2, 20.0], [2690.0, 0.12, 26.0]]:
				v += float(p[1]) * sin(TAU * float(p[0]) * t) * exp(-t * float(p[2]))
			var golpe := rng.randf_range(-1.0, 1.0) * exp(-t * 90.0) * 0.6
			return (v + golpe) * 0.6)
	return _cubo


static func _hacer(segundos: float, onda: Callable) -> AudioStreamWAV:
	var n := int(HZ * segundos)
	var datos := PackedByteArray()
	datos.resize(n * 2)
	for i in n:
		var v: float = onda.call(float(i) / HZ)
		datos.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32767.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = HZ
	s.stereo = false
	s.data = datos
	return s
