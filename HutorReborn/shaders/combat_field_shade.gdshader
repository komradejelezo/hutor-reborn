shader_type canvas_item;
render_mode blend_mix, unshaded;
void fragment() {
    // Static tonal veil, not a displacement/filter of the supplied master.
    float vertical=sin(UV.y*3.14159265);
    float sides=smoothstep(0.0,0.08,UV.x)*smoothstep(0.0,0.08,1.0-UV.x);
    COLOR=vec4(0.025,0.02,0.025,vertical*sides*0.15);
}
