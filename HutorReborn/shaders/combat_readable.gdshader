shader_type canvas_item;
render_mode blend_mix, unshaded;
uniform float saturation = 1.0;
uniform vec3 balance = vec3(1.0);
uniform float exposure = 1.04;
uniform bool green_magic = false;
varying vec4 actor_tint;
void vertex() { actor_tint=COLOR; }
void fragment() {
    vec4 c=texture(TEXTURE,UV);
    float lum=dot(c.rgb,vec3(0.2126,0.7152,0.0722));
    vec3 rgb=mix(vec3(lum),c.rgb,saturation)*balance*exposure;
    // Gentle warm reflected light lifts deep black shadows inside the model.
    rgb=max(rgb,vec3(0.028,0.021,0.016));
    if (green_magic) {
        float light=step(0.55,max(c.r,c.g))*step(0.22,c.g)*step(c.r,c.g*1.7)*step(c.b,c.g*0.7);
        rgb=mix(rgb,vec3(rgb.r*0.3,min(rgb.g*1.3,1.0),rgb.b*0.65),light*0.8);
    }
    // Key light comes from the sunset above/right. Highlight existing silhouette
    // pixels only; never emit alpha beyond the supplied texture contour.
    float top=texture(TEXTURE,UV-vec2(0.0,TEXTURE_PIXEL_SIZE.y)).a;
    float right=texture(TEXTURE,UV+vec2(TEXTURE_PIXEL_SIZE.x,0.0)).a;
    float rim=max(0.0,c.a-min(top,right));
    rgb=mix(rgb,vec3(0.68,0.50,0.32),rim*0.12);
    COLOR=vec4(rgb,c.a)*actor_tint;
}
