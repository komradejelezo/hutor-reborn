extends SceneTree
## Same camera/effects, ABBA order; read-only diagnostics, not a target-GPU claim.
func _initialize() -> void:call_deferred("run")
func run() -> void:
    var world:Node2D=load("res://scenes/world/krivaya_sosna/krivaya_sosna.tscn").instantiate()
    root.add_child(world);current_scene=world
    world.player.set_physics_process(false)
    world.player.position=Vector2(1713,1000)
    var camera:Camera2D=world.player.get_node("Camera2D")
    camera.position_smoothing_enabled=false;camera.force_update_scroll()
    var population:Node2D=world.get_node("Actors/Residents")
    var results:Array=[]
    for enabled in [false,true,true,false]:
        population.visible=enabled
        population.process_mode=Node.PROCESS_MODE_INHERIT if enabled else Node.PROCESS_MODE_DISABLED
        for actor in population.residents.values():
            var marker:Node=actor.get_node("Interaction")
            if enabled and not marker.is_in_group("interactables"):marker.add_to_group("interactables")
            elif not enabled and marker.is_in_group("interactables"):marker.remove_from_group("interactables")
        for i in range(45):await process_frame
        var samples:Array=[]
        var averages:=[0.0,0.0,0.0]
        for i in range(90):
            await process_frame
            var row:=[Performance.get_monitor(Performance.TIME_PROCESS)*1000,Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000,Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)]
            samples.append(row)
            for j in range(3):averages[j]+=row[j]/90.0
        var physics:Array=[]
        for sample in samples:physics.append(sample[1])
        physics.sort()
        results.append({"residents":enabled,"process_mean_ms":averages[0],"physics_mean_ms":averages[1],"physics_p95_ms":physics[85],"draw_calls":averages[2]})
    var navigation:HutorNpcNavigation=population.navigation
    var output:={"godot":Engine.get_version_info().string,"renderer":RenderingServer.get_video_adapter_name(),"samples_per_pass":90,"warmup_frames":45,"order":"off-on-on-off","same_camera":"woodcutter courtyard","effects":"unchanged/on","passes":results,"navigation":{"solves":navigation.solve_count,"cache_hits":navigation.cache_hits,"max_solves_per_tick":navigation.max_solves_in_tick,"cache_entries":navigation._cache.size()},"note":"Software llvmpipe; this comparison is diagnostic, not target hardware FPS."}
    var file:=FileAccess.open(OS.get_cmdline_user_args()[0],FileAccess.WRITE)
    file.store_string(JSON.stringify(output,"  ",true));file.close()
    print("PASS: benchmark saved; max ",navigation.max_solves_in_tick," solves/tick")
    world.queue_free();await process_frame;quit()
