shader_type spatial;
uniform sampler2D light_mask : source_color, filter_linear;
uniform bool dusk = false;
uniform float dusk_mix : hint_range(0.0, 1.0) = 0.0;
void fragment() {
    vec3 mask = texture(light_mask, UV).rgb;
    ALBEDO = mix(vec3(0.09,0.16,0.14),vec3(0.42,0.29,0.13),dusk_mix);
    EMISSION = mask * dusk_mix * 1.1;
    ROUGHNESS = 0.5;
}
