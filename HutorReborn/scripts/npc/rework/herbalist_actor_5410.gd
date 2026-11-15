extends "res://scripts/npc/npc.gd"
## Herbalist-only final approach to the existing table/cauldron, swept against the
## real solids. No global navigation/routine changes or position teleportation.
var _approach_wait:=-1.0
func _at_station() -> bool:
    if not is_instance_valid(activity_controller):return false
    var record:HutorDailyResidentState=activity_controller.resident
    var step:=current_step()
    return record.scene==&"herbalist" and record.mode==&"local" and step and step.label in ["sort_herbs","brew"]
func _goal() -> Vector2:
    var brew:=current_step().label=="brew"
    var object:Node2D=director.get_node("../Props/"+("Cauldron" if brew else "Table"))
    return object.position+(Vector2(-26,-4) if brew else Vector2(-29,-9))
func _physics_process(delta:float) -> void:
    if state==State.WAITING and not motion_paused and _at_station() and position.distance_to(_goal())>2.1:
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
    if _at_station() and not path.is_empty():
        var goal:=_goal();var motion:=goal-path[-1]
        if motion.length()<=32:
            var shape:=CircleShape2D.new();shape.radius=definition.foot_radius+.5
            var query:=PhysicsShapeQueryParameters2D.new();query.shape=shape;query.collision_mask=1
            query.transform=Transform2D(0,path[-1]+Vector2(0,-3));query.motion=motion
            var fractions:=get_world_2d().direct_space_state.cast_motion(query)
            if fractions[0]>=.999:
                if motion.length()>.1:path.append(goal)
                current_step().position=goal # Private daily definition only.
    super._path_received(token,path)
