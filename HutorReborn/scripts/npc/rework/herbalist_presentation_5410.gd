extends "res://scripts/npc/rework/resident_presentation.gd"
## Herbalist-only visual chores. VillageLife retains all schedule/time, residency,
## paths and dialogue state. Each non-looping action completes before another starts.
const BOOK_CLOSED=preload("res://assets/npc/herbalist5410/game/book_closed.png")
const BOOK_OPEN=preload("res://assets/npc/herbalist5410/game/book_open.png")
const LIVE_HERBS=preload("res://scenes/objects/krivaya_sosna/stage32/white_herbs.tscn")
var _world:Node2D
var _table:Node2D
var _pot:Node2D
var _hands:Sprite2D
var _props:Dictionary={}
var _active:=false
var _pause:=.5
var _pass:=0
var _clip:StringName=&""
var _talking:=false
var _settling:=false
var _patch:Node2D

func _restore() -> void:
    for name in _props:
        var item:Sprite2D=_props[name]
        if not is_instance_valid(item):continue
        item.show()
        item.position={"mortar":Vector2(-15,-32),"pestle":Vector2(-12,-36),"herbs_mat":Vector2(-2,-36),"book_closed":Vector2(12,-32)}[name]
    if _props.has("book_closed"):_props.book_closed.texture=BOOK_CLOSED
func release(actor:HutorResident) -> void:
    _restore();_props.clear()
    if is_instance_valid(_hands):_hands.queue_free()
    _hands=null;_table=null;_world=null;_pot=null;_patch=null
    _active=false;_talking=false;_settling=false;_pause=.5
    super.release(actor)
func _bind(world:Node2D) -> void:
    if _world==world:return
    _restore()
    if is_instance_valid(_hands):_hands.queue_free()
    _hands=null;_props.clear();_world=world
    _table=world.get_node_or_null("Actors/Props/Table");_pot=world.get_node_or_null("Actors/Props/Cauldron")
    if not is_instance_valid(_table):return
    for key in ["mortar","pestle","herbs_mat","book_closed"]:
        var item:=_table.get_node_or_null(key+"5410")
        if item:_props[key]=item
    _hands=Sprite2D.new();_hands.name="HerbalistHands5410";_hands.centered=false
    _hands.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
    _hands.region_enabled=true;_hands.region_rect=Rect2(0,0,96,73)
    _table.add_child(_hands);_hands.hide();_restore()
func _surface(actor:HutorResident,enabled:bool) -> void:
    if not is_instance_valid(_hands):return
    _hands.visible=enabled
    if enabled:
        var s:AnimatedSprite2D=actor.get_node("AnimatedSprite2D")
        _hands.texture=s.sprite_frames.get_frame_texture(s.animation,s.frame)
        _hands.material=s.material;_hands.flip_h=false
        _hands.position=actor.position-_table.position+s.offset
func _tools(s:AnimatedSprite2D) -> void:
    _restore()
    if _props.is_empty():return
    if _clip==&"sort_herbs":
        _props.herbs_mat.position=Vector2(-15,-32);_props.mortar.position=Vector2(2,-32)
    elif _clip==&"grind_herbs":
        _props.pestle.visible=not (s.frame>=1 and s.frame<7)
    elif _clip==&"read_herbal":
        _props.book_closed.position=Vector2(-15,-32);_props.mortar.position=Vector2(2,-32)
        _props.book_closed.texture=BOOK_OPEN if s.frame in [1,6] else BOOK_CLOSED
        _props.book_closed.visible=not (s.frame>=2 and s.frame<6)
func _draw(actor:HutorResident,clip:StringName,restart:bool=false) -> void:
    var s:AnimatedSprite2D=actor.get_node("AnimatedSprite2D");s.flip_h=false
    if s.animation!=clip or restart:s.play(clip);s.set_frame_and_progress(0,0)
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
func _plants(world:Node2D,point:Vector2) -> Node2D:
    # Reuse original living vegetation beside the two established forage points.
    # Small non-solid clumps persist in the cached world; no random new locations.
    var group:Node2D=world.get_node_or_null("Actors/ForageHerbs5410")
    if not group:
        group=Node2D.new();group.name="ForageHerbs5410";group.y_sort_enabled=true;world.get_node("Actors").add_child(group)
    var key:="Herbs_"+str(roundi(point.x))+"_"+str(roundi(point.y))
    var item:Node2D=group.get_node_or_null(key)
    if not item and group.get_child_count()<2:
        item=LIVE_HERBS.instantiate();item.name=key;item.position=point+Vector2(13,2);item.scale=Vector2.ONE*.4
        group.add_child(item)
    return item
func present(actor:HutorResident,record:HutorDailyResidentState,look:StringName,delta:float) -> bool:
    var s:AnimatedSprite2D=actor.get_node("AnimatedSprite2D")
    s.position=Vector2.ZERO;s.z_index=0
    var step:=actor.current_step()
    if not step:return false
    var world:Node2D=actor.director.get_parent().get_parent();_bind(world);_surface(actor,false)
    var key:=String(record.scene)+"/"+str(record.block_stamp)+"/"+str(actor.step_index)
    if action_key!=key:
        action_key=key;_active=false;_pause=.5;_talking=false;_settling=false;_patch=null;_restore()
    actor.get_node("Interaction").position=step.talk_offset if actor.state in [actor.State.WAITING,actor.State.TALKING] else Vector2.ZERO
    if actor.state==actor.State.TALKING:
        if not _talking:
            _talking=true;_settling=_active and s.is_playing() and s.frame<6
            if _settling:s.set_frame_and_progress(6,0)
        if _settling and s.is_playing():
            _tools(s);_surface(actor,_clip in [&"sort_herbs",&"grind_herbs",&"read_herbal"]);return true
        _settling=false;_active=false;_restore();actor.animator.apply("talk",actor.facing,&"",false);return true
    if _talking:_talking=false;_settling=false;_active=false;_pause=.7
    if actor.state==actor.State.MOVING and not actor.velocity.is_zero_approx():
        _restore();_active=false;last_work="";actor.animator.apply("walk",actor.facing,&"",false);return true
    var requested:StringName=&""
    if actor.state==actor.State.WAITING and record.mode==&"local" and actor.position.distance_to(step.position)<12:
        if record.scene==&"village" and step.label=="gather":
            _patch=_plants(world,step.position)
            if is_instance_valid(_patch) and actor.position.distance_to(_patch.position)<24:requested=&"gather_herbs"
        elif record.scene==&"herbalist" and step.label=="sort_herbs":
            if is_instance_valid(_table) and actor.position.distance_to(_table.position+Vector2(-29,-9))<2.2 and _props.size()==4:
                requested=[&"sort_herbs",&"grind_herbs",&"read_herbal"][_pass%3]
        elif record.scene==&"herbalist" and step.label=="brew":
            if is_instance_valid(_pot) and actor.position.distance_to(_pot.position+Vector2(-26,-4))<2.2:requested=&"brew_infusion"
    if requested==&"":
        _restore();_active=false;last_work="";actor.animator.apply("turn" if look!=&"" else "idle",look if look!=&"" else actor.facing,&"",false);return true
    if _active and not s.is_playing():_active=false;_pause=1.1+float(_pass%3)*.2
    if not _active:
        _pause-=delta*minf(2.5,sqrt(actor.activity_controller.manager.clock.speed))
        if _pause>0 or _budget(actor,record)<_duration(actor,requested)+.3:
            _restore();last_work="";actor.animator.apply("idle",&"right",&"",false);return true
        _clip=requested;_active=true;_pass+=1;work_starts+=1;_draw(actor,_clip,true)
    _draw(actor,_clip);last_work=String(_clip);_tools(s)
    _surface(actor,_clip in [&"sort_herbs",&"grind_herbs",&"read_herbal"])
    return true
