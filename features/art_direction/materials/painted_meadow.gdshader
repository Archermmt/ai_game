shader_type spatial;
global uniform float living_time;
global uniform float living_cloud;
global uniform float living_snow;
global uniform float living_season;
varying vec3 living_position;
varying float living_up;


uniform sampler2D grass_map : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D meadow_macro : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D soil_map : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D wet_map : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform float soil_strength : hint_range(0.0, 1.0) = 0.76;
varying vec3 world_position;
varying vec2 blend_weights;

void vertex() {
    living_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    living_up = max(0.0, NORMAL.y);
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    blend_weights = COLOR.rg;
}

void fragment() {
    // Two unrelated scales keep the clearing broad and quiet, without a checker lawn.
    vec2 p = world_position.xz;
    vec3 broad = texture(meadow_macro, p / 24.0).rgb;
    vec3 brush = texture(grass_map, p / 3.8 + vec2(0.17, 0.39)).rgb;
    vec3 grass = broad * 0.72 + brush * 0.28;
    // Broad cool/warm painted fields keep the short meadow rooted in the ground.
    float field = 0.5 + 0.23*sin(p.x*0.32 + sin(p.y*0.27)) + 0.19*cos(p.y*0.41-p.x*0.13);
    vec3 shaded_grass = grass * vec3(0.78,0.91,1.12);
    vec3 sunny_grass = grass * vec3(1.00,1.01,0.93);
    grass = mix(shaded_grass,sunny_grass,smoothstep(0.15,0.87,field));
    vec3 soil = texture(soil_map, p / 4.6).rgb;
    vec3 bank = texture(wet_map, p / 5.2).rgb;
    float earth = smoothstep(0.03, 0.91, blend_weights.r) * soil_strength;
    float wet = smoothstep(0.03, 0.85, blend_weights.g);
    ALBEDO = mix(mix(grass, soil, earth), bank, wet * 0.74);
    ROUGHNESS = mix(0.98, 0.86, wet);
    SPECULAR = 0.13;
    vec2 cp = living_position.xz * 0.13 + vec2(living_time * 0.025, living_time * 0.011);
    float cloud_mask = smoothstep(0.40, 0.72, 0.5 + sin(cp.x + sin(cp.y)) * 0.22 + cos(cp.y * 0.8 - cp.x * 0.5) * 0.20);
    ALBEDO *= 1.0 - cloud_mask * living_cloud * 0.30;

    float autumn = 1.0 - step(0.45, abs(living_season - 2.0));
    float winter = step(2.5, living_season);
    ALBEDO = mix(ALBEDO, ALBEDO * vec3(1.55, 0.87, 0.42), autumn * 0.72);
    ALBEDO = mix(ALBEDO, ALBEDO * vec3(1.32, 1.06, 0.68), winter * 0.65);

    ALBEDO = mix(ALBEDO, vec3(0.80, 0.86, 0.86), living_snow * smoothstep(0.55, 0.95, living_up));

}
