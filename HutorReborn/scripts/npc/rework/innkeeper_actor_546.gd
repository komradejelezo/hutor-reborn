extends "res://scripts/npc/npc.gd"
## Innkeeper-only last approach to the rear of the counter. Keep the shared,
## conservative navigation bake and all other residents' paths unchanged.
var _approach_wait:=-1.0

func _physics_process(delta:float) -> void:
    if state==State.WAITING and not motion_paused and is_instance_valid(activity_controller):
        var record:HutorDailyResidentState=activity_controller.resident
        var step:=current_step()
        if record.scene==&"inn" and record.mode==&"local" and step and step.label in ["prepare_inn","wipe_mug","arrange_dishes","pause_counter"]:
            var counter:Node2D=director.get_node("../Props/Counter")
            # A restored waiting snapshot is snapped to the conservative grid.
            # Reach the working edge again physically and keep the remaining wait.
            if absf(position.y-(counter.position.y-20))>2.1:
                _approach_wait=wait_left;_request_path()
    super._physics_process(delta)

func _arrive() -> void:
    super._arrive()
    if _approach_wait>=0:
        wait_left=minf(wait_left,_approach_wait);_approach_wait=-1
        if is_instance_valid(activity_controller):
            var manager:Node=activity_controller.manager
            activity_controller.resident.until=manager.clock.absolute_minutes+wait_left*manager._minutes_per_second()

func enter_location(data:HutorNpcDefinition,population:Node2D,spawn:Vector2) -> void:
    _approach_wait=-1
    super.enter_location(data,population,spawn)

func _path_received(token:int,path:PackedVector2Array) -> void:
    if token!=_token:return
    if is_instance_valid(activity_controller):
        var record:HutorDailyResidentState=activity_controller.resident
        var step:=current_step()
        if record.scene==&"inn" and record.mode==&"local" and step and step.label in ["prepare_inn","wipe_mug","arrange_dishes","pause_counter"] and not path.is_empty():
            var counter:Node2D=director.get_node("../Props/Counter")
            var goal:=Vector2(step.position.x,counter.position.y-20)
            var motion:=goal-path[-1]
            if motion.length()<=32:
                var shape:=CircleShape2D.new();shape.radius=definition.foot_radius+.5
                var query:=PhysicsShapeQueryParameters2D.new();query.shape=shape;query.collision_mask=1
                query.transform=Transform2D(0,path[-1]+Vector2(0,-3));query.motion=motion
                var fractions:=get_world_2d().direct_space_state.cast_motion(query)
                if fractions[0]>=.999:
                    if motion.length()>.1:path.append(goal)
                    step.position=goal # Private daily definition, never the source resource.
    super._path_received(token,path)
