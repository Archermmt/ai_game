shader_type sky;
// Original inexpensive painted sky. Explicit time enables photographic freezing.
uniform float sky_time = 0.0;
uniform float daylight = 1.0;
uniform float cloud_cover = 0.18;
uniform float dust_amount = 0.0;
uniform vec3 sun_direction = vec3(0.0, 1.0, 0.0);
float hash(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }
float noise2(vec2 p) {
    vec2 i = floor(p); vec2 f = fract(p); f = f*f*(3.0-2.0*f);
    return mix(mix(hash(vec3(i,0)),hash(vec3(i+vec2(1,0),0)),f.x),mix(hash(vec3(i+vec2(0,1),0)),hash(vec3(i+vec2(1),0)),f.x),f.y);
}
float paint(vec2 p) { return noise2(p)*0.62 + noise2(p*2.07)*0.26 + noise2(p*4.13)*0.12; }
void sky() {
    vec3 d = normalize(EYEDIR);
    float horizon = pow(1.0 - max(d.y, 0.0), 3.0);
    vec3 top = mix(vec3(0.018,0.032,0.085),vec3(0.32,0.57,0.69),daylight);
    vec3 rim = mix(vec3(0.11,0.14,0.25),vec3(0.83,0.84,0.67),daylight);
    float overcast = smoothstep(0.55,1.0,cloud_cover);
    top = mix(top,mix(vec3(0.025,0.035,0.06),vec3(0.25,0.30,0.33),daylight),overcast*0.85);
    rim = mix(rim,mix(vec3(0.08,0.10,0.16),vec3(0.50,0.54,0.54),daylight),overcast*0.8);
    float sunset = (1.0-smoothstep(0.0,0.32,abs(sun_direction.y))) * smoothstep(-0.22,0.02,sun_direction.y);
    rim = mix(rim,vec3(0.92,0.55,0.34),sunset*0.65);
    vec3 color = mix(top,rim,horizon);
    if (!AT_CUBEMAP_PASS) {
        float up = smoothstep(-0.04,0.10,d.y);
        float night = (1.0-daylight)*up;
        vec3 cells = d*210.0;
        float seed = hash(floor(cells));
        float star = (1.0-smoothstep(0.035,0.15,length(fract(cells)-0.5))) * step(0.965,seed);
        star *= 0.8+0.2*sin(sky_time*0.45+seed*100.0);
        float band = pow(max(0.0,1.0-abs(dot(d,normalize(vec3(0.35,0.55,0.76))))),24.0);
        float galaxy = band * (0.2+0.8*paint(d.xz*13.0+d.y*7.0));
        color += (vec3(0.83,0.85,0.73)*star + vec3(0.12,0.10,0.20)*galaxy)*night;
        float sun_dot = dot(d,sun_direction);
        float sun_disc = smoothstep(cos(0.020),cos(0.014),sun_dot);
        float glow = pow(max(sun_dot,0.0),120.0)*0.14;
        color += vec3(1.0,0.77,0.39)*(sun_disc+glow)*up*daylight;
        vec3 moon_dir = -sun_direction;
        float moon_disc = smoothstep(cos(0.027),cos(0.023),dot(d,moon_dir));
        float moon_mark = paint(d.xz*240.0)*0.12;
        color += vec3(0.76,0.82,0.75)*(0.85+moon_mark)*moon_disc*night;
        vec2 uv = d.xz / max(0.17,d.y+0.16) * 2.8;
        uv += vec2(sky_time*0.009,sky_time*0.003);
        float n = paint(uv);
        float mask = smoothstep(0.72-cloud_cover*0.56,0.85-cloud_cover*0.40,n)*up;
        vec3 clouds = mix(vec3(0.10,0.14,0.22),vec3(0.94,0.92,0.78),daylight);
        clouds = mix(clouds, mix(vec3(0.06,0.08,0.13),vec3(0.42,0.48,0.49),daylight),cloud_cover*cloud_cover*0.78);
        clouds *= 0.85 + n*0.20;
        color = mix(color,clouds,mask*0.97);
    }
    color = mix(color,vec3(0.55,0.41,0.25)*mix(0.25,1.0,daylight),dust_amount*0.7);
    COLOR = color;
}
