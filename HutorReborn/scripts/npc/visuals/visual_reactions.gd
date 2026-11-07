class_name HutorNpcVisualReactions
extends RefCounted
## A bounded visual glance: never changes NPC state, position, route or wait_left.
var profile: Dictionary
var glancing := false
var looks_started := 0
var _cooldown := 0.0
var _dwell := 0.0
var _elapsed := 0.0
var _seen_visit := false
var _target: StringName = &"down"
var _origin: StringName = &"down"
const DIRECTIONS: Array[StringName] = [&"down",&"left",&"up",&"right"]
func _init(data: Dictionary = {}) -> void:profile=data
func _facing(axis: Vector2) -> StringName:
    return (&"right" if axis.x>0 else &"left") if absf(axis.x)>absf(axis.y) else (&"down" if axis.y>0 else &"up")
func _between(first: StringName, last: StringName) -> StringName:
    var start:=DIRECTIONS.find(first);var finish:=DIRECTIONS.find(last)
    return DIRECTIONS[(start+1)%4] if absi(start-finish)==2 else last
func reset_attention() -> void:
    glancing=false;_dwell=0;_elapsed=0
func update(actor: HutorResident, delta: float, allowed: bool = true) -> StringName:
    _cooldown=maxf(0,_cooldown-delta)
    if actor.state==HutorResident.State.TALKING:
        reset_attention();_cooldown=float(profile.get("cooldown",18));_seen_visit=true
        return &""
    if not allowed or actor.motion_paused or actor.state!=HutorResident.State.WAITING or not is_instance_valid(actor.director.player):
        reset_attention();return &""
    var step:=actor.current_step()
    # The archived seated sprite has no head-turn frames. Keep it seated.
    if step and step.animation==&"work_sit":reset_attention();return &""
    var hero:CharacterBody2D=actor.director.player
    var anchor:Vector2=actor.global_position+(step.talk_offset if step else Vector2.ZERO)
    var distance:float=anchor.distance_to(hero.global_position)
    var radius:float=profile.get("radius",64)
    if distance>radius+16:
        _seen_visit=false;reset_attention();return &""
    if glancing:
        _elapsed+=delta
        _target=_facing(hero.global_position-actor.global_position)
        var duration:float=profile.get("duration",.75)
        if _elapsed>=duration:reset_attention();return &""
        var turn:float=profile.get("turn_seconds",.12)
        if _elapsed<turn:return _between(_origin,_target)
        if _elapsed>duration-turn:
            # Return through the same quarter-turn, not a full circular spin.
            return _between(_origin,_target) if absi(DIRECTIONS.find(_origin)-DIRECTIONS.find(_target))==2 else _origin
        return _target
    if distance>radius or _cooldown>0 or _seen_visit:return &""
    _dwell+=delta
    if _dwell<float(profile.get("delay",.35)):return &""
    glancing=true;looks_started+=1;_seen_visit=true;_elapsed=0;_dwell=0
    _origin=actor.facing;_target=_facing(hero.global_position-actor.global_position)
    _cooldown=float(profile.get("cooldown",18))
    return _between(_origin,_target)
