shader_type canvas_item;
uniform float density : hint_range(0.0, 1.0) = 0.075;
void fragment() {
    // This shader is on a separate distant strip, never on the master or ground.
    float band = pow(sin(UV.y * 3.14159265), 2.0);
    float drift = 0.65 + 0.2 * sin(UV.x * 9.0 - TIME * 0.025)
        + 0.15 * sin(UV.x * 17.0 + UV.y * 3.0 - TIME * 0.017);
    COLOR = vec4(0.52, 0.54, 0.58, band * drift * density);
}
