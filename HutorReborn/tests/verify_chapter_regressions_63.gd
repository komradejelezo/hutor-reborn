extends "res://tests/verify_chapter_access_63.gd"
## Scene connectivity audit, dialogue sequence and v1 in-progress save compatibility.
func audit(actions:Array) -> void:
    var g:=grid()
    for a in actions:
        var path:=approach(a,g)
        check(not path.is_empty(),"entrance-connected interaction: "+String(c.travel.active_id)+"/"+a)
func run() -> void:
    c=root.get_node("ChapterI");await c.start_new(true);c.life.clock.running=false
    var content:Script=load("res://scripts/chapter/chapter_content.gd")
    check(not content.options(c.state,"innkeeper").any(func(o:Array):return o[0]=="mug_done"),"no Miron confession or reward before identifying cup")
    check(content.options(c.state,"innkeeper_wife").is_empty(),"no question about unheard night strikes on arrival")
    c.state.mark("night")
    var testimony:Array=content.options(c.state,"herbalist_brother").filter(func(o:Array):return o[0]=="w_herbalist_brother")
    check(not String(testimony[0][2]).contains("Дровосек говорит"),"brother does not quote an interview that has not happened")
    for action in ["toy_started","wood_started","mug_started","inn_work","dry_started"]:c.apply(action)
    await go("storehouse")
    var before:Dictionary=c.state.pack();c.interact("repair");await frames(10)
    check(c.dialogue.is_active() and c.dialogue.data.nodes.start.text.contains("Не хватает колеса"),"workbench explains missing wheel without inventing ingredients")
    c.dialogue.close_dialogue();await settled();check(c.state.pack()==before,"missing-wheel inspection has no inventory side effects")
    for action in ["wheel","repair","collect_logs","take_dishes","take_mug","dry_take"]:
        c.apply(action);await frames()
        check(c.save_game(),"in-progress v1 save: "+action)
        var expected:Dictionary=c.state.pack()
        check(await c.load_game(true) and c.state.pack()==expected,"disk restore keeps exact stage/items: "+action)
        c.life.clock.running=false
        check(c.available("repair")== (not c.state.has("toy_done")),"workbench remains inspectable after repair/load")
        check(c.available("take_mug")==not c.state.has("mug_taken"),"cup visibility restored after load")
    await go("inn")
    for action in ["take_dishes","take_mug"]:
        var marker:Node2D=c.travel.active_world.get_node("ChapterWorld/Story_"+action)
        check(marker.get_meta("art").all(func(art:CanvasItem):return not art.visible),"taken table objects stay hidden after restoring save: "+action)
    c.apply("mug_owner");c.speak("innkeeper");await frames(12)
    if c.dialogue.phase==c.dialogue.Phase.OPENING:await c.dialogue.window.opened
    c.dialogue.window.reveal_all()
    var choices:Array=c.dialogue.data.nodes.start.choices
    for i in choices.size():
        if choices[i].id=="mug_done":c.dialogue.choose(i);break
    var seen:=0
    while c.dialogue.is_active() and seen<4:
        if c.dialogue.phase!=c.dialogue.Phase.READING:await frames();continue
        c.dialogue.window.reveal_all();seen+=1
        check(not c.state.has("mug_done"),"confession reward waits for conversation end, line "+str(seen))
        c.dialogue.advance();await frames(4)
    await settled()
    check(seen==3 and c.state.has("mug_done") and c.state.count("mug")==0,"three linked confession lines finish with exactly one reward")
    # An old save can put Hans on the footprint of the newly readable mattress.
    c.travel.active_world.player.position=Vector2(750,430);c.save_game();var expected:Dictionary=c.state.pack()
    check(await c.load_game(true),"pre-fix mattress-position v1 save loads")
    check(c.travel.active_world.player.position==Vector2(750,419) and c.state.pack()==expected,"only obstructed old position moves beside bed; progress unchanged")
    c.life.clock.running=false
    await audit(["sleep","wait"])
    # Enable each investigation object without completing its action; audit the real ray/geometry.
    await go("");c.state.flags.erase("logs_taken");c.state.flags.erase("wheel_found")
    c.state.flags.erase("axe_found");c.state.flags.erase("tools");c.state.flags.erase("tracks")
    c.state.mark("herbs_started");await frames()
    await audit(["sign","leave","axe_found","tools","tracks","wheel","collect_logs","valerian","thyme","poison","abandoned"])
    c.state.mark("herbs_done");c.state.mark("ban_known");await frames();await audit(["pine_symbol","north"])
    c.state.mark("diary_found");await frames();await audit(["finale"])
    await go("logging_camp");await audit(["camp_exit","wolves"])
    c.state.mark("wolves_clear");await frames();await audit(["struggle","handle","cloth","vanishing"])
    await go("abandoned");c.state.flags.erase("diary_found");c.state.changed.emit();await frames();await audit(["house_exit","family","house_symbol","floor_cache","cabinet"])
    await go("elder");c.state.decisions.approach="elder";c.state.changed.emit();await frames();await audit(["archive","official_copy"])
    c.ui.menu();await scene_changed;await frames()
    print("RESULT: ",passed," chapter regression checks passed, ",failed," failed");quit(0 if failed==0 else 1)
