class_name MaterialLibrary
extends RefCounted
var cache:Dictionary={}
func material(id:String,tint:Color,scale_uv:float=1.0) -> ShaderMaterial:
	var key=str([id,tint,scale_uv])
	if cache.has(key):return cache[key]
	var shader=Shader.new();shader.code="""shader_type spatial;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 tint : source_color;
uniform float uv_scale=1.0;
void fragment(){vec2 uv=UV*uv_scale;ALBEDO=tint.rgb*mix(vec3(1.0),texture(albedo_tex,uv).rgb,0.23);NORMAL_MAP=texture(normal_tex,uv).rgb;NORMAL_MAP_DEPTH=0.05;ROUGHNESS=0.95;}
"""
	var mat=ShaderMaterial.new();mat.shader=shader
	mat.set_shader_parameter("albedo_tex",load("res://game/art/materials/"+id+"_diffuse.jpg"))
	mat.set_shader_parameter("normal_tex",load("res://game/art/materials/"+id+"_nor_gl.jpg"))
	mat.set_shader_parameter("tint",tint);mat.set_shader_parameter("uv_scale",scale_uv)
	cache[key]=mat;return mat
func dress(root:Node3D,kind:String) -> void:
	if kind not in ["house","tea","lighthouse"]:return
	for node in root.find_children("*","MeshInstance3D",true,false):
		for s in range(node.mesh.get_surface_count()):
			var m=node.get_active_material(s)
			if not m is StandardMaterial3D:continue
			if (m.albedo_color.is_equal_approx(ArtKit.CORAL) or m.albedo_color.is_equal_approx(ArtKit.BLUE)) and node.mesh.get_aabb().size.x>1.0:
				node.set_surface_override_material(s,material("grey_roof_tiles_02",m.albedo_color.lightened(0.1),1.5))
			elif m.albedo_color.is_equal_approx(ArtKit.CREAM):
				node.set_surface_override_material(s,material("white_plaster_02",ArtKit.CREAM,1.0))
