@tool
extends MeshInstance3D
## Farola de hierro colado: basa, fuste, travesaño para la escalera del farolero
## y farol de cuatro caras con su sombrerete. El cristal es el nodo Vidrio de farola.tscn.

const HIERRO := Color(0.07, 0.075, 0.08)

static var _malla: ArrayMesh
static var _material: StandardMaterial3D


func _ready() -> void:
	if _malla == null:
		_malla = _hacer()
		_material = StandardMaterial3D.new()
		_material.vertex_color_use_as_albedo = true
		_material.roughness = 0.5
	mesh = _malla
	material_override = _material


static func _hacer() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_cilindro(st, 0.0, 0.2, 0.17, 0.5, 8, PI / 8.0)
	_cilindro(st, 0.5, 0.11, 0.07, 0.22, 8, PI / 8.0)
	_cilindro(st, 0.72, 0.065, 0.055, 1.82, 8, 0.0)
	_cilindro(st, 2.5, 0.09, 0.09, 0.1, 8, 0.0)
	# travesaño
	_cilindro_x(st, Vector3(0, 2.42, 0), 0.72, 0.025)
	# marco del farol: base, cuatro montantes y sombrerete
	_cilindro(st, 2.6, 0.15, 0.15, 0.05, 4, PI * 0.25)
	for k in 4:
		var a := PI * 0.25 + PI * 0.5 * float(k)
		var p := Vector3(cos(a), 0, sin(a))
		_poste(st, p * 0.135 + Vector3.UP * 2.65, p * 0.2 + Vector3.UP * 3.09)
	_cilindro(st, 3.09, 0.25, 0.05, 0.22, 4, PI * 0.25)
	_cilindro(st, 3.31, 0.03, 0.0, 0.14, 4, 0.0)
	return st.commit()


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, n: Vector3) -> void:
	if (b - a).cross(c - a).dot(n) > 0.0:
		var t := b
		b = c
		c = t
	for v in [a, b, c]:
		st.set_color(HIERRO)
		st.set_normal(n)
		st.add_vertex(v)


static func _cilindro(st: SurfaceTool, y: float, r0: float, r1: float, alto: float, lados: int, giro: float) -> void:
	var pie := Vector3(0, y, 0)
	for i in lados:
		var a0 := giro + TAU * float(i) / float(lados)
		var a1 := giro + TAU * float(i + 1) / float(lados)
		var d0 := Vector3(cos(a0), 0.0, sin(a0))
		var d1 := Vector3(cos(a1), 0.0, sin(a1))
		var n := ((d0 + d1) * 0.5).normalized()
		var arriba := Vector3.UP * alto
		_tri(st, pie + d0 * r0, pie + d1 * r0, pie + d1 * r1 + arriba, n)
		_tri(st, pie + d0 * r0, pie + d1 * r1 + arriba, pie + d0 * r1 + arriba, n)
		if r1 > 0.0:
			_tri(st, pie + arriba, pie + d0 * r1 + arriba, pie + d1 * r1 + arriba, Vector3.UP)


## Barra horizontal a lo largo de x, de sección cuadrada.
static func _cilindro_x(st: SurfaceTool, centro: Vector3, largo: float, r: float) -> void:
	_poste(st, centro - Vector3(largo * 0.5, 0, 0), centro + Vector3(largo * 0.5, 0, 0), r)


## Barra fina entre dos puntos (cuatro caras).
static func _poste(st: SurfaceTool, a: Vector3, b: Vector3, r: float = 0.015) -> void:
	var eje := (b - a).normalized()
	var u := eje.cross(Vector3.FORWARD if absf(eje.y) > 0.9 else Vector3.UP).normalized()
	var v := eje.cross(u).normalized()
	var esquinas := [u * r + v * r, -u * r + v * r, -u * r - v * r, u * r - v * r]
	for i in 4:
		var e0: Vector3 = esquinas[i]
		var e1: Vector3 = esquinas[(i + 1) % 4]
		var n := (e0 + e1).normalized()
		_tri(st, a + e0, a + e1, b + e1, n)
		_tri(st, a + e0, b + e1, b + e0, n)
