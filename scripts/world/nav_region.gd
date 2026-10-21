extends NavigationRegion3D
## Calcula la malla de navegación al arrancar si no se horneó en el editor.


func _ready() -> void:
	if navigation_mesh == null:
		push_warning("NavRegion: no hay NavigationMesh asignado.")
		return

	if navigation_mesh.get_polygon_count() > 0:
		return  # ya horneada en el editor

	# false = síncrono, lista antes del primer clic
	bake_navigation_mesh(false)
	print("NavRegion: mapa de navegación calculado (%d polígonos)" % navigation_mesh.get_polygon_count())
