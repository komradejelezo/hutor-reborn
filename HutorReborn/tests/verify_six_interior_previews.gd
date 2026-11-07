extends "res://tests/verify_interiors.gd"
func run() -> void:
    # Isolate the approved pre-schedule component fixture. Live residency has separate integration coverage.
    root.get_node("VillageLife").enabled=false
    travel=root.get_node("InteriorTravel")
    for id in [&"inn",&"elder",&"herbalist",&"woodcutter",&"old_man",&"storehouse"]:
        if is_instance_valid(travel.exterior):
            travel.exterior.queue_free();await process_frame;await process_frame
        var room:Node2D=load("res://scenes/interiors/"+String(id)+".tscn").instantiate()
        root.add_child(room);current_scene=room;await frames(8)
        check(travel.active_world==room and travel.active_id==id,"F6 playable: "+String(id))
        check(room.player.sensor.target==room.get_node("Exit"),"F6 exit reachable")
        check(room.player.get_node("Camera2D").zoom==Vector2(1.3,1.3),"F6 uses existing indoor zoom")
        await tap_e();await wait_transition()
        check(is_instance_valid(travel.exterior) and travel.active_id==&"","F6 exit returns to normal village")
        check(travel.exterior.player.get_node("Camera2D").zoom==Vector2.ONE,"F6 exit restores outdoor zoom")
        check(not travel.exterior.player.controls_locked,"F6 exit releases input")
        check(get_nodes_in_group("residents").size()==9,"F6 exit retains exactly nine residents")
    print("RESULT: ",passed," six-room preview checks passed, ",failed," failed")
    quit(0 if failed==0 else 1)
