extends "res://tests/verify_interiors.gd"
## Talking may change logical facing; a fixed work surface must not mirror away.
func run() -> void:
    travel=root.get_node("InteriorTravel");change_scene_to_file(travel.VILLAGE);await frames(12)
    var life:Node=root.get_node("VillageLife");life.clock.running=false;life.clock.seek(425)
    check(travel.request_transition(&"woodcutter"),"existing home loads");await wait_transition()
    var actor:HutorResident=life.states[&"woodcutter_wife"].actor
    var sprite:AnimatedSprite2D=actor.get_node("AnimatedSprite2D")
    actor.set_physics_process(false);actor.position=actor.current_step().position;actor.state=actor.State.WAITING
    for direction in [&"left",&"right",&"up",&"down"]:
        actor.facing=direction;actor._present()
        check(sprite.animation==&"work_cook" and not sprite.flip_h,"cooking remains at right-hand pot after logical facing: "+String(direction))
        check(actor.facing==direction,"renderer does not rewrite logical facing")
    life.clock.seek(1100);await frames(6)
    actor.set_physics_process(false);actor.position=actor.current_step().position;actor.state=actor.State.WAITING
    actor.facing=&"left";actor._present()
    check(not sprite.flip_h,"kneel entry stays oriented toward original basin")
    var hero:CharacterBody2D=travel.active_world.player
    hero.position=actor.position+Vector2(-23,0);await frames(5)
    check(hero.sensor.target==actor.get_node("Interaction"),"real E can approach wife from left")
    await tap_e();await create_timer(.1).timeout
    var dm:Node=root.get_node("DialogueManager")
    check(dm.is_active() and actor.state==actor.State.TALKING,"logical dialogue opens during drawn rise")
    actor._present();check(not sprite.flip_h and sprite.animation==&"work_stand_up","rise stays toward work before turning to Hans")
    for i in 45:actor._present();await physics_frame
    check(sprite.animation==&"talk_left" and sprite.flip_h,"completed rise turns talk toward Hans on left")
    dm.close_dialogue();await create_timer(.3).timeout
    hero.position=actor.position+Vector2(-100,0);actor.activity_controller.reactions.reset_attention();actor._present()
    check(actor.state!=actor.State.TALKING and not sprite.flip_h,"resumed washing returns to basin on right")
    print("RESULT: ",passed," wife work-orientation checks passed, ",failed," failed")
    quit(0 if failed==0 else 1)
