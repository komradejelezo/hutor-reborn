extends "res://tests/verify_interiors.gd"
## Diagnostic placement at real scheduled goals, not evidence of native travel.
var life:Node
func run() -> void:
    travel=root.get_node("InteriorTravel")
    var village:Node2D=load(travel.VILLAGE).instantiate()
    root.add_child(village);current_scene=village;await frames(10)
    life=root.get_node("VillageLife");life.clock.running=false
    var cases:Array=[
        ["elder","elder",425,"read_documents"],
        ["innkeeper","inn",425,"prepare_inn"],
        ["innkeeper_wife","inn",625,"clean_tables"],
        ["innkeeper_wife","inn",625,"kitchen"],
        ["innkeeper_wife","inn",625,"sweep_floor"],
        ["woodcutter_wife","woodcutter",425,"cook"],
        ["woodcutter_wife","village",625,"sweep_yard"],
        ["woodcutter_wife","village",625,"household"],
        ["woodcutter_son","village",500,"play_stick"],
        ["woodcutter_son","village",500,"kneel_toy"],
        ["old_man","village",425,"sit_and_smoke"],
        ["herbalist","village",425,"gather"],
        ["herbalist","herbalist",665,"sort_herbs"],
        ["herbalist_brother","herbalist",425,"household"]]
    for row in cases:
        life.enabled=true;life.clock.seek(row[2])
        var room_id:StringName=StringName(row[1])
        if travel.active_id!=&"":travel.request_transition(travel.active_id,true);await wait_transition()
        if room_id!=&"village":travel.request_transition(room_id);await wait_transition()
        var r:HutorDailyResidentState=life.states[StringName(row[0])]
        var room:Node2D=travel.active_world
        life.enabled=false
        for rr in life.states.values():rr.actor.set_physics_process(false)
        r.scene=room_id;r.mode=&"local"
        for block in r.schedule.blocks:
            if block.scene==row[1] and block.start<=row[2]:r.block=block
        life._apply_local(r,r.actor.position)
        var npc:HutorResident=r.actor;npc.set_physics_process(false)
        var index:=-1
        for i in npc.definition.routine.size():
            if npc.definition.routine[i].label==row[3]:index=i
        check(index>=0,"original scheduled activity exists: "+str(row))
        if index<0:continue
        npc.step_index=index
        var step:HutorNpcRoutineStep=npc.current_step()
        npc.position=step.position;npc.state=npc.State.WAITING
        var pos:=npc.position
        var renderer:RefCounted=npc.activity_controller.visual54
        renderer.present(npc,r,&"",.25)
        var clip:String=npc.get_node("AnimatedSprite2D").animation
        check(clip.begins_with("work_"),"bound work starts at real goal: "+str(row)+" -> "+clip)
        check(npc.position==pos,"presentation never teleports body: "+str(row))
        if DisplayServer.get_name()!="headless" and not OS.get_cmdline_user_args().is_empty():
            var prefix:String=OS.get_cmdline_user_args()[0]
            var camera:Camera2D=room.player.get_node("Camera2D")
            camera.set_as_top_level(true);camera.position_smoothing_enabled=false
            camera.global_position=room.room_bounds.get_center() if room.get("room_bounds")!=null else npc.global_position
            camera.force_update_scroll();room.hud.hide()
            await create_timer(.35).timeout
            await RenderingServer.frame_post_draw
            root.get_texture().get_image().save_png(prefix+"-"+row[0]+"-"+row[3]+".png")
            await create_timer(1.0).timeout
            camera.set_as_top_level(false)
        if row[0]=="old_man":
            var original_facing:StringName=npc.facing;npc.facing=&"left"
            renderer.present(npc,r,&"",.1)
            check(npc.get_node("PipeSmoke").position.x<0,"pipe smoke follows reflected seated pose")
            npc.facing=original_facing
        if row[0]=="elder":
            renderer.work_clock=8;renderer.present(npc,r,&"",.1)
            check(npc.get_node("AnimatedSprite2D").animation==&"work_write","elder alternates reading and writing only at Desk")
        var spec:Dictionary=HutorNpcWorkBindings54.specification(r.id,r.scene,step.label)
        if spec.has("object"):
            var surface:Node2D=room.get_node(spec.object)
            var saved:=surface.position;surface.position+=Vector2(500,0)
            renderer.present(npc,r,&"",.1)
            check(String(npc.get_node("AnimatedSprite2D").animation).begins_with("idle_"),"missing work surface cannot animate in air: "+str(row))
            surface.position=saved
        var props:Node=room.get_node_or_null("Actors/NpcWorkProps54")
        var count:int=props.get_child_count() if props else 0
        for i in 20:renderer.present(npc,r,&"",.1)
        check(props==null or props.get_child_count()==count,"work prop is reused: "+str(row))
        npc.position+=Vector2(150,0);renderer.present(npc,r,&"",.1)
        check(String(npc.get_node("AnimatedSprite2D").animation).begins_with("idle_"),"work stops outside goal: "+str(row))
        npc.position=pos;npc.state=npc.State.TALKING;renderer.present(npc,r,&"",.1)
        check(String(npc.get_node("AnimatedSprite2D").animation).begins_with("talk_"),"dialogue overrides work: "+str(row))
        npc.state=npc.State.WAITING;renderer.present(npc,r,&"",.1)
        check(String(npc.get_node("AnimatedSprite2D").animation).begins_with("work_"),"same work resumes after dialogue: "+str(row))
    print("RESULT: ",passed," work binding checks passed, ",failed," failed")
    quit(0 if failed==0 else 1)
