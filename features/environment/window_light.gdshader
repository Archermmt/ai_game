shader_type spatial;
uniform sampler2D light_mask : source_color, filter_linear;
uniform bool dusk = false;
void fragment() {
    vec3 mask = texture(light_mask, UV).rgb;
    ALBEDO = dusk ? vec3(0.42, 0.29, 0.13) : vec3(0.09, 0.16, 0.14);
    EMISSION = dusk ? mask * 1.4 : vec3(0.0);
    ROUGHNESS = 0.34;
}
