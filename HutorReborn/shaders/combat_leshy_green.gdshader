shader_type canvas_item;
varying vec4 actor_tint;
void vertex() { actor_tint=COLOR; }
void fragment() {
    vec4 c = texture(TEXTURE, UV);
    float warm_light = step(0.55,max(c.r,c.g))*step(0.22,c.g)*step(c.r,c.g*1.7)*step(c.b,c.g*0.7);
    c.rgb=mix(c.rgb,vec3(c.r*0.3,min(c.g*1.3,1.0),c.b*0.65),warm_light*0.8);
    COLOR=c*actor_tint;
}
