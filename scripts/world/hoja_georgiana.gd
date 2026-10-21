@tool
extends MeshInstance3D
## Hoja de puerta de seis cuarterones, pintada, con pomo y aldaba de latón.
## Origen abajo en el centro, como la del kit (1,25 x 2,5); la cara a +z.

## Color de la pintura; se pone antes de entrar al árbol.
@export var color: Color = Color(0.12, 0.24, 0.16)

const ANCHO := 1.22
const ALTO := 2.48
const GRUESO := 0.08
const LATON := Color(0.8, 0.62, 0.3)

## Una malla por color: todas las puertas del mismo color la comparten.
static var _mallas: Dictionary = {}
static var _material: StandardMaterial3D


func _ready() -> void:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.vertex_color_use_as_albedo = true
		_material.roughness = 0.7
	var clave := color.to_html()
	if not _mallas.has(clave):
		_mallas[clave] = _hacer(color)
	mesh = _mallas[clave]
	material_override = _material


static func _hacer(c: Color) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_caja(st, Vector3(0, ALTO * 0.5, 0), Vector3(ANCHO, ALTO, GRUESO), c)
	# cuarterones: dos columnas, tres alturas, con su moldura más clara
	var altos := [0.55, 0.78, 0.62]
	var y := 0.2
	for f in 3:
		for lado in [-1.0, 1.0]:
			var centro := Vector3(float(lado) * ANCHO * 0.22, y + float(altos[f]) * 0.5, GRUESO * 0.5 + 0.01)
			_caja(st, centro, Vector3(ANCHO * 0.34, float(altos[f]), 0.02), c.lightened(0.14))
			_caja(st, centro + Vector3(0, 0, 0.012), Vector3(ANCHO * 0.26, float(altos[f]) - 0.1, 0.012), c)
		y += float(altos[f]) + 0.12
	# pomo, aldaba y buzón
	_caja(st, Vector3(ANCHO * 0.36, 1.1, GRUESO * 0.5 + 0.04), Vector3(0.07, 0.07, 0.06), LATON)
	_caja(st, Vector3(0, 1.62, GRUESO * 0.5 + 0.03), Vector3(0.14, 0.16, 0.03), LATON)
	_caja(st, Vector3(0, 1.0, GRUESO * 0.5 + 0.02), Vector3(0.26, 0.05, 0.02), LATON)
	return st.commit()


static func _caja(st: SurfaceTool, centro: Vector3, tam: Vector3, col: Color) -> void:
	var h := tam * 0.5
	var ejes: Array[Vector3] = [Vector3.RIGHT, Vector3.UP, Vector3.BACK]
	for i in 3:
		var j := (i + 1) % 3
		var l := (i + 2) % 3
		for sig in [-1.0, 1.0]:
			var n: Vector3 = ejes[i] * float(sig)
			var c0: Vector3 = centro + n * h[i]
			var ej: Vector3 = ejes[j] * h[j]
			var el: Vector3 = ejes[l] * h[l]
			var q := [c0 - ej - el, c0 + ej - el, c0 + ej + el, c0 - ej + el]
			for t in [[0, 1, 2], [0, 2, 3]]:
				var a: Vector3 = q[t[0]]
				var b: Vector3 = q[t[1]]
				var d: Vector3 = q[t[2]]
				# frente en sentido horario
				if (b - a).cross(d - a).dot(n) > 0.0:
					var x := b
					b = d
					d = x
				for v in [a, b, d]:
					st.set_color(col)
					st.set_normal(n)
					st.add_vertex(v)
