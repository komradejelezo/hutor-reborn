extends "res://tests/verify_interiors.gd"
var actor:HutorResident
var sprite:AnimatedSprite2D
var world:Node2D
func converse(label:String) -> void:
    var chosen:=false
    for offset in [Vector2(-24,0),Vector2(0,24),Vector2(24,0),Vector2(0,-24)]:
        world.player.position=actor.position+offset;await frames(5)
        if free_at(world,world.player.position) and world.player.sensor.target==actor.get_node("Interaction"):chosen=true;break
    check(chosen,"original E reachable "+label)
    if not chosen:return
    var index:=actor.step_index
    await tap_e();var pos:=actor.position
    check(not actor.get_node("PipeSmoke").emitting,"smoking stops immediately on talk "+label)
    await frames(190)
    var dm:Node=root.get_node("DialogueManager")
    check(dm.is_active() and actor.state==actor.State.TALKING,"existing dialogue opens "+label)
    check(actor.position==pos and actor.velocity==Vector2.ZERO,"feet stay fixed during rise/conversation "+label)
    check(String(sprite.animation).begins_with("talk_"),"pipe lowered and rise finishes before directed talk "+label)
    check(not sprite.flip_h,"left talk uses independent left art "+label)
    dm.close_dialogue();await frames(10)
    check(actor.step_index==index and actor.state!=actor.State.TALKING,"same scheduled action resumes "+label)
    world.player.position=Vector2(800,1100)
func run() -> void:
    travel=root.get_node("InteriorTravel");change_scene_to_file(travel.VILLAGE);await frames(12)
    var life:Node=root.get_node("VillageLife");life.clock.running=false;life.clock.seek(360)
    world=travel.active_world;world.player.position=Vector2(800,1100)
    var r:HutorDailyResidentState=life.states[&"old_man"];actor=r.actor;sprite=actor.get_node("AnimatedSprite2D")
    var body:=actor.get_instance_id();var source_schedule:=FileAccess.get_file_as_string("res://data/life/residents/old_man.json")
    var all_ids:Dictionary={}
    for id in life.states:all_ids[id]=life.states[id].actor.get_instance_id()
    var clips:Dictionary={};var phases:Dictionary={};var spoke:Dictionary={};var invariant:="";var previous:=actor.position
    for i in 7800:
        await physics_frame
        clips[sprite.animation]=true
        if not phases.has(sprite.animation):phases[sprite.animation]={}
        phases[sprite.animation][sprite.frame]=true
        if actor.position.distance_to(previous)>18.0/60+.2:invariant="position jump"
        if not free_at(world,actor.position,actor.definition.foot_radius):invariant="world collision overlap"
        if actor.state==actor.State.MOVING and actor.velocity.length()>0:
            if actor.get_node("PipeSmoke").emitting or not String(sprite.animation).begins_with("walk_"):invariant="work/smoking while walking"
        if sprite.flip_h or sprite.position!=Vector2.ZERO or sprite.scale!=Vector2.ONE or sprite.z_index!=0:invariant="handedness/pivot/scale"
        if actor.get_node("PipeSmoke").emitting:
            if sprite.animation not in [&"smoke_pipe",&"sit_smoke"] or sprite.frame not in [4,5]:invariant="smoke outside exhale window"
        if sprite.animation in [&"smoke_pipe",&"sit_smoke"] and sprite.frame==4 and not spoke.has(sprite.animation):
            spoke[sprite.animation]=true
            if sprite.animation==&"sit_smoke":
                var seat:Node2D=actor.activity_controller.visual54._seat
                check(is_instance_valid(seat) and actor.position.distance_to(seat.position)<12,"sitting on the existing activity bench")
            await converse(String(sprite.animation));previous=actor.position
        previous=actor.position
        if clips.has(&"think") and clips.has(&"stand_up") and spoke.size()==2 and clips.has(&"sit_idle"):break
    for clip in [&"smoke_pipe",&"sit_down",&"sit_idle",&"sit_smoke",&"stand_up",&"think"]:check(clips.has(clip),"real authored action "+String(clip))
    check(invariant.is_empty(),"real motion/smoke/pivot invariants: "+invariant)
    check(actor.activity_controller.visual54.exhalations>=2,"actual exhalations occur")
    for d in ["left","right","down","up"]:
        actor.set_physics_process(false);actor.animator.apply("walk",StringName(d),&"",false)
        check(not sprite.flip_h and sprite.animation==StringName("walk_"+d),"independent direction "+d)
    actor.set_physics_process(true)
    check(sprite.sprite_frames.get_frame_texture("walk_left",0)!=sprite.sprite_frames.get_frame_texture("walk_right",0),"left gait is not the right gait mirrored")
    check(actor.definition.speed==18 and actor.distance_walked>140,"original slow speed, real route on foot")
    life.clock.seek(1100)
    travel.request_transition(&"old_man");await wait_transition();world=travel.active_world;world.player.position=Vector2(600,390)
    for i in 2000:
        await physics_frame
        if sprite.animation==&"smoke_pipe" and sprite.frame==4:break
    check(sprite.animation==&"smoke_pipe","existing home hearth activity uses standing pipe cycle")
    world.atmosphere.set_effects_enabled(false);await frames(3)
    check(not actor.get_node("PipeSmoke").emitting and not actor.get_node("PipeSmoke").visible,"existing effects toggle disables pipe smoke")
    world.atmosphere.set_effects_enabled(true)
    travel.request_transition(&"old_man",true);await wait_transition()
    travel.request_transition(&"old_man");await wait_transition()
    check(actor.get_instance_id()==body,"same old man across original scene transitions")
    for id in life.states:check(all_ids[id]==life.states[id].actor.get_instance_id(),"all original actors retained "+String(id))
    check(source_schedule==FileAccess.get_file_as_string("res://data/life/residents/old_man.json"),"schedule data unchanged")
    print("OBSERVED ",clips," PHASES ",phases)
    await frames(8)
    print("RESULT: ",passed," old-man checks passed, ",failed," failed");quit(0 if failed==0 else 1)
