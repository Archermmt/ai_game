shader_type spatial;
render_mode ambient_light_disabled, specular_disabled;

// Gentle fill keeps the roof and plaster broad in shadow. A real light
// provides the remaining value change and receives the scene's cast shadows.
uniform vec4 swatch : source_color = vec4(1.0);

uniform float roof_half_span = 0.0;
varying float slope_distance;

void vertex() {
    slope_distance = VERTEX.z;
}

void fragment() {
    vec3 color = swatch.rgb;
    if (roof_half_span > 0.0) {
        float s = abs(slope_distance) / roof_half_span;
        color *= mix(0.37, 1.0, smoothstep(0.01, 0.26, s));
        color *= mix(1.0, 0.73, smoothstep(0.91, 1.0, s));
    }
    ALBEDO = color;
    ROUGHNESS = 1.0;
    EMISSION = color * 0.66;
}

void light() {
    float light_wrap = smoothstep(-0.3, 0.85, dot(NORMAL, LIGHT));
    float fill = mix(0.20, 0.41, light_wrap);
    DIFFUSE_LIGHT += fill * ATTENUATION * LIGHT_COLOR / PI;
}
