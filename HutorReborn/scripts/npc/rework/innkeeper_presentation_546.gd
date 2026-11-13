extends "res://scripts/npc/rework/resident_presentation.gd"
## Innkeeper-only chores at existing surfaces; no movement or schedule ownership.
var _counter:Node2D
var _overlay:Sprite2D
var _active:=false
var _pause:=.4
var _pass:=0
var _clip:StringName=&""
var _talking:=false
var _settling:=false
var _settle_facing:StringName=&"down"
var _props:Dictionary={}

func _restore_props() -> void:
    for item in _props.values():
        if is_instance_valid(item):item.show()

func release(actor:HutorResident) -> void:
    _restore_props();_props.clear()
    if is_instance_valid(_overlay):_overlay.queue_free()
    _overlay=null;_counter=null;_active=false;_talking=false;_settling=false;_pause=.4
    super.release(actor)

func _bind(world:Node2D) -> void:
    var counter:Node2D=world.get_node_or_null("Actors/Props/Counter")
    if counter==_counter:return
    _restore_props();_counter=counter;_props.clear()
    if not is_instance_valid(counter):return
    for key in ["MugWipe546","MugService546","Pitcher546","Cloth546"]:
        var item:=counter.get_node_or_null(key)
        if item:_props[key]=item
    _overlay=Sprite2D.new();_overlay.name="InnkeeperHands546"
    _overlay.centered=false;_overlay.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
    _overlay.region_enabled=true;_overlay.region_rect=Rect2(0,0,96,73)
    counter.add_child(_overlay);_overlay.hide()

func _tools(sprite:AnimatedSprite2D, clip:StringName, counter_work:bool) -> void:
    _restore_props()
    if not counter_work:return
    var frame:=sprite.frame
    var in_hands:=frame>=2 and frame<7
    if clip==&"work_wipe" and _props.has("Cloth546"):_props.Cloth546.visible=not in_hands
    if clip==&"work_mug":
        for key in ["MugWipe546","Cloth546"]:
            if _props.has(key):_props[key].visible=not in_hands
    if clip==&"work_serve":
        if _props.has("MugService546"):
            _props.MugService546.visible=not in_hands
            if frame>=7:_props.MugService546.texture=load("res://assets/npc/innkeeper546/game/mug_full.png")
        if _props.has("Pitcher546"):_props.Pitcher546.visible=not (frame>=1 and frame<7)

func _hands(actor:HutorResident, enabled:bool) -> void:
    if not is_instance_valid(_overlay):return
    _overlay.visible=enabled
    if not enabled:return
    var sprite:AnimatedSprite2D=actor.get_node("AnimatedSprite2D")
    _overlay.texture=sprite.sprite_frames.get_frame_texture(sprite.animation,sprite.frame)
    _overlay.material=sprite.material;_overlay.flip_h=sprite.flip_h
    _overlay.position=actor.position-_counter.position+sprite.offset

func present(actor:HutorResident,record:HutorDailyResidentState,look:StringName,delta:float) -> bool:
    var sprite:AnimatedSprite2D=actor.get_node("AnimatedSprite2D")
    sprite.position=Vector2.ZERO;sprite.z_index=0
    var step:=actor.current_step()
    var world:Node2D=actor.director.get_parent().get_parent()
    if record.scene!=&"inn":return super.present(actor,record,look,delta)
    _bind(world)
    var key:=String(record.scene)+"/"+str(record.block_stamp)+"/"+str(actor.step_index)
    if key!=action_key:
        action_key=key;work_clock=0;_active=false;_pause=.4;_talking=false;_settling=false
        actor.animator.set_work_context(key)
    actor.get_node("Interaction").position=step.talk_offset if step and actor.state in [actor.State.WAITING,actor.State.TALKING] else Vector2.ZERO
    _hands(actor,false)
    if actor.state==actor.State.TALKING:
        if not _talking:
            _talking=true
            # Finish only the drawn put-down/straighten, never keep wiping during dialogue.
            _settling=_active and sprite.frame>=1 and sprite.frame<6
            _settle_facing=&"right" if _clip==&"work_cook" else &"down"
            if _settling:sprite.set_frame_and_progress(6,0)
        if _settling and sprite.is_playing():
            _tools(sprite,_clip,_clip!=&"work_cook");_hands(actor,_clip!=&"work_cook")
            return true
        _settling=false;_restore_props();actor.animator.apply("talk",actor.facing,&"",false)
        return true
    if _talking:
        _talking=false;_settling=false;_active=false;_pause=.7
    if actor.state==actor.State.MOVING and not actor.velocity.is_zero_approx():
        _restore_props();_active=false;last_work=""
        actor.animator.apply("walk",actor.facing,&"",false);return true
    if not step or actor.state!=actor.State.WAITING or record.mode!=&"local" or actor.position.distance_to(step.position)>12:
        _restore_props();_active=false;last_work="";actor.animator.apply("idle",actor.facing,&"",false);return true
    _clip={"prepare_inn":&"work_wipe","wipe_mug":&"work_mug","arrange_dishes":&"work_serve","check_hearth":&"work_cook"}.get(step.label,&"")
    var surface:Node2D=world.get_node_or_null("Actors/Props/Fireplace/CookingCrock546") if _clip==&"work_cook" else _counter
    var valid:=is_instance_valid(surface) and (actor.position.distance_to(surface.global_position)<32 if _clip==&"work_cook" else actor.position.distance_to(surface.position)<94)
    if _clip==&"" or not valid:
        if _clip!=&"" and not valid:rejected_work+=1
        _restore_props();_active=false;last_work=""
        actor.animator.apply("turn" if look!=&"" else "idle",look if look!=&"" else actor.facing,&"",false);return true
    var rate:=minf(2.5,sqrt(actor.activity_controller.manager.clock.speed))
    work_clock+=delta*rate
    if _active and not sprite.is_playing():
        _active=false;_pause=1.8+float(_pass%3)*.4
    if not _active:
        _pause-=delta*rate
        if _pause>0:
            _restore_props();last_work=""
            actor.animator.apply("turn" if look!=&"" else "idle",look if look!=&"" else step.facing,&"",false);return true
        _active=true;_pass+=1;work_starts+=1
        actor.animator.set_work_context(key+"/"+str(_pass))
    last_work=String(_clip)
    actor.animator.apply("work",&"right" if _clip==&"work_cook" else &"down",_clip,false)
    _tools(sprite,_clip,_clip!=&"work_cook");_hands(actor,_clip!=&"work_cook")
    return true
