extends "res://tests/verify_combat_ui_61.gd"
const LAB="res://scenes/combat/CombatGraphicsLab.tscn"
func capture(name:String) -> void:
    var output:=OS.get_environment("OVERHAUL_CAPTURE")
    if output.is_empty() or DisplayServer.get_name()=="headless":return
    await RenderingServer.frame_post_draw
    DirAccess.make_dir_recursive_absolute(output)
    check(root.get_texture().get_image().save_png(output+"/"+name+".png")==OK,"capture "+name)
func run() -> void:
    change_scene_to_file(LAB);await scene_changed;await frames()
    var lab:Control=current_scene
    check(lab.actors.size()==2 and lab.characters.item_count==7,"all seven existing battle kinds in lab")
    var master:TextureRect=lab.forest.get_node("Master")
    var transform:=master.get_transform()
    for i in 7:
        lab.characters.select(i);lab.characters.item_selected.emit(i);await frames()
        var kind:String=lab.characters.get_item_text(i)
        check(lab.actors.size()==2,"before/after actors "+kind)
        for j in lab.clips.item_count:
            lab.clips.select(j);lab.clips.item_selected.emit(j)
            var view:Button=lab.actors[1];var sprite:AnimatedSprite2D=view.sprite
            var count:=sprite.sprite_frames.get_frame_count(lab.selected_clip())
            check(count>0,"nonempty clip "+kind+"/"+lab.selected_clip())
            lab.step(1)
            check(sprite.frame==mini(1,count-1) and not sprite.is_playing(),"manual frame step/pause "+kind+"/"+lab.selected_clip())
            lab.set_frame(count-1);lab.step(1)
            check(sprite.frame==count-1,"frame clamp "+kind+"/"+lab.selected_clip())
            lab.play();await frames(2);lab.pause()
            check(not sprite.is_playing() and sprite.scale.x==sprite.scale.y,"play/pause uniform scale "+kind+"/"+lab.selected_clip())
            lab.set_frame(mini(2,count-1));lab.play()
            check(sprite.frame==mini(2,count-1) if count>3 else sprite.frame>=0,"resume preserves paused position "+kind+"/"+lab.selected_clip())
            lab.pause()
            if kind=="woodcutter":
                check(is_equal_approx(float(sprite.material.get_shader_parameter("saturation")),.8),"approved wood palette shader default is preserved")
            if kind in ["woodcutter","herbalist"]:
                check(sprite.sprite_frames.resource_path.contains("readability"),"battle-local atlas "+kind)
        if kind in ["woodcutter","spirit","mercenary","herbalist"]:
            for j in lab.clips.item_count:
                if lab.clips.get_item_text(j) in ["idle_down","default"]:lab.clips.select(j)
            lab.stop();await frames();await capture("lab-"+kind)
    for index in 4:
        lab.background.select(index);lab.background.item_selected.emit(index);await frames()
        check(lab.forest.visible==(index==0),"diagnostic background "+str(index))
    lab.characters.select(0);lab.characters.item_selected.emit(0)
    for key in lab.forest.effects:
        lab.forest.set_effect(key,false);check(not lab.forest.effects[key],"effect off "+key)
        lab.forest.set_effect(key,true)
    check(lab.forest.get_node("Atmosphere").get_child_count()==3,"three separate distant mist layers")
    lab.quality.select(0);lab.quality.item_selected.emit(0)
    check(not lab.forest.get_node("Atmosphere").is_processing(),"Off stops environment CPU processing")
    lab.quality.select(1);lab.quality.item_selected.emit(1)
    check(lab.forest.get_node("Atmosphere/DistantMist").visible and not lab.forest.get_node("Atmosphere/DistantMist2").visible,"Low reduces mist layers")
    lab.quality.select(2);lab.quality.item_selected.emit(2)
    lab.background.select(0);lab.background.item_selected.emit(0)
    lab.environment_only=true;lab._visibility();await frames(20);await capture("environment-standard")
    check(not lab.actors[1].visible and master.get_transform()==transform,"environment-only; master stays fixed")
    change_scene_to_file(ARENA);await scene_changed;await frames()
    var arena:Control=current_scene;arena.fast.button_pressed=true
    for id in ["duel","tincture","forest","companions","betrayal"]:
        arena._start_scenario(id);await ready_turn(arena)
        for view in arena.views.values():
            check(view.sprite.modulate.a==1 and view.sprite.self_modulate.a==1,"no opacity fade "+view.unit.kind)
            check(is_equal_approx((view.position+view.body.position).y,378),"common ground "+view.unit.kind)
        await capture(id+"-after")
        if id=="companions":
            # A controlled before fixture from main: old wood atlas/side pose and
            # old stage61 spirit. Hans/Leshy/material/background unchanged.
            var wood=arena.views.woodcutter
            wood.sprite.sprite_frames=load("res://assets/npc/woodcutter542/game/frames.tres")
            wood.sprite.play("idle_right")
            var tex:Texture2D=wood.sprite.sprite_frames.get_frame_texture("idle_right",0)
            var box:=tex.get_image().get_used_rect()
            wood.sprite.offset=Vector2(-tex.get_width()*.5,-box.end.y)
            wood.sprite.scale=Vector2.ONE*128/box.size.y
            var spirit=arena.views.spirit
            var sf:=SpriteFrames.new();sf.add_frame("default",load("res://assets/combat/stage61/spirit.png"))
            spirit.sprite.sprite_frames=sf;tex=sf.get_frame_texture("default",0);box=tex.get_image().get_used_rect()
            spirit.sprite.offset=Vector2(-tex.get_width()*.5,-box.end.y);spirit.sprite.scale=Vector2.ONE*128/box.size.y
            await frames();await capture("companions-before")
    var contact:Node2D=preload("res://scripts/combat/animation/combat_contact.gd").new()
    arena.add_child(contact);await create_timer(.4).timeout
    check(not is_instance_valid(contact),"bounded keyframe contact VFX self-frees")
    for size in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1280,800),Vector2i(1920,1080)]:
        if DisplayServer.get_name()!="headless":
            root.size=size;root.position=Vector2i.ZERO;await frames(8)
            check(DisplayServer.window_get_size()==size,"native window "+str(size))
            await capture("window-"+str(size.x)+"x"+str(size.y))
    if DisplayServer.get_name()!="headless":
        root.mode=Window.MODE_FULLSCREEN;await frames(10);await capture("fullscreen")
        check(root.mode==Window.MODE_FULLSCREEN,"native fullscreen")
        root.mode=Window.MODE_WINDOWED;root.size=Vector2i(960,540)
    print("RESULT: ",passed," overhaul checks passed, ",failed," failed")
    quit(0 if failed==0 else 1)
