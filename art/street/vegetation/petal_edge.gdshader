shader_type spatial;
render_mode unshaded, cull_front;

uniform vec4 ink : source_color = vec4(0.63, 0.48, 0.60, 1.0);
uniform float thickness = 0.020;

void vertex() {
	VERTEX += NORMAL * thickness;
}

void fragment() {
	ALBEDO = ink.rgb;
}
