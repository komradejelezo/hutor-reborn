extends "res://tests/verify_interiors.gd"
var life:Node
var world:Node2D
var actor:HutorResident
var sprite:AnimatedSprite2D
var clips:Dictionary={}
var actions:Dictionary={}
var spoke:Dictionary={}
func converse(label:String) -> void:
    var marker:HutorInteractable=actor.get_node("Interaction");var chosen:=false
    for offset in [Vector2(0,24),Vector2(-24,0),Vector2(24,0),Vector2(0,-24)]:
        world.player.position=actor.position+offset;await frames(5)
        if free_at(world,world.player.position) and world.player.sensor.target==marker:chosen=true;break
    check(chosen,"reachable original E: "+label)
    if not chosen:return
    var body:=actor.position;var index:=actor.step_index
    await tap_e()
    # A moving actor can advance one physics tick before E is accepted.
    check(actor.position.distance_to(body)<=34.0/30+.01,"at most input acceptance ticks: "+label)
    body=actor.position
    await frames(60)
    var manager:Node=root.get_node("DialogueManager")
    check(manager.is_active() and actor.state==actor.State.TALKING,"original dialogue: "+label)
    check(actor.position==body and actor.velocity==Vector2.ZERO,"talk locks feet: "+label)
    check(not String(sprite.animation).begins_with("work_"),"work settled before conversation: "+label)
    manager.close_dialogue();await frames(12)
    check(actor.state!=actor.State.TALKING and actor.step_index==index,"same occupation resumes: "+label)
    world.player.position=Vector2(580,460)
func run() -> void:
    travel=root.get_node("InteriorTravel");change_scene_to_file(travel.VILLAGE);await frames(12)
    life=root.get_node("VillageLife");life.clock.running=false;life.clock.seek(600)
    travel.request_transition(&"inn");await wait_transition();world=travel.active_world;world.player.position=Vector2(580,460)
    actor=life.states[&"innkeeper_wife"].actor;sprite=actor.get_node("AnimatedSprite2D")
    var husband:HutorResident=life.states[&"innkeeper"].actor
    var ids:Dictionary={}
    for id in life.states:ids[id]=life.states[id].actor.get_instance_id()
    var previous:=actor.position;var invariant:="";var carried:=false;var delivery_walk:=0.0;var husband_clips:Dictionary={}
    for i in 18000:
        await physics_frame
        var step:=actor.current_step()
        if actor.state==actor.State.WAITING:actions[step.label]=true
        if String(sprite.animation).begins_with("work_"):
            clips[sprite.animation]=true
            if sprite.frame==3 and not spoke.has(sprite.animation) and sprite.animation!=&"work_rest":
                spoke[sprite.animation]=true;await converse(String(sprite.animation));previous=actor.position
        if step.label=="serve_food" and actor.state==actor.State.MOVING and actor.velocity.length()>0:
            carried=carried or String(sprite.animation).begins_with("carry_")
            delivery_walk+=actor.position.distance_to(previous)
            if delivery_walk>40 and not spoke.has("carry_route"):
                spoke["carry_route"]=true;await converse("carrying tray")
                check(actor.activity_controller.visual54.carrying,"tray stays supported during and after talk on route")
                previous=actor.position
        if actor.position.distance_to(previous)>34.0/60+.2:invariant="position jump"
        if not free_at(world,actor.position,actor.definition.foot_radius):invariant="static collision overlap"
        if actor.position.distance_to(husband.position)<8:invariant="couple overlap"
        if sprite.position!=Vector2.ZERO or sprite.scale!=Vector2.ONE or sprite.z_index!=0:invariant="ungrounded sprite"
        previous=actor.position
        var hs:AnimatedSprite2D=husband.get_node("AnimatedSprite2D")
        if String(hs.animation).begins_with("work_"):husband_clips[hs.animation]=true
        if actions.has("pause_kitchen") and actions.has("sweep_floor") and spoke.size()>=8 and clips.has(&"work_rest"):break
    for clip in ["work_cook","work_cut","work_pickup","work_place","work_wipe","work_dishes","work_sweep","work_rest"]:check(clips.has(StringName(clip)),"actual authored clip: "+clip)
    for action in ["kitchen","cut_food","take_tray","serve_food","clean_tables","polish_dishes","sweep_floor","pause_kitchen"]:check(actions.has(action),"physical route: "+action)
    check(invariant.is_empty(),"feet/physics invariant: "+invariant)
    check(carried and delivery_walk>280,"tray carried on real navigation, distance "+str(delivery_walk))
    check(husband_clips.has(&"work_mug") and husband_clips.has(&"work_serve") and husband_clips.has(&"work_cook"),"husband continues original duties alongside wife")
    check(actor.activity_controller.visual54.rejected_work==0,"all wife surfaces are reachable")
    check(actor.definition.speed==34,"wife original walking speed")
    travel.request_transition(&"inn",true);await wait_transition();travel.request_transition(&"inn");await wait_transition()
    for id in life.states:check(ids[id]==life.states[id].actor.get_instance_id(),"same original actor: "+String(id))
    check(actor.is_inside_tree(),"wife re-enters existing inn")
    print("CLIPS ",clips," ACTIONS ",actions," SPOKE ",spoke)
    print("RESULT: ",passed," wife work checks passed, ",failed," failed");quit(0 if failed==0 else 1)
