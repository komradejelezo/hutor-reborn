extends "res://scripts/npc/rework/resident_presentation.gd"
## Elder-only authored gestures at existing places. VillageLife owns every path,
## work interval, scene crossing and conversation; this does not move any body.
const CLOSED=preload("res://assets/npc/elder548/game/journal_closed.png")
const OPEN=preload("res://assets/npc/elder548/game/journal_open.png")
const ROLL=preload("res://assets/npc/elder548/game/parchment_rolled.png")
var _world:Node2D
var _desk:Node2D
var _hands:Sprite2D
var _props:Dictionary={}
var _active:=false
var _pause:=.4
var _pass:=0
var _clip:StringName=&""
var _direction:StringName=&"down"
var _talking:=false
var _settling:=false
var _point_cooldown:=0.0
var gestures_to_residents:=0

func _restore() -> void:
    for item in _props.values():
        if is_instance_valid(item):item.show()
    if _props.has("Journal548"):
        _props.Journal548.texture=CLOSED
        _props.Journal548.position=Vector2(-20,-36)
    if _props.has("Paper548"):_props.Paper548.texture=ROLL

func release(actor:HutorResident) -> void:
    _restore();_props.clear()
    if is_instance_valid(_hands):_hands.queue_free()
    _hands=null;_desk=null;_world=null;_active=false;_talking=false;_settling=false
    super.release(actor)

func _bind(world:Node2D) -> void:
    if _world==world:return
    _world=world;_desk=world.get_node_or_null("Actors/Props/Desk")
    if not is_instance_valid(_desk):return
    for key in ["Paper548","Journal548","Inkwell548","Quill548"]:_props[key]=_desk.get_node(key)
    _hands=Sprite2D.new();_hands.name="ElderHands548";_hands.centered=false
    _hands.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
    _hands.region_enabled=true;_hands.region_rect=Rect2(0,0,96,70)
    _desk.add_child(_hands);_hands.hide()

func _surface(actor:HutorResident, enabled:bool) -> void:
    if not is_instance_valid(_hands):return
    _hands.visible=enabled
    if not enabled:return
    var sprite:AnimatedSprite2D=actor.get_node("AnimatedSprite2D")
    _hands.texture=sprite.sprite_frames.get_frame_texture(sprite.animation,sprite.frame)
    _hands.material=sprite.material;_hands.flip_h=sprite.flip_h
    _hands.position=actor.position-_desk.position+sprite.offset

func _tools(sprite:AnimatedSprite2D) -> void:
    _restore()
    if _props.is_empty():return
    if sprite.animation==&"work_read":_props.Paper548.visible=not (sprite.frame>=2 and sprite.frame<6)
    if sprite.animation==&"work_write":
        _props.Journal548.position=Vector2(-20,-36)
        _props.Paper548.hide()
        _props.Journal548.texture=OPEN if sprite.frame>=1 and sprite.frame<6 else CLOSED
        _props.Quill548.visible=not (sprite.frame>=2 and sprite.frame<6)

func _toward(axis:Vector2) -> StringName:
    return (&"right" if axis.x>0 else &"left") if absf(axis.x)>absf(axis.y) else (&"down" if axis.y>0 else &"up")

func _neighbor(actor:HutorResident) -> HutorResident:
    var partner:HutorResident;var reach:=112.0
    for other in actor.director.residents.values():
        if other==actor or not other.is_inside_tree() or not other.visible or other.state==other.State.TALKING:continue
        var distance:=actor.position.distance_to(other.position)
        if distance<reach and distance>10:partner=other;reach=distance
    return partner

func present(actor:HutorResident,record:HutorDailyResidentState,look:StringName,delta:float) -> bool:
    var sprite:AnimatedSprite2D=actor.get_node("AnimatedSprite2D")
    sprite.position=Vector2.ZERO;sprite.z_index=0
    var step:=actor.current_step()
    if not step:return false
    _bind(actor.director.get_parent().get_parent());_surface(actor,false)
    var key:=String(record.scene)+"/"+str(record.block_stamp)+"/"+str(actor.step_index)
    if key!=action_key:
        action_key=key;_active=false;_pause=.4;_talking=false;_settling=false
        actor.animator.set_work_context(key);_restore()
    actor.get_node("Interaction").position=step.talk_offset if actor.state in [actor.State.WAITING,actor.State.TALKING] else Vector2.ZERO
    _point_cooldown=maxf(0,_point_cooldown-delta)
    if actor.state==actor.State.TALKING:
        if not _talking:
            _talking=true
            _settling=_active and sprite.is_playing() and sprite.frame<sprite.sprite_frames.get_frame_count(sprite.animation)-1
            if _settling:
                var ending:=3 if String(sprite.animation).begins_with("point_") else sprite.sprite_frames.get_frame_count(sprite.animation)-2
                sprite.set_frame_and_progress(maxi(sprite.frame,ending),0)
        if _settling and sprite.is_playing():
            _tools(sprite);_surface(actor,_clip in [&"work_read",&"work_write"]);return true
        _settling=false;_restore();actor.animator.apply("talk",actor.facing,&"",false);return true
    if _talking:_talking=false;_settling=false;_active=false;_pause=.8
    if actor.state==actor.State.MOVING and not actor.velocity.is_zero_approx():
        _restore();_active=false;last_work="";actor.animator.apply("walk",actor.facing,&"",false);return true
    if actor.state!=actor.State.WAITING or record.mode!=&"local" or actor.position.distance_to(step.position)>12:
        _restore();_active=false;last_work="";actor.animator.apply("idle",actor.facing,&"",false);return true
    var requested:StringName={"read_documents":&"work_read","write_journal":&"work_write","ponder":&"work_think","inspect_square":&"work_inspect","inspect_well":&"work_inspect","common_store":&"work_inspect","watch_village":&"work_inspect"}.get(step.label,&"")
    if requested==&"":
        _restore();last_work="";actor.animator.apply("turn" if look!=&"" else "idle",look if look!=&"" else step.facing,&"",false);return true
    if requested in [&"work_read",&"work_write"] and (not is_instance_valid(_desk) or actor.position.distance_to(_desk.position)>50):
        rejected_work+=1;_restore();actor.animator.apply("idle",step.facing,&"",false);return true
    var rate:=minf(2.5,sqrt(actor.activity_controller.manager.clock.speed))
    if _active and not sprite.is_playing():_active=false;_pause=2.0+float(_pass%3)*.6
    if not _active:
        _pause-=delta*rate
        if _pause>0:
            _restore();last_work="";actor.animator.apply("turn" if look!=&"" else "idle",look if look!=&"" else step.facing,&"",false);return true
        _clip=requested;_direction=&"right" if requested in [&"work_read",&"work_write"] else &"down"
        if record.scene==&"village" and _point_cooldown<=0:
            var partner:=_neighbor(actor)
            if is_instance_valid(partner):
                var direction:=_toward(partner.position-actor.position)
                # No back-view pointing drawing exists: do not fake a front pose.
                if direction!=&"up":
                    _clip=StringName("point_"+String(direction));_direction=direction
                    _point_cooldown=16;gestures_to_residents+=1
        _active=true;_pass+=1;work_starts+=1;actor.animator.set_work_context(key+"/"+str(_pass))
    last_work=String(_clip)
    if String(_clip).begins_with("point_"):actor.animator.apply("point",_direction,&"",false)
    else:actor.animator.apply("work",_direction,_clip,false)
    _tools(sprite);_surface(actor,_clip in [&"work_read",&"work_write"])
    return true
