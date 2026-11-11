shader_type canvas_item;
// Existing orange source texels only. The stove and its proportions stay still.
// No smooth UV motion, generated colours or new character frames.
uniform int flame_phase = 0;
bool flame(vec4 c) { return c.a > 0.2 && c.r > 0.24 && c.r > c.g * 1.35 && c.g > c.b * 1.5; }
void fragment() {
    vec2 pixel = floor(UV / TEXTURE_PIXEL_SIZE);
    vec4 original = texture(TEXTURE, (pixel + vec2(0.5)) * TEXTURE_PIXEL_SIZE);
    vec4 color = original;
    if (pixel.x >= 22.0 && pixel.x <= 38.0 && pixel.y >= 45.0 && pixel.y <= 62.0) {
        float phase = float(flame_phase);
        float shift = phase == 1.0 ? 1.0 : (phase == 2.0 ? -1.0 : 0.0);
        vec4 neighbor = texture(TEXTURE, (pixel + vec2(shift, 0.0) + vec2(0.5)) * TEXTURE_PIXEL_SIZE);
        if (flame(original) || flame(neighbor)) color = neighbor;
    }
    COLOR = color;
}
