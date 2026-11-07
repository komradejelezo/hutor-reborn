extends "res://tests/verify_interiors.gd"
var life: Node
var identities: Dictionary = {}
func same_people() -> bool:
    if life.states.size()!=9:return false
    var active:Dictionary={}
    for node in get_nodes_in_group("residents"):
        if active.has(node.definition.id):return false
        active[node.definition.id]=node.get_instance_id()
    var all_bodies:Dictionary={}
    var worlds:Array=[travel.exterior,life._parking]
    worlds.append_array(travel.rooms.values())
    for world in worlds:
        for node in world.find_children("*","CharacterBody2D",true,false):
            if not node is HutorResident:continue
            if all_bodies.has(node.definition.id):return false
            all_bodies[node.definition.id]=node.get_instance_id()
    return all_bodies==identities
func visit(id: StringName, minute: float) -> Node2D:
    life.clock.seek(minute)
    check(travel.request_transition(id),"entry accepted: "+String(id))
    await wait_transition()
    check(life.clock.absolute_minutes==minute,"time survives transition: "+String(id))
    check(same_people(),"same nine identities after entry: "+String(id))
    return travel.active_world
func leave(id: StringName) -> void:
    check(travel.request_transition(id,true),"exit accepted: "+String(id))
    await wait_transition()
    check(same_people(),"same nine identities after exit: "+String(id))
func speak(npc: HutorResident) -> void:
    var hero:CharacterBody2D=travel.active_world.player
    var marker:HutorInteractable=npc.get_node("Interaction")
    var possible:=false
    for offset in [Vector2(0,22),Vector2(22,0),Vector2(-22,0),Vector2(0,-22),Vector2(0,34)]:
        hero.position=marker.global_position+offset;await frames()
        if free_at(travel.active_world,hero.position) and hero.sensor.target==marker:possible=true;break
    check(possible,"working resident has reachable E prompt: "+String(npc.definition.id))
    if possible:await tap_e();await create_timer(.28).timeout
func run() -> void:
    travel=root.get_node("InteriorTravel")
    var village:Node2D=load(travel.VILLAGE).instantiate()
    root.add_child(village);current_scene=village;await frames(10)
    life=root.get_node("VillageLife");life.clock.running=false
    for id in life.states:identities[id]=life.states[id].actor.get_instance_id()
    var hero:CharacterBody2D=village.player
    var hero_id:=hero.get_instance_id()
    var camera_before:Dictionary=travel._camera_snapshot(hero)
    # Pause and midnight phase checks independent of NPC debug-seek behavior.
    var clock:HutorGameClock=load("res://scripts/life/game_clock.gd").new();root.add_child(clock)
    clock.running=true;clock._process(1.25)
    check(is_equal_approx(clock.absolute_minutes,421),"30-minute-day rate is 0.8 game minutes per second")
    paused=true;clock._process(60);check(is_equal_approx(clock.absolute_minutes,421),"pause freezes game clock");paused=false
    for pair in [[359,"night"],[360,"morning"],[600,"day"],[1080,"evening"],[1320,"night"],[1440,"night"]]:
        clock.seek(pair[0]);check(clock.phase_name()==StringName(pair[1]),"phase boundary at "+str(pair[0]))
    clock.seek(1501);check(clock.display_time()=="01:01","hours wrap at midnight");clock.queue_free()
    for id in [&"woodcutter",&"inn",&"elder",&"herbalist",&"old_man",&"storehouse"]:
        var minute:=425.0 if id==&"woodcutter" else 730.0 if id in [&"inn",&"herbalist"] else 1215.0
        var room:=await visit(id,minute)
        check(room.player.get_instance_id()==hero_id,"same Hans object across all six rooms")
        check(hero.get_node("Camera2D").zoom==Vector2(1.3,1.3) and free_at(room,hero.position),"existing interior camera and clear spawn")
        var population:Node2D=room.get_node("Actors/Residents")
        if id==&"storehouse":check(population.residents.is_empty(),"storehouse gains no resident")
        else:
            check(not population.residents.is_empty(),"scheduled occupants present in "+String(id))
            # Advance only resident clocks/motion so action animation is actually reached.
            hero.position=Vector2(435,405) if id==&"woodcutter" else room.get_node("Entry").position
            life.clock.set_speed(30)
            await create_timer(2).timeout
            life.clock.set_speed(1)
            var npc:HutorResident=population.residents.values()[0]
            var r:HutorDailyResidentState=life.states[npc.definition.id]
            check(npc.state==HutorResident.State.WAITING or npc.steps_completed>0,"resident reaches contextual action using real navigation")
            await speak(npc)
            var manager:Node=root.get_node("DialogueManager")
            check(manager.is_active() and npc.state==HutorResident.State.TALKING and hero.controls_locked,"existing dialogue pauses work and Hans")
            if manager.is_active():
                var stopped:=npc.position
                check(not travel.request_transition(id,true),"dialogue prevents competing hero transition")
                await frames(8);check(npc.position==stopped,"dialogue stops NPC movement")
                manager.close_dialogue();await create_timer(.2).timeout
                check(npc.state!=HutorResident.State.TALKING and not hero.controls_locked,"conversation resumes occupation")
            for other:HutorResident in population.residents.values():
                if other==npc:continue
                await speak(other)
                check(manager.is_active() and other.state==HutorResident.State.TALKING,"household dialogue pauses context animation: "+String(other.definition.id))
                if manager.is_active():
                    manager.close_dialogue();await create_timer(.2).timeout
                    check(other.state!=HutorResident.State.TALKING,"household occupation resumes: "+String(other.definition.id))
            var saved_id:=npc.get_instance_id()
            var saved_step:=npc.step_index
            var saved_pos:=npc.position
            await leave(id)
            check(travel.request_transition(id),"same-room revisit accepted");await wait_transition()
            check(npc.get_instance_id()==saved_id and npc.step_index==saved_step and npc.position.distance_to(saved_pos)<25,"short visit preserves current activity/progress")
        await leave(id)
    await visit(&"herbalist",1215)
    var brother:HutorResident=life.states[&"herbalist_brother"].actor
    await speak(brother)
    var manager_before:Node=root.get_node("DialogueManager")
    check(manager_before.is_active() and brother.state==HutorResident.State.TALKING,"returned worker retains original conversation")
    if manager_before.is_active():manager_before.close_dialogue();await create_timer(.2).timeout
    await leave(&"herbalist")
    check(travel._camera_snapshot(hero)==camera_before,"exterior camera is restored exactly")
    check(hero.speed==94 and hero.walk_sprite_scale==1.0/24.0,"time acceleration leaves Hans unchanged")
    # A conversation may span a schedule boundary; recompute intent only when it ends.
    life.clock.seek(1079)
    var elder:HutorResident=life.states[&"elder"].actor
    await frames(15);elder.set_physics_process(false)
    await speak(elder)
    var manager:Node=root.get_node("DialogueManager")
    check(manager.is_active(),"outdoor dialogue starts before evening")
    if manager.is_active():
        var held:=elder.position
        life.clock.seek(1081);await frames(5)
        check(elder.state==HutorResident.State.TALKING and elder.position==held,"schedule change never interrupts conversation")
        manager.close_dialogue();await create_timer(.2).timeout
        check(life.states[&"elder"].mode==&"travel" and life.states[&"elder"].desired_scene==&"elder","evening route replanned after dialogue")
    elder.set_physics_process(true)
    # Switch scenes halfway through a real boundary crossing, then let the
    # off-scene clock complete departure/return. Collision exceptions must not leak.
    hero.position=Vector2(1100,2300)
    life.clock.seek(479);life.clock.set_speed(1)
    var worker:HutorDailyResidentState=life.states[&"woodcutter"]
    worker.actor.position=life._gate(worker)
    life.clock.absolute_minutes=480;life._tick(480)
    var limit:=Time.get_ticks_msec()+3000
    while worker.mode!=&"boundary_out" and Time.get_ticks_msec()<limit:await physics_frame
    check(worker.mode==&"boundary_out" and not worker.actor.get_collision_exceptions().is_empty(),"worker starts actual boundary segment")
    check(travel.request_transition(&"inn"),"Hans may enter while worker crosses boundary");await wait_transition()
    check(not worker.actor.is_inside_tree() and worker.actor.get_collision_exceptions().is_empty(),"parking clears temporary map-boundary exception")
    life.clock.absolute_minutes=490;life._tick(490)
    check(worker.mode==&"offsite" and worker.scene==&"logging","off-scene departure completes virtually")
    life.clock.absolute_minutes=1081;life._tick(1081)
    life.clock.absolute_minutes=1090;life._tick(1090)
    await leave(&"inn")
    check(worker.actor.is_inside_tree() and worker.actor.get_collision_exceptions().is_empty(),"returning worker restores all normal collisions")
    check(same_people(),"all transitions and dialogue retain exactly nine identities")
    print("RESULT: ",passed," daily-lifecycle checks passed, ",failed," failed")
    quit(0 if failed==0 else 1)
