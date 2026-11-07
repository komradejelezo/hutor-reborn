extends "res://tools/review_interiors.gd"
## Render the unchanged dialogue window with all four real emotions, all nine IDs.
var life: Node
func run() -> void:
    travel=root.get_node("InteriorTravel")
    var village:Node2D=load(travel.VILLAGE).instantiate()
    root.add_child(village);current_scene=village;await frames(10)
    life=root.get_node("VillageLife");life.clock.running=false
    root.size=Vector2i(960,540);root.content_scale_size=root.size
    var manager:Node=root.get_node("DialogueManager")
    var data_class=load("res://scripts/dialogue/dialogue_data.gd")
    for id in life.states:
        var r:HutorDailyResidentState=life.states[id]
        var minute:=665.0 if id==&"herbalist" else 1215.0 if id==&"old_man" else 425.0
        life.clock.seek(minute);travel.request_transition(r.schedule.home)
        while travel.busy:await process_frame
        var room:Node2D=travel.active_world
        var npc:HutorResident=r.actor
        room.player.position=room.get_node("Entry").position
        await frames()
        # Use existing original dialogue data/controller/window, with only a UI
        # preview choice of emotion. Saved dialogue text/graph remains intact.
        var conversation:HutorDialogueData=data_class.from_file(npc.definition.dialogue_path)
        manager.start_dialogue(conversation,room.player,room.hud)
        npc.begin_conversation();await create_timer(.28).timeout
        for emotion in ["neutral","joy","displeased","anxious"]:
            var line:Dictionary=conversation.nodes[conversation.start].duplicate(true);line.emotion=emotion
            manager.window.show_line(line);manager.window.reveal_all()
            await screenshot(String(id)+"-"+emotion)
        manager.close_dialogue();await create_timer(.2).timeout;npc.end_conversation()
        travel.request_transition(r.schedule.home,true)
        while travel.busy:await process_frame
    print("PASS: 36 real emotion variants rendered in unchanged dialogue UI")
    quit()
