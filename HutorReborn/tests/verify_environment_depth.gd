extends SceneTree
## Real opaque-pixel compositing through the saved actor hierarchy/Y-sort groups.
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
    for i in range(3):await process_frame
    await RenderingServer.frame_post_draw
    return root.get_texture().get_image()
func run() -> void:
    root.size=Vector2i(320,256)
    root.content_scale_size=root.size
    root.transparent_bg=true
    var world:Node2D=load("res://scenes/world/krivaya_sosna/krivaya_sosna.tscn").instantiate()
    root.add_child(world)
    current_scene=world
    world.atmosphere.set_effects_enabled(false)
    for light in world.find_children("*","PointLight2D",true,false):light.enabled=false
    for modulate in world.find_children("*","CanvasModulate",true,false):modulate.color=Color.WHITE
    for group in ["Ground","Ground Details","Ground Objects","Foreground","HUD"]:world.get_node(group).hide()
    for group in ["Structures","Nature","Props"]:
        for child in world.get_node("Actors/"+group).get_children():child.hide()
    var player:CharacterBody2D=world.get_node("Actors/Hans")
    player.set_physics_process(false)
    var sprite:AnimatedSprite2D=player.get_node("AnimatedSprite2D")
    sprite.play("idle_down")
    sprite.stop()
    sprite.frame=0
    var camera:Camera2D=player.get_node("Camera2D")
    camera.set_as_top_level(true)
    camera.position_smoothing_enabled=false
    camera.global_position=Vector2(1300,950)
    camera.force_update_scroll()
    var cases:Array=[]
    cases.append([world.get_node("Actors/Structures/ElderHouse"),110.0,25.0,"house"])
    cases.append([world.get_node("Actors/Nature/CrookedPine"),35.0,20.0,"landmark"])
    var ordinary:Node2D
    var fence:Node2D
    for item in world.get_node("Actors/Nature").get_children():
        if not ordinary and (item.scene_file_path.get_file().begins_with("pine_") or item.scene_file_path.get_file().begins_with("mirror_pine")):ordinary=item
    for item in world.get_node("Actors/Props").get_children():
        if not fence and item.scene_file_path.ends_with("/fence_h.tscn"):fence=item
    cases.append([ordinary,30.0,20.0,"tree"])
    cases.append([fence,22.0,18.0,"fence"])
    # The former hunter rack was already repurposed as the old man's bench in main.
    for kind in ["bush_round","fallen_b","short_bench"]:
        var found:Node2D
        for item in world.find_children("S32_*","Node2D",true,false):
            if item.get_meta("detail_asset","")==kind:
                found=item
                break
        check(found!=null,"saved scene contains depth-test object: "+kind)
        if found:cases.append([found,26.0 if kind=="fallen_b" else 18.0,18.0,kind])
    var audit:Array=[]
    for data in cases:
        var target:Node2D=data[0]
        target.global_position=Vector2(1300,1000)
        # Attached windows/smoke are irrelevant to the object's depth silhouette.
        for child in target.get_children():
            if child is CanvasItem and child.name!="Art":child.hide()
        for front in [false,true]:
            player.global_position=target.global_position+Vector2(0,data[2] if front else -data[1])
            player.hide()
            target.show()
            var object_image:=await capture()
            target.hide()
            player.show()
            var player_image:=await capture()
            target.show()
            var combined:=await capture()
            var overlap:=0
            var wrong:=0
            for y in range(256):
                for x in range(320):
                    var a:=object_image.get_pixel(x,y)
                    var b:=player_image.get_pixel(x,y)
                    if a.a<.999 or b.a<.999:continue
                    if a.is_equal_approx(b):continue
                    overlap+=1
                    var expected:Color=b if front else a
                    if not combined.get_pixel(x,y).is_equal_approx(expected):wrong+=1
            check(overlap>=12 and wrong==0,str(data[3])+": Hans "+("in front" if front else "behind")+" respects actual opaque overlap ("+str(overlap)+" pixels)")
            audit.append({"kind":data[3],"front":front,"overlap":overlap,"wrong":wrong})
        target.hide()
    if OS.get_cmdline_user_args().size()>0:
        var file:=FileAccess.open(OS.get_cmdline_user_args()[0],FileAccess.WRITE)
        file.store_string(JSON.stringify(audit,"  "))
        file.close()
    print("RESULT: ",passed," depth checks passed, ",failed," failed")
    world.queue_free()
    await process_frame
    quit(0 if failed==0 else 1)
