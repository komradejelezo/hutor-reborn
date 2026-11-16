extends "res://tests/verify_interiors.gd"
var actor:HutorResident
var sprite:AnimatedSprite2D
var life:Node
var world:Node2D
var phases:Dictionary={}
var invariant:=""
func observe() -> void:
    if not phases.has(sprite.animation):phases[sprite.animation]={}
    phases[sprite.animation][sprite.frame]=true
    if sprite.flip_h or sprite.scale!=Vector2.ONE or sprite.position!=Vector2.ZERO or sprite.z_index!=0:invariant="scale/pivot/handedness"
    if not free_at(world,actor.position,actor.definition.foot_radius):invariant="solid overlap"
    if actor.state==actor.State.MOVING and actor.velocity.length()>0 and not String(sprite.animation).begins_with("walk_"):invariant="tool/gesture while walking"
func converse(label:String) -> void:
    var chosen:=false
    for offset in [Vector2(-24,0),Vector2(0,24),Vector2(24,0),Vector2(0,-24)]:
        world.player.position=actor.position+offset;await frames(5)
        if free_at(world,world.player.position) and world.player.sensor.target==actor.get_node("Interaction"):chosen=true;break
    check(chosen,"original E accessible "+label)
    if not chosen:return
    var index:=actor.step_index
    await tap_e();var pos:=actor.position
    await frames(250)
    var dm:Node=root.get_node("DialogueManager")
    check(dm.is_active() and actor.state==actor.State.TALKING,"original brother dialogue "+label)
    check(actor.position==pos and actor.velocity==Vector2.ZERO,"fixed feet while stroke finishes "+label)
    check(String(sprite.animation).begins_with("talk_") and not sprite.flip_h,"finish putting axe back before directed talk "+label)
    if dm.is_active():dm.close_dialogue()
    await frames(10)
    check(actor.step_index==index and actor.state!=actor.State.TALKING,"same activity resumes "+label)
    world.player.position=Vector2(600,420)
func run() -> void:
    travel=root.get_node("InteriorTravel");change_scene_to_file(travel.VILLAGE);await frames(12)
    life=root.get_node("VillageLife");life.clock.running=false;life.clock.seek(360)
    travel.request_transition(&"herbalist");await wait_transition();world=travel.active_world;world.player.position=Vector2(600,420)
    var r:HutorDailyResidentState=life.states[&"herbalist_brother"];actor=r.actor;sprite=actor.get_node("AnimatedSprite2D")
    var ids:Dictionary={}
    for id in life.states:ids[id]=life.states[id].actor.get_instance_id()
    var block:Node2D=world.get_node("Actors/Props/BrotherWorkBlock5411")
    check(not free_at(world,block.position,2),"visible workblock has actual collision")
    check(free_at(world,block.position-Vector2(18,0),5),"original working point remains free")
    var seen:Dictionary={};var spoke:=false;var tool_valid:=true
    for i in 6500:
        await physics_frame;observe()
        if sprite.animation in [&"chop_wood",&"split_logs"]:
            if actor.position.distance_to(block.position-Vector2(18,0))>=3:tool_valid=false;print("TOOL_DISTANCE ",actor.position,block.position,actor.state)
            if sprite.frame>=1 and sprite.is_playing() and block.get_node("Axe").visible:tool_valid=false;print("TOOL_DUPLICATE ",sprite.animation,sprite.frame,actor.state)
            if sprite.frame==5 and not block.get_node("Log").texture.resource_path.ends_with("split_billet.png"):tool_valid=false
            if sprite.frame==0 and not block.get_node("Log").texture.resource_path.ends_with("billet.png"):tool_valid=false
            seen[sprite.animation]=true
            if sprite.animation==&"chop_wood" and sprite.frame==3 and not spoke:spoke=true;await converse("raised axe")
        if phases.get(&"chop_wood",{}).size()==8 and phases.get(&"split_logs",{}).size()==8 and phases.get(&"think",{}).size()==4:break
    for clip in [&"chop_wood",&"split_logs"]:check(phases.get(clip,{}).size()==8,"all drawn work phases "+String(clip))
    check(phases.get(&"think",{}).size()==4,"existing prepare_work uses complete think action")
    check(tool_valid,"work only at block, no simultaneous axe on block and in hand")
    check(invariant.is_empty(),"motion invariant: "+invariant)
    life.clock.seek(1080)
    for i in 1800:
        await physics_frame;observe()
        if phases.get(&"tired_idle",{}).size()==4:break
    check(phases.get(&"tired_idle",{}).size()==4,"standing tired rest at existing home_rest point")
    check(block.get_node("Axe").visible,"tool remains on block after work")
    for d in [&"down",&"up",&"left",&"right"]:
        actor.set_physics_process(false);actor.animator.apply("walk",d,&"",false)
        check(sprite.animation==StringName("walk_"+String(d)) and not sprite.flip_h,"independent gait "+String(d))
    actor.set_physics_process(true)
    check(actor.definition.speed==37,"original speed37 preserved")
    check(not sprite.sprite_frames.has_animation("carry_wood") and not sprite.sprite_frames.has_animation("run_down"),"no fake unsupported carry/run")
    travel.request_transition(&"herbalist",true);await wait_transition()
    travel.request_transition(&"herbalist");await wait_transition()
    for id in life.states:check(ids[id]==life.states[id].actor.get_instance_id(),"same resident across house transitions "+String(id))
    print("PHASES ",phases)
    print("RESULT: ",passed," brother checks passed, ",failed," failed");quit(0 if failed==0 else 1)
