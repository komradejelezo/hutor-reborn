extends "res://tests/verify_interiors.gd"
## F6 remains an isolated geometry preview; exiting boots normal live residency.
func run() -> void:
    travel=root.get_node("InteriorTravel")
    var room:Node2D=load("res://scenes/interiors/woodcutter.tscn").instantiate()
    root.add_child(room);current_scene=room;await frames(8)
    check(not root.get_node("VillageLife").initialized,"F6 has no extra resident instances")
    await tap_e();await wait_transition();await frames(8)
    var life:Node=root.get_node("VillageLife")
    check(life.initialized and life.states.size()==9 and travel.active_id==&"","F6 exit starts normal live village")
    check(life.clock.running and life.clock.absolute_minutes>=420,"normal game clock starts once")
    check(travel.request_transition(&"woodcutter"),"post-preview entry uses existing travel")
    await wait_transition()
    check(travel.active_world.get_node("Actors/Residents").residents.size()==3,"original family scheduled at home after F6 exit")
    print("RESULT: ",passed," live-preview checks passed, ",failed," failed")
    quit(0 if failed==0 else 1)
