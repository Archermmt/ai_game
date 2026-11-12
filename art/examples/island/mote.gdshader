shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform vec4 tint : source_color = vec4(.96,.78,.81,.4);
void vertex() {
	vec3 s=vec3(length(MODEL_MATRIX[0].xyz),length(MODEL_MATRIX[1].xyz),length(MODEL_MATRIX[2].xyz));
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0]*s.x,INV_VIEW_MATRIX[1]*s.y,INV_VIEW_MATRIX[2]*s.z,MODEL_MATRIX[3]);
}
void fragment() {
	float r=length((UV-.5)*2.);
	ALBEDO=tint.rgb;
	ALPHA=tint.a*exp(-r*r*3.3)*(1.-smoothstep(.65,1.,r));
}
