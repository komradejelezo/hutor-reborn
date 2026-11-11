extends "res://tests/verify_interiors.gd"
## Targeted animation regressions; fixtures change only in-memory test actors.
func run() -> void:
    travel=root.get_node("InteriorTravel")
    change_scene_to_file(travel.VILLAGE);await frames(12)
    var life:Node=root.get_node("VillageLife")
    life.clock.running=false;life.clock.seek(600);await frames(5)
    var child:HutorResident=life.states[&"woodcutter_son"].actor
    child.set_physics_process(false)
    var record:HutorDailyResidentState=life.states[&"woodcutter_son"]
    var sprite:AnimatedSprite2D=child.get_node("AnimatedSprite2D")
    var original_speed:float=child.definition.speed
    var source_speed:float=record.original.speed
    var step:HutorNpcRoutineStep=child.current_step()
    var label:=step.label
    child.state=HutorResident.State.MOVING
    child.velocity=Vector2(77.5,0)
    record.mode=&"local";record.activity=&"play_stick" # activity still describes the previous stop while travelling.
    step.label="run_yard";child.activity_controller.present(child)
    child.animator.apply("walk",&"right",&"",false)
    check(sprite.animation==&"run_right","destination step, not stale activity, selects yard run")
    check(is_equal_approx(sprite.speed_scale,1.0) and sprite.sprite_frames.get_animation_speed(sprite.animation)==6,"normal child run is 6 FPS without 1.45 multiplier")
    sprite.set_frame_and_progress(1,.35)
    child.animator.apply("walk",&"left",&"",false)
    check(sprite.frame==1 and is_equal_approx(sprite.frame_progress,.35) and sprite.flip_h,"direction change retains gait phase and mirrors once")
    step.label="visit_mother";child.activity_controller.present(child)
    child.animator.apply("walk",&"left",&"",false)
    check(sprite.animation==&"walk_left","ordinary family visit uses walk, not forced run")
    child.velocity=Vector2(38.75,0);child.activity_controller.present(child)
    check(is_equal_approx(sprite.speed_scale,.5),"playback follows actual slower arrival velocity")
    check(is_equal_approx(child.definition.speed,original_speed) and is_equal_approx(record.original.speed,source_speed),"visual playback never changes physical or source speed")
    child.facing=&"right";var anchor:=child.position
    var velocity:=child.velocity
    child.face_point(anchor+Vector2(10,10.2),true)
    check(child.facing==&"right","small diagonal fluctuation keeps previous facing")
    child.face_point(anchor+Vector2(5,10),true)
    check(child.facing==&"down","decisive direction change still turns")
    child.face_point(anchor+Vector2(10,10.2))
    check(child.facing==&"down" and child.position==anchor and child.velocity==velocity,"explicit attention remains exact and never moves actor")
    step.label=label
    check(current_scene.get_node("Actors/Structures/CommonHouse/Art").texture.resource_path.contains("visual_fixes_5_3"),"saved village uses corrected active house texture")
    for id in [&"inn",&"elder",&"herbalist",&"woodcutter",&"old_man",&"storehouse"]:
        check(travel.request_transition(id),String(id)+" entry")
        await wait_transition()
        var room:Node2D=travel.active_world
        check(room.get_node("Walls").tile_set.has_source(532),String(id)+" directional wall tiles applied")
        check(room.player.get_node("Camera2D").zoom.is_equal_approx(Vector2.ONE*1.3),String(id)+" original camera scale retained")
        if id in [&"herbalist",&"old_man"]:
            var name:="Table" if id==&"herbalist" else "SideTable"
            check(room.get_node("Actors/Props/"+name+"/Art").texture.resource_path.ends_with("table_round.png"),String(id)+" real native table texture")
        if id in [&"herbalist",&"storehouse"]:check(room.has_node("Atmosphere/WindowFill532"),String(id)+" bounded local fill")
        check(travel.request_transition(id,true),String(id)+" exit");await wait_transition()
    print("RESULT: ",passed," visual-fix checks passed, ",failed," failed")
    quit(0 if failed==0 else 1)
