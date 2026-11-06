extends SceneTree
## Actual GPU pixels: character contrast, fog anchoring/scale and native shadows.
var passed:=0
var failed:=0
func _initialize() -> void:call_deferred("run")
func check(ok:bool,message:String) -> void:
    if ok:
        passed+=1
        print("PASS: ",message)
    else:
        failed+=1
        push_error("FAIL: "+message)
func capture() -> Image:
    for i in range(4):await process_frame
    await RenderingServer.frame_post_draw
    var result:=root.get_texture().get_image()
    result.convert(Image.FORMAT_RGBA8)
    return result
func difference(a:Image,b:Image,tolerance:int=1) -> Dictionary:
    if a.get_size()!=b.get_size():return {"bad":999999,"maximum":255}
    var aa:=a.get_data()
    var bb:=b.get_data()
    var bad:=0
    var maximum:=0
    for i in range(aa.size()):
        var error:=absi(int(aa[i])-int(bb[i]))
        maximum=maxi(maximum,error)
        if error>tolerance:bad+=1
    return {"bad":bad,"maximum":maximum}
func run() -> void:
    var world:Node2D=load("res://scenes/world/krivaya_sosna/krivaya_sosna.tscn").instantiate()
    root.add_child(world)
    current_scene=world
    var player:CharacterBody2D=world.get_node("Actors/Hans")
    player.set_physics_process(false)
    var sprite:AnimatedSprite2D=player.get_node("AnimatedSprite2D")
    sprite.play("idle_down")
    sprite.stop()
    sprite.frame=0
    var camera:Camera2D=player.get_node("Camera2D")
    camera.set_as_top_level(true)
    camera.position_smoothing_enabled=false
    var fog:ColorRect=world.get_node("Atmosphere/Screen/Fog")
    var material:ShaderMaterial=fog.material
    material.set_shader_parameter("time_override",40.0)
    for light in world.find_children("*","PointLight2D",true,false):
        light.set_process(false)
        light.energy=light.base_energy
    for plant in get_nodes_in_group("wind_plants"):
        if plant.material:plant.material.set_shader_parameter("strength",0.0)
    for particle in get_nodes_in_group("ambient_particles"):
        particle.emitting=false
        particle.hide()
    world.get_node("HUD").hide()
    var metrics:Dictionary={"readability":[]}
    var views:Dictionary={
        "plaza":[Vector2(1378,1362),Vector2(1378,1442)],
        "elder":[Vector2(950,780),Vector2(936,775)],
        "miller":[Vector2(1720,780),Vector2(1713,775)],
        "common":[Vector2(1287,1280),Vector2(1287,1242)],
        "hunter":[Vector2(880,1650),Vector2(858,1650)],
        "herbalist":[Vector2(1800,1650),Vector2(1717,1650)],
        "pine":[Vector2(510,720),Vector2(560,917)],
        "north":[Vector2(1387,270),Vector2(1387,198)],
        "gate":[Vector2(1287,1800),Vector2(1287,1865)]}
    for key in views:
        player.position=views[key][1]
        camera.global_position=views[key][0]
        camera.force_update_scroll()
        player.show()
        var with_player:=await capture()
        player.hide()
        var without_player:=await capture()
        var foot:=root.get_canvas_transform()*player.global_position
        var region:=Rect2i(Vector2i(foot)-Vector2i(20,52),Vector2i(40,54)).intersection(Rect2i(Vector2i.ZERO,with_player.get_size()))
        var visible:=0
        var total:=0.0
        for y in range(region.position.y,region.end.y):
            for x in range(region.position.x,region.end.x):
                var a:=with_player.get_pixel(x,y)
                var b:=without_player.get_pixel(x,y)
                var contrast:=maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))
                if contrast>4.0/255:
                    visible+=1
                    total+=contrast
        check(visible>=240,"Hans remains distinguishable with full lighting/fog: "+str(key)+" ("+str(visible)+" pixels)")
        metrics.readability.append({"view":key,"visible_pixels":visible,"mean_rgb_contrast":total/maxi(visible,1)})
    var cookie:GradientTexture2D=world.find_children("*","PointLight2D",true,false)[0].texture
    var cookie_image:=cookie.get_image()
    var radial_smooth:=cookie_image!=null
    if cookie_image:
        var previous_alpha:=cookie_image.get_pixel(256,256).a
        for x in range(257,512):
            var alpha:=cookie_image.get_pixel(x,256).a
            radial_smooth=radial_smooth and alpha<=previous_alpha+.005 and absf(alpha-previous_alpha)<.035
            previous_alpha=alpha
    check(radial_smooth and cookie_image.get_size()==Vector2i(512,512) and cookie_image.get_pixel(0,0).a==0 and cookie_image.get_pixel(256,256).a>.99,"real renderer generates a continuous radial texture without light bands")
    for name in ["Ground","Ground Details","Ground Objects","Actors","Foreground","Lighting"]:world.get_node(name).hide()
    root.size=Vector2i(320,192)
    root.content_scale_size=root.size
    root.transparent_bg=true
    camera.zoom=Vector2.ONE
    camera.global_position=Vector2(500,1800)
    camera.force_update_scroll()
    material.set_shader_parameter("vignette_strength",0.0)
    var reference:=await capture()
    var maximum_alpha:=0.0
    for y in range(192):
        for x in range(320):maximum_alpha=maxf(maximum_alpha,reference.get_pixel(x,y).a)
    check(maximum_alpha>.001 and maximum_alpha<=.035,"actual mist alpha remains low and nonzero")
    camera.global_position.x+=1
    camera.force_update_scroll()
    var shifted:=await capture()
    var alignment:=difference(reference.get_region(Rect2i(1,0,319,192)),shifted.get_region(Rect2i(0,0,319,192)))
    check(alignment.bad==0,"mist tracks a one-world-pixel camera pan without screen-grid swimming")
    material.set_shader_parameter("time_override",70.0)
    var drifting:=await capture()
    check(difference(shifted,drifting,0).bad>20,"mist has slow continuous motion at a fixed camera")
    material.set_shader_parameter("time_override",40.0)
    camera.global_position=Vector2(500,1800)
    camera.force_update_scroll()
    var normal:=await capture()
    root.size=Vector2i(640,384)
    # Keep the approved base viewport; this exercises actual integer window stretch.
    var doubled_window:=await capture()
    doubled_window.resize(320,192,Image.INTERPOLATE_NEAREST)
    var scale_error:=difference(normal,doubled_window)
    check(scale_error.bad==0,"integer window resize preserves world mist phase and scale")
    root.size=Vector2i(320,192)
    camera.zoom=Vector2(2,2)
    camera.force_update_scroll()
    var zoomed:=await capture()
    var expected:=normal.get_region(Rect2i(80,48,160,96))
    expected.resize(320,192,Image.INTERPOLATE_NEAREST)
    check(material.get_shader_parameter("viewport_world_size").is_equal_approx(Vector2(160,96)),"mist uses the actual camera world viewport size")
    var zoom_error:=difference(expected,zoomed)
    check(zoom_error.bad==0,"diagnostic 2x camera zoom preserves world-space mist coordinates")
    metrics.fog={"maximum_alpha":maximum_alpha,"pan":alignment,"window_scale":scale_error,"zoom":zoom_error}
    # Isolate the existing ground and one actual lantern. Leave native casters active.
    camera.zoom=Vector2.ONE
    camera.global_position=Vector2(1240,1160)
    camera.force_update_scroll()
    world.get_node("Atmosphere").set_effects_enabled(false)
    world.get_node("Ground").show()
    world.get_node("Actors").show()
    for node in world.find_children("*","CanvasItem",true,false):
        if node is Sprite2D or node is AnimatedSprite2D or node is Polygon2D or node is CPUParticles2D:node.hide()
    for light in world.find_children("*","PointLight2D",true,false):light.enabled=false
    var lantern:PointLight2D=world.get_node("Actors/Props/HangingLantern189/WarmLight2")
    lantern.enabled=true
    lantern.shadow_enabled=false
    var unshadowed:=await capture()
    lantern.shadow_enabled=true
    var shadowed:=await capture()
    var shadow_pixels:=0
    for y in range(192):
        for x in range(320):
            var a:=unshadowed.get_pixel(x,y)
            var b:=shadowed.get_pixel(x,y)
            if a.r-b.r>1.0/255:shadow_pixels+=1
    check(shadow_pixels>24,"native house occluder actually blocks lantern light on the ground")
    metrics.shadow_pixels=shadow_pixels
    if OS.get_cmdline_user_args().size()>0:
        var file:=FileAccess.open(OS.get_cmdline_user_args()[0],FileAccess.WRITE)
        file.store_string(JSON.stringify(metrics,"  ",true))
        file.close()
    print("RESULT: ",passed," lighting render checks passed, ",failed," failed")
    world.queue_free()
    await process_frame
    quit(0 if failed==0 else 1)
