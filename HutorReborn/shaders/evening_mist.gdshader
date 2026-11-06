shader_type canvas_item;
render_mode unshaded;

uniform float fog_strength : hint_range(0.0, 0.10) = 0.032;
uniform float vignette_strength : hint_range(0.0, 0.30) = 0.16;
uniform vec3 mist_tint : source_color = vec3(0.45, 0.51, 0.53);
uniform vec3 edge_tint : source_color = vec3(0.025, 0.045, 0.060);
uniform vec2 camera_world = vec2(0.0);
uniform vec2 viewport_world_size = vec2(960.0, 540.0);
uniform vec2 readability_anchor = vec2(0.0);
uniform sampler2D mist_noise : filter_linear, repeat_enable;
// Negative uses normal engine time; nonnegative is a deterministic review mode.
uniform float time_override = -1.0;

void fragment() {
    float t = time_override < 0.0 ? TIME : time_override;
    vec2 world = camera_world + (UV - vec2(0.5)) * viewport_world_size;
    // One reusable native noise texture, period larger than the entire map.
    float broad = texture(mist_noise, world / 4096.0 + vec2(t * 0.0008, t * 0.0003)).r;
    float mist = smoothstep(0.25, 0.85, broad);
    // Broad, barely visible fog attenuation, never an outline or a player light.
    vec2 actor_delta = (world - readability_anchor) / vec2(92.0, 110.0);
    float protection = mix(0.15, 1.0, smoothstep(0.0225, 2.7225, dot(actor_delta, actor_delta)));
    vec2 edge_delta = (UV - vec2(0.5)) * vec2(1.0, 0.82);
    float edge = smoothstep(0.0961, 0.5776, dot(edge_delta, edge_delta));
    float haze_alpha = mist * fog_strength * protection;
    float edge_alpha = edge * vignette_strength;
    float alpha = haze_alpha + edge_alpha * (1.0 - haze_alpha);
    vec3 premultiplied = mist_tint * haze_alpha + edge_tint * edge_alpha * (1.0 - haze_alpha);
    COLOR = vec4(premultiplied / max(alpha, 0.00001), alpha);
}
