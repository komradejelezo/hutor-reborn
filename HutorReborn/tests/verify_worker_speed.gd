extends "res://tests/verify_interiors.gd"
## Regression: first visible materialization may be a return from virtual work.
func run()->void:
    travel=root.get_node("InteriorTravel")
    change_scene_to_file(travel.VILLAGE);await frames(12)
    var life:Node=root.get_node("VillageLife");life.clock.running=false
    var originals:Dictionary={}
    for id in [&"woodcutter",&"herbalist_brother"]:originals[id]=life.states[id].original.speed
    check(travel.request_transition(&"inn"),"Hans enters inn before workers first appear")
    await wait_transition()
    life.clock.seek(1079)
    life.clock.set_speed(30);life.clock.running=true
    var deadline:=Time.get_ticks_msec()+5000
    while life.states[&"woodcutter"].mode!=&"boundary_in" and Time.get_ticks_msec()<deadline:await process_frame
    life.clock.running=false
    check(life.states[&"woodcutter"].mode==&"boundary_in","virtual worker starts evening return while Hans is indoors")
    for id in originals:
        life.states[id].actor.tree_entered.connect(func():
            # Equivalent to F7 while the returning body first becomes visible.
            life.clock.set_speed(120);life.clock.set_speed(1),CONNECT_ONE_SHOT)
    check(travel.request_transition(&"inn",true),"Hans returns outside while workers cross boundary")
    await wait_transition()
    life.clock.set_speed(120);life.clock.set_speed(1)
    for id in originals:
        var r:HutorDailyResidentState=life.states[id]
        check(r.actor.definition!=r.original,String(id)+" visible runtime definition is independent of immutable original")
        check(is_equal_approx(r.original.speed,originals[id]),String(id)+" source speed survives F7 acceleration/reset")
        check(is_equal_approx(r.actor.definition.speed,originals[id]),String(id)+" runtime speed actually returns to x1")
        print("SPEED ",id," baseline=",originals[id]," original=",r.original.speed," runtime=",r.actor.definition.speed)
    print("RESULT: ",passed," worker-speed checks passed, ",failed," failed")
    quit(0 if failed==0 else 1)
