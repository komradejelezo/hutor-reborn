extends SceneTree
## Diagnostic only: isolate the measured expensive effects at the central square.
func _initialize() -> void:call_deferred("run")
func run() -> void:
    var world:Node2D=load("res://scenes/world/krivaya_sosna/krivaya_sosna.tscn").instantiate()
    root.add_child(world)
    current_scene=world
    var player:CharacterBody2D=world.get_node("Actors/Hans")
    player.set_physics_process(false)
    var camera:Camera2D=player.get_node("Camera2D")
    camera.position_smoothing_enabled=false
    var lights:=world.find_children("*","PointLight2D",true,false)
    var original:Array=[]
    for light in lights:
        light.set_process(false)
        light.energy=light.base_energy
        original.append([light.texture_scale,light.shadow_enabled])
    var results:Array=[]
    for mode in ["all","no_shadows","no_fog","small_pools","small_pools_no_shadows","small_pools_no_fog","small_pools_no_shadows_no_fog"]:
        world.atmosphere.fog.visible=not "no_fog" in mode
        for i in range(lights.size()):
            lights[i].shadow_enabled=original[i][1] and not "no_shadows" in mode
            lights[i].texture_scale=original[i][0]*(.72 if "small_pools" in mode else 1.0)
        camera.force_update_scroll()
        for i in range(30):await process_frame
        var elapsed:=0.0
        var calls:=0.0
        for i in range(45):
            await process_frame
            elapsed+=Performance.get_monitor(Performance.TIME_PROCESS)*1000/45
            calls+=Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)/45
        results.append({"mode":mode,"process_ms":elapsed,"draw_calls":calls})
        print("PROFILE ",mode,": ",elapsed," ms; ",calls," calls")
    var file:=FileAccess.open(OS.get_cmdline_user_args()[0],FileAccess.WRITE)
    file.store_string(JSON.stringify(results,"  ",true))
    file.close()
    world.queue_free()
    await process_frame
    quit()
