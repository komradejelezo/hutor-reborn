extends SceneTree
## Integration fixtures teleport Hans/seek time explicitly; this is not a manual playthrough.
var c:Node
var passed:=0
var failed:=0
var captures:=""
func _initialize() -> void:call_deferred("run")
func check(ok:bool,msg:String) -> void:
    if ok:passed+=1;print("PASS: ",msg)
    else:failed+=1;push_error(msg)
func frames(n:int=4) -> void:
    for i in n:await process_frame
func settled() -> void:
    for i in 10000:
        if not c.travel.busy and not c.busy and not c.dialogue.is_active():return
        await process_frame
    check(false,"transition deadline")
func go(id:String) -> void:
    await settled()
    if String(c.travel.active_id)==id:return
    if c.travel.active_id!=&"":c._go(c.travel.active_id,true);await settled()
    if id!="":c._go(StringName(id));await settled()
    await frames()
func answer(action:String) -> void:
    check(c.dialogue.is_active(),"existing dialogue open for "+action)
    if not c.dialogue.is_active():return
    if c.dialogue.phase==c.dialogue.Phase.OPENING:await c.dialogue.window.opened
    c.dialogue.window.reveal_all();await frames()
    var choices:Array=c.dialogue.data.nodes[c.dialogue.current_line].get("choices",[])
    var index:=-1
    for i in choices.size():
        if choices[i].id==action:index=i
    check(index>=0,"conditioned answer present: "+action)
    if index<0:c.dialogue.close_dialogue();await settled();return
    c.dialogue.choose(index);c.dialogue.window.reveal_all();c.dialogue.close_dialogue();await settled();await frames()
func point(action:String,choice:String="") -> void:
    var marker:Node2D=c.travel.active_world.get_node_or_null("ChapterWorld/Story_"+action)
    check(is_instance_valid(marker) and marker.is_in_group("interactables"),"live world object available: "+action)
    if not is_instance_valid(marker):return
    var hero:CharacterBody2D=c.travel.active_world.player
    var shape:=CircleShape2D.new();shape.radius=8
    for offset in [Vector2.ZERO,Vector2(0,24),Vector2(24,0),Vector2(-24,0),Vector2(0,-24),Vector2(0,40)]:
        var query:=PhysicsShapeQueryParameters2D.new();query.shape=shape;query.collision_mask=1;query.transform=Transform2D(0,marker.global_position+offset+Vector2(0,-3))
        if hero.get_world_2d().direct_space_state.intersect_shape(query,1).is_empty():hero.global_position=marker.global_position+offset;break
    for i in 6:await physics_frame
    if not c.dialogue.is_active():
        check(hero.sensor.target==marker,"sensor can select actual reachable story object: "+action)
        var key:=InputEventKey.new();key.physical_keycode=KEY_E;key.keycode=KEY_E;key.pressed=true
        Input.parse_input_event(key);Input.flush_buffered_events();await frames()
        key=InputEventKey.new();key.physical_keycode=KEY_E;key.keycode=KEY_E;key.pressed=false
        Input.parse_input_event(key);Input.flush_buffered_events();await frames()
    await answer(action if choice=="" else choice)
func npc(id:String,action:String) -> void:
    c.life.clock.seek(floor(c.life.clock.absolute_minutes/1440)*1440+1335);await frames()
    var r:RefCounted=c.life.states[StringName(id)];await go("" if r.scene==&"village" else String(r.scene))
    await frames(10);check(r.actor.is_inside_tree(),"same original resident present: "+id)
    c.travel.active_world.player.position=r.actor.position+Vector2(24,24)
    c.travel.active_world._show_description({"chapter_npc":id});await answer(action)
func snap(name:String) -> void:
    if captures=="":return
    var camera:Camera2D=c.travel.active_world.player.get_node("Camera2D");camera.reset_smoothing();camera.force_update_scroll();await frames(3);await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(captures.path_join(name+".png"))
func run() -> void:
    c=root.get_node("ChapterI")
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--captures="):captures=arg.trim_prefix("--captures=");DirAccess.make_dir_recursive_absolute(captures)
    await c.start_new(true);c.life.clock.running=false;await frames()
    check(c.state.stage()==0 and c.travel.active_world.player.position==Vector2(1378,2460),"new chapter starts on southern road at evening")
    check(c.life.states.size()==9 and c._reserved.has("woodcutter"),"existing woodcutter greets without cloning residents")
    var identities:Dictionary={}
    for id in c.life.states:identities[id]=c.life.states[id].actor.get_instance_id()
    await point("sign");c.speak("woodcutter");await answer("greeted")
    await npc("innkeeper","inn_work");await point("take_dishes");await point("deliver_dishes");await npc("innkeeper","work_paid")
    check(c.state.has("lodging") and c.state.money==6,"lodging earned by two actual world interactions")
    await snap("inn-night");await point("sleep")
    check(c.state.stage()==1 and c.state.has("night"),"three-strike night advances to investigation")
    for id in ["woodcutter_son","woodcutter_wife","herbalist_brother","woodcutter"]:await npc(id,"w_"+id)
    await go("");await point("tracks");await point("axe_found");await point("tools")
    c.ui.inventory();check(c.ui.is_open(),"inventory shows story items");c.ui.inspect("axe");await answer("axe_keep")
    check(c.state.stage()==2,"all investigation evidence and keep-axe branch connected")
    await npc("herbalist","herbs_started");await go("");await point("poison");await npc("herbalist","discard_poison")
    await go("");await point("thyme");await point("valerian");await npc("herbalist","herbs_done")
    check(c.state.stage()==3 and c.state.count("tincture")==2,"wrong herb corrected and actual harvest delivered")
    await npc("old_man","warning");await go("");await point("pine_symbol")
    check(c.state.stage()==4,"old man and pine unlock forest route")
    await point("north","go_camp");check(c.travel.active_id==&"logging_camp","real separate logging scene entered with same Hans")
    c.travel.active_world.player.position=Vector2(360,580);await frames()
    check(c.state.decisions.get("wolves")=="bypass","physical western route bypasses wolves without combat")
    await snap("logging-camp")
    for a in ["vanishing","handle","cloth","struggle"]:await point(a)
    check(c.state.stage()==5 and c.state.count("cloth")==1,"all four physical camp findings collected")
    await point("camp_exit","exit_location");await npc("herbalist","approach_herbalist")
    await go("");await point("abandoned","go_house")
    check(c.travel.active_id==&"abandoned" and c.state.has("house_open"),"abandoned house opens by story at night")
    check(c._reserved.has("herbalist") and c.life.states[&"herbalist"].actor.get_parent()==c.travel.active_world.get_node("Actors/Residents"),"same herbalist body really accompanies Hans inside")
    var companion:HutorResident=c.life.states[&"herbalist"].actor;var before:=companion.position;c.travel.active_world.player.position+=Vector2(90,-30);await frames(70)
    check(companion.position.distance_to(before)>1,"companion follows using body collisions and original animation")
    await point("family");await point("house_symbol");await point("floor_cache");await point("cabinet");await snap("abandoned-house")
    check(c.state.count("diary")==1 and c.state.has("diary_found"),"actual key/cache/cabinet reveal diary")
    check(c.save_game(),"manual save in abandoned house succeeds")
    var expected:Dictionary=c.state.pack();var minute:float=c.life.clock.absolute_minutes;var pos:Vector2=c.travel.active_world.player.position
    c.state.money=0;c.state.items.clear()
    check(await c.load_game(true),"test save loads a fresh session")
    check(c.state.pack()==expected and c.travel.active_id==&"abandoned" and c.travel.active_world.player.position==pos and is_equal_approx(c.life.clock.absolute_minutes,minute),"all flags, inventory, decisions, time and exact location restored")
    check(c.life.states.size()==9 and c._reserved.has("herbalist"),"nine identities and one companion after load")
    await point("house_exit","exit_location");await point("finale")
    check(c.state.stage()==6 and c.ui.is_open(),"one-shot final cinematic ends in chapter completion screen")
    c.ui.close();check(not paused and not c.travel.active_world.player.controls_locked,"free exploration restored after finale")
    check(c.save_game() and await c.load_game(true),"completed chapter can be saved and loaded")
    check(c.state.has("finale") and not c.available("finale"),"loaded completed chapter never repeats final event")
    check(await c.load_game(true,"checkpoint"),"checkpoint before finale loads")
    check(c.state.has("diary_found") and not c.state.has("finale"),"checkpoint can replay finale without losing diary")
    check(not c.SAVE.exists(false),"test flow never writes a normal save")
    c.ui.journal("Улики");await snap("journal");c.ui.close()
    # All side chores use their actual scene objects and the same conversations.
    await npc("woodcutter_son","toy_started");await go("");await point("wheel");await go("storehouse");await point("repair");await npc("woodcutter_son","toy_done")
    await npc("woodcutter_wife","wood_started");await go("");await point("collect_logs");await go("woodcutter");await point("deliver_logs");await npc("woodcutter_wife","wood_done")
    await npc("innkeeper","mug_started");await point("take_mug");await npc("herbalist_brother","mug_owner");await npc("innkeeper","mug_done")
    await npc("herbalist","dry_started");await go("storehouse");await point("dry_take");await go("herbalist");await point("dry_sort");await npc("herbalist","dry_done")
    check(c.state.SIDES.all(func(q:Array):return c.state.has(q[3])),"all four optional quest chains complete through world objects")
    await go("");await point("north","go_camp")
    # New test branch for the independent story combat adapter; no changes to arena.
    c.state.flags.erase("wolves_clear");c.state.decisions.erase("wolves");c.state.changed.emit();c.start_encounter();await frames()
    var arena:Control=current_scene;arena.fast.button_pressed=true
    for i in 20000:
        await process_frame
        if arena.busy:continue
        if arena.battle.result!="":break
        if arena.battle.actor().team==0:
            var target:String=arena.battle.targets("attack")[0]
            arena._target(target)
    check(arena.battle.result in ["victory","defeat"],"unchanged battle engine reaches terminal result in story adapter")
    c.finish_encounter(arena.battle.result,arena.battle.units.hans.hp,arena.battle.potions);await frames()
    check(current_scene==c.travel.active_world and c.travel.active_id==&"logging_camp" and c.life.states.size()==9 and not c.busy,"combat returns to same cached world without losing NPCs")
    await go("");c.ui.menu();await scene_changed;await frames()
    check(not c.active and current_scene.scene_file_path.ends_with("MainMenu.tscn"),"chapter cleanly returns to menu")
    print("RESULT: ",passed," chapter integration checks passed, ",failed," failed");quit(0 if failed==0 else 1)
