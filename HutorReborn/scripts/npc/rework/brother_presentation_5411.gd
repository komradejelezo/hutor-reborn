extends "res://scripts/npc/rework/resident_presentation.gd"
## Brother-only visual chores. The existing manager owns all paths, times,
## offsite logging and indoor crossings. No delivery/inventory or extra NPC state.
var _bound_sprite:AnimatedSprite2D
var _frame_cb:Callable
var _whole:Texture2D
var _split:Texture2D
var _log:Sprite2D
var _world:Node2D
var _block:Node2D
var _axe:Sprite2D
var _active:=false
var _clip:StringName=&""
var _pause:=.5
var _pass:=0
var _talking:=false
var _settling:=false
func _restore() -> void:
    if is_instance_valid(_axe):_axe.show()
func release(actor:HutorResident) -> void:
    if is_instance_valid(_bound_sprite) and _bound_sprite.frame_changed.is_connected(_frame_cb):_bound_sprite.frame_changed.disconnect(_frame_cb)
    _bound_sprite=null
    _restore();_world=null;_block=null;_axe=null;_log=null
    _active=false;_talking=false;_settling=false;_pause=.5
    super.release(actor)
func _bind(world:Node2D) -> void:
    if _world==world:return
    _restore();_world=world
    _block=world.get_node_or_null("Actors/Props/BrotherWorkBlock5411")
    _axe=_block.get_node_or_null("Axe") if is_instance_valid(_block) else null
    _log=_block.get_node_or_null("Log") if is_instance_valid(_block) else null
    if is_instance_valid(_log):
        _whole=load("res://assets/npc/herbalist_brother5411/game/billet.png")
        _split=load("res://assets/npc/herbalist_brother5411/game/split_billet.png")
func _draw(actor:HutorResident,clip:StringName,restart:bool=false) -> void:
    var s:AnimatedSprite2D=actor.get_node("AnimatedSprite2D");s.flip_h=false
    if s.animation!=clip or restart:s.play(clip);s.set_frame_and_progress(0,0)
func _tool(sprite:AnimatedSprite2D) -> void:
    if is_instance_valid(_axe):_axe.visible=not (_active and _clip in [&"chop_wood",&"split_logs"] and sprite.frame>=1)
    if is_instance_valid(_log) and _active and _clip in [&"chop_wood",&"split_logs"]:_log.texture=_split if sprite.frame>=5 else _whole
func _frame_changed(actor:HutorResident) -> void:
    if is_instance_valid(actor):_tool(actor.get_node("AnimatedSprite2D"))
func _duration(actor:HutorResident,clip:StringName) -> float:
    var s:AnimatedSprite2D=actor.get_node("AnimatedSprite2D")
    return s.sprite_frames.get_frame_count(clip)/maxf(.1,s.sprite_frames.get_animation_speed(clip)*s.speed_scale)
func _budget(actor:HutorResident,record:HutorDailyResidentState) -> float:
    var result:=actor.wait_left/maxf(.1,actor.wait_time_scale)
    var manager:Node=actor.activity_controller.manager
    if manager.clock.running:
        var minute:float=manager.clock.minute_of_day();var next:=1440.0
        for block in record.schedule.blocks:
            if float(block.start)>minute:next=minf(next,float(block.start))
        result=minf(result,(next-minute)/manager._minutes_per_second()/manager.clock.speed)
    return result
func present(actor:HutorResident,record:HutorDailyResidentState,look:StringName,delta:float) -> bool:
    var s:AnimatedSprite2D=actor.get_node("AnimatedSprite2D")
    if _bound_sprite!=s:
        _bound_sprite=s;_frame_cb=Callable(self,"_frame_changed").bind(actor);s.frame_changed.connect(_frame_cb)
    s.position=Vector2.ZERO;s.z_index=0
    var step:=actor.current_step()
    if not step:return false
    _bind(actor.director.get_parent().get_parent())
    var key:=String(record.scene)+"/"+str(record.block_stamp)+"/"+str(actor.step_index)
    if key!=action_key:
        action_key=key;_restore();_active=false;_talking=false;_settling=false;_pause=.5
    actor.get_node("Interaction").position=step.talk_offset if actor.state in [actor.State.WAITING,actor.State.TALKING] else Vector2.ZERO
    if actor.state==actor.State.TALKING:
        if not _talking:
            _talking=true;_settling=_active and s.is_playing()
        # Complete the committed stroke/put-back at the same grounded pivot.
        # The normal dialogue already locked both actors; never delay its session.
        if _settling and s.is_playing():_tool(s);return true
        _settling=false;_active=false;_restore();actor.animator.apply("talk",actor.facing,&"",false);return true
    if _talking:_talking=false;_settling=false;_active=false;_pause=.7
    if actor.state==actor.State.MOVING and not actor.velocity.is_zero_approx():
        _restore();_active=false;last_work="";actor.animator.apply("walk",actor.facing,&"",false);return true
    var requested:StringName=&""
    if actor.state==actor.State.WAITING and record.mode==&"local" and actor.position.distance_to(step.position)<12 and record.scene==&"herbalist":
        if step.label=="household" and is_instance_valid(_block) and is_instance_valid(_axe) and actor.position.distance_to(_block.position-Vector2(18,0))<3:
            requested=&"chop_wood" if _pass%2==0 else &"split_logs"
        elif step.label=="prepare_work":requested=&"think"
        elif step.label=="home_rest":requested=&"tired_idle"
    if requested==&"":
        _restore();_active=false;last_work="";actor.animator.apply("turn" if look!=&"" else "idle",look if look!=&"" else actor.facing,&"",false);return true
    if _active and not s.is_playing():_active=false;_pause=1.4;_restore()
    if not _active:
        _pause-=delta*minf(2.5,sqrt(actor.activity_controller.manager.clock.speed))
        if _pause>0 or _budget(actor,record)<_duration(actor,requested)+.3:
            last_work="";_restore();actor.animator.apply("idle",&"right" if requested!=&"think" else &"down",&"",false);return true
        _clip=requested;_active=true;_pass+=1;work_starts+=1;_draw(actor,_clip,true)
    _draw(actor,_clip);last_work=String(_clip);_tool(s)
    return true
