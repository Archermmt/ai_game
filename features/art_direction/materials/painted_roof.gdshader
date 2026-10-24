shader_type spatial;
global uniform float living_time;
global uniform float living_cloud;
global uniform float living_snow;
global uniform float living_season;
varying vec3 living_position;
varying float living_up;


uniform sampler2D tile_map : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform vec4 roof_tint : source_color = vec4(1.0);
uniform bool aged = false;
varying vec3 local_position;
varying vec4 tile_color;

void vertex() {
    living_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    living_up = max(0.0, NORMAL.y);
    local_position = VERTEX;
    tile_color = COLOR;
}

void fragment() {
    // Continuous paint coordinates cross tile boundaries. The same little
    // orange square must not be stamped onto every individually modelled tile.
    vec2 paint_position = vec2(local_position.z, local_position.x + local_position.y * 0.48);
    vec3 clay = texture(tile_map, paint_position * 0.24).rgb;
    vec3 broad = texture(tile_map, paint_position * 0.069 + vec2(0.37, 0.13)).rgb;
    clay = mix(clay, broad, 0.32);
    vec3 tile_wash = clamp(tile_color.rgb / vec3(0.73725, 0.47059, 0.31765), vec3(0.92), vec3(1.08));
    ALBEDO = clay * roof_tint.rgb * mix(vec3(1.0), tile_wash, 0.46);
    ROUGHNESS = aged ? 0.98 : 0.91;
    SPECULAR = 0.10;
    vec2 cp = living_position.xz * 0.13 + vec2(living_time * 0.025, living_time * 0.011);
    float cloud_mask = smoothstep(0.40, 0.72, 0.5 + sin(cp.x + sin(cp.y)) * 0.22 + cos(cp.y * 0.8 - cp.x * 0.5) * 0.20);
    ALBEDO *= 1.0 - cloud_mask * living_cloud * 0.30;

    ALBEDO = mix(ALBEDO, vec3(0.80, 0.86, 0.86), living_snow * smoothstep(0.55, 0.95, living_up));

}
