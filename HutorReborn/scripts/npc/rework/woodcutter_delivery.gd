extends RefCounted
## Only the pilot's visible load. Reads residency; never moves a body or time.
var delivered := 0
var home_entry_seen := false
var placing := false
var active_return := 0

func update(record:HutorDailyResidentState) -> void:
    var token:int=record.event_counts.get("return_from_work",0)
    if token!=active_return:
        active_return=token;home_entry_seen=false;placing=false
    # During boundary/travel, record.block still describes the old logging job.
    # Read the requested time block without changing the residency owner.
    var manager:Node=record.actor.activity_controller.manager
    var requested:Dictionary=manager._requested(record)
    var returning_block:bool=requested.get("activities",[]).any(func(item:Dictionary):return item.get("id","")=="rest_after_work")
    if not returning_block:delivered=maxi(delivered,token)
    var eligible:=token>delivered and token>0
    if eligible and record.scene==&"woodcutter":
        if record.actor.state==HutorResident.State.MOVING:home_entry_seen=true
        # If delivery finished while this room was offscreen, do not replay it.
        elif record.actor.state==HutorResident.State.WAITING and not home_entry_seen and record.actor.is_inside_tree() and not placing:
            delivered=token;eligible=false
    if record.scene not in [&"village",&"woodcutter"]:eligible=false
    record.actor.animator.pilot_carrying=eligible and not placing

func present(actor:HutorResident,record:HutorDailyResidentState) -> bool:
    update(record)
    var sprite:AnimatedSprite2D=actor.get_node("AnimatedSprite2D")
    var step:HutorNpcRoutineStep=actor.current_step()
    if not placing and home_entry_seen and active_return>delivered and record.scene==&"woodcutter" and record.mode==&"local" and actor.state==actor.State.WAITING and step and step.label=="rest_after_work" and actor.position.distance_to(step.position)<12:
        placing=true;actor.animator.pilot_carrying=false
        actor.animator.apply("work",&"right",&"work_put_down",false)
    if not placing:return false
    if sprite.animation==&"work_put_down" and sprite.is_playing():
        # A dialogue locks the real body immediately; renderer completes release.
        return true
    if sprite.animation==&"work_put_down":
        var world:Node2D=actor.director.get_parent().get_parent()
        var props:Node=world.get_node("Actors/Props")
        var bundle:Sprite2D=props.get_node_or_null("DeliveredLogs542")
        if bundle==null:
            bundle=Sprite2D.new();bundle.name="DeliveredLogs542";bundle.texture=load("res://assets/npc/woodcutter542/game/placed_logs.png")
            bundle.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;props.add_child(bundle)
        bundle.scale=sprite.scale
        bundle.material=sprite.material
        bundle.position=actor.position+Vector2(18,-4)*sprite.scale
        bundle.z_index=0
    placing=false;delivered=active_return;actor.animator.pilot_carrying=false
    return false

func release(actor:HutorResident) -> void:
    # Scene switches may park this same actor halfway through the route.
    # Its residency/event token survives; no extra NPC or logical inventory.
    if placing:delivered=active_return
    placing=false;home_entry_seen=false;actor.animator.pilot_carrying=false
