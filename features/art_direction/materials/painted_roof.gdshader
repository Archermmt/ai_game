shader_type spatial;

uniform sampler2D tile_map : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform vec4 roof_tint : source_color = vec4(1.0);
uniform bool aged = false;
varying vec3 local_position;
varying vec4 tile_color;

void vertex() {
    local_position = VERTEX;
    tile_color = COLOR;
}

void fragment() {
    vec3 clay = texture(tile_map, UV).rgb;
    float wash = sin(local_position.x * 0.77 + local_position.z * 0.51) * 0.022;
    vec3 tile_wash = clamp(tile_color.rgb / vec3(0.73725, 0.47059, 0.31765), vec3(0.76), vec3(1.19));
    ALBEDO = clay * roof_tint.rgb * tile_wash * (1.0 + wash);
    ROUGHNESS = aged ? 0.98 : 0.91;
    SPECULAR = 0.16;
}
