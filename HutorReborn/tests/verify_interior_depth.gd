extends "res://tests/verify_environment_depth.gd"
## Actual opaque compositing, including inherited prop art and nested Y-sort.
func run() -> void:
    root.size=Vector2i(320,256);root.content_scale_size=root.size;root.transparent_bg=true
    for id in ["inn","elder","herbalist"]:
        var world:Node2D=load("res://scenes/interiors/"+id+".tscn").instantiate()
        root.add_child(world);current_scene=world
        world.get_node("Evening").color=Color.WHITE
        for light in world.find_children("*","PointLight2D",true,false):light.enabled=false
        for group in ["Void","Floor","Walls","HUD","Exit"]:world.get_node(group).hide()
        for item in world.get_node("Actors/Props").get_children():item.hide()
        var hero:CharacterBody2D=world.player
        hero.set_physics_process(false);hero.sensor.set_physics_process(false)
        var sprite:AnimatedSprite2D=hero.sprite
        sprite.play("idle_down");sprite.stop();sprite.frame=0
        var camera:Camera2D=hero.get_node("Camera2D")
        camera.set_as_top_level(true);camera.position_smoothing_enabled=false
        camera.global_position=Vector2(480,320);camera.force_update_scroll()
        var names:Array=["Counter","TableA","Fireplace"] if id=="inn" else ["Desk","Bed","Chest","Hearth"] if id=="elder" else ["BedA","Table","Stove"]
        for name in names:
            var target:Node2D=world.get_node("Actors/Props/"+name)
            target.position=Vector2(480,350)
            for front in [false,true]:
                hero.position=target.position+Vector2(0,12 if front else -28)
                hero.hide();target.show()
                var a:Image=await capture()
                target.hide();hero.show()
                var b:Image=await capture()
                target.show()
                var combined:Image=await capture()
                var overlap:=0;var wrong:=0
                for y in 256:
                    for x in 320:
                        var object_color:Color=a.get_pixel(x,y)
                        var hero_color:Color=b.get_pixel(x,y)
                        if object_color.a<.999 or hero_color.a<.999 or object_color.is_equal_approx(hero_color):continue
                        overlap+=1
                        var expected:Color=hero_color if front else object_color
                        if not combined.get_pixel(x,y).is_equal_approx(expected):wrong+=1
                check(overlap>=12 and wrong==0,id+"/"+name+" "+("front" if front else "behind")+": "+str(overlap)+" opaque overlap, "+str(wrong)+" wrong pixels")
            target.hide()
        world.queue_free();await process_frame
    print("RESULT: ",passed," interior depth checks passed, ",failed," failed")
    quit(0 if failed==0 else 1)
