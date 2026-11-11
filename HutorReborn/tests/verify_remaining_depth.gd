extends "res://tests/verify_environment_depth.gd"
func run() -> void:
    root.size=Vector2i(320,256);root.content_scale_size=root.size;root.transparent_bg=true
    for id in ["woodcutter","old_man","storehouse"]:
        var room:Node2D=load("res://scenes/interiors/"+id+".tscn").instantiate()
        root.add_child(room);current_scene=room
        room.get_node("Evening").color=Color.WHITE
        room.atmosphere.set_effects_enabled(false) # Freeze decorative flame during opaque-layer comparisons.
        for lamp in room.find_children("*","PointLight2D",true,false):lamp.enabled=false
        for name in ["Void","Floor","Walls","FloorDetails","HUD","Exit"]:room.get_node(name).hide()
        for item in room.get_node("Actors/Props").get_children():item.hide()
        var hero:CharacterBody2D=room.player
        hero.set_physics_process(false);hero.sensor.set_physics_process(false)
        hero.sprite.play("idle_down");hero.sprite.stop();hero.sprite.frame=0
        var camera:Camera2D=hero.get_node("Camera2D")
        camera.set_as_top_level(true);camera.position_smoothing_enabled=false
        camera.global_position=Vector2(480,320);camera.force_update_scroll()
        var names:Array=["ParentsBed","SonBed","DiningTable","Stove","ChairA"] if id=="woodcutter" else ["OldBed","Armchair","SideTable","OldStove"] if id=="old_man" else ["ShelfA","GrainD","CrateA","WorkTable","Firewood"]
        for name in names:
            var target:Node2D=room.get_node("Actors/Props/"+name)
            target.position=Vector2(480,350)
            for front in [false,true]:
                hero.position=target.position+Vector2(0,12 if front else -28)
                hero.hide();target.show();var object_image:Image=await capture()
                target.hide();hero.show();var hero_image:Image=await capture()
                target.show();var combined:Image=await capture()
                var overlap:=0;var wrong:=0
                for y in 256:
                    for x in 320:
                        var a:Color=object_image.get_pixel(x,y)
                        var b:Color=hero_image.get_pixel(x,y)
                        if a.a<.999 or b.a<.999 or a.is_equal_approx(b):continue
                        overlap+=1
                        if not combined.get_pixel(x,y).is_equal_approx(b if front else a):wrong+=1
                check(overlap>=12 and wrong==0,id+"/"+name+" "+("front" if front else "behind")+": "+str(overlap)+" opaque overlap, "+str(wrong)+" wrong")
            target.hide()
        room.queue_free();await process_frame
    print("RESULT: ",passed," remaining-interior depth checks passed, ",failed," failed")
    quit(0 if failed==0 else 1)
