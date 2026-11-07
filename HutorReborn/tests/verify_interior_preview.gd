extends "res://tests/verify_interiors.gd"
func run() -> void:
    # Isolate the approved pre-schedule component fixture. Live residency has separate integration coverage.
    root.get_node("VillageLife").enabled=false
    travel=root.get_node("InteriorTravel")
    for id in [&"inn",&"elder",&"herbalist"]:
        if is_instance_valid(travel.exterior):
            travel.exterior.queue_free();await process_frame;await process_frame
        var room:Node2D=load("res://scenes/interiors/"+String(id)+".tscn").instantiate()
        root.add_child(room);current_scene=room;await frames(8)
        check(travel.active_world==room and travel.active_id==id,"standalone F6 room is playable: "+String(id))
        check(room.player.sensor.target==room.get_node("Exit"),"standalone entry can reach exit")
        check(room.player.get_node("Camera2D").zoom==Vector2(1.3,1.3),"standalone preview uses indoor camera")
        await tap_e();await wait_transition()
        check(is_instance_valid(travel.exterior) and travel.active_id==&"","standalone exit creates a normal village session")
        check(travel.exterior.player.get_node("Camera2D").zoom==Vector2.ONE,"normal outside zoom restored after standalone preview")
        check(not travel.exterior.player.controls_locked,"standalone exit releases input")
        check(get_nodes_in_group("residents").size()==9,"standalone preview exit has exactly nine existing residents")
    print("RESULT: ",passed," standalone preview checks passed, ",failed," failed")
    quit(0 if failed==0 else 1)
