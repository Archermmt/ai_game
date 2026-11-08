shader_type spatial;
uniform sampler2D island_field : filter_linear, repeat_disable;
uniform vec4 shallow : source_color=vec4(0.34,0.64,0.60,1.0);
uniform vec4 deep_color : source_color=vec4(0.15,0.39,0.46,1.0);
uniform float clock=0.0;
uniform float motion=1.0;
varying vec3 world;
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){vec2 uv=(world.xz+vec2(0.5))/64.0;vec2 field=texture(island_field,uv).rg;float land_height=field.r*2.2-0.15;float depth=field.g*8.0;vec2 wave=vec2(sin(world.x*1.4+world.z*0.6+clock*0.7),cos(world.z*1.9-world.x*0.4+clock*0.5));NORMAL_MAP=vec3(wave*0.025+0.5,1.0);NORMAL_MAP_DEPTH=0.35;vec3 base=mix(shallow.rgb,deep_color.rgb,smoothstep(0.2,6.0,depth));float shore=1.0-smoothstep(0.012,0.07,abs(land_height+0.04));float broken=0.65+0.35*sin(world.x*21.0+world.z*17.0+clock*0.8);ALBEDO=mix(base,vec3(0.82,0.90,0.81),shore*broken*0.8);ROUGHNESS=0.28;SPECULAR=0.5;EMISSION=base*0.2;}
