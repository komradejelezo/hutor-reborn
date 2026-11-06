extends SceneTree
## Comparable hot-scene samples; no changes to project or scene configuration.
func _initialize() -> void:call_deferred("run")
func run() -> void:
    var world:Node2D=load("res://scenes/world/krivaya_sosna/krivaya_sosna.tscn").instantiate()
    root.add_child(world)
    current_scene=world
    var player:CharacterBody2D=world.get_node("Actors/Hans")
    player.set_physics_process(false)
    var camera:Camera2D=player.get_node("Camera2D")
    camera.position_smoothing_enabled=false
    var results:Array=[]
    for center in [Vector2(1378,1442),Vector2(510,760),Vector2(1050,350),Vector2(1800,1650)]:
        player.position=center
        camera.force_update_scroll()
        for i in range(45):await process_frame
        var samples:Array=[]
        for i in range(90):
            await process_frame
            samples.append([Performance.get_monitor(Performance.TIME_PROCESS)*1000,Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000,Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)])
        var average:=[0.0,0.0,0.0,0.0]
        for sample in samples:
            for i in range(4):average[i]+=sample[i]/samples.size()
        results.append({"center":str(center),"process_ms":average[0],"physics_ms":average[1],"draw_calls":average[2],"drawn_objects":average[3]})
    var file:=FileAccess.open(OS.get_cmdline_user_args()[0],FileAccess.WRITE)
    file.store_string(JSON.stringify({"samples_per_view":90,"views":results,"wind_nodes":get_nodes_in_group("wind_plants").size(),"nodes":get_node_count(),"solid_shapes":world.find_children("*","CollisionShape2D",true,false).size()},"  ",true))
    file.close()
    world.queue_free()
    await process_frame
    quit()
