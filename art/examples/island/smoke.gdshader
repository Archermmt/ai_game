shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
#include "res://examples/island/reflection_projection.gdshaderinc"
varying vec3 object_coord;
uniform float opacity = 0.68;
uniform bool mirrored = false;
void vertex() {
    object_coord = VERTEX;
    if (mirrored) {
        VERTEX.y += mirror_height_shift(VERTEX, MODEL_MATRIX, CAMERA_POSITION_WORLD);
    }
}
void fragment(){
    float t = clamp(((object_coord.y - 1.03) / .80 - 6.08) / 4.65, 0., 1.);
    float x = (object_coord.x + .45) * .82903757 - (object_coord.z + .53) * .55919290 - .58;
    x += 1.65 - .15 * sin(t*8.) - t*t*.12;
    float center = 1. - smoothstep(.05,.99,abs(x)/(.068+.115*t));
    ALBEDO = vec3(.71,.61,.57);
    ALPHA = opacity * center * pow(1.-t,.68);
}
