shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D tuft : source_color, filter_linear_mipmap_anisotropic;
uniform float clock = 0.0;
uniform bool flower = false;
varying vec3 tint;

void vertex() {
	// MultiMesh colors are the swatch's sRGB components in both render paths.
	tint = OUTPUT_IS_SRGB ? COLOR.rgb : pow(COLOR.rgb, vec3(2.2));
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.x += sin(world.x * 1.7 + world.z * 0.8 + clock * 0.85) * 0.017 * pow(1.0 - UV.y, 2.0);
}

void fragment() {
	if (flower) {
		vec2 p = (UV - vec2(0.5, 0.25)) * 2.0;
		float head = 1.0 - step(0.18 + 0.05 * cos(atan(p.y, p.x) * 5.0), length(p));
		float stem = (1.0 - step(0.025, abs(UV.x - 0.5))) * step(0.25, UV.y);
		ALBEDO = mix(tint * 0.48, tint, head);
		ALPHA = max(head, stem);
	} else {
		vec4 tex = texture(tuft, UV);
		ALBEDO = mix(tex.rgb, tint, 0.65) * mix(0.87, 1.03, 1.0 - UV.y);
		ALPHA = tex.a;
	}
	ALPHA_SCISSOR_THRESHOLD = 0.38;
}
