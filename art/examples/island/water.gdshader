shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled;
uniform sampler2D scene_color : hint_screen_texture, repeat_disable, filter_linear_mipmap;
varying vec2 water_pos;
float hash(vec2 p) {return fract(sin(dot(p,vec2(31.17,97.41)))*15731.25);}
void vertex(){water_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xz;}
void fragment(){
    vec2 cell=water_pos*vec2(1.35,3.8);
    vec2 g=floor(cell);
    vec2 xy=fract(cell)-vec2(hash(g+7.),hash(g+11.));
    float glint=smoothstep(.86,1.,hash(g+4.))*exp(-dot(xy*vec2(9.,16.),xy*vec2(9.,16.)));
    glint *= 1.-smoothstep(9.,24.,length(water_pos));
    float ripple=sin(water_pos.y*11.+water_pos.x*2.)+.52*sin(water_pos.y*17.-water_pos.x*4.);
    vec2 offset=vec2(1.65*ripple,.50*sin(water_pos.y*9.0+water_pos.x*1.3))/VIEWPORT_SIZE;
    vec3 lake=textureLod(scene_color,SCREEN_UV+offset,1.25).rgb;
    vec3 fleck=mix(vec3(.20,.27,.36),vec3(.58,.32,.36),hash(g+41.));
    // Blue-green scattering is visible through shallow water by the bank.
    float bank_distance = length(water_pos / vec2(6.0, 3.8)) - 1.1;
    float shallows = exp(-bank_distance * bank_distance / 0.15);
    float open_water = smoothstep(-0.015, 0.044, lake.b - lake.r);
    ALBEDO=lake+fleck*glint+shallows*open_water*vec3(0.014,0.024,0.033);
    ALPHA=1.;
}
