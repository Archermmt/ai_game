shader_type spatial;
render_mode unshaded,cull_disabled;
uniform sampler2D leaves : source_color,filter_linear_mipmap_anisotropic;
uniform vec4 tint : source_color=vec4(1.0);
uniform float clock=0.0;
varying vec3 world;
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;VERTEX.x+=sin(world.x+world.z+clock)*0.018;}
void fragment(){vec4 tex=texture(leaves,UV);ALBEDO=tex.rgb*tint.rgb;ALPHA=tex.a;ALPHA_SCISSOR_THRESHOLD=0.40;}
