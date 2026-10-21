shader_type spatial;

uniform sampler2D light_mask : source_color, filter_linear;
uniform bool dusk = false;
uniform float dusk_mix : hint_range(0.0, 1.0) = 0.0;

void fragment() {
    vec3 glow = texture(light_mask, UV).rgb;
    float warm = max(dusk_mix, dusk ? 0.65 : 0.0);
    ALBEDO = mix(vec3(0.075, 0.16, 0.15), vec3(0.28, 0.20, 0.095), warm);
    EMISSION = glow * warm * 0.85;
    ROUGHNESS = 0.52;
    SPECULAR = 0.28;
}
