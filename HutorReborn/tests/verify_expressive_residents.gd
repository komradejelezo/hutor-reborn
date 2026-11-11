extends "res://tests/verify_interiors.gd"
## Real active-scene residents, original dialogue paths and visual-only attention.
var life: Node
func retained_pixels(actual:Image, original:Image, cleaned:bool) -> bool:
    if actual.get_size()!=original.get_size():return false
    if not cleaned:return actual.get_data()==original.get_data()
    var a:=actual.get_data();var b:=original.get_data()
    for i in range(0,a.size(),4):
        if a[i+3]>b[i+3]:return false
        # Godot fixes hidden RGB at transparent borders during texture import.
        if a[i+3]>0 and (a[i]!=b[i] or a[i+1]!=b[i+1] or a[i+2]!=b[i+2]):return false
    return true
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
        var original_path:String="res://assets/npc/stage46/"+id+".tres"
        if not ResourceLoader.exists(original_path):original_path="res://assets/npc/stage43/"+id+"/frames.tres"
        var original_frames:SpriteFrames=load(original_path)
        for direction in ["down","up","left","right"]:
            check(f.has_animation("idle_"+direction) and f.has_animation("walk_"+direction) and f.has_animation("turn_"+direction),"four-way poses/walk/turn: "+id+"/"+direction)
            var unchanged:=true
            for mode in ["idle_","walk_"]:
                var clip:StringName=StringName(mode+direction)
                unchanged=unchanged and f.get_frame_count(clip)==original_frames.get_frame_count(clip)
                for index in f.get_frame_count(clip):
                    unchanged=unchanged and retained_pixels(f.get_frame_texture(clip,index).get_image(),original_frames.get_frame_texture(clip,index).get_image(),id in ["woodcutter","innkeeper_wife"])
            check(unchanged,"visible source RGB retained, only reviewed alpha cleanup allowed: "+id+"/"+direction)
            check(f.get_frame_count("idle_"+direction)==1 and f.get_frame_count("turn_"+direction)==1 and not f.get_animation_loop("turn_"+direction),"static fallback is explicitly honest: "+id+"/"+direction)
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
    print("RESULT: ",passed," expressive-resident checks passed, ",failed," failed")
    quit(0 if failed==0 else 1)
