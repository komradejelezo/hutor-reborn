shader_type canvas_item;
uniform float strength = 1.0;
uniform float speed = 1.3;
void vertex() {
    float tip = pow(1.0 - UV.y, 2.0);
    float phase = MODEL_MATRIX[3].x * 0.031 + MODEL_MATRIX[3].y * 0.017;
    VERTEX.x += floor(sin(TIME * speed + phase) * strength * tip + 0.5);
}
