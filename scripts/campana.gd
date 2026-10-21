extends RefCounted
## Toque de campana generado (no hay muestra): parciales de campana con caída.

const HZ := 22050
const SEGUNDOS := 3.4
const FUNDAMENTAL := 196.0
## [razón, amplitud, caída/s]: hum, prima, tercera menor, quinta, nominal...
const PARCIALES := [[0.5, 0.32, 0.5], [1.0, 0.5, 1.0], [1.19, 0.28, 1.5], [1.5, 0.16, 1.9],
	[2.0, 0.32, 1.7], [2.74, 0.12, 2.8], [3.01, 0.09, 3.4], [4.1, 0.05, 5.0]]

static var _sonido: AudioStreamWAV


static func sonido() -> AudioStreamWAV:
	if _sonido != null:
		return _sonido
	var n := int(HZ * SEGUNDOS)
	var datos := PackedByteArray()
	datos.resize(n * 2)
	for i in n:
		var t := float(i) / HZ
		var v := 0.0
		for p in PARCIALES:
			v += float(p[1]) * sin(TAU * FUNDAMENTAL * float(p[0]) * t) * exp(-t * float(p[2]))
		v *= minf(1.0, t * 500.0)
		datos.encode_s16(i * 2, int(clampf(v * 0.5, -1.0, 1.0) * 32767.0))
	_sonido = AudioStreamWAV.new()
	_sonido.format = AudioStreamWAV.FORMAT_16_BITS
	_sonido.mix_rate = HZ
	_sonido.stereo = false
	_sonido.data = datos
	return _sonido
