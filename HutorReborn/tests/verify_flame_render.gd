extends SceneTree
func _initialize() -> void:call_deferred("run")
func capture() -> Image:
    for i in 3:await process_frame
    await RenderingServer.frame_post_draw
    return root.get_texture().get_image()
func run() -> void:
    root.size=Vector2i(160,160);root.content_scale_size=root.size
    var sprite:=Sprite2D.new();sprite.centered=false;sprite.position=Vector2(40,40)
    sprite.texture=load("res://assets/interiors/stage44/fireplace.png");sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
    var material:=ShaderMaterial.new();material.shader=load("res://shaders/hearth_flame.gdshader")
    sprite.material=material;root.add_child(sprite)
    material.set_shader_parameter("flame_phase",0);var still:=await capture()
    var changed:=0;var outside:=0
    for phase in [1,2]:
        material.set_shader_parameter("flame_phase",phase);var moving:=await capture()
        for y in 160:
            for x in 160:
                if still.get_pixel(x,y).is_equal_approx(moving.get_pixel(x,y)):continue
                changed+=1
                if not Rect2i(62,85,17,18).has_point(Vector2i(x,y)):outside+=1
    var ok:=changed>0 and outside==0
    print("RESULT: flame pixel changes=",changed," outside flame ROI=",outside," success=",ok)
    quit(0 if ok else 1)
