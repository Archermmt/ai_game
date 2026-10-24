shader_type spatial;

uniform sampler2D light_mask : source_color, filter_linear;
uniform bool dusk = false;
uniform float dusk_mix : hint_range(0.0, 1.0) = 0.0;

void fragment() {
    vec3 glow = texture(light_mask, UV).rgb;
    float warm = max(dusk_mix, dusk ? 0.65 : 0.0);
    // An opaque painted reflection keeps the room closed while suggesting cool
    // sky above and a quiet warm curtain below, including at the day preset.
    float sky = smoothstep(0.28, 0.90, 1.0 - UV.y + sin(UV.x * 5.2) * 0.06);
    vec3 daylight = mix(vec3(0.095, 0.14, 0.13), vec3(0.26, 0.37, 0.37), sky);
    float curtain = smoothstep(0.25, 0.86, glow.r);
    daylight = mix(daylight, vec3(0.38, 0.32, 0.20), curtain * 0.16);
    ALBEDO = mix(daylight, vec3(0.28, 0.20, 0.095) * (0.85 + glow * 0.3), warm);
    EMISSION = glow * warm * 0.72;
    ROUGHNESS = 0.68;
    SPECULAR = 0.20;
}
