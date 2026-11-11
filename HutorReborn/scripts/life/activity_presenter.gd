extends Node
## Context playback only. No transform scaling, cloning or world geometry edits.
var manager: Node
var resident: HutorDailyResidentState
var _hidden: Array[CanvasItem] = []
var _presentation_key := ""
var reactions: HutorNpcVisualReactions
func _ready() -> void:
    reactions=HutorNpcVisualReactions.new(HutorNpcVisualLibrary.profile(resident.id))
func clear_props() -> void:
    for item in _hidden:
        if is_instance_valid(item):item.show()
    _hidden.clear();_presentation_key=""
    if reactions:reactions.reset_attention()
func present(actor: HutorResident) -> bool:
    var sprite: AnimatedSprite2D=actor.get_node("AnimatedSprite2D")
    var reference_speed:float=resident.original.speed
    if resident.id==&"woodcutter_son":reference_speed*=resident.schedule.get("run_multiplier",1.0)
    sprite.speed_scale = clampf(actor.velocity.length()/reference_speed,.35,2.5) if actor.state==actor.State.MOVING else minf(2.5,sqrt(manager.clock.speed))
    var destination_step:HutorNpcRoutineStep=actor.current_step()
    actor.animator.prefer_run = resident.id==&"woodcutter_son" and resident.mode==&"local" and destination_step!=null and destination_step.label.begins_with("run_")
    sprite.position=Vector2.ZERO
    var delta:float=actor.get_physics_process_delta_time() if Engine.is_in_physics_frame() else 0.0
    var look:StringName=reactions.update(actor,delta,resident.mode==&"local")
    var ambient:Node=get_node_or_null("/root/AmbientDirector")
    if look==&"" and is_instance_valid(ambient):
        look=ambient.glance_direction(actor,resident)
    var working:bool=actor.state==actor.State.WAITING and resident.mode==&"local" and look==&""
    var key:String=String(resident.activity) if working else ""
    if key!=_presentation_key:
        for item in _hidden:
            if is_instance_valid(item):item.show()
        _hidden.clear();_presentation_key=key
        if working:
            var spec:Dictionary=resident.block.activities[actor.step_index%resident.block.activities.size()]
            for path in spec.get("hide_props",[]):
                var item:CanvasItem=manager.world_for(resident.scene).get_node_or_null(path+"/Art")
                if item and item.visible:_hidden.append(item);item.hide()
    if look!=&"":
        var current:HutorNpcRoutineStep=actor.current_step()
        actor.get_node("Interaction").position=current.talk_offset if current else Vector2.ZERO
        actor.animator.apply("turn",look,&"",false)
        return true
    if not working:return false
    var step:HutorNpcRoutineStep=actor.current_step()
    if step==null:return false
    actor.get_node("Interaction").position=step.talk_offset
    if step.animation==&"work_sit":
        actor.animator.apply("work",actor.facing,&"work_sit",false)
        var smoke:CPUParticles2D=actor.get_node("PipeSmoke")
        var allowed:bool=actor.director.atmosphere.effects_enabled
        smoke.visible=allowed;smoke.emitting=allowed
        smoke.position=Vector2(-10 if sprite.flip_h else 10,-24)
        return true
    if step.animation==&"gesture_read" or step.animation==&"gesture_think":
        # No reading art exists. Hold the authored pose; real attention above
        # still works, without a timer repeatedly swivelling the entire body.
        actor.animator.apply("idle",step.facing,&"",false)
        return true
    return false
