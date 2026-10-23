shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
global uniform float living_time;
uniform bool snow = false;
void vertex() {
    vec3 center = MODEL_MATRIX[3].xyz;
    float t = living_time;
    center.y = mod(center.y - t * (snow ? 1.0 : 13.0), 22.0) - 1.0;
    center.x += snow ? sin(t * 0.7 + center.z) * 0.65 : center.y * 0.10;
    vec3 p = center + INV_VIEW_MATRIX[0].xyz * VERTEX.x + INV_VIEW_MATRIX[1].xyz * VERTEX.y;
    POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(p, 1.0);
}
void fragment() {
    float alpha = snow ? 1.0 - smoothstep(0.26, 0.5, length(UV - vec2(0.5))) : sin(UV.y * 3.14159) * 0.43;
    ALBEDO = snow ? vec3(0.95, 0.98, 1.0) : vec3(0.66, 0.79, 0.83);
    ALPHA = alpha * (snow ? 0.88 : 0.7);
}
