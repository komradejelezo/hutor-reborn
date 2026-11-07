extends "res://tests/verify_interiors.gd"
## Fault-inject one home before VillageLife bootstraps; never edit a saved resource.
func run() -> void:
    travel=root.get_node("InteriorTravel")
    var id:=StringName(OS.get_cmdline_user_args()[0])
    var data:HutorBuildingDefinition=travel.buildings[id]
    var original:=data.interior_scene
    data.interior_scene="res://scenes/interiors/unavailable_stage491.tscn"
    change_scene_to_file(travel.VILLAGE);await frames(12)
    var life:Node=root.get_node("VillageLife")
    life.clock.running=false
    check(life.initialized and life.states.size()==9,"missing "+String(id)+" does not break nine-resident bootstrap")
    check(not travel.rooms.has(id),"unavailable home is never cached as a fake scene")
    check(not travel.request_transition(id) and not travel.active_world.player.controls_locked,"missing home cannot trap Hans")
    # Exercise inactive resident updates and morning/evening scene changes as well.
    for minute in [600,730,1080,1215,1380]:
        life.clock.seek(minute);await frames(3)
        check(life.states.size()==9 and not travel.busy,"virtual residents survive time seek "+str(minute))
    data.interior_scene=original
    check(travel.request_transition(id),"restored original scene can be retried")
    await wait_transition()
    check(travel.active_id==id and not travel.active_world.player.controls_locked,"retry enters original home")
    check(travel.request_transition(id,true),"retry exit accepted")
    await wait_transition()
    check(travel.active_id==&"" and not travel.active_world.player.controls_locked,"retry returns to village")
    print("RESULT: ",passed," missing-interior checks passed, ",failed," failed: ",id)
    quit(0 if failed==0 else 1)
