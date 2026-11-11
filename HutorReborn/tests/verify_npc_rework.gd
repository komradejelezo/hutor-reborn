extends "res://tests/verify_interiors.gd"
## Real active-scene residents, original dialogue paths and visual-only attention.
var life: Node
func run() -> void:
    travel=root.get_node("InteriorTravel")
    var village:Node2D=load(travel.VILLAGE).instantiate()
    root.add_child(village);current_scene=village;await frames(10)
    life=root.get_node("VillageLife");life.clock.running=false
    var ids:Dictionary={}
    for id in life.states:ids[id]=life.states[id].actor.get_instance_id()
    var profiles:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/visuals/residents.json"))
    for id in profiles:
        var r:HutorDailyResidentState=life.states[StringName(id)]
        var minute:=665.0 if id=="herbalist" else 1215.0 if id=="old_man" else 425.0
        life.clock.seek(minute)
        check(travel.request_transition(r.schedule.home),"existing scene entry: "+id);await wait_transition()
        var room:Node2D=travel.active_world
        var npc:HutorResident=r.actor
        check(npc.is_inside_tree() and npc.get_instance_id()==ids[StringName(id)],"same original actor visible: "+id)
        var sprite:AnimatedSprite2D=npc.get_node("AnimatedSprite2D")
        check(sprite.texture_filter==CanvasItem.TEXTURE_FILTER_NEAREST and sprite.scale==Vector2.ONE and sprite.rotation==0,"undistorted nearest body: "+id)
        var f:SpriteFrames=sprite.sprite_frames
        check(int(f.get_meta("rework_version",0))==54,"approved Stage54 resource: "+id)
        for direction in ["down","up","left","right"]:
            check(f.get_frame_count("walk_"+direction)==8,"eight source walking images: "+id+"/"+direction)
            check(f.has_animation("idle_"+direction) and f.has_animation("turn_"+direction),"directional fallback exists: "+id+"/"+direction)
            npc.animator.apply("walk",StringName(direction),&"",false)
            check(not sprite.flip_h,"native directional art is not double mirrored: "+id+"/"+direction)
        check(f.get_frame_count("talk")==4,"four talk drawings: "+id)
        check(f.get_frame_count("idle_up")==1,"missing rear idle is honestly static: "+id)
        npc.animator.prefer_run=false
        # Directly tick an isolated renderer with the real body; the NPC's state
        # and timers are frozen for measurement, not rewritten by the renderer.
        npc.set_physics_process(false)
        var state_before:int=npc.state
        npc.state=HutorResident.State.WAITING
        var step:=npc.current_step();var clip_before:=step.animation;step.animation=&"" # Exercise a standing glance independently of prop-bound poses.
        var reactive:=HutorNpcVisualReactions.new(profiles[id])
        var hero:CharacterBody2D=room.player
        hero.position=npc.global_position+step.talk_offset+Vector2(24,0)
        var initial:={"position":npc.position,"state":npc.state,"index":npc.step_index,"wait":npc.wait_left,"goal":step.position,"facing":npc.facing}
        var delay:float=profiles[id].delay
        check(reactive.update(npc,delay*.5)==&"","reaction respects individual delay: "+id)
        check(reactive.update(npc,delay*.6)!=&"" and reactive.glancing,"brief glance starts: "+id)
        for i in 25:reactive.update(npc,.1)
        check(not reactive.glancing and reactive.looks_started==1,"glance finishes: "+id)
        for i in 400:reactive.update(npc,.1)
        check(reactive.looks_started==1,"lingering Hans does not constantly interrupt: "+id)
        check(initial=={"position":npc.position,"state":npc.state,"index":npc.step_index,"wait":npc.wait_left,"goal":step.position,"facing":npc.facing},"attention changes no routine, movement or facing state: "+id)
        step.animation=clip_before;npc.state=state_before
        # Existing accepted conversation must use this resident's four actual portraits.
        npc.state=HutorResident.State.WAITING;npc._present()
        var marker:HutorInteractable=npc.get_node("Interaction")
        var chosen:=false
        for offset in [Vector2(0,22),Vector2(22,0),Vector2(-22,0),Vector2(0,-22),Vector2(0,35)]:
            hero.position=marker.global_position+offset;await frames()
            if free_at(room,hero.position) and hero.sensor.target==marker:chosen=true;break
        check(chosen,"reachable original E conversation: "+id)
        if chosen:
            var saved_index:=npc.step_index
            await tap_e();await create_timer(.28).timeout
            var manager:Node=root.get_node("DialogueManager")
            check(manager.is_active() and npc.state==HutorResident.State.TALKING,"work stops through existing dialogue: "+id)
            if manager.is_active():
                var line:Dictionary=manager.data.nodes[manager.current_line]
                for emotion in ["neutral","joy","displeased","anxious"]:
                    var variant:Dictionary=line.duplicate(true);variant.emotion=emotion
                    var texture:Texture2D=manager.window._resolve_portrait(variant)
                    check(texture.resource_path==profiles[id].portraits[emotion] and texture.get_size()==Vector2(128,192),"correct real portrait: "+id+"/"+emotion)
                var position:=npc.position;await frames(8)
                check(npc.position==position,"dialogue holds body: "+id)
                manager.close_dialogue();await create_timer(.2).timeout
                check(npc.state!=HutorResident.State.TALKING and npc.step_index==saved_index,"original occupation resumes: "+id)
        npc.set_physics_process(true)
        check(travel.request_transition(r.schedule.home,true),"existing exit: "+id);await wait_transition()
    check(profiles.old_man.delay>profiles.woodcutter_son.delay*5,"old man reacts much slower than curious child")
    for id in life.states:check(life.states[id].actor.get_instance_id()==ids[id],"no duplicate resident: "+String(id))
    print("RESULT: ",passed," Stage54 resident checks passed, ",failed," failed")
    quit(0 if failed==0 else 1)
