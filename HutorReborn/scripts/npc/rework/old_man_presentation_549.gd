extends "res://scripts/npc/rework/resident_presentation.gd"
## Old-man-only poses. No body movement, schedule editing or second smoke system.
var _bound_sprite:AnimatedSprite2D
var _frame_cb:Callable
var _seated:=false
var _phase:StringName=&""
var _active:=false
var _clip:StringName=&""
var _pause:=.5
var _pass:=0
var _talking:=false
var _settling:=false
var _seat:Node2D
var _stood:=false
var exhalations:=0
var _exhaling:=false

func release(actor:HutorResident) -> void:
    if is_instance_valid(_bound_sprite) and _bound_sprite.frame_changed.is_connected(_frame_cb):_bound_sprite.frame_changed.disconnect(_frame_cb)
    _bound_sprite=null
    _seated=false;_phase=&"";_active=false;_talking=false;_settling=false;_seat=null;_stood=false
    _exhaling=false
    super.release(actor)

func _frame_changed(actor:HutorResident) -> void:
    if not is_instance_valid(actor):return
    _smoke(actor,actor.state==actor.State.WAITING and _phase==&"" and _active and actor.get_node("AnimatedSprite2D").animation==_clip)

func _draw(actor:HutorResident,clip:StringName,restart:bool=false) -> void:
    var sprite:AnimatedSprite2D=actor.get_node("AnimatedSprite2D")
    # Action drawings are authored right/front. All left locomotion/talk uses
    # independent left resources via the normal animator's native-left metadata.
    sprite.flip_h=false
    if sprite.animation!=clip or restart:sprite.play(clip);sprite.set_frame_and_progress(0,0)

func _smoke(actor:HutorResident,enabled:bool) -> void:
    var sprite:AnimatedSprite2D=actor.get_node("AnimatedSprite2D")
    var particle:CPUParticles2D=actor.get_node("PipeSmoke")
    var allowed:bool=actor.director.atmosphere.effects_enabled
    var puff:=enabled and allowed and sprite.animation in [&"smoke_pipe",&"sit_smoke"] and sprite.frame in [4,5]
    if puff and not _exhaling:exhalations+=1
    _exhaling=puff;particle.emitting=puff;particle.visible=allowed
    particle.position=Vector2(10,-24 if sprite.animation==&"sit_smoke" else -34)

func _duration(actor:HutorResident,clip:StringName) -> float:
    var s:AnimatedSprite2D=actor.get_node("AnimatedSprite2D")
    return s.sprite_frames.get_frame_count(clip)/maxf(.1,s.sprite_frames.get_animation_speed(clip)*s.speed_scale)

func _budget(actor:HutorResident,record:HutorDailyResidentState) -> float:
    var remaining:=actor.wait_left/maxf(.1,actor.wait_time_scale)
    var manager:Node=actor.activity_controller.manager
    if manager.clock.running:
        var minute:float=manager.clock.minute_of_day();var next:=1440.0
        for block in record.schedule.blocks:
            if float(block.start)>minute:next=minf(next,float(block.start))
        remaining=minf(remaining,(next-minute)/manager._minutes_per_second()/manager.clock.speed)
    return remaining

func _rise(actor:HutorResident) -> void:
    var s:AnimatedSprite2D=actor.get_node("AnimatedSprite2D")
    var from:=s.sprite_frames.get_frame_count("sit_down")-1-s.frame if s.animation==&"sit_down" else 0
    _smoke(actor,false)
    _phase=&"stand_up";_active=false
    _draw(actor,_phase,true);s.set_frame_and_progress(maxi(0,from),0)

func _transition(actor:HutorResident) -> bool:
    if _phase==&"":return false
    var s:AnimatedSprite2D=actor.get_node("AnimatedSprite2D")
    _draw(actor,_phase)
    if s.is_playing():return true
    _seated=_phase==&"sit_down"
    if _phase==&"stand_up":_stood=true
    _phase=&"";_pause=.5
    return false

func present(actor:HutorResident,record:HutorDailyResidentState,look:StringName,delta:float) -> bool:
    var s:AnimatedSprite2D=actor.get_node("AnimatedSprite2D")
    if _bound_sprite!=s:
        _bound_sprite=s;_frame_cb=Callable(self,"_frame_changed").bind(actor)
        s.frame_changed.connect(_frame_cb)
    s.position=Vector2.ZERO;s.z_index=0
    var step:=actor.current_step()
    if actor.state!=actor.State.WAITING or _phase!=&"" or _talking:_smoke(actor,false)
    if not step:
        _smoke(actor,false);return false
    var key:=String(record.scene)+"/"+str(record.block_stamp)+"/"+str(actor.step_index)
    if key!=action_key:
        action_key=key;_seated=false;_phase=&"";_active=false;_pause=.5;_talking=false;_settling=false;_stood=false;_seat=null
    actor.get_node("Interaction").position=step.talk_offset if actor.state in [actor.State.WAITING,actor.State.TALKING] else Vector2.ZERO
    if actor.state==actor.State.TALKING:
        if not _talking:
            _talking=true
            if _seated or _phase==&"sit_down":_rise(actor)
            elif _active and s.is_playing() and s.frame<s.sprite_frames.get_frame_count(s.animation)-1:
                _settling=true;s.set_frame_and_progress(maxi(s.frame,s.sprite_frames.get_frame_count(s.animation)-2),0)
        if _transition(actor):return true
        if _settling and s.is_playing():return true
        _settling=false;_active=false
        actor.animator.apply("talk",actor.facing,&"",false);_smoke(actor,false);return true
    if _talking:_talking=false;_settling=false;_active=false;_pause=.7;_stood=false
    if actor.state==actor.State.MOVING and not actor.velocity.is_zero_approx():
        _seated=false;_phase=&"";_active=false;last_work=""
        actor.animator.apply("walk",actor.facing,&"",false);_smoke(actor,false);return true
    if actor.state!=actor.State.WAITING or record.mode!=&"local" or actor.position.distance_to(step.position)>12:
        _active=false;last_work="";actor.animator.apply("idle",actor.facing,&"",false);_smoke(actor,false);return true
    var is_seat:=record.scene==&"village" and step.label=="sit_and_smoke"
    var budget:=_budget(actor,record)
    var rise_time:=_duration(actor,&"stand_up")
    if _seated and _phase==&"" and budget<rise_time+.35:_rise(actor)
    if _transition(actor):return true
    if is_seat and not _seated and not _stood and budget>rise_time+_duration(actor,&"sit_down")+2:
        # Reuse the already-established generic seat at the same activity point.
        _seat=_prop(actor.director.get_parent().get_parent(),"seat",step.position)
        if is_instance_valid(_seat) and not _seat.has_meta("old_man_seat549"):
            # Keep the existing activity coordinate. The generated bench sits
            # behind the hips, not across the chest or above the entire actor.
            _seat.position=step.position+Vector2(0,-4)
            _seat.get_node("Art").position.y+=11
            _seat.set_meta("old_man_seat549",true)
        if is_instance_valid(_seat) and actor.position.distance_to(_seat.position)<12:
            _phase=&"sit_down";_active=false;_smoke(actor,false);_draw(actor,_phase,true);return true
    var requested:StringName=&"think" if step.label=="ponder" else &"smoke_pipe" if step.label in ["slow_walk","watch_hans","rest_by_hearth"] else &"sit_smoke" if is_seat and _seated else &"lean_on_staff"
    if _active and not s.is_playing():_active=false;_pause=2.5+float(_pass%3)*.6
    if not _active:
        var rate:=minf(2.5,sqrt(actor.activity_controller.manager.clock.speed));_pause-=delta*rate
        if _pause>0 or (is_seat and _stood):
            last_work=""
            if _seated:_draw(actor,&"sit_idle")
            else:actor.animator.apply("turn" if look!=&"" else "idle",look if look!=&"" else actor.facing,&"",false)
            _smoke(actor,false);return true
        _active=true;_pass+=1;_clip=requested;work_starts+=1;_draw(actor,_clip,true)
    _draw(actor,_clip);last_work=String(_clip)
    _smoke(actor,_phase==&"" and actor.state==actor.State.WAITING)
    return true
