extends "res://scripts/npc/npc.gd"
## Only the original son's body uses this subclass. Existing navigation,
## conversations, doors and absolute schedule blocks remain owned by their systems.
const MOTION=preload("res://scripts/npc/rework/son_motion_545.gd")
var motion_speed:=0.0
var play_phase:=""
var play_clip:StringName=&""
var play_serial:=0
var play_counts:Dictionary={}
var _play_key:=""
var _phase_time:=0.0
var _pause_duration:=2.0
var _origin:=Vector2.ZERO
var _play_path:=PackedVector2Array()
var _play_index:=0
var _game_path_pending:=false
var _stalled:=0.0
var _ball:Sprite2D
var _ball_from:=Vector2.ZERO
var _ball_to:=Vector2.ZERO
var _kick_sign:=1.0
var _released:=false
var _talk_facing:StringName=&"down"
var _play_choice:=0

func begin_conversation() -> void:
    if state!=State.TALKING:_talk_facing=facing
    super.begin_conversation()

func end_conversation() -> void:
    var talking:=state==State.TALKING
    super.end_conversation()
    if talking:facing=_talk_facing;_present()

func _next_step() -> void:
    if play_phase in ["kneel","inspect","pickup"]:
        _phase("finish",&"work_stand_up");wait_left=.5/minf(2.5,sqrt(_clock_speed()))*wait_time_scale
        return
    super._next_step()

func _record() -> HutorDailyResidentState:
    return activity_controller.resident if is_instance_valid(activity_controller) else null

func _clock_speed() -> float:
    return activity_controller.manager.clock.speed if is_instance_valid(activity_controller) else 1.0

func _request_path() -> void:
    _clear_game()
    super._request_path()

func _path_received(token:int,path:PackedVector2Array) -> void:
    if token!=_token:return
    if _game_path_pending:
        _game_path_pending=false;_play_path=path;_play_index=1 if path.size()>1 else 0
        if path.is_empty():_phase("rest",&"work_rest")
        return
    super._path_received(token,path)

func _physics_process(delta:float) -> void:
    var record:=_record()
    if record:
        if definition==record.original:definition=record.original.duplicate()
        var step:=current_step()
        var nominal:=MOTION.speed(record,step.label if step else "")
        var target:=nominal*_clock_speed()
        if state==State.MOVING and step:
            target=minf(target,sqrt(2*170*_clock_speed()*_clock_speed()*position.distance_to(step.position)))
            motion_speed=move_toward(motion_speed,target,220*_clock_speed()*_clock_speed()*delta)
        elif play_phase not in ["chase","return"]:motion_speed=0
        definition.speed=maxf(.1,motion_speed) if state==State.MOVING else target
    super._physics_process(delta)
    if not record or not _ready_to_walk:return
    if state==State.TALKING or motion_paused:return # Ball and action cursor pause too.
    var step:=current_step()
    var eligible:=state==State.WAITING and record.mode==&"local" and step and step.label in ["home_play","play_stick","return_yard","kneel_toy","inspect_well"]
    if not eligible:
        if not _play_key.is_empty():_clear_game()
        return
    var key:=String(record.scene)+"/"+str(record.block_stamp)+"/"+str(step_index)
    if key!=_play_key:
        _clear_game();_play_key=key;_origin=position
        _pause_duration=_rng.randf_range(1.4,2.8)
        if step.label in ["kneel_toy","inspect_well","home_play"]:
            facing=&"left" if step.facing==&"left" else &"right"
            _phase("kneel",&"work_kneel_down")
        else:_phase("rest",&"work_rest")
    _update_game(delta,record)
    _present()

func _phase(value:String,clip:StringName=&"") -> void:
    play_phase=value;play_clip=clip;_phase_time=0;_stalled=0;play_serial+=1
    play_counts[value]=int(play_counts.get(value,0))+1
    animator.set_work_context("son545/"+str(play_serial))

func _clear_game() -> void:
    if _game_path_pending:_token+=1
    _game_path_pending=false;_play_key="";play_phase="";play_clip=&"";_play_path.clear()
    motion_speed=0;_released=false
    if is_instance_valid(_ball):_ball.queue_free()
    _ball=null

func suspend_location() -> Dictionary:
    # The same resident survives scene changes; transient floor toys are released.
    # Off-screen residency uses the existing schedule, never a second child.
    _clear_game()
    return super.suspend_location()

func _make_ball() -> void:
    if is_instance_valid(_ball):return
    _ball=Sprite2D.new();_ball.name="SonPlayBall545"
    _ball.texture=load("res://assets/npc/stage54/game/props/toy_ball.png")
    _ball.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
    _ball.scale=Vector2.ONE*5.0/maxf(_ball.texture.get_width(),_ball.texture.get_height())
    director.get_parent().add_child(_ball) # Actors: same Y-sort as ground feet.

func _kick_space() -> bool:
    var signs:Array=[1.0,-1.0] if _rng.randf()<.5 else [-1.0,1.0]
    for sign_value:float in signs:
        var displacement:=Vector2(sign_value*_rng.randf_range(30,43),0)
        var goal:=position+displacement
        if not definition.route_bounds.has_point(goal):continue
        # A full-body swept test protects walls, fences, Hans and other residents.
        if test_move(global_transform,displacement):continue
        _kick_sign=sign_value;facing=&"right" if sign_value>0 else &"left"
        _make_ball();_ball_from=position+Vector2(sign_value*8,-2)
        _ball_to=goal+Vector2(sign_value*6,-2);_ball.position=_ball_from;_ball.show()
        _released=false;_phase("kick",&"work_ball")
        return true
    return false

func _game_path(goal:Vector2,phase:String) -> void:
    _phase(phase);_token+=1;_game_path_pending=true;_play_path.clear()
    director.navigation.request(self,_token,global_position,goal,definition.route_bounds,Vector2i(-1,-1),true)

func _move_play(delta:float,record:HutorDailyResidentState) -> bool:
    if _game_path_pending:return false
    while _play_index<_play_path.size() and position.distance_to(_play_path[_play_index])<1.5:_play_index+=1
    if _play_index>=_play_path.size():velocity=Vector2.ZERO;motion_speed=0;return true
    var axis:=_play_path[_play_index]-position
    var remaining:=position.distance_to(_play_path[-1])
    var top:=record.original.speed*float(record.schedule.get("run_multiplier",1.25))*_clock_speed()
    var target:=minf(top,sqrt(2*170*_clock_speed()*_clock_speed()*remaining))
    var blocked:=false
    var neighbors:Array=director.residents.values()
    if is_instance_valid(director.player):neighbors.append(director.player)
    for other in neighbors:
        if other==self or not is_instance_valid(other):continue
        var offset:Vector2=other.global_position-global_position
        if offset.length()<18 and offset.dot(axis)>0:blocked=true;break
    motion_speed=move_toward(motion_speed,0 if blocked else target,220*_clock_speed()*_clock_speed()*delta)
    velocity=axis.normalized()*minf(motion_speed,axis.length()/maxf(delta,.001))
    if not velocity.is_zero_approx():face_point(position+velocity,true)
    var before:=position;move_and_slide();var traveled:=before.distance_to(position);distance_walked+=traveled
    _stalled=_stalled+delta if traveled<.05 else 0.0
    if _stalled>1.6 or _phase_time>6:
        velocity=Vector2.ZERO
        if is_instance_valid(_ball):_ball.hide()
        _phase("rest",&"work_rest")
    return false

func _update_game(delta:float,record:HutorDailyResidentState) -> void:
    var rate:=minf(2.5,sqrt(_clock_speed()))
    _phase_time+=delta*rate
    match play_phase:
        "rest":
            if _phase_time<_pause_duration or wait_left<1.3:return
            # Alternate short games; random pauses and kick directions vary them.
            # A run of unlucky random draws must not hide ball play indefinitely.
            var choice:=_play_choice
            if record.scene!=&"village":choice=1
            else:_play_choice=(_play_choice+1)%3
            if choice==0 and _kick_space():return
            facing=&"right" if _rng.randf()<.5 else &"left"
            _phase("kneel",&"work_kneel_down") if choice==1 else _phase("jump",&"work_jump")
        "kick":
            if _phase_time>=2.0/6.0:_released=true
            if _released and is_instance_valid(_ball):
                _ball.position=_ball_from.lerp(_ball_to,clampf((_phase_time-2.0/6.0)/.8,0,1))
            if _phase_time>=1.14:_game_path(_ball_to+Vector2(-_kick_sign*7,2),"chase")
        "chase":
            if _move_play(delta,record):
                facing=&"right" if _kick_sign>0 else &"left";_phase("pickup",&"work_kneel_down")
        "pickup":
            if _phase_time>=.22 and is_instance_valid(_ball):_ball.hide()
            if _phase_time>=2.0/6.0:_phase("rise_return",&"work_stand_up")
        "rise_return":
            if _phase_time>=.5:_game_path(_origin,"return")
        "return":
            if _move_play(delta,record):facing=&"right" if _kick_sign>0 else &"left";_phase("joy",&"work_joy")
        "kneel":
            if _phase_time>=2.0/6.0:_phase("inspect",&"work_kneel")
        "inspect":
            if _phase_time>=_pause_duration:_phase("rise",&"work_stand_up")
        "rise":
            if _phase_time>=.5:_pause_duration=_rng.randf_range(1.8,3.8);_phase("rest",&"work_rest")
        "jump":
            if _phase_time>=5.0/6.0:_phase("joy",&"work_joy")
        "joy":
            if _phase_time>=.5:_pause_duration=_rng.randf_range(2,4);_phase("rest",&"work_rest")
