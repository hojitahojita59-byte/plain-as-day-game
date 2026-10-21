extends Node3D
## Pase de estilo (hijo de la raíz): contorno negro, color apagado y niebla
## atada al miasma.

const OUTLINE_SHADER := preload("res://materials/outline.gdshader")

@export_group("Contorno")
## Grosor de línea, en metros.
@export var line_thickness: float = 0.02
@export var line_color: Color = Color(0.04, 0.04, 0.05)
## Nodos cuyo nombre contenga uno de estos textos van sin contorno.
@export var skip_names: PackedStringArray = []

@export_group("Color del mundo")
## 1.0 = color original, 0.0 = B/N.
@export_range(0.0, 1.0) var saturation: float = 0.35
@export_range(0.5, 2.0) var contrast: float = 1.12
@export_range(0.5, 2.0) var brightness: float = 1.0

@export_group("Niebla y miasma")
## Niebla con miasma = 1.
@export var fog_miasma: Color = Color(0.36, 0.40, 0.24)
## Niebla con miasma = 0.
@export var fog_clean: Color = Color(0.62, 0.66, 0.70)
@export var fog_density_miasma: float = 0.030
@export var fog_density_clean: float = 0.004

var _outline: ShaderMaterial
var _env: Environment = null


func _ready() -> void:
	_outline = ShaderMaterial.new()
	_outline.shader = OUTLINE_SHADER
	_outline.set_shader_parameter("thickness", line_thickness)
	_outline.set_shader_parameter("line_color", line_color)

	var scene_root := get_parent()
	if scene_root == null:
		push_warning("ArtStyle: cuélgame de la raíz de la escena, no del árbol suelto.")
		return

	var painted := _apply_outline(scene_root)
	print("[Estilo] Contorno aplicado a %d mallas." % painted)
	# Web: la sombra del sol cuadruplica el dibujo; MSAA 4x pesa en Chromebook.
	if OS.has_feature("web"):
		get_viewport().msaa_3d = Viewport.MSAA_DISABLED
		get_viewport().screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
		for sol in scene_root.find_children("*", "DirectionalLight3D", true, false):
			(sol as DirectionalLight3D).shadow_enabled = false

	_env = _find_environment(scene_root)
	if _env == null:
		push_warning("ArtStyle: no encuentro un WorldEnvironment en esta escena.")
		return

	_env.adjustment_enabled = true
	_env.adjustment_saturation = saturation
	_env.adjustment_contrast = contrast
	_env.adjustment_brightness = brightness

	GameState.miasma_changed.connect(_on_miasma_changed)
	_on_miasma_changed(GameState.get_miasma())


## Recorre toda la escena, incl. hijos de .glb (en runtime son nodos normales).
func _apply_outline(node: Node) -> int:
	var count := 0

	if node is MeshInstance3D and not _is_skipped(node.name) \
			and not node.has_meta(&"sin_contorno") \
			and not _demasiado_pequeno(node as MeshInstance3D):
		(node as MeshInstance3D).material_overlay = _contorno_para(node)
		count += 1

	for child in node.get_children():
		count += _apply_outline(child)

	return count


## Meta `contorno` (número) multiplica el grosor; caché por factor.
var _contornos: Dictionary = {}


func _contorno_para(n: Node) -> ShaderMaterial:
	if not n.has_meta(&"contorno"):
		return _outline
	var k := float(n.get_meta(&"contorno"))
	if not _contornos.has(k):
		var m := _outline.duplicate() as ShaderMaterial
		m.set_shader_parameter("thickness", line_thickness * k)
		_contornos[k] = m
	return _contornos[k]


## Por nombre (piezas del kit); lo construido en código usa meta `sin_contorno`.
func _is_skipped(node_name: String) -> bool:
	for fragment in skip_names:
		if not String(fragment).is_empty() and node_name.containsn(String(fragment)):
			return true
	return false


func _find_environment(node: Node) -> Environment:
	if node is WorldEnvironment:
		return (node as WorldEnvironment).environment
	for child in node.get_children():
		var found := _find_environment(child)
		if found != null:
			return found
	return null


## Niebla según miasma: 1.0 = verde denso; mínimo del juego 0.15.
func _on_miasma_changed(value: float) -> void:
	if _env == null:
		return
	_env.fog_light_color = fog_clean.lerp(fog_miasma, value)
	# Cada día de epidemia, algo más espesa.
	_env.fog_density = lerpf(fog_density_clean, fog_density_miasma, value) * (1.0 + 0.18 * (GameState.dia - 1))


## Lado mínimo (m) para contorno: el cascarón invertido se come piezas finas.
const MINIMO_PARA_CONTORNO := 0.12


func _demasiado_pequeno(m: MeshInstance3D) -> bool:
	if m.mesh == null:
		return true
	var caja := m.mesh.get_aabb().size * m.global_transform.basis.get_scale()
	return minf(minf(absf(caja.x), absf(caja.y)), absf(caja.z)) < MINIMO_PARA_CONTORNO
