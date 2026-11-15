extends "res://tests/verify_interiors.gd"
var actor:HutorResident
var sprite:AnimatedSprite2D
var world:Node2D
var life:Node
var phases:Dictionary={}
var invariants:=""
func observe() -> void:
    if not phases.has(sprite.animation):phases[sprite.animation]={}
    phases[sprite.animation][sprite.frame]=true
    if sprite.flip_h or sprite.position!=Vector2.ZERO or sprite.scale!=Vector2.ONE or sprite.z_index!=0:invariants="pivot/handedness/scale"
    if not free_at(world,actor.position,actor.definition.foot_radius):invariants="solid overlap"
    if actor.state==actor.State.MOVING and actor.velocity.length()>0 and not String(sprite.animation).begins_with("walk_"):invariants="chore while walking"
func converse(label:String) -> void:
    var chosen:=false
    for offset in [Vector2(-24,0),Vector2(0,24),Vector2(24,0),Vector2(0,-24)]:
        world.player.position=actor.position+offset;await frames(5)
        if free_at(world,world.player.position) and world.player.sensor.target==actor.get_node("Interaction"):chosen=true;break
    check(chosen,"original E accessible "+label)
    if not chosen:return
    var index:=actor.step_index
    await tap_e();var pos:=actor.position
    await frames(90)
    var dm:Node=root.get_node("DialogueManager")
    check(dm.is_active() and actor.state==actor.State.TALKING,"original dialogue "+label)
    check(actor.position==pos and actor.velocity==Vector2.ZERO,"no position change during finishing action "+label)
    check(String(sprite.animation).begins_with("talk_") and not sprite.flip_h,"put away tool/rise then face Hans "+label)
    if dm.is_active():dm.close_dialogue()
    await frames(10)
    check(actor.step_index==index and actor.state!=actor.State.TALKING,"resume original activity "+label)
    world.player.position=Vector2(800,1100) if life.states[&"herbalist"].scene==&"village" else Vector2(600,420)
func until_clip(clip:StringName,count:int=3500) -> bool:
    for i in count:
        await physics_frame;observe()
        if sprite.animation==clip and sprite.frame==4:return true
    return false
func run() -> void:
    travel=root.get_node("InteriorTravel");change_scene_to_file(travel.VILLAGE);await frames(12)
    life=root.get_node("VillageLife");life.clock.running=false;life.clock.seek(420)
    world=travel.active_world;world.player.position=Vector2(800,1100)
    var r:HutorDailyResidentState=life.states[&"herbalist"];actor=r.actor;sprite=actor.get_node("AnimatedSprite2D")
    var ids:Dictionary={}
    for id in life.states:ids[id]=life.states[id].actor.get_instance_id()
    check(await until_clip(&"gather_herbs"),"actual first outdoor gathering")
    var patch:Node2D=actor.activity_controller.visual54._patch
    check(is_instance_valid(patch) and actor.position.distance_to(patch.position)<24,"gather beside real living plants")
    check(patch.get_node("Art").texture!=null and patch.find_children("*","StaticBody2D").is_empty(),"original plant art without invisible obstacle")
    for i in 600:
        await physics_frame;observe()
        if phases.get(&"gather_herbs",{}).has(7):break
    check(phases.get(&"gather_herbs",{}).has(7),"complete crouch/pick/put away/rise")
    check(await until_clip(&"gather_herbs"),"next crouch cycle before interruption")
    await converse("gather")
    life.clock.seek(840)
    check(await until_clip(&"gather_herbs"),"second existing field reached on foot")
    check(actor.position.distance_to(Vector2(2150,1720))<15,"second original outdoor point")
    check(world.get_node("Actors/ForageHerbs5410").get_child_count()==2,"only two persistent living patches")
    life.clock.seek(660);travel.request_transition(&"herbalist");await wait_transition();world=travel.active_world;world.player.position=Vector2(600,420)
    var table:Node2D=world.get_node("Actors/Props/Table")
    var seen:Dictionary={};var checked:Dictionary={};var talked:=false
    for i in 6000:
        await physics_frame;observe()
        if sprite.animation in [&"sort_herbs",&"grind_herbs",&"read_herbal"]:
            seen[sprite.animation]=true
            if sprite.frame==4 and not checked.has(sprite.animation):
                checked[sprite.animation]=true
                check(table.get_node("Art").visible and world.get_node("Actors/Props/DryHerbs/Art").visible,"real furniture stays visible "+String(sprite.animation))
                check(actor.position.distance_to(table.position+Vector2(-29,-9))<2.2,"physical swept working approach "+String(sprite.animation))
                check(actor.activity_controller.visual54._hands.visible,"upper-body table overlap without raised feet")
                if sprite.animation==&"grind_herbs":check(table.get_node("mortar5410").visible and not table.get_node("pestle5410").visible,"real mortar and one held pestle")
                if sprite.animation==&"read_herbal":check(not table.get_node("book_closed5410").visible,"held book not duplicated on table")
                if not talked:talked=true;await converse("table")
        if seen.size()==3 and phases.get(&"sort_herbs",{}).has(7) and phases.get(&"read_herbal",{}).has(7) and phases.get(&"grind_herbs",{}).has(7):break
    check(seen.size()==3,"all three table chores used in unchanged sort interval")
    for clip in [&"sort_herbs",&"grind_herbs",&"read_herbal"]:check(phases.get(clip,{}).size()==8,"all eight drawn phases "+String(clip))
    life.clock.seek(960)
    check(await until_clip(&"brew_infusion"),"brew at actual existing cauldron")
    var pot:Node2D=world.get_node("Actors/Props/Cauldron")
    check(actor.position.distance_to(pot.position+Vector2(-26,-4))<2.2 and pot.get_node("Art").visible,"cauldron contact, original pot visible")
    for i in 600:
        await physics_frame;observe()
        if phases.get(&"brew_infusion",{}).has(7):break
    check(phases.get(&"brew_infusion",{}).has(7),"complete brewing cycle and spoon lowering")
    check(await until_clip(&"brew_infusion"),"next brew before interruption")
    await converse("brew")
    check(invariants.is_empty(),"physical motion invariants: "+invariants)
    for d in ["left","right","up","down"]:
        actor.set_physics_process(false);actor.animator.apply("walk",StringName(d),&"",false)
        check(sprite.animation==StringName("walk_"+d) and not sprite.flip_h,"independent direction "+d)
    actor.set_physics_process(true)
    check(actor.definition.speed==29,"original slow walking speed")
    check(life.states[&"herbalist_brother"].original.id==&"herbalist_brother","original brother retained")
    travel.request_transition(&"herbalist",true);await wait_transition()
    travel.request_transition(&"herbalist");await wait_transition()
    for id in life.states:check(life.states[id].actor.get_instance_id()==ids[id],"same original body across scenes "+String(id))
    print("PHASES ",phases)
    print("RESULT: ",passed," herbalist checks passed, ",failed," failed");quit(0 if failed==0 else 1)
