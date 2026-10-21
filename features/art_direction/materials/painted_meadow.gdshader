shader_type spatial;

uniform sampler2D grass_map : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D meadow_macro : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D soil_map : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D wet_map : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform float soil_strength : hint_range(0.0, 1.0) = 0.76;
varying vec3 world_position;
varying vec2 blend_weights;

void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    blend_weights = COLOR.rg;
}

void fragment() {
    // Two unrelated scales keep the clearing broad and quiet, without a checker lawn.
    vec2 p = world_position.xz;
    vec3 broad = texture(meadow_macro, p / 24.0).rgb;
    vec3 brush = texture(grass_map, p / 3.8 + vec2(0.17, 0.39)).rgb;
    vec3 grass = broad * 0.72 + brush * 0.28;
    vec3 soil = texture(soil_map, p / 4.6).rgb;
    vec3 bank = texture(wet_map, p / 5.2).rgb;
    float earth = smoothstep(0.03, 0.91, blend_weights.r) * soil_strength;
    float wet = smoothstep(0.03, 0.85, blend_weights.g);
    ALBEDO = mix(mix(grass, soil, earth), bank, wet * 0.74);
    ROUGHNESS = mix(0.98, 0.86, wet);
    SPECULAR = 0.13;
}
