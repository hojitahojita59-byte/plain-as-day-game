class_name Vestuario
extends RefCounted
## Viste a un vecino desde un dict, p.ej. {"abrigo": [r,g,b], "gorra": true}.
## Las tablas mapean nombre corto -> propiedad de la figura.

const COLORES := {
	"abrigo": &"color_abrigo",
	"pantalon": &"color_pantalon",
	"sombrero": &"color_sombrero",
	"cuello": &"color_cuello",
	"pelo": &"pelo",
}

const BANDERAS := {
	"chistera": &"lleva_chistera",
	"gorra": &"lleva_gorra",
	"chal": &"lleva_chal",
	"alzacuellos": &"lleva_alzacuellos",
	"mira_alrededor": &"mira_alrededor",
	"sentado": &"sentado",
}

const NUMEROS := {
	"estatura": &"estatura",
	"inclinacion": &"inclinacion",
	"brazo_izquierdo": &"brazo_izquierdo",
	"brazo_derecho": &"brazo_derecho",
	"codo_izquierdo": &"codo_izquierdo",
	"codo_derecho": &"codo_derecho",
	"cadencia": &"cadencia",
	"amplitud": &"amplitud",
	"gesto": &"gesto",
	"redondez": &"redondez",
}


const TEXTOS := {
	"cara": &"cara",
	"quien": &"quien",
}


## Llamar ANTES de add_child(): la figura se viste en su _ready().
static func aplicar(figura: Node, ropa: Dictionary) -> void:
	if figura == null or ropa.is_empty():
		return

	for corto in COLORES:
		if ropa.has(corto):
			figura.set(COLORES[corto], _color(ropa[corto]))
	for corto in BANDERAS:
		if ropa.has(corto):
			figura.set(BANDERAS[corto], bool(ropa[corto]))
	for corto in NUMEROS:
		if ropa.has(corto):
			figura.set(NUMEROS[corto], float(ropa[corto]))

	for corto in TEXTOS:
		if ropa.has(corto):
			figura.set(TEXTOS[corto], String(ropa[corto]))

	for clave in ropa:
		var c := String(clave)
		if not (COLORES.has(c) or BANDERAS.has(c) or NUMEROS.has(c) or TEXTOS.has(c)):
			push_warning("Vestuario: no sé qué es '" + c + "'. Mira la tabla de vestuario.gd.")


## [r, g, b] o [r, g, b, a], de 0 a 1.
static func _color(v: Variant) -> Color:
	var a := Array(v)
	if a.size() < 3:
		push_warning("Vestuario: un color necesita al menos tres números, llegó " + str(v))
		return Color.MAGENTA
	var alfa := 1.0 if a.size() < 4 else float(a[3])
	return Color(float(a[0]), float(a[1]), float(a[2]), alfa)
