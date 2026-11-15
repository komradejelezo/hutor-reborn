extends "res://tests/verify_interiors.gd"
var life:Node
var world:Node2D
var actor:HutorResident
var sprite:AnimatedSprite2D
var observed:Dictionary={}
func converse(label:String) -> void:
    var marker:HutorInteractable=actor.get_node("Interaction");var chosen:=false
    for offset in [Vector2(-24,0),Vector2(0,24),Vector2(24,0),Vector2(0,-24)]:
        world.player.position=actor.position+offset;await frames(5)
        if free_at(world,world.player.position) and world.player.sensor.target==marker:chosen=true;break
    check(chosen,"reachable original E "+label)
    if not chosen:return
    var step:=actor.step_index
    await tap_e();var position:=actor.position;await frames(60)
    var manager:Node=root.get_node("DialogueManager")
    check(manager.is_active() and actor.state==actor.State.TALKING,"existing conversation "+label)
    check(actor.position==position and actor.velocity==Vector2.ZERO,"dialogue locks real body "+label)
    check(not String(sprite.animation).begins_with("work_"),"authored put-down settles into talk "+label)
    if world.has_node("Actors/Props/Desk"):
        check(world.get_node("Actors/Props/Desk/Paper548").visible and world.get_node("Actors/Props/Desk/Quill548").visible,"no held document/quill duplicates after settling "+label)
    manager.close_dialogue();await frames(12)
    check(actor.step_index==step and actor.state!=actor.State.TALKING,"same occupation resumes "+label)
    world.player.position=Vector2(560,390)
func run() -> void:
    travel=root.get_node("InteriorTravel");change_scene_to_file(travel.VILLAGE);await frames(12)
    life=root.get_node("VillageLife");life.clock.running=false;life.clock.seek(408)
    travel.request_transition(&"elder");await wait_transition();world=travel.active_world;world.player.position=Vector2(560,390)
    var record:HutorDailyResidentState=life.states[&"elder"]
    actor=record.actor;sprite=actor.get_node("AnimatedSprite2D")
    var ids:Dictionary={}
    for id in life.states:ids[id]=life.states[id].actor.get_instance_id()
    var previous:=actor.position;var invariant:="";var conversations:Dictionary={};var pauses:=false
    for i in 6500:
        await physics_frame
        var clip:=String(sprite.animation)
        if clip.begins_with("work_"):
            observed[clip]=true
            if sprite.frame==3 and not conversations.has(clip):
                conversations[clip]=true;await converse(clip);previous=actor.position
        elif actor.state==actor.State.WAITING:pauses=true
        if actor.position.distance_to(previous)>30.0/60+.2:invariant="position jump"
        if not free_at(world,actor.position,actor.definition.foot_radius):invariant="furniture intersection"
        if sprite.position!=Vector2.ZERO or sprite.z_index!=0 or sprite.scale!=Vector2.ONE:invariant="ungrounded scale/pivot"
        previous=actor.position
        if observed.has("work_read") and observed.has("work_write") and observed.has("work_think") and conversations.size()==3:break
    for clip in ["work_read","work_write","work_think"]:check(observed.has(clip),"real occupation "+clip)
    check(pauses,"jobs include natural pauses")
    check(invariant.is_empty(),"physical work invariant "+invariant)
    check(actor.definition.speed==30 and actor.activity_controller.visual54.rejected_work==0,"original speed and reachable desk")
    # Actual NPC doorway leg, selected at the existing 10:00 boundary.
    life.clock.seek(595);await frames(8);life.clock.running=true
    var departed:=false;var departure_distance:=actor.distance_walked
    for i in 4000:
        await physics_frame
        if record.scene==&"village":departed=true;break
    life.clock.running=false
    check(departed and actor.distance_walked>departure_distance+40,"elder physically reaches home exit at day boundary")
    travel.request_transition(&"elder",true);await wait_transition();world=travel.active_world
    world.player.position=Vector2(1550,1600)
    check(actor.is_inside_tree() and record.scene==&"village","same elder materializes on existing village route")
    var outside_clips:Dictionary={};var square:=false
    for i in 5000:
        await physics_frame
        if actor.state==actor.State.WAITING:square=true
        if String(sprite.animation).begins_with("work_") or String(sprite.animation).begins_with("point_"):outside_clips[sprite.animation]=true
        if outside_clips.has(&"work_inspect"):break
    check(square and outside_clips.has(&"work_inspect"),"actual village inspection after physical exit")
    # Controlled nearby resident fixture exercises the existing proximity trigger.
    var partner:HutorResident=life.states[&"woodcutter_son"].actor
    var saved:=partner.position;var processing:=partner.is_physics_processing()
    partner.set_physics_process(false);partner.position=actor.position+Vector2(65,15)
    actor.activity_controller.visual54._point_cooldown=0
    var gestured:=false
    for i in 500:
        await physics_frame
        if String(sprite.animation).begins_with("point_") and sprite.frame==2:gestured=true;break
    check(gestured,"short directed gesture toward an actual nearby resident (arranged fixture)")
    if gestured:await converse("point to resident")
    partner.position=saved;partner.set_physics_process(processing)
    life.clock.seek(1075);life.clock.running=true
    var returned:=false
    for i in 6500:
        await physics_frame
        if record.scene==&"elder":returned=true;break
    life.clock.running=false
    check(returned,"evening routine physically reaches existing home door")
    check(travel.request_transition(&"elder"),"existing hero door transition after elder returns");await wait_transition();world=travel.active_world
    # Both actors use the same doorway. The existing system queues the NPC
    # while Hans occupies Entry; move Hans away and let the real clock retry.
    world.player.position=Vector2(560,390);life.clock.running=true
    await frames(100);life.clock.running=false
    check(actor.is_inside_tree() and record.scene==&"elder" and not record.pending_entry,"elder enters once Hans clears the shared doorway")
    for id in life.states:check(ids[id]==life.states[id].actor.get_instance_id(),"original actor preserved "+String(id))
    await frames(8)
    print("RESULT: ",passed," elder work and residency checks passed, ",failed," failed");quit(0 if failed==0 else 1)
