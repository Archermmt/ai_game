shader_type spatial;
render_mode blend_mix, depth_draw_opaque;
uniform bool reduce_motion = false;
uniform bool freeze_time = false;
uniform float sample_time = 0.0;
varying vec2 water_uv;
void vertex() { water_uv = VERTEX.xz; }
void fragment() {
    float t = reduce_motion ? 0.0 : (freeze_time ? sample_time : TIME) * 0.25;
    float wave = sin(water_uv.x * 4.0 + t) * cos(water_uv.y * 3.0 + t);
    ALBEDO = mix(vec3(0.14, 0.29, 0.24), vec3(0.32, 0.47, 0.38), wave * 0.12 + 0.45);
    ROUGHNESS = 0.26; METALLIC = 0.05; ALPHA = 0.78;
}
