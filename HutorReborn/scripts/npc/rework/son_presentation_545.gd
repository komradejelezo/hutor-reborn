extends "res://scripts/npc/rework/resident_presentation.gd"
## Presentation of the son's own physical game. Never changes the other actors.
func present(actor:HutorResident, record:HutorDailyResidentState, look:StringName, delta:float) -> bool:
    var sprite:AnimatedSprite2D=actor.get_node("AnimatedSprite2D")
    if actor.state==actor.State.TALKING:
        actor.animator.apply("talk",actor.facing,&"",false)
        sprite.position=Vector2.ZERO
        return true
    var phase:String=actor.get("play_phase")
    if actor.state==actor.State.WAITING and record.mode==&"local" and not phase.is_empty():
        actor.get_node("Interaction").position=Vector2.ZERO
        if phase in ["chase","return"] and not actor.velocity.is_zero_approx():
            actor.animator.prefer_run=true
            sprite.speed_scale=clampf(actor.velocity.length()/(record.original.speed*float(record.schedule.run_multiplier)),0,2.5)
            actor.animator.apply("walk",actor.facing,&"",false)
        elif look!=&"" and phase=="rest":actor.animator.apply("turn",look,&"",false)
        else:actor.animator.apply("work",actor.facing,actor.get("play_clip"),false)
        sprite.position=Vector2.ZERO;sprite.z_index=0
        return true
    # No imaginary kneeling/ball work before reaching the real schedule point.
    if actor.state==actor.State.WAITING:
        actor.animator.apply("idle",actor.facing,&"",false)
        return true
    return super.present(actor,record,look,delta)
