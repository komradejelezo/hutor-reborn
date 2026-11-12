extends "res://scripts/npc/rework/resident_presentation.gd"
## Wife-only drawn kneel/rise transitions. No movement, time or state changes.
var _kneeling := false
var _washing := false
var _rising := false
var _talk_recovered := false

func release(actor:HutorResident) -> void:
    _kneeling=false;_washing=false;_rising=false;_talk_recovered=false
    super.release(actor)

func _continue(sprite:AnimatedSprite2D, clip:StringName, previous:StringName, frame:int, progress:float) -> void:
    sprite.play(clip)
    sprite.flip_h=false # Drawn transitions face the fixed work surface on the right.
    if previous==clip:sprite.set_frame_and_progress(frame,progress)

func present(actor:HutorResident, record:HutorDailyResidentState, look:StringName, delta:float) -> bool:
    var sprite:AnimatedSprite2D=actor.get_node("AnimatedSprite2D")
    var previous:=sprite.animation;var frame:=sprite.frame;var progress:=sprite.frame_progress
    var playing:=sprite.is_playing()
    super.present(actor,record,look,delta)
    if not last_work.is_empty():sprite.flip_h=false
    if actor.state==actor.State.TALKING:
        if (_washing or _kneeling) and not _talk_recovered:
            _rising=true;_washing=false;_kneeling=false;_talk_recovered=true
        if _rising:
            if previous==&"work_stand_up" and not playing:_rising=false
            else:_continue(sprite,&"work_stand_up",previous,frame,progress)
        return true
    _talk_recovered=false;_rising=false
    if last_work!="work_laundry":
        _washing=false;_kneeling=false
        return true
    if not _washing and not _kneeling:_kneeling=true
    if _kneeling:
        if previous==&"work_kneel_down" and not playing:
            _kneeling=false;_washing=true
        else:_continue(sprite,&"work_kneel_down",previous,frame,progress)
    return true
