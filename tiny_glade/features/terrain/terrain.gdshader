shader_type spatial;
uniform sampler2D grass_map : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D soil_map : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D wet_map : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform float soil_strength : hint_range(0.0, 1.0) = 0.8;
varying vec2 world_uv;
varying vec2 blend_weights;
void vertex() { world_uv = VERTEX.xz / 5.0; blend_weights = COLOR.rg; }
void fragment() {
    vec3 grass = texture(grass_map, world_uv).rgb;
    vec3 soil = texture(soil_map, world_uv).rgb;
    vec3 wet = texture(wet_map, world_uv).rgb;
    ALBEDO = mix(mix(grass, soil, blend_weights.r * soil_strength), wet, blend_weights.g * 0.85);
    ROUGHNESS = mix(0.96, 0.68, blend_weights.g);
}
