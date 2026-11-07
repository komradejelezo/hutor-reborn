extends "res://tests/verify_environment_depth.gd"
## Opaque raster comparison through the actual nested world/population Y-sort.
func run() -> void:
    # Isolate the approved pre-schedule component fixture. Live residency has separate integration coverage.
    root.get_node("VillageLife").enabled=false
    root.size=Vector2i(320,256)
    root.content_scale_size=root.size
    root.transparent_bg=true
    var world:Node2D=load("res://scenes/world/krivaya_sosna/krivaya_sosna.tscn").instantiate()
    root.add_child(world); current_scene=world
    world.atmosphere.set_effects_enabled(false)
    for light in world.find_children("*","PointLight2D",true,false):light.enabled=false
    for modulate in world.find_children("*","CanvasModulate",true,false):modulate.color=Color.WHITE
    for group in ["Ground","Ground Details","Ground Objects","Extension Ground","New Paths","Foreground","HUD"]:world.get_node(group).hide()
    for group in ["Structures","Nature","Props"]:
        for child in world.get_node("Actors/"+group).get_children():child.hide()
    var population:Node2D=world.get_node("Actors/Residents")
    for actor in population.residents.values():
        actor.set_physics_process(false); actor.hide()
    var hans:CharacterBody2D=world.player
    hans.set_physics_process(false); hans.hide()
    var camera:Camera2D=hans.get_node("Camera2D")
    camera.set_as_top_level(true); camera.position_smoothing_enabled=false
    camera.global_position=Vector2(1300,950); camera.force_update_scroll()
    var fence:Node2D
    for item in world.get_node("Actors/Props").get_children():
        if item.scene_file_path.ends_with("/fence_h.tscn"):
            fence=item; break
    var cases:Array=[
        [world.get_node("Actors/Structures/ElderHouse"),110.0,16.0,"house"],
        [world.get_node("Actors/Nature/CrookedPine"),28.0,16.0,"pine"],
        [fence,17.0,12.0,"fence"],
        [hans,14.0,14.0,"Hans"]]
    var audit:Array=[]
    for id in [&"woodcutter",&"woodcutter_son",&"old_man"]:
        var actor:Node2D=population.resident(id)
        var sprite:AnimatedSprite2D=actor.get_node("AnimatedSprite2D")
        sprite.play("idle_down"); sprite.stop(); sprite.frame=0
        for data in cases:
            var target:Node2D=data[0]
            target.global_position=Vector2(1300,1000)
            for child in target.get_children():
                if child is CanvasItem and child.name!="Art" and child.name!="AnimatedSprite2D":child.hide()
            for front in [false,true]:
                actor.global_position=target.global_position+Vector2(0,data[2] if front else -data[1])
                actor.hide(); target.show()
                var object_image:Image=await capture()
                target.hide(); actor.show()
                var actor_image:Image=await capture()
                target.show()
                var combined:Image=await capture()
                var overlap:=0
                var wrong:=0
                for y in range(256):
                    for x in range(320):
                        var a:Color=object_image.get_pixel(x,y)
                        var b:Color=actor_image.get_pixel(x,y)
                        if a.a<.999 or b.a<.999 or a.is_equal_approx(b):continue
                        overlap+=1
                        var expected:Color=b if front else a
                        if not combined.get_pixel(x,y).is_equal_approx(expected):wrong+=1
                check(overlap>=12 and wrong==0,String(id)+" "+("front/" if front else "behind/")+String(data[3])+": "+str(overlap)+" opaque pixels, "+str(wrong)+" wrong")
                audit.append({"resident":id,"target":data[3],"front":front,"overlap":overlap,"wrong":wrong})
            target.hide()
        actor.hide()
    if not OS.get_cmdline_user_args().is_empty():
        var file:=FileAccess.open(OS.get_cmdline_user_args()[0],FileAccess.WRITE)
        file.store_string(JSON.stringify(audit,"  "));file.close()
    print("RESULT: ",passed," resident depth checks passed, ",failed," failed")
    world.queue_free(); await process_frame
    quit(0 if failed==0 else 1)
