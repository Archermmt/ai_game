shader_type spatial;
uniform sampler2D plaster_map : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D tile_map : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform bool aged = false;
varying vec3 local_position;
varying vec4 vertex_tint;
void vertex() { local_position = VERTEX; vertex_tint = COLOR; }
void fragment() {
    bool roof = vertex_tint.g < 0.6;
    vec2 uv = abs(NORMAL.y) > 0.5 ? local_position.xz * 0.4 : UV * 0.4;
    vec3 paint = roof ? texture(tile_map, uv).rgb : texture(plaster_map, uv).rgb;
    float moss = aged ? (1.0 - smoothstep(0.0, 0.85, local_position.y)) * 0.3 : 0.0;
    ALBEDO = mix(paint, vec3(0.20, 0.30, 0.12), moss);
    ROUGHNESS = aged ? 0.98 : 0.88;
}
