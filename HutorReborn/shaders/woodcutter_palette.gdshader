shader_type canvas_item;
// Colour only: preserve UVs, alpha, nearest sampling and authored animation.
// Normal CanvasItem lighting remains active in the village and interiors.
uniform float saturation : hint_range(0.0, 1.0) = 0.8;
uniform vec3 balance = vec3(0.94, 0.97, 1.0);
uniform float exposure : hint_range(0.5, 1.5) = 0.96;

void fragment() {
    vec3 original = COLOR.rgb;
    float luminance = dot(original, vec3(0.2126, 0.7152, 0.0722));
    COLOR.rgb = mix(vec3(luminance), original, saturation) * balance * exposure;
}
