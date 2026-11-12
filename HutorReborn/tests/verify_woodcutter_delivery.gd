extends "res://tests/verify_interiors.gd"
## Pilot rendering only, using the existing real actor/interior/dialogue.
func run() -> void:
    travel=root.get_node("InteriorTravel")
    change_scene_to_file(travel.VILLAGE);await frames(12)
    var life:Node=root.get_node("VillageLife");life.clock.running=false;life.clock.seek(425)
    check(travel.request_transition(&"woodcutter"),"existing family house loads");await wait_transition()
    life.set_physics_process(false)
    for r in life.states.values():r.actor.set_physics_process(false)
    var record:HutorDailyResidentState=life.states[&"woodcutter"]
    var actor:HutorResident=record.actor
    var sprite:AnimatedSprite2D=actor.get_node("AnimatedSprite2D")
    var view:RefCounted=actor.activity_controller.pilot_delivery
    # Controlled renderer input; never alters schedule or route definitions.
    record.block=record.schedule.blocks[4]
    life.clock.absolute_minutes=1085
    record.event_counts["return_from_work"]=1;record.scene=&"village";record.mode=&"boundary_in"
    view.update(record)
    for direction in [&"down",&"up",&"left",&"right"]:
        actor.animator.apply("walk",direction,&"",false)
        check(sprite.animation==StringName("carry_"+String(direction)),"return route uses direction: "+String(direction))
        check(sprite.flip_h==(direction==&"left"),"carry reflected only once: "+String(direction))
        actor.animator.apply("talk",direction,&"",false)
        check(sprite.animation==StringName("carry_idle_"+String(direction)),"talk holds load on planted feet: "+String(direction))
    actor.animator.pilot_carrying=false
    actor.animator.apply("walk",&"right",&"",false);sprite.set_frame_and_progress(3,.4)
    actor.animator.apply("walk",&"left",&"",false)
    check(sprite.frame==3 and absf(sprite.frame_progress-.4)<.01,"direction change preserves six-frame gait phase")
    # A non-loop rest settles once. No artificial endless gesture restart.
    actor.animator.apply("work",&"down",&"work_rest",false)
    sprite.set_frame_and_progress(2,1);sprite.pause()
    actor.animator.apply("work",&"down",&"work_rest",false)
    check(not sprite.is_playing() and sprite.frame==2,"rest remains settled")
    record.scene=&"woodcutter";record.mode=&"local";record.activity=&"rest_after_work"
    actor.state=actor.State.WAIT_PATH;view.update(record)
    check(actor.animator.pilot_carrying and view.delivered==0,"waiting for indoor navigation does not count as completed delivery")
    actor.state=actor.State.MOVING;view.update(record)
    var step:HutorNpcRoutineStep=actor.current_step();step.label="rest_after_work";step.position=actor.position
    actor.state=actor.State.WAITING
    check(view.present(actor,record) and sprite.animation==&"work_put_down","arrival starts authored placement, not empty-hand pop")
    sprite.set_frame_and_progress(1,0)
    actor.animator.apply("talk",&"down",&"",false)
    check(sprite.animation==&"work_put_down","conversation does not abandon lifted load mid-release")
    while sprite.is_playing():await physics_frame
    check(not view.present(actor,record) and view.delivered==1,"completed release returns presentation ownership")
    check(travel.active_world.has_node("Actors/Props/DeliveredLogs542"),"same released bundle stays at feet")
    view.update(record);check(not actor.animator.pilot_carrying,"completed delivery does not restart each rest cycle")
    view.release(actor);view.update(record)
    check(view.delivered==1 and not actor.animator.pilot_carrying,"scene parking retains completed return token")
    record.event_counts["return_from_work"]=2;record.scene=&"village";view.update(record)
    check(actor.animator.pilot_carrying,"following evening is a new visible return")
    view.release(actor);record.scene=&"woodcutter";actor.state=actor.State.WAITING;view.update(record)
    check(view.delivered==2 and not actor.animator.pilot_carrying,"offscreen completed home arrival is not replayed")
    record.event_counts["return_from_work"]=3;record.block=record.schedule.blocks[2];record.scene=&"village";actor.state=actor.State.MOVING;life.clock.absolute_minutes=455
    view.update(record)
    check(not actor.animator.pilot_carrying and view.delivered==3,"next morning cannot replay an unseen evening delivery")
    print("RESULT: ",passed," delivery/animation checks passed, ",failed," failed")
    quit(0 if failed==0 else 1)
