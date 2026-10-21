shader_type spatial;

uniform sampler2D plaster_map : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D tile_map : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform bool aged = false;
uniform vec4 plaster_tint : source_color = vec4(1.0);
uniform vec4 roof_tint : source_color = vec4(1.0);
varying vec3 local_position;
varying vec3 local_normal;
varying vec4 vertex_tint;

void vertex() {
    local_position = VERTEX;
    local_normal = NORMAL;
    vertex_tint = COLOR;
}

void fragment() {
    bool roof = vertex_tint.g < 0.6;
    vec3 weights = pow(abs(local_normal), vec3(6.0));
    weights /= max(dot(weights, vec3(1.0)), 0.001);
    vec3 plaster = texture(plaster_map, local_position.zy * 0.46).rgb * weights.x
                 + texture(plaster_map, local_position.xz * 0.46).rgb * weights.y
                 + texture(plaster_map, local_position.xy * 0.46).rgb * weights.z;
    vec3 paint = roof ? texture(tile_map, UV * 0.55).rgb : plaster;
    paint *= roof ? roof_tint.rgb : plaster_tint.rgb;
    // Gentle damp foot; aging never turns the whole wall uniformly green.
    float foot = 1.0 - smoothstep(0.03, aged ? 0.64 : 0.28, local_position.y);
    float mottled = texture(plaster_map, local_position.xz * 0.83).g;
    paint = mix(paint, paint * vec3(0.70, 0.79, 0.68), foot * (aged ? 0.30 : 0.12) * mottled);
    ALBEDO = paint;
    ROUGHNESS = 0.94;
    SPECULAR = 0.16;
}
