extends "res://tools/review_interiors.gd"
## Actual framebuffer sequence of a timed, nonblocking old-man glance.
func run() -> void:
    travel=root.get_node("InteriorTravel")
    var world:Node2D=load(travel.VILLAGE).instantiate()
    root.add_child(world);current_scene=world;await frames(10)
    var life:Node=root.get_node("VillageLife");life.clock.running=false
    world.player.position=Vector2(1100,2300);life.clock.seek(361)
    var npc:HutorResident=life.states[&"old_man"].actor
    var deadline:=Time.get_ticks_msec()+3000
    while npc.state!=HutorResident.State.WAITING and Time.get_ticks_msec()<deadline:await physics_frame
    root.size=Vector2i(960,540);root.content_scale_size=root.size
    var camera:Camera2D=world.player.get_node("Camera2D")
    camera.set_as_top_level(true);camera.position_smoothing_enabled=false
    camera.global_position=npc.position+Vector2(0,-40);camera.force_update_scroll()
    await screenshot("before")
    world.player.position=npc.position+Vector2(-54,18)
    var count:=0
    var captures:Array=[]
    var began:=Time.get_ticks_msec()
    var end:=Time.get_ticks_msec()+12000
    var tail:=0
    while Time.get_ticks_msec()<end:
        await create_timer(.12).timeout
        await RenderingServer.frame_post_draw
        root.get_texture().get_image().save_png(destination+"-%03d.png"%count)
        captures.append({"image":destination+"-%03d.png"%count,"milliseconds":Time.get_ticks_msec()-began,"animation":String(npc.get_node("AnimatedSprite2D").animation),"state":npc.state,"step":npc.step_index})
        count+=1
        if npc.activity_controller.reactions.looks_started>0 and not npc.activity_controller.reactions.glancing:
            tail+=1
            if tail>=4:break
    var capture_file:=FileAccess.open(destination+"-frames.json",FileAccess.WRITE)
    capture_file.store_string(JSON.stringify(captures,"  ")+"\n")
    var reactions:HutorNpcVisualReactions=npc.activity_controller.reactions
    print("CAPTURE: ",count," real frames; glances=",reactions.looks_started," state=",npc.state," step=",npc.step_index)
    quit()
