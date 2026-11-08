shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D tuft : source_color,filter_linear_mipmap_anisotropic;
uniform float clock=0.0;
uniform bool flower=false;
varying vec4 tint;
void vertex(){tint=COLOR;vec3 world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;VERTEX.x+=sin(world.x*1.7+world.z*0.8+clock*1.3)*0.035*(1.0-UV.y)*(1.0-UV.y);}
void fragment(){vec4 tex=texture(tuft,UV);if(flower){vec2 p=(UV-vec2(0.5,0.25))*2.0;float r=length(p);float head=1.0-step(0.18+0.05*cos(atan(p.y,p.x)*5.0),r);float stem=(1.0-step(0.025,abs(UV.x-0.5)))*step(0.25,UV.y);ALBEDO=mix(vec3(0.27,0.43,0.21),tint.rgb,head);ALPHA=max(head,stem);}else{ALBEDO=tex.rgb*mix(0.88,1.15,tint.r);ALPHA=tex.a;}ALPHA_SCISSOR_THRESHOLD=0.38;}
