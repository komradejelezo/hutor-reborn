extends "res://tests/verify_interiors.gd"
## Real evening boundary, with the old logging block still on the travelling record.
func run() -> void:
    travel=root.get_node("InteriorTravel")
    change_scene_to_file(travel.VILLAGE);await frames(12)
    var life:Node=root.get_node("VillageLife");life.clock.running=false;life.clock.seek(1079)
    var record:HutorDailyResidentState=life.states[&"woodcutter"]
    var identity:=record.actor.get_instance_id()
    var observed:={"return":false}
    life.residency_changed.connect(func(id:StringName,_scene:StringName):
        if id==&"woodcutter" and record.mode==&"boundary_in":
            observed["return"]=true;life.clock.running=false;life.clock.set_speed(1))
    life.clock.set_speed(30);life.clock.running=true
    var deadline:=Time.get_ticks_msec()+5000
    while not observed["return"] and Time.get_ticks_msec()<deadline:await process_frame
    life.clock.running=false;life.clock.set_speed(1);await frames(4)
    print("RETURN STATE ",life.clock.absolute_minutes," ",record.scene," ",record.mode," ",record.actor.is_inside_tree()," ",record.actor.activity_controller.pilot_delivery.delivered)
    check(record.mode==&"boundary_in" and record.scene==&"village","real scheduled return reaches physical boundary")
    check(record.actor.get_instance_id()==identity and record.actor.is_inside_tree(),"same resident returns from virtual logging")
    check(record.actor.animator.pilot_carrying,"requested evening block activates load while old work block remains")
    check(String(record.actor.get_node("AnimatedSprite2D").animation).begins_with("carry_"),"manual boundary movement actually renders carrying")
    check(not life.states[&"herbalist_brother"].actor.animator.pilot_carrying,"brother keeps original empty-hand renderer")
    check(travel.request_transition(&"woodcutter"),"Hans enters existing family room before return")
    await wait_transition()
    travel.active_world.player.position+=Vector2(35,0)
    life.clock.set_speed(30);life.clock.running=true
    deadline=Time.get_ticks_msec()+12000
    var saw_home_carry:=false
    var saw_placement:=false
    while Time.get_ticks_msec()<deadline:
        await physics_frame
        if record.scene==&"woodcutter" and record.actor.is_inside_tree():
            saw_home_carry=saw_home_carry or record.actor.animator.pilot_carrying
            saw_placement=saw_placement or record.actor.activity_controller.pilot_delivery.placing
            if travel.active_world.has_node("Actors/Props/DeliveredLogs542"):break
    life.clock.running=false
    check(saw_home_carry,"same loaded actor walks indoors with returned logs")
    check(saw_placement,"scheduled home arrival plays authored release")
    check(travel.active_world.has_node("Actors/Props/DeliveredLogs542"),"real return leaves matching ground bundle")
    check(record.actor.get_instance_id()==identity and record.scene==&"woodcutter","delivery preserves resident identity/home residency")
    print("RESULT: ",passed," real return checks passed, ",failed," failed")
    quit(0 if failed==0 else 1)
