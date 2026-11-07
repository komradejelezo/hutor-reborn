extends "res://tests/verify_interiors.gd"
## Default live residency, not the old all-outdoors component fixture.
var life: Node
var identities: Dictionary = {}
var seen: Dictionary = {}
var phases: Dictionary = {}
var boundary_seen: Dictionary = {}
var invalid := ""
func run() -> void:
    travel=root.get_node("InteriorTravel")
    var world:Node2D=load(travel.VILLAGE).instantiate()
    root.add_child(world);current_scene=world;await frames(10)
    life=root.get_node("VillageLife")
    check(life.initialized and life.states.size()==9,"one daily owner initialized for nine original residents")
    check(life.clock.real_day_seconds==1800,"default day is 30 real minutes")
    for id in life.states:
        identities[id]=life.states[id].actor.get_instance_id();seen[id]={}
    world.player.position=Vector2(1100,2300)
    var end:float=life.clock.absolute_minutes+1440
    var deadline:=Time.get_ticks_msec()+60000
    life.clock.set_speed(120)
    while life.clock.absolute_minutes<end and Time.get_ticks_msec()<deadline:
        await physics_frame
        phases[life.clock.phase_name()]=true
        for id in life.states:
            var r:HutorDailyResidentState=life.states[id]
            seen[id][r.activity]=true
            if identities[id]!=r.actor.get_instance_id():invalid="identity changed: "+String(id)
            if r.actor.is_inside_tree():
                if r.scene!=life.active_scene():invalid="active body in wrong scene: "+String(id)
                if r.mode==&"boundary_out" or r.mode==&"boundary_in":
                    boundary_seen[id]=true
                    if r.actor.get_collision_exceptions().size()!=1:invalid="boundary ignores unexpected colliders"
                elif not free_at(world,r.actor.position,r.original.foot_radius):invalid="NPC feet intersect world geometry: "+String(id)+" "+str(r.actor.position)
                if id==&"woodcutter_son" and r.scene==&"village" and not Rect2(1180,740,730,970).grow(20).has_point(r.actor.position):invalid="child left safe yard/central route"
            if r.mode==&"offsite" and r.actor.is_inside_tree():invalid="offsite body still active"
    life.clock.running=false
    check(life.clock.absolute_minutes>=end,"full day advances without seeking, within timeout")
    check(invalid.is_empty(),"live physics/identity/safe-zone invariants: "+invalid)
    check(phases.size()==4,"morning, day, evening and night observed")
    for id in life.states:
        var r:HutorDailyResidentState=life.states[id]
        check(seen[id].size()>=3,String(id)+" performs distinct occupations: "+str(seen[id].keys()))
        if id in [&"woodcutter",&"herbalist_brother"]:
            check(r.event_counts.get("left_for_work",0)==1 and r.event_counts.get("return_from_work",0)==1,"one physical logging departure and return: "+String(id))
            check(boundary_seen.has(id),"worker visibly crosses map boundary: "+String(id))
            check(r.scene==r.schedule.home,"worker is back at own home next morning: "+String(id))
        if id==&"woodcutter_son":check(seen[id].has(&"kneel_toy") and seen[id].has(&"play_stick") and seen[id].has(&"run_yard"),"child plays, kneels and runs")
        if id==&"old_man":check(seen[id].has(&"sit_and_smoke"),"old man has seated smoking occupation")
    for event in life.events:
        if event.event in ["left_for_work","return_from_work"]:check(event.detail=="north_logging","same declared gateway used in both directions")
    var navigation:HutorNpcNavigation=world.get_node("Actors/Residents/Navigation")
    check(navigation.max_solves_in_tick<=2 and navigation._cache.size()<=128,"existing navigation work/cache budgets respected")
    for room in travel.rooms.values():
        check(room.get_node("Actors/Residents/Navigation").solve_count==0,"off-scene room does no path solves: "+String(room.building_id))
    check(life.events.size()<=1024,"bounded diagnostics")
    print("RESULT: ",passed," daily-cycle checks passed, ",failed," failed")
    quit(0 if failed==0 else 1)
