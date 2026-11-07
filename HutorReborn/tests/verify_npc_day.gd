extends "res://tests/verify_interiors.gd"
## Full accelerated day with Hans left on the village's normal central route.
func run() -> void:
    travel=root.get_node("InteriorTravel")
    change_scene_to_file(travel.VILLAGE);await frames(12)
    var world:Node2D=current_scene
    var life:Node=root.get_node("VillageLife")
    var identities:Dictionary={};var activities:Dictionary={};var before:Dictionary={}
    var phases:Dictionary={};var crossings:Dictionary={}
    var invalid:="";var closest_gap:=INF
    for id in life.states:
        identities[id]=life.states[id].actor.get_instance_id();activities[id]={}
    # Do not move Hans out of the routes to make the day pass.
    var hero_start:Vector2=world.player.position
    var end:float=life.clock.absolute_minutes+1440
    life.clock.set_speed(30)
    var deadline:=Time.get_ticks_msec()+90000
    while life.clock.absolute_minutes<end and Time.get_ticks_msec()<deadline:
        await physics_frame
        phases[life.clock.phase_name()]=true
        var active:Array=[]
        for id in life.states:
            var r:HutorDailyResidentState=life.states[id];var a:HutorResident=r.actor
            if a.get_instance_id()!=identities[id]:invalid="identity changed: "+String(id)
            activities[id][r.activity]=true
            if not a.is_inside_tree():before.erase(id);continue
            active.append(a)
            if r.scene!=&"village":invalid="active body in wrong scene"
            if before.has(id) and a.position.distance_to(before[id])>r.original.speed*life.clock.speed*a.get_physics_process_delta_time()+2:
                invalid="visible teleport: "+String(id)
            before[id]=a.position
            if not free_at(world,a.position,r.original.foot_radius) and r.mode not in [&"boundary_in",&"boundary_out"]:
                invalid="world collision: "+String(id)
            if r.mode in [&"boundary_in",&"boundary_out"]:crossings[id]=true
            if id==&"woodcutter_son" and not Rect2(1180,740,730,970).grow(20).has_point(a.position):invalid="child outside safe area"
        for i in active.size():
            for j in range(i+1,active.size()):
                var gap:float=active[i].position.distance_to(active[j].position)-active[i].definition.foot_radius-active[j].definition.foot_radius
                closest_gap=minf(closest_gap,gap)
                if gap<-.5:invalid="feet overlap: "+String(active[i].definition.id)+"/"+String(active[j].definition.id)
    life.clock.running=false
    check(life.clock.absolute_minutes>=end,"full day completes at x30 without seeking")
    check(invalid.is_empty(),"continuous physics, identity and child-safe-area checks: "+invalid)
    check(world.player.position==hero_start,"Hans remains stationary on the central route")
    check(phases.size()==4,"morning/day/evening/night observed")
    check(life.states.size()==9,"exactly nine logical residents")
    for id in life.states:
        var r:HutorDailyResidentState=life.states[id]
        check(activities[id].size()>=3,String(id)+" executes distinct daily phases")
        check(r.actor.get_instance_id()==identities[id],String(id)+" body is never recreated")
        if id in [&"woodcutter",&"herbalist_brother"]:
            check(crossings.has(id),String(id)+" visibly crosses map boundary")
            check(r.event_counts.get("left_for_work",0)==1 and r.event_counts.get("return_from_work",0)==1,String(id)+" leaves and returns once")
            check(r.scene==r.schedule.home,String(id)+" returns to its own home")
        if id in [&"innkeeper",&"innkeeper_wife"]:check(r.scene==&"inn","inn workers remain attached to inn schedule")
        if id==&"woodcutter_son":check(activities[id].has(&"play_stick") and activities[id].has(&"kneel_toy") and activities[id].has(&"run_yard"),"child plays, kneels and runs")
    var nav:HutorNpcNavigation=world.get_node("Actors/Residents/Navigation")
    check(nav.max_solves_in_tick<=2 and nav._cache.size()<=128,"bounded navigation work and cache")
    check(life.events.size()<=1024,"bounded schedule diagnostics")
    print("METRICS: minimum resident foot clearance=",closest_gap," dynamic solves=",nav.dynamic_solves," probes=",nav.dynamic_probes)
    print("RESULT: ",passed," live-day checks passed, ",failed," failed")
    quit(0 if failed==0 else 1)
