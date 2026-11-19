shader_type canvas_item;
uniform float density : hint_range(0.0, 1.0) = 0.045;
uniform float phase = 0.0;
uniform float drift_speed = 0.025;
void fragment() {
    // Separate distant strip. Never samples/displaces the ground/master image.
    float band = pow(sin(UV.y * 3.14159265), 2.0);
    float side = smoothstep(0.0, 0.1, UV.x) * smoothstep(0.0, 0.1, 1.0 - UV.x);
    float drift = 0.65 + 0.2 * sin(UV.x * 9.0 - TIME * drift_speed + phase)
        + 0.15 * sin(UV.x * 17.0 + UV.y * 3.0 - TIME * drift_speed * 0.68 + phase);
    COLOR = vec4(0.52, 0.54, 0.58, band * side * drift * density);
}
