shader_type spatial;
global uniform float living_time;
global uniform float living_cloud;
global uniform float living_snow;
global uniform float living_season;
varying vec3 living_position;
varying float living_up;


uniform sampler2D plaster_map : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D tile_map : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform bool aged = false;
uniform vec4 plaster_tint : source_color = vec4(1.0);
uniform vec4 roof_tint : source_color = vec4(1.0);
varying vec3 local_position;
varying vec3 local_normal;
varying vec4 vertex_tint;

void vertex() {
    living_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    living_up = max(0.0, NORMAL.y);
    local_position = VERTEX;
    local_normal = NORMAL;
    vertex_tint = COLOR;
}

void fragment() {
    bool roof = vertex_tint.g < 0.6;
    vec3 weights = pow(abs(local_normal), vec3(6.0));
    weights /= max(dot(weights, vec3(1.0)), 0.001);
    // Trowelled fields are wider than the openings. A second, slow wash spans
    // the whole facade so every wall does not repeat one small texture square.
    vec3 plaster = texture(plaster_map, local_position.zy * 0.27).rgb * weights.x
                 + texture(plaster_map, local_position.xz * 0.27).rgb * weights.y
                 + texture(plaster_map, local_position.xy * 0.27).rgb * weights.z;
    float broad_wash = texture(plaster_map, local_position.xy * 0.071
                              + local_position.zy * 0.043 + vec2(0.31, 0.17)).g;
    plaster *= mix(vec3(0.94, 0.965, 0.98), vec3(1.055, 1.025, 0.98),
                   smoothstep(0.38, 0.73, broad_wash));
    vec3 paint = roof ? texture(tile_map, UV * 0.55).rgb : plaster;
    paint *= roof ? roof_tint.rgb : plaster_tint.rgb;
    // Gentle damp foot; aging never turns the whole wall uniformly green.
    float mottled = texture(plaster_map, local_position.xz * 0.31 + vec2(0.18, 0.49)).g;
    float foot = 1.0 - smoothstep(0.06, (aged ? 0.76 : 0.38) * (0.6 + mottled), local_position.y);
    paint = mix(paint, paint * vec3(0.70, 0.78, 0.72), foot * (aged ? 0.26 : 0.10));
    ALBEDO = paint;
    ROUGHNESS = 0.94;
    SPECULAR = 0.12;
    vec2 cp = living_position.xz * 0.13 + vec2(living_time * 0.025, living_time * 0.011);
    float cloud_mask = smoothstep(0.40, 0.72, 0.5 + sin(cp.x + sin(cp.y)) * 0.22 + cos(cp.y * 0.8 - cp.x * 0.5) * 0.20);
    ALBEDO *= 1.0 - cloud_mask * living_cloud * 0.30;

    ALBEDO = mix(ALBEDO, vec3(0.80, 0.86, 0.86), living_snow * smoothstep(0.55, 0.95, living_up));

}
