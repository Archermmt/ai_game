shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
global uniform float living_time;
uniform bool snow = false;
uniform bool dust = false;
uniform float severity = 1.0;
uniform float amount = 1.0;
uniform float phase = 0.0;
varying flat float particle_seed;
void vertex() {
    particle_seed = fract(sin(float(INSTANCE_ID) * 127.1 + 19.7) * 43758.5453);
    vec3 center = MODEL_MATRIX[3].xyz;
    float t = phase;
    center.y = mod(center.y - t * (dust ? 0.3 : (snow ? 1.0 : 13.0)), 22.0) - 1.0;
    if (severity > 1.0 || dust) {
        center.x = mod(center.x + t * (dust ? 8.0 : 2.8) + 32.0, 64.0) - 32.0;
    }
    center.x += snow ? sin(t * 0.7 + center.z) * 0.65 : center.y * 0.10;
    float stretch = !snow && !dust ? min(severity, 1.6) : 1.0;
    vec3 p = center + INV_VIEW_MATRIX[0].xyz * VERTEX.x * mix(0.35,1.0,amount) + INV_VIEW_MATRIX[1].xyz * VERTEX.y * stretch * mix(0.5,1.0,amount);
    POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(p, 1.0);
}
void fragment() {
    float alpha = (snow || dust) ? 1.0 - smoothstep(0.26, 0.5, length(UV - vec2(0.5))) : sin(UV.y * 3.14159) * 0.43;
    ALBEDO = dust ? vec3(0.71, 0.54, 0.33) : (snow ? vec3(0.95, 0.98, 1.0) : vec3(0.66, 0.79, 0.83));
    ALPHA = smoothstep(particle_seed, particle_seed+0.035, amount) * alpha * (dust ? 0.35 : (snow ? 0.88 : min(0.7 * severity, 1.0)));
}
