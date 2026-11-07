extends "res://tools/review_interiors.gd"
## Live schedule captures. Debug seeking positions the clock, not an invented pose.
var life: Node
func frame_world(world: Node2D, center: Vector2) -> void:
    root.size=Vector2i(960,540);root.content_scale_size=root.size
    var camera:Camera2D=world.player.get_node("Camera2D")
    camera.position_smoothing_enabled=false;camera.set_as_top_level(true)
    camera.global_position=center;camera.force_update_scroll()
func screenshot(suffix: String) -> void:
    for record:HutorDailyResidentState in life.states.values():
        if record.actor.is_inside_tree():
            print(suffix," ",record.id," ",record.actor.position," ",record.actor.state," ",record.activity," visible=",record.actor.is_visible_in_tree()," clip=",record.actor.get_node("AnimatedSprite2D").animation)
    await super.screenshot(suffix)
func run() -> void:
    travel=root.get_node("InteriorTravel")
    var village:Node2D=load(travel.VILLAGE).instantiate()
    root.add_child(village);current_scene=village;await frames(10)
    life=root.get_node("VillageLife");life.clock.running=false
    life.clock.seek(370);village.player.position=Vector2(765,1050)
    frame_world(village,Vector2(700,980));await frames(15)
    await screenshot("pine-smoking")
    life.clock.seek(489);village.player.position=Vector2(1625,1020)
    frame_world(village,Vector2(1650,965));await frames(15)
    await screenshot("child-playing")
    for pair in [["woodcutter",425],["inn",730],["herbalist",665],["elder",375]]:
        var id:=StringName(pair[0]);life.clock.seek(float(pair[1]))
        village.player.get_node("Camera2D").set_as_top_level(false)
        travel.request_transition(id)
        while travel.busy:await process_frame
        var room:Node2D=travel.active_world
        frame_world(room,room.room_bounds.get_center())
        room.player.position=room.get_node("Entry").position
        await frames(20);await screenshot(String(id)+"-work")
        if id==&"inn":
            var npc:HutorResident=life.states[&"innkeeper"].actor
            room.player.position=npc.get_node("Interaction").global_position+Vector2(0,22)
            await frames();room.player.interaction_requested.emit(npc.get_node("Interaction").interact())
            await create_timer(.3).timeout
            root.get_node("DialogueManager").window.reveal_all()
            await screenshot("working-dialogue")
            root.get_node("DialogueManager").close_dialogue();await create_timer(.2).timeout
        room.player.get_node("Camera2D").set_as_top_level(false)
        travel.request_transition(id,true)
        while travel.busy:await process_frame
    print("PASS: seven live daily-life captures")
    quit()
