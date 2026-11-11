extends "res://tools/review_interiors.gd"
## Diagnostic poses in real rooms. Physics paused deliberately; not a navigation test.
func run() -> void:
    travel=root.get_node("InteriorTravel")
    change_scene_to_file(travel.VILLAGE);await frames(12)
    var life:Node=root.get_node("VillageLife");life.clock.running=false
    root.size=Vector2i(960,540);root.content_scale_size=root.size
    var banner:=CanvasLayer.new();banner.layer=90;root.add_child(banner)
    var text:=Label.new();text.position=Vector2(8,4);text.add_theme_font_size_override("font_size",14);banner.add_child(text)
    print("NPC541_REVIEW_READY")
    for id in life.states:
        var r:HutorDailyResidentState=life.states[id]
        life.clock.seek(665 if id==&"herbalist" else 1215 if id==&"old_man" else 425)
        if travel.active_id!=r.schedule.home:
            if travel.active_id!=&"":travel.request_transition(travel.active_id,true)
            while travel.busy:await process_frame
            travel.request_transition(r.schedule.home)
            while travel.busy:await process_frame
        var room:Node2D=travel.active_world
        for other in life.states.values():other.actor.set_physics_process(false)
        room.player.set_physics_process(false);room.hud.hide()
        var npc:HutorResident=r.actor
        var saved:=npc.position
        var sprite:AnimatedSprite2D=npc.get_node("AnimatedSprite2D")
        var step:HutorNpcRoutineStep=npc.current_step();var label:=step.label
        # Two existing bodies on a common baseline; no clone and no saved scene edit.
        var base:Vector2=room.get_node("Entry").position+Vector2(-30,-36)
        npc.position=base;room.player.position=base+Vector2(54,0)
        npc.state=npc.State.RECOVERING;npc.facing=&"down";npc.velocity=Vector2.ZERO
        npc._present();room.player.sprite.play("idle_down")
        var camera:Camera2D=room.player.get_node("Camera2D")
        var camera_position:=camera.position;var smoothing:=camera.position_smoothing_enabled
        camera.set_as_top_level(true);camera.position_smoothing_enabled=false;camera.global_position=room.room_bounds.get_center();camera.force_update_scroll()
        text.text="5.4.1 DIAGNOSTIC / existing room / physics paused | "+String(id)+" + Hans; anatomy unchanged"
        await screenshot(String(id)+"-comparison")
        step.label="visual_pose_preview"
        for direction in [&"down",&"right",&"up",&"left"]:
            npc.state=npc.State.MOVING;npc.facing=direction
            npc.velocity=Vector2.RIGHT*npc.definition.speed
            npc._present()
            text.text="DIAGNOSTIC IN-PLACE CLIP / NOT travel | "+String(id)+" walk_"+String(direction)
            await create_timer(.8).timeout
        npc.state=npc.State.RECOVERING;npc.velocity=Vector2.ZERO;npc._present()
        text.text="DIAGNOSTIC idle / "+String(id)
        await create_timer(.5).timeout
        step.label=label;npc.position=saved
        camera.set_as_top_level(false);camera.position=camera_position;camera.position_smoothing_enabled=smoothing
        var summary:={"id":id,"frames":sprite.sprite_frames.resource_path,"home":r.schedule.home,"scale":str(sprite.scale),"walk_directions":4,"kind":"diagnostic in-place playback, not autonomous routes"}
        print("NPC541_REVIEW ",JSON.stringify(summary))
    print("NPC541_REVIEW_COMPLETE")
    quit()
