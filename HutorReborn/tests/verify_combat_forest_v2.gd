extends "res://tests/verify_combat_ui_61.gd"
const PACK="res://assets/combat/forest_v2/"
func shot(name:String) -> void:
    var output:=OS.get_environment("COMBAT_CAPTURE_DIR")
    if output.is_empty() or DisplayServer.get_name()=="headless":return
    await RenderingServer.frame_post_draw
    DirAccess.make_dir_recursive_absolute(output)
    check(root.get_texture().get_image().save_png(output+"/"+name+".png")==OK,"capture "+name)
    if name=="fullscreen":
        var screen:=DisplayServer.screen_get_image(DisplayServer.window_get_current_screen())
        check(screen!=null and screen.save_png(output+"/fullscreen-native.png")==OK,"native fullscreen screen capture")
func run() -> void:
    var hashes:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(PACK+"source_checksums.json"))
    check(hashes.size()==259,"all 259 supplied source files retained")
    for path in hashes:
        check(FileAccess.file_exists(PACK+path) and FileAccess.get_sha256(PACK+path)==hashes[path],"source bytes "+path)
    var lib:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(PACK+"library.json"))
    for unit in ["hans","wolf","leshy"]:
        check(lib[unit].idle.source_count==24 and lib[unit].idle.derived_from==unit.capitalize()+"/Idle","approved supplied Idle retained "+unit)
    check(lib.wolf.idle.correction.frame==12 and lib.wolf.idle.correction.donor_frame==11,"local paw repair recorded")
    check(lib.wolf.attack.frames.size()==24 and lib.wolf.attack.impact==13 and lib.wolf.attack.ms==45,"new wolf bite uses all v3 poses with jaw-close impact")
    change_scene_to_file(ARENA);await scene_changed;await frames()
    var arena:Control=current_scene;arena.fast.button_pressed=true
    var stage:Control=arena.get_node("ForestStage");var master:TextureRect=stage.get_node("Master")
    check(master.texture.get_size()==Vector2(1672,941) and master.texture_filter==CanvasItem.TEXTURE_FILTER_NEAREST,"supplied RGB master and Nearest")
    check(master.material==null and master.scale==Vector2.ONE and master.stretch_mode==TextureRect.STRETCH_KEEP_ASPECT_COVERED,"master not warped; aspect ratio preserved")
    var transform:Transform2D=master.get_transform()
    await frames(120)
    check(master.get_transform()==transform,"master/ground stays static while atmosphere advances")
    arena.atmosphere.select(0);arena.atmosphere.item_selected.emit(0);await frames()
    check(not stage.get_node("Atmosphere").visible and not stage.get_node("Atmosphere").is_processing(),"atmosphere switch disables overlay and CPU update")
    arena.atmosphere.select(2);arena.atmosphere.item_selected.emit(2);await frames()
    check(stage.get_node("Atmosphere").visible and stage.get_node("Atmosphere").is_processing(),"atmosphere switch restores separate layers")
    stage.intensity=.4
    check(is_equal_approx(float(stage.get_node("Atmosphere/DistantMist").material.get_shader_parameter("density")),.018),"intensity also controls separate mist shader")
    stage.intensity=.65
    for id in ["duel","ambush","companions","tincture","betrayal","forest"]:
        arena._start_scenario(id);await ready_turn(arena)
        for view in arena.views.values():
            var foot:Vector2=view.position+view.body.position
            check(is_equal_approx(foot.y,378),"common grounded formation "+id+"/"+view.unit.id)
            check(view.name_label.position.y>view.body.position.y and view.bar.position.y>view.body.position.y,"HUD below feet, not covering model "+view.unit.id)
            check(view.position.y+view.size.y<=466,"formation footer clears action panel "+view.unit.id)
        check(arena.actions.attack.position.y>=488 and arena.hint_label.position.y>=466,"actions clear combat field "+id)
    change_scene_to_file("res://scenes/combat/CombatAnimationReview.tscn");await scene_changed;await frames()
    stage=current_scene.get_node("ForestStage");master=stage.get_node("Master")
    check(current_scene.drivers.size()==3,"Hans, wolf and leshy share one grounded scene")
    await shot("all-three-stage")
    stage.atmosphere_enabled=false;await frames();await shot("stage-disabled")
    stage.atmosphere_enabled=true;await frames();await shot("stage-enabled")
    var capture_dir:=OS.get_environment("COMBAT_CAPTURE_DIR")
    if not capture_dir.is_empty() and DisplayServer.get_name()!="headless":
        var off:=Image.load_from_file(capture_dir+"/stage-disabled.png")
        var on:=Image.load_from_file(capture_dir+"/stage-enabled.png")
        check(off.get_region(Rect2i(330,300,35,35)).get_data()==on.get_region(Rect2i(330,300,35,35)).get_data(),"1225 unoccupied ground pixels unchanged with FX off/on")
        check(off.get_region(Rect2i(260,164,522,73)).get_data()!=on.get_region(Rect2i(260,164,522,73)).get_data(),"distant atmospheric strip actually changes with FX switch")
    if DisplayServer.get_name()!="headless":
        for size in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1920,1080)]:
            root.size=size;root.position=Vector2i.ZERO;await frames(15)
            check(DisplayServer.window_get_size()==size,"native window size "+str(size))
            await shot("window-"+str(size.x))
        root.mode=Window.MODE_FULLSCREEN;await frames(20)
        check(DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN,"16:9 fullscreen mode")
        await shot("fullscreen")
        root.mode=Window.MODE_WINDOWED;root.size=Vector2i(960,540)
    else:print("LIMITATION: display/fullscreen/captures require graphical invocation")
    print("RESULT: ",passed," forest v2 checks passed, ",failed," failed")
    quit(0 if failed==0 else 1)
