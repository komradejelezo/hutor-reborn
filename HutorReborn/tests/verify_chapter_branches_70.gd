extends "res://tests/verify_chapter_flow_70.gd"
func run() -> void:
    c=root.get_node("ChapterI")
    await c.start_new(true);c.life.clock.running=false
    await go("inn");c.speak("innkeeper_wife")
    await create_timer(3.1).timeout
    check(c.state.has("wife_interrupted") and c._reserved.has("elder"),"real elder visit interrupts wife at evening, using original actor")
    await create_timer(5.0).timeout
    check(not c._reserved.has("elder") and c.life.states.size()==9,"elder walks to exit and resumes daily simulation")
    await npc("innkeeper","pay");check(c.state.money==3 and c.state.decisions.lodging=="pay","paid lodging branch uses real original innkeeper")
    await go("");await point("leave","leave_end")
    check(c.state.has("left_village") and c.ui.blocking and c.ui.is_open(),"southern road has real independent departure ending")
    c.ui.close();check(await c.load_game(true,"checkpoint"),"departure checkpoint can restore decision")
    check(not c.state.has("left_village"),"departure ending does not contaminate checkpoint")
    for id in ["elder","herbalist_brother"]:
        await c.start_new(true,2);c.life.clock.running=false;c.state.decisions.erase("axe")
        await npc(id,"axe_elder" if id=="elder" else "axe_brother")
        check(c.state.decisions.axe==("elder" if id=="elder" else "brother") and c.state.stage()==2,"alternate axe dialogue preserves next quest: "+id)
    await c.start_new(true,3);c.life.clock.running=false;c.life.clock.seek(1085);await frames(6)
    check(c._reserved.has("old_man") and c.life.states[&"old_man"].actor.is_inside_tree(),"original old man stays by pine for evening story meeting")
    c.speak("old_man");await answer("warning");await frames(5)
    check(not c._reserved.has("old_man") and c.life.states[&"old_man"].scene==&"village", "old man really walks home after story, no visible teleport")
    for approach in ["alone","elder","herbalist"]:
        await c.start_new(true,5);c.life.clock.running=false
        if approach=="alone":await point("abandoned","approach_alone")
        else:await npc(approach,"approach_"+approach)
        if approach=="elder":
            await point("official_copy");check(c.state.count("copy")==1,"reporting to elder opens actual archive document route")
        c.life.clock.seek(1335);await go("");await point("abandoned","go_house")
        check(c._reserved.has("herbalist")== (approach=="herbalist"),"correct physical companion branch: "+approach)
        var trust:int=c.state.trust.get("elder",0)
        await point("floor_cache");await point("cabinet")
        check(c.state.has("diary_found"),"every house approach reaches diary: "+approach)
        await point("house_exit","exit_location");await point("abandoned","go_house")
        check(int(c.state.trust.get("elder",0))==trust,"re-entry never repeats relationship consequence: "+approach)
    await c.start_new(true,4);c.life.clock.running=false
    await npc("innkeeper","bait_received");await go("");await point("north","go_camp");await point("wolves","bait")
    check(c.state.decisions.get("wolves")=="bait" and c.state.count("bait")==0,"actual bait item distracts physical guard")
    for outcome in ["victory","defeat","retreated"]:
        c.state.flags.erase("wolves_clear");c.state.changed.emit();var hero:CharacterBody2D=c.travel.active_world.player
        c.start_encounter();await frames(10)
        c.finish_encounter(outcome,72,0);await frames(8)
        check(c.travel.active_world.player==hero and not hero.controls_locked and c.life.states.size()==9,"same Hans and NPC session after combat adapter: "+outcome)
        check(c.state.has("wolves_clear")== (outcome=="victory"),"story battle consequence: "+outcome)
    c.save_game();var expected:Dictionary=c.state.pack();var scene:Node=current_scene
    var file:=FileAccess.open(c.SAVE.path(true,"manual"),FileAccess.WRITE);file.store_string("truncated");file.close()
    check(not await c.load_game(true),"truncated save rejected")
    check(c.state.pack()==expected and current_scene==scene,"corrupt load keeps live session intact")
    c.save_game();file=FileAccess.open(c.SAVE.path(true,"manual"),FileAccess.READ_WRITE);file.seek_end(-1);file.store_8(111);file.close()
    check(not await c.load_game(true),"payload checksum rejects accidental byte corruption")
    check(not c.SAVE.exists(false),"branch fixtures never modify normal saves")
    c.ui.menu();await scene_changed;await frames()
    print("RESULT: ",passed," chapter branch/save checks passed, ",failed," failed");quit(0 if failed==0 else 1)
