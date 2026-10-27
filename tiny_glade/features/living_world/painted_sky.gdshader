shader_type sky;
// Original inexpensive painted sky. Explicit time enables photographic freezing.
uniform float sky_time = 0.0;
uniform float daylight = 1.0;
uniform float cloud_cover = 0.18;
uniform bool painted_clouds_enabled = true;
uniform float dust_amount = 0.0;
uniform vec3 ridge_tint = vec3(0.13, 0.23, 0.22);
uniform vec3 sun_direction = vec3(0.0, 1.0, 0.0);
float hash(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }
float noise2(vec2 p) {
    vec2 i = floor(p); vec2 f = fract(p); f = f*f*(3.0-2.0*f);
    return mix(mix(hash(vec3(i,0)),hash(vec3(i+vec2(1,0),0)),f.x),mix(hash(vec3(i+vec2(0,1),0)),hash(vec3(i+vec2(1),0)),f.x),f.y);
}
float paint(vec2 p) { return noise2(p)*0.62 + noise2(p*2.07)*0.26 + noise2(p*4.13)*0.12; }
// Two angular banks of asymmetric cumulus, each with a quiet base and lobed top.
// Three horizontal neighbours keep the sky seam continuous; no volume raymarch.
vec2 cumulus_bank(vec3 d, float row) {
    float longitude = atan(d.x,d.z) / 6.2831853 * 10.0 + sky_time*0.007;
    float cell = floor(longitude);
    float local_x = fract(longitude)-0.5;
    float cover = smoothstep(0.18,0.95,cloud_cover);
    float result = 0.0;
    float light = 0.0;
    for (int i=-1; i<=1; i++) {
        float key = mod(cell+float(i),10.0);
        float seed = hash(vec3(key,row*31.0,8.0));
        float presence = smoothstep(seed-0.03,seed+0.03,0.63+cover*0.39-row*0.15);
        float centre = mix(0.27,0.66,row) + (seed-0.5)*0.10;
        vec2 f = vec2((local_x-float(i)-(seed-0.5)*0.35)/(0.70+seed*0.18+cover*0.4), (d.y-centre)/(0.36-row*0.075));
        float base = (length(vec2(f.x/0.67,(f.y+0.06)/0.23))-1.0)*0.23;
        float puff_a = length(f-vec2(-0.25,0.02))-0.29;
        float puff_b = length(f-vec2(0.03,0.16+seed*0.1))-0.35;
        float puff_c = length(f-vec2(0.32,0.015))-0.26;
        float edge = min(min(base,puff_a),min(puff_b,puff_c));
        float bristle = (noise2(f*13.0+vec2(key,row))-0.5)*0.018;
        float mask = (1.0-smoothstep(-0.018,0.018,edge+bristle))*presence;
        float tone = clamp(0.44+f.y*1.10+seed*0.10,0.0,1.0);
        light = mix(light,tone,mask);
        result = max(result,mask);
    }
    return vec2(result,light);
}
void sky() {
    vec3 d = normalize(EYEDIR);
    float horizon = pow(1.0 - max(d.y, 0.0), 3.0);
    vec3 top = mix(vec3(0.008,0.017,0.044),vec3(0.060,0.25,0.48),daylight);
    vec3 rim = mix(vec3(0.055,0.085,0.16),vec3(0.55,0.69,0.72),daylight);
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
        vec2 low_cloud = cumulus_bank(d,0.0);
        vec2 high_cloud = cumulus_bank(d,1.0);
        float mask = max(low_cloud.x,high_cloud.x)*up*(painted_clouds_enabled ? 1.0 : 0.0);
        float lit = mix(low_cloud.y,high_cloud.y,high_cloud.x);
        vec3 bright = mix(vec3(0.13,0.18,0.29),vec3(0.94,0.91,0.78),daylight);
        vec3 belly = mix(vec3(0.035,0.060,0.12),vec3(0.16,0.29,0.44),daylight);
        bright = mix(bright,vec3(0.39,0.46,0.49)*mix(0.2,1.0,daylight),overcast*0.75);
        vec3 clouds = mix(belly,bright,smoothstep(0.10,0.90,lit));
        clouds = mix(clouds,vec3(0.78,0.42,0.27),sunset*lit*0.30);
        color = mix(color,clouds,mask*0.98);
        // Far-away painted ridges sit behind the actual forest curtain.
        float azimuth = atan(d.z,d.x);
        float far_ridge = 0.025 + 0.018*sin(azimuth*5.0+0.7) + 0.012*sin(azimuth*11.0);
        float near_ridge = 0.008 + 0.012*sin(azimuth*7.0+2.0) + 0.009*sin(azimuth*16.0);
        float far_mask = 1.0-smoothstep(far_ridge,far_ridge+0.006,d.y);
        float near_mask = 1.0-smoothstep(near_ridge,near_ridge+0.004,d.y);
        vec3 distant = mix(vec3(0.025,0.045,0.080),mix(ridge_tint,rim,0.68),daylight);
        vec3 nearer = mix(vec3(0.017,0.034,0.055),mix(ridge_tint,rim,0.38),daylight);
        color = mix(color,distant,far_mask*0.88);
        color = mix(color,nearer,near_mask*0.93);
    }
    color = mix(color,vec3(0.55,0.41,0.25)*mix(0.25,1.0,daylight),dust_amount*0.7);
    COLOR = color;
}
