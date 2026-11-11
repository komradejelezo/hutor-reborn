extends "res://tests/verify_interiors.gd"
## In-memory real actors, no saved scene/schedule edits. Tests presentation only.
func run() -> void:
    travel=root.get_node("InteriorTravel")
    change_scene_to_file(travel.VILLAGE);await frames(12)
    var life:Node=root.get_node("VillageLife");life.clock.running=false
    life.clock.seek(425);await frames(5)
    check(travel.request_transition(&"inn"),"enter original inn");await wait_transition()
    var r:HutorDailyResidentState=life.states[&"innkeeper"]
    var npc:HutorResident=r.actor
    npc.set_physics_process(false)
    var sprite:AnimatedSprite2D=npc.get_node("AnimatedSprite2D")
    var animator:Node=npc.animator
    for other in life.states.values():other.actor.set_physics_process(false)
    for id in life.states:
        var f:SpriteFrames=HutorNpcVisualLibrary.frames_for(id,life.states[id].original.frames)
        check(int(f.get_meta("correction_version",0))==541,"corrected resource connected: "+String(id))
        var body:HutorResident=life.states[id].actor
        var drawing:AnimatedSprite2D=body.get_node("AnimatedSprite2D")
        var work:StringName=&""
        for name in f.get_animation_names():
            if String(name).begins_with("work_") and f.get_frame_count(name)>2:work=name;break
        var anchor:=body.position
        body.animator.set_work_context(String(id)+"/test")
        body.animator.apply("work",&"right",work,false)
        drawing.set_frame_and_progress(2,.3)
        body.animator.apply("talk",&"right",&"",false)
        body.animator.apply("work",&"right",work,false)
        check(drawing.frame==2 and is_equal_approx(drawing.frame_progress,.3) and body.position==anchor,"each resident resumes own work without moving feet: "+String(id))
        for facing in [&"down",&"up",&"left",&"right"]:
            var count:=f.get_frame_count("walk_"+String(facing))
            check(count==8,"actual source walking count unchanged: "+String(id)+"/"+String(facing))
    animator.set_work_context("same-chore")
    animator.apply("work",&"right",&"work_wipe",false)
    sprite.set_frame_and_progress(3,.65)
    animator.apply("talk",&"right",&"",false)
    animator.apply("work",&"right",&"work_wipe",false)
    check(sprite.frame==3 and is_equal_approx(sprite.frame_progress,.65),"conversation resumes exact stroke, not frame zero")
    animator.apply("idle",&"down",&"",false)
    animator.set_work_context("next-chore")
    animator.apply("work",&"right",&"work_wipe",false)
    check(sprite.frame==0,"new chore cannot inherit old cursor")
    sprite.set_frame_and_progress(4,.2)
    animator.set_work_context("new-scene-same-clip")
    animator.apply("work",&"right",&"work_wipe",false)
    check(sprite.frame==0,"same clip in a new context starts fresh")
    animator.apply("walk",&"right",&"",false)
    sprite.set_frame_and_progress(5,.4)
    animator.apply("walk",&"left",&"",false)
    check(sprite.frame==5 and is_equal_approx(sprite.frame_progress,.4) and not sprite.flip_h,"native left retains gait phase and orientation")
    var original_speed:float=npc.definition.speed
    npc.state=npc.State.MOVING;npc.velocity=Vector2(original_speed*.1,0)
    npc.activity_controller.present(npc)
    check(is_equal_approx(sprite.speed_scale,.1),"slow arrival has proportional playback, no 35 percent floor")
    npc.velocity=Vector2(original_speed,0);npc.facing=&"right"
    npc.activity_controller.visual54.present(npc,r,&"left",.1)
    check(sprite.animation==&"walk_right","a stale visual glance cannot replace actual locomotion")
    npc.state=npc.State.TALKING;sprite.position=Vector2(0,18)
    npc.activity_controller.visual54.present(npc,r,&"",.01)
    check(sprite.position==Vector2.ZERO,"full standing body retains feet pivot immediately after work")
    sprite.position=Vector2(0,18);sprite.z_index=1
    npc.get_node("PipeSmoke").emitting=true
    npc.activity_controller.clear_props()
    check(sprite.position==Vector2.ZERO and sprite.z_index==0 and not npc.get_node("PipeSmoke").emitting,"parking clears work offset, overlay and smoke")
    check(npc.definition.speed==original_speed,"presentation never changes physical speed")
    print("RESULT: ",passed," NPC correction checks passed, ",failed," failed")
    quit(0 if failed==0 else 1)
