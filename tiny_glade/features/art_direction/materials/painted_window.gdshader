shader_type spatial;

uniform bool dusk = false;
uniform float dusk_mix : hint_range(0.0, 1.0) = 0.0;
instance uniform bool sill_plant = false;
varying float pane_phase;

void vertex() {
	pane_phase = sin(dot(MODEL_MATRIX[3].xz, vec2(0.83, 1.73)));
}

float oval(vec2 p, vec2 centre, vec2 radii, float tilt) {
	p -= centre;
	p.y -= p.x * tilt;
	return 1.0 - smoothstep(0.83, 1.07, length(p / radii));
}

void fragment() {
	float warm = max(dusk_mix, dusk ? 0.65 : 0.0);
	// The glass catches a moving slice of sky as the player walks past.
	vec3 sight = (INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz;
	vec2 look = vec2(dot(sight, normalize(MODEL_MATRIX[0].xyz)), sight.y);
	vec2 reflection_uv = UV + look * vec2(0.16, 0.10);
	float x = reflection_uv.x + pane_phase;
	float treeline = 0.57 + sin(9.0 * x) * 0.09 + sin(23.0 * x + 0.8) * 0.035;
	float sky = smoothstep(treeline - 0.11, treeline + 0.09, reflection_uv.y);
	vec3 reflection = mix(vec3(0.045, 0.095, 0.083), vec3(0.24, 0.35, 0.35), sky);

	// The recessed room shifts behind the reflection. Soft folds frame one
	// brighter wall, and the sill silhouette stays attached to its window.
	vec2 room = UV - look * vec2(0.085, 0.055);
	float left_fold = 0.09 + 0.12 * room.y * room.y + 0.018 * sin(room.y * 8.0);
	float curtain = (1.0 - smoothstep(left_fold - 0.015, left_fold + 0.015, room.x))
		+ smoothstep(0.94 - 0.13 * room.y, 0.965 - 0.13 * room.y, room.x);
	float folds = 0.8 + 0.2 * cos(room.x * 89.0 + room.y * 2.2);
	float room_light = exp(-3.8 * dot(room - vec2(0.60, 0.45), room - vec2(0.60, 0.45)));
	vec3 room_paint = mix(vec3(0.47, 0.245, 0.115), vec3(1.0, 0.64, 0.30), room_light);
	room_paint = mix(room_paint, vec3(0.52, 0.29, 0.14) * folds, clamp(curtain, 0.0, 1.0));
	float silhouette = 0.0;
	if (sill_plant) {
		float pot = 1.0 - smoothstep(0.0, 0.012, abs(room.x - 0.28) - (0.061 + room.y * 0.2));
		pot *= 1.0 - smoothstep(0.14, 0.15, room.y);
		float stem = (1.0 - smoothstep(0.004, 0.010, abs(room.x - 0.28 - room.y * 0.07)))
			* (1.0 - smoothstep(0.26, 0.28, room.y));
		silhouette = max(max(pot, stem), max(oval(room, vec2(0.266, 0.223), vec2(0.042, 0.02), -0.56),
			oval(room, vec2(0.332, 0.26), vec2(0.044, 0.023), 0.57)));
	}
	float frame_shade = smoothstep(0.0, 0.075, min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y)));
	room_paint *= mix(0.73, 1.0, frame_shade) * mix(1.0, 0.23, silhouette);
	ALBEDO = mix(reflection * mix(1.0, 0.57, silhouette), room_paint * 0.37, warm);
	EMISSION = room_paint * warm * 0.82;
	ROUGHNESS = mix(0.39, 0.61, warm);
	SPECULAR = 0.28;
}
