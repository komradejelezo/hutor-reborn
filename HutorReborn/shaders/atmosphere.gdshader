shader_type canvas_item;
render_mode unshaded;
uniform float fog_strength : hint_range(0.0, 1.0) = 0.07;
uniform vec2 camera_world = vec2(0.0);
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
    vec2 i = floor(p); vec2 f = fract(p); f = f*f*(3.0-2.0*f);
    return mix(mix(hash(i), hash(i+vec2(1.,0.)),f.x),mix(hash(i+vec2(0.,1.)),hash(i+vec2(1.,1.)),f.x),f.y);
}
void fragment() {
    vec2 pixel_uv = floor(UV * vec2(480.0, 270.0)) / vec2(480.0, 270.0);
    vec2 p = pixel_uv * vec2(5.0, 3.0) + camera_world * 0.003;
    float mist = noise(p + vec2(TIME * 0.025, TIME * 0.009));
    mist = smoothstep(0.28, 0.85, mist);
    float vignette = smoothstep(0.35, 0.78, length((UV-0.5)*vec2(1.0, 0.82)));
    vec3 col = mix(vec3(0.57, 0.64, 0.61), vec3(0.02, 0.05, 0.055), vignette);
    float alpha = mist * fog_strength + vignette * 0.42;
    COLOR = vec4(col, alpha);
}
