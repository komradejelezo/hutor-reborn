extends "res://tests/verify_interiors.gd"
func converse(actor:HutorResident,world:Node2D,label:String) -> void:
    var marker:HutorInteractable=actor.get_node("Interaction")
    var hero:CharacterBody2D=world.player
    var selected:=false
    for offset in [Vector2(0,22),Vector2(22,0),Vector2(-22,0),Vector2(0,30)]:
        hero.position=marker.global_position+offset;await frames(5)
        if hero.sensor.target==marker and free_at(world,hero.position):selected=true;break
    check(selected,"reachable existing E target: "+label)
    if not selected:return
    var position:=actor.position;var index:=actor.step_index
    await tap_e();await create_timer(.3).timeout
    var manager:Node=root.get_node("DialogueManager")
    check(manager.is_active() and actor.state==actor.State.TALKING,"existing dialogue opens: "+label)
    await frames(45)
    var sprite:AnimatedSprite2D=actor.get_node("AnimatedSprite2D")
    check(actor.position==position and actor.velocity==Vector2.ZERO,"body stays locked throughout conversation: "+label)
    check(not String(sprite.animation).begins_with("work_"),"only set-down completes; work stops during conversation: "+label)
    manager.close_dialogue();await frames(15)
    check(actor.state!=actor.State.TALKING and actor.step_index==index,"same occupation resumes after dialogue: "+label)
    hero.position=Vector2(580,440)

func run() -> void:
    travel=root.get_node("InteriorTravel");change_scene_to_file(travel.VILLAGE);await frames(12)
    var life:Node=root.get_node("VillageLife");life.clock.running=false;life.clock.seek(600)
    check(travel.request_transition(&"inn"),"existing inn entry");await wait_transition()
    var world:Node2D=travel.active_world;world.player.position=Vector2(580,440)
    var record:HutorDailyResidentState=life.states[&"innkeeper"]
    var actor:HutorResident=record.actor;var sprite:AnimatedSprite2D=actor.get_node("AnimatedSprite2D")
    var body:=actor.get_instance_id();var ids:Dictionary={}
    for id in life.states:ids[id]=life.states[id].actor.get_instance_id()
    var clips:Dictionary={};var actions:Dictionary={};var conversations:Dictionary={}
    var invariant:="";var previous:=actor.position;var reached_hearth:=false;var pause_seen:=false
    for i in 15000:
        await physics_frame
        if actor.state==actor.State.WAITING:
            actions[actor.current_step().label]=true
            if String(sprite.animation).begins_with("work_"):
                clips[sprite.animation]=true
                if sprite.animation==&"work_cook":
                    reached_hearth=actor.position.distance_to(world.get_node("Actors/Props/Fireplace/CookingCrock546").global_position)<32
                if sprite.frame==3 and not conversations.has(sprite.animation):
                    if sprite.animation==&"work_mug":check(not world.get_node("Actors/Props/Counter/MugWipe546").visible,"held mug is not duplicated on the tabletop")
                    if sprite.animation==&"work_serve":check(not world.get_node("Actors/Props/Counter/MugService546").visible and not world.get_node("Actors/Props/Counter/Pitcher546").visible,"held serving vessels are not duplicated on the tabletop")
                    conversations[sprite.animation]=true
                    await converse(actor,world,String(sprite.animation))
                    previous=actor.position
            else:pause_seen=true
        if actor.position.distance_to(previous)>28.0/60+.2:invariant="discontinuous movement"
        if not free_at(world,actor.position,actor.definition.foot_radius):invariant="static furniture overlap"
        if sprite.position!=Vector2.ZERO or sprite.z_index!=0:invariant="foot pivot moved or entire body raised above furniture"
        previous=actor.position
        if clips.has(&"work_mug") and clips.has(&"work_serve") and clips.has(&"work_cook") and conversations.size()>=3 and actions.has("pause_counter"):break
    for action in ["wipe_mug","arrange_dishes","check_hearth","pause_counter"]:check(actions.has(action),"real route reaches: "+action)
    for clip in [&"work_mug",&"work_serve",&"work_cook"]:check(clips.has(clip),"actual multi-frame action: "+String(clip))
    check(reached_hearth,"spoon work is bound to an existing visible crock at the hearth")
    check(pause_seen,"work includes quiet pauses")
    check(invariant.is_empty(),"physical furniture/foot registration invariant: "+invariant)
    check(record.original.speed==28 and actor.distance_walked>150,"source speed remains 28 and work points are reached on foot")
    life.clock.seek(365)
    for i in 1500:
        await physics_frame
        if sprite.animation==&"work_wipe" and sprite.frame==3:break
    check(sprite.animation==&"work_wipe","morning preparation actually wipes the counter")
    await converse(actor,world,"counter-wipe")
    check(travel.request_transition(&"inn",true),"existing inn exit");await wait_transition()
    check(travel.request_transition(&"inn"),"repeat existing entry");await wait_transition()
    check(record.actor.get_instance_id()==body,"same innkeeper after repeat scene change")
    for i in 300:
        await physics_frame
        if actor.state==actor.State.WAITING and absf(actor.position.y-240)<2:break
    check(absf(actor.position.y-240)<2,"restored counter work physically approaches the correct rear edge")
    for id in life.states:check(ids[id]==life.states[id].actor.get_instance_id(),"unchanged original resident: "+String(id))
    print("CLIPS ",clips," ACTIONS ",actions," CONVERSATIONS ",conversations)
    print("RESULT: ",passed," innkeeper work checks passed, ",failed," failed")
    quit(0 if failed==0 else 1)
