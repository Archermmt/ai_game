extends SceneTree
## Offline native thumbnails using the same painted textures and tint multipliers as runtime.

const TEXTURES: Dictionary = {
	"plaster": preload("res://assets/materials/textures/plaster.png"),
	"wood": preload("res://assets/materials/textures/wood.png"),
	"terracotta": preload("res://assets/materials/textures/terracotta.png"),
	"stone": preload("res://assets/materials/textures/stone.png"),
	"vegetation_atlas": preload("res://assets/materials/textures/vegetation_atlas.png")
}

var views: Array[SubViewport] = []
var _frames: int = 0


func _initialize() -> void:
	get_root().size = Vector2i(1280, 800)
	for card: Dictionary in GardenPalette.CARDS:
		var viewport: SubViewport = SubViewport.new()
		viewport.size = Vector2i(96, 96)
		viewport.own_world_3d = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		get_root().add_child(viewport)
		views.append(viewport)
		var environment: WorldEnvironment = WorldEnvironment.new()
		var settings: Environment = Environment.new()
		settings.background_mode = Environment.BG_COLOR
		settings.background_color = Color("eee8d7")
		settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		settings.ambient_light_color = Color.WHITE
		settings.ambient_light_energy = 0.7
		environment.environment = settings
		viewport.add_child(environment)
		var sun: DirectionalLight3D = DirectionalLight3D.new()
		sun.rotation_degrees = Vector3(-50, -30, 0)
		sun.light_energy = 0.8
		viewport.add_child(sun)
		var camera: Camera3D = Camera3D.new()
		viewport.add_child(camera)
		camera.position = Vector3(2, 1.5, 2)
		camera.rotation = Vector3(-atan(1.0 / sqrt(8.0)), PI / 4, 0)
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 1.85
		var model: Node3D
		if card["group"] == "foliage":
			model = WeekFourCatalog.create("NAT-06", "swatch", null, null)
			for paint: ShaderMaterial in WeekSixCatalog.wind_materials(model):
				paint.set_shader_parameter("reduce_motion", true)
				paint.set_shader_parameter("foliage_tint", Color(card["tint"]))
		else:
			var node: MeshInstance3D = MeshInstance3D.new()
			var shape: BoxMesh = BoxMesh.new()
			shape.size = Vector3(1, 1, 1)
			node.mesh = shape
			node.position.y = 0.5
			var material: StandardMaterial3D = StandardMaterial3D.new()
			material.albedo_texture = TEXTURES[card["texture"]]
			material.albedo_color = Color(card["tint"])
			material.roughness = 0.95
			node.material_override = material
			model = node
		viewport.add_child(model)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 60:
		RenderingServer.force_draw(false)
		for i: int in range(views.size()):
			var path: String = "res://assets/week_07/ui/" + GardenPalette.CARDS[i]["id"] + ".png"
			views[i].get_texture().get_image().save_png(path)
		return true
	return false
