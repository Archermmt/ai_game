shader_type spatial;
global uniform float living_time;
global uniform float living_cloud;
global uniform float living_snow;
global uniform float living_season;
varying vec3 living_position;
varying float living_up;

render_mode cull_disabled;

uniform sampler2D atlas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform float wind_strength : hint_range(0.0, 1.0) = 0.45;
uniform float wind_direction = 0.4;
uniform float amplitude = 0.16;
uniform float phase = 0.0;
uniform bool batched = false;
uniform bool season_deciduous = false;
uniform vec4 foliage_tint : source_color = vec4(1.0);
uniform bool reduce_motion = false;
uniform bool freeze_time = false;
uniform float sample_time = 0.0;
varying float fruit;
varying float leaf_tip;

void vertex() {
    living_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    living_up = max(0.0, NORMAL.y);
    fruit = COLOR.b;
    leaf_tip = COLOR.r;
    float instance_phase = phase + (batched ? INSTANCE_CUSTOM.r * 62.83 : 0.0);
    float t = freeze_time ? sample_time : TIME;
    float amount = reduce_motion ? 0.0 : wind_strength * amplitude * COLOR.r;
    vec2 direction = vec2(cos(wind_direction), sin(wind_direction));
    VERTEX.xz += direction * amount * (sin(t * 1.2 + instance_phase)
                + COLOR.g * sin(t * 2.0 + instance_phase) * 0.2);
}

void fragment() {
    vec4 paint = texture(atlas, UV);
    float green = smoothstep(0.012, 0.085, paint.g - paint.r);
    vec3 foliage = paint.rgb * mix(vec3(1.0), foliage_tint.rgb, green);
    // Cool gray-green body keeps sunlit leaves and moss from becoming lime.
    // It is part of this painted material, so flowers/bark/stone keep their hue.
    vec3 sage = foliage * vec3(0.80, 0.92, 1.12) + vec3(0.0, 0.0, 0.012);
    foliage = mix(foliage, sage, green * 0.75);
    // Petal, bark, moss and fruit have their own painted atlas colors.
    ALBEDO = foliage;
    ALPHA = paint.a;
    ALPHA_SCISSOR_THRESHOLD = 0.43;
    ROUGHNESS = 0.95;
    SPECULAR = 0.12;
    BACKLIGHT = foliage * green * leaf_tip * 0.06;
    vec2 cp = living_position.xz * 0.13 + vec2(living_time * 0.025, living_time * 0.011);
    float cloud_mask = smoothstep(0.40, 0.72, 0.5 + sin(cp.x + sin(cp.y)) * 0.22 + cos(cp.y * 0.8 - cp.x * 0.5) * 0.20);
    ALBEDO *= 1.0 - cloud_mask * living_cloud * 0.30;

    float autumn = 1.0 - step(0.45, abs(living_season - 2.0));
    float winter = step(2.5, living_season);
    ALBEDO = mix(ALBEDO, ALBEDO * vec3(1.55, 0.87, 0.42), autumn * 0.72);
    ALBEDO = mix(ALBEDO, ALBEDO * vec3(1.32, 1.06, 0.68), winter * 0.65);

    if (season_deciduous && living_season > 2.5 && green > 0.3) { discard; }

    ALBEDO = mix(ALBEDO, vec3(0.80, 0.86, 0.86), living_snow * smoothstep(0.55, 0.95, living_up));

}
