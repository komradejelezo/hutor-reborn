extends "res://tests/verify_chapter_flow_70.gd"
## Short graphical fixtures; time seeks/teleports and overview zoom are explicit.
func run() -> void:
    c=root.get_node("ChapterI")
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--captures="):captures=arg.trim_prefix("--captures=");DirAccess.make_dir_recursive_absolute(captures)
    await c.start_new(true,4);c.life.clock.running=false;c.life.clock.seek(1085)
    await go("logging_camp");c.travel.active_world.player.position=Vector2(560,750);await frames(8);await snap("logging-camp")
    c.travel.active_world.atmosphere.set_effects_enabled(false);check(not c.travel.active_world.get_node("Mist").visible,"new forest fog follows existing effects switch")
    c.travel.active_world.atmosphere.set_effects_enabled(true);check(c.travel.active_world.get_node("Mist").visible,"new forest fog restores cleanly")
    var cam:Camera2D=c.travel.active_world.player.get_node("Camera2D");cam.zoom=Vector2.ONE*.46;await snap("logging-overview");cam.zoom=Vector2.ONE
    c.state.prepare(5);await go("");await npc("herbalist","approach_herbalist");await go("");await point("abandoned","go_house")
    c.travel.active_world.player.position=Vector2(520,420);await frames(80);await snap("abandoned-house")
    await point("floor_cache");await point("cabinet");c.ui.inventory();await snap("inventory");c.ui.close()
    c.ui.journal();await snap("journal");c.ui.close()
    await point("house_exit","exit_location")
    create_timer(3.8).timeout.connect(func():snap("finale-moment"))
    await point("finale");await snap("chapter-complete");c.ui.close()
    check(c.state.has("finale"),"final graphical chapter event completed")
    c.ui.menu();await scene_changed;await frames()
    print("RESULT: ",passed," visual fixture checks passed, ",failed," failed");quit(0 if failed==0 else 1)
