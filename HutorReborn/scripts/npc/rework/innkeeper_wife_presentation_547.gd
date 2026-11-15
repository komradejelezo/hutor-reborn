extends "res://scripts/npc/rework/resident_presentation.gd"
## Wife-only presentation. Existing VillageLife owns time, paths and residency.
var carrying:=false
var _world:Node2D
var _items:Dictionary={}
var _hands:Dictionary={}
var _broom:Sprite2D
var _active:=false
var _once_done:=false
var _pause:=.35
var _pass:=0
var _clip:StringName=&""
var _talking:=false
var _settling:=false

func release(actor:HutorResident) -> void:
    for overlay in _hands.values():
        if is_instance_valid(overlay):overlay.queue_free()
    if is_instance_valid(_broom):_broom.queue_free()
    _hands.clear();_items.clear();_world=null;_broom=null
    _active=false;_talking=false;_settling=false;_once_done=false
    actor.animator.pilot_carrying=false
    super.release(actor)

func _bind(world:Node2D) -> void:
    if world==_world:return
    _world=world
    for pair in [["board","TableC/Board547"],["tray","TableC/Tray547"],["dishes","TableC/Dishes547"],["served","TableA/Served547"]]:
        _items[pair[0]]=world.get_node("Actors/Props/"+pair[1])
    for name in ["TableA","TableC"]:
        var surface:Node2D=world.get_node("Actors/Props/"+name)
        var overlay:=Sprite2D.new();overlay.name="WifeHands547";overlay.centered=false
        overlay.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
        overlay.region_enabled=true;overlay.region_rect=Rect2(0,0,96,72)
        surface.add_child(overlay);overlay.hide();_hands[name]=overlay
    _broom=Sprite2D.new();_broom.name="WifeBroom547";_broom.texture=load("res://assets/npc/innkeeper_wife547/game/broom.png")
    _broom.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;_broom.offset=Vector2(0,-8)
    world.get_node("Actors/Props").add_child(_broom);_broom.hide()

func _hide_hands() -> void:
    for overlay in _hands.values():overlay.hide()

func _surface(actor:HutorResident,name:String) -> void:
    var sprite:AnimatedSprite2D=actor.get_node("AnimatedSprite2D")
    var overlay:Sprite2D=_hands[name]
    overlay.show();overlay.texture=sprite.sprite_frames.get_frame_texture(sprite.animation,sprite.frame)
    overlay.flip_h=sprite.flip_h;overlay.material=sprite.material
    overlay.position=actor.position-overlay.get_parent().position+sprite.offset

func _props(sprite:AnimatedSprite2D,step:HutorNpcRoutineStep) -> void:
    _items.board.visible=step.label=="cut_food"
    _items.tray.visible=step.label=="take_tray" and not carrying
    _items.dishes.visible=step.label=="polish_dishes" and not (_active and sprite.frame>=2 and sprite.frame<6)
    if step.label=="take_tray" and sprite.animation==&"work_pickup" and sprite.frame>=2:carrying=true;_items.tray.hide()
    if step.label=="serve_food" and sprite.animation==&"work_place" and sprite.frame>=2:carrying=false;_items.served.show()
    if step.label=="clean_tables" and sprite.animation==&"work_wipe" and sprite.frame>=5:_items.served.hide()

func _neutral(actor:HutorResident,mode:String,direction:StringName) -> void:
    actor.animator.pilot_carrying=carrying
    actor.animator.apply("carry_idle" if carrying else mode,direction,&"",false)

func present(actor:HutorResident,record:HutorDailyResidentState,look:StringName,delta:float) -> bool:
    var sprite:AnimatedSprite2D=actor.get_node("AnimatedSprite2D")
    sprite.position=Vector2.ZERO;sprite.z_index=0
    var step:=actor.current_step()
    if record.scene!=&"inn":return super.present(actor,record,look,delta)
    _bind(actor.director.get_parent().get_parent());_hide_hands();_broom.hide()
    if not step:return false
    var key:=String(record.scene)+"/"+str(record.block_stamp)+"/"+str(actor.step_index)
    if key!=action_key:
        action_key=key;_active=false;_once_done=false;_pause=.35;_talking=false;_settling=false
        # Offline catch-up already resolves the carrying leg to its saved position.
        if step.label=="serve_food":carrying=true
        elif step.label!="take_tray":carrying=false
        actor.animator.set_work_context(key)
    actor.get_node("Interaction").position=step.talk_offset if actor.state in [actor.State.WAITING,actor.State.TALKING] else Vector2.ZERO
    _props(sprite,step)
    if actor.state==actor.State.TALKING:
        if not _talking:
            _talking=true
            _settling=_active and sprite.is_playing() and _clip!=&"work_sweep" and sprite.frame<sprite.sprite_frames.get_frame_count(_clip)-2
            if _settling:sprite.set_frame_and_progress(sprite.sprite_frames.get_frame_count(_clip)-2,0)
        if _settling and sprite.is_playing():
            _props(sprite,step)
            if _clip in [&"work_cut",&"work_wipe",&"work_dishes",&"work_pickup",&"work_place"]:_surface(actor,"TableA" if step.label in ["serve_food","clean_tables"] else "TableC")
            return true
        if _settling:
            _props(sprite,step)
            if _clip in [&"work_pickup",&"work_place"]:_once_done=true
        _settling=false
        _items.dishes.visible=step.label=="polish_dishes"
        if _clip==&"work_sweep":_broom.position=actor.position+Vector2(12,0);_broom.show()
        _neutral(actor,"talk",actor.facing);return true
    if _talking:
        _talking=false;_settling=false;_active=false;_pause=.6
    actor.animator.pilot_carrying=carrying
    if actor.state==actor.State.MOVING and not actor.velocity.is_zero_approx():
        _active=false;last_work=""
        actor.animator.apply("carry" if carrying else "walk",actor.facing,&"",false);return true
    if actor.state!=actor.State.WAITING or record.mode!=&"local" or actor.position.distance_to(step.position)>12:
        _active=false;last_work="";_neutral(actor,"idle",actor.facing);return true
    _clip={"kitchen":&"work_cook","cut_food":&"work_cut","take_tray":&"work_pickup","serve_food":&"work_place","clean_tables":&"work_wipe","polish_dishes":&"work_dishes","sweep_floor":&"work_sweep","pause_kitchen":&"work_rest","rest_night":&"work_rest"}.get(step.label,&"")
    if _clip==&"":_neutral(actor,"turn" if look!=&"" else "idle",look if look!=&"" else step.facing);return true
    var surface:Node2D
    if step.label=="kitchen":surface=_world.get_node("Actors/Props/Fireplace/WifeCrock547")
    elif step.label in ["cut_food","take_tray","polish_dishes"]:surface=_world.get_node("Actors/Props/TableC")
    elif step.label in ["serve_food","clean_tables"]:surface=_world.get_node("Actors/Props/TableA")
    if is_instance_valid(surface) and actor.position.distance_to(surface.global_position)>(34 if step.label=="kitchen" else 48):
        rejected_work+=1;_neutral(actor,"idle",step.facing);return true
    var direction:StringName=&"left" if step.label=="kitchen" else &"right" if step.label in ["cut_food","take_tray","serve_food","sweep_floor"] else &"down"
    var rate:=minf(2.5,sqrt(actor.activity_controller.manager.clock.speed))
    if _active and not sprite.is_playing():
        _active=false;_pause=1.5+float(_pass%3)*.35
        if _clip in [&"work_pickup",&"work_place"]:_once_done=true
    if not _active:
        _pause-=delta*rate
        if _pause>0 or _once_done:
            last_work="";_neutral(actor,"turn" if look!=&"" else "idle",look if look!=&"" else direction);return true
        _active=true;_pass+=1;work_starts+=1;actor.animator.set_work_context(key+"/"+str(_pass))
    last_work=String(_clip);actor.animator.apply("work",direction,_clip,false);_props(sprite,step)
    if step.label in ["cut_food","take_tray","serve_food","clean_tables","polish_dishes"]:_surface(actor,"TableA" if step.label in ["serve_food","clean_tables"] else "TableC")
    return true
