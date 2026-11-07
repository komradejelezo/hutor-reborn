extends Node
signal activity_changed(npc_id: StringName, activity: StringName)
signal residency_changed(npc_id: StringName, scene_id: StringName)
## A scene-independent residency/schedule owner; existing bodies are never cloned.
const CLOCK = preload("res://scripts/life/game_clock.gd")
const RECORD = preload("res://scripts/life/resident_state.gd")
const PRESENTER = preload("res://scripts/life/activity_presenter.gd")
const STEP = preload("res://scripts/npc/routine_step.gd")
var enabled := true # Legacy component fixtures disable this before loading a world.
var initialized := false
var switching := false
var clock: HutorGameClock
var travel: Node
var states: Dictionary = {}
var gateway: Dictionary = {}
var gateways: Dictionary = {}
var events: Array[Dictionary] = []
var _parking := Node2D.new()
var _frames: Dictionary = {}
var _profiles: Dictionary = {}
var _widget: CanvasLayer
var _time_label: Label
var virtual_updates := 0
var materializations := 0

func _ready() -> void:
    process_mode=Node.PROCESS_MODE_ALWAYS
    clock=CLOCK.new();clock.name="Clock";add_child(clock)
    travel=get_node("/root/InteriorTravel")
    var registry_path:="res://data/life/registry.json"
    if FileAccess.file_exists(registry_path):
        var registry:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(registry_path))
        clock.real_day_seconds=registry.real_day_seconds;clock.absolute_minutes=registry.start_minute
        for path in registry.residents:
            var profile:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
            _profiles[StringName(profile.id)]=profile
        var definitions:Array=JSON.parse_string(FileAccess.get_file_as_string("res://data/life/gateways.json"))
        for definition in definitions:gateways[StringName(definition.virtual_destination)]=definition
        gateway=definitions[0]
    clock.minute_changed.connect(_tick)
    clock.speed_changed.connect(_speed_changed)
    clock.sought.connect(_scrub)
    get_node("/root/DialogueManager").dialogue_finished.connect(func(_id: String,_reason: String):_tick.call_deferred(clock.absolute_minutes))
    get_tree().root.child_entered_tree.connect(_root_added)

func _root_added(node: Node) -> void:
    if node.scene_file_path==travel.VILLAGE:_bootstrap.call_deferred(node)

func _bootstrap(world: Node2D) -> void:
    if not enabled or initialized or not is_instance_valid(world):return
    if _profiles.is_empty():return
    initialized=true;travel.residency_driver=self
    var population:Node2D=world.get_node("Actors/Residents")
    for actor in population.residents.values().duplicate():
        if not _profiles.has(actor.definition.id):continue
        var record:HutorDailyResidentState=RECORD.new()
        record.id=actor.definition.id;record.actor=actor;record.original=actor.definition
        record.schedule=_profiles[record.id];record.scene=record.schedule.home
        var presenter:Node=PRESENTER.new();presenter.name="DailyActivity"
        presenter.manager=self;presenter.resident=record;actor.add_child(presenter)
        actor.activity_controller=presenter
        actor._ready_to_walk=true;actor._token+=1
        actor.routine_step_changed.connect(_arrived)
        states[record.id]=record
        _choose(record);record.block=record.schedule.blocks[_block_index(record.schedule)]
        record.block_stamp=_block_start(record.block);record.scene=record.block.scene
        _set_virtual_phase(record,true)
        actor.reparent(_parking,false)
    for definition in gateways.values():
        var portal:=Marker2D.new();portal.name="NpcGateway_"+String(definition.id)
        portal.position=Vector2(definition.position[0],definition.position[1])
        portal.set_meta("gateway_id",definition.id);portal.set_meta("virtual_destination",definition.virtual_destination)
        world.get_node("Exploration").add_child(portal)
    _make_widget();clock.running=true
    world.tree_exiting.connect(func():
        if world.is_queued_for_deletion():_release_session())
    after_scene_change(&"village")
    _event(null,"session_started","village")

func _make_widget() -> void:
    if is_instance_valid(_widget):return
    _widget=CanvasLayer.new();_widget.layer=8;add_child(_widget)
    var root_control:=Control.new();root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root_control.mouse_filter=Control.MOUSE_FILTER_IGNORE;_widget.add_child(root_control)
    _time_label=Label.new();_time_label.position=Vector2(750,77)
    _time_label.add_theme_font_override("font",load("res://assets/fonts/DejaVuSans.ttf"))
    _time_label.add_theme_font_size_override("font_size",11)
    _time_label.add_theme_color_override("font_color",Color("c5b993"))
    root_control.add_child(_time_label);_update_widget()

func _update_widget() -> void:
    if not is_instance_valid(_time_label):return
    var labels:={"morning":"утро","day":"день","evening":"вечер","night":"ночь"}
    _time_label.text=clock.display_time()+" · "+labels[String(clock.phase_name())]+("  ×"+str(int(clock.speed)) if clock.speed!=1 else "")
    _widget.visible=initialized and not get_node("/root/DialogueManager").is_active()

func _input(event: InputEvent) -> void:
    if not initialized or not OS.is_debug_build() or not event is InputEventKey:return
    if event.pressed and not event.echo and event.physical_keycode==KEY_F7 and not get_node("/root/DialogueManager").is_active():
        clock.set_speed(30 if clock.speed==1 else 120 if clock.speed==30 else 1)
        get_viewport().set_input_as_handled()

func world_for(scene: StringName) -> Node2D:
    if scene==&"village":return travel.exterior
    if _is_virtual(scene):return null
    return travel._room(scene)

func _is_virtual(scene: StringName) -> bool:return gateways.has(scene)

func _gateway(record: HutorDailyResidentState) -> Dictionary:
    if gateways.has(record.scene):return gateways[record.scene]
    if gateways.has(record.desired_scene):return gateways[record.desired_scene]
    return gateways.get(StringName(record.schedule.get("work_location",gateway.virtual_destination)),gateway)

func _navigation(scene: StringName) -> HutorNpcNavigation:
    var world := world_for(scene)
    return world.get_node("Actors/Residents/Navigation") if world else null

func _point(scene: StringName, value: Variant) -> Vector2:
    if value is Array:return Vector2(value[0],value[1])
    if value is String:
        var world := world_for(scene)
        var marker := world.get_node_or_null(NodePath(value)) as Node2D if world else null
        return marker.position if marker else Vector2.ZERO
    return Vector2.ZERO

func _safe(record: HutorDailyResidentState, point: Vector2) -> Vector2:
    var nav:=_navigation(record.scene)
    # An unavailable room stays virtual; it must not break the outdoor session.
    if nav == null:return point
    var bounds:=Rect2()
    if record.scene==&"village" and record.schedule.has("safe_village_rect"):
        var r:Array=record.schedule.safe_village_rect;bounds=Rect2(r[0],r[1],r[2],r[3])
    var grid:=nav.grid_for(bounds)
    var cell:=nav.closest_cell(grid,point)
    if cell==Vector2i(-1,-1) and StringName(record.block.scene)==record.scene:cell=nav.closest_cell(grid,_point(record.scene,record.block.activities[record.index].point))
    if cell==Vector2i(-1,-1):
        var fallback:Vector2=record.original.routine[0].position if record.scene==&"village" else _point(record.scene,"Entry")
        cell=nav.closest_cell(grid,fallback)
    return grid.get_point_position(cell)

func _block_index(profile: Dictionary) -> int:
    var index:int=profile.blocks.size()-1
    for i in profile.blocks.size():
        if profile.blocks[i].start<=clock.minute_of_day():index=i
    return index

func _block_start(block: Dictionary) -> float:
    return floor((clock.absolute_minutes-float(block.start))/1440.0)*1440.0+float(block.start)

func _choose(record: HutorDailyResidentState) -> void:
    var block:Dictionary=record.schedule.blocks[_block_index(record.schedule)]
    record.desired_scene=StringName(block.scene)

func _requested(record: HutorDailyResidentState) -> Dictionary:
    return record.schedule.blocks[_block_index(record.schedule)]

func _set_virtual_phase(record: HutorDailyResidentState, exact: bool = false) -> void:
    var activities:Array=record.block.activities
    var length:=0.0
    for action in activities:length+=float(action.minutes)
    var phase:=fposmod(clock.absolute_minutes-record.block_stamp,maxf(1,length))
    record.index=0
    for i in activities.size():
        if phase<float(activities[i].minutes):record.index=i;break
        phase-=float(activities[i].minutes)
    record.activity=StringName(activities[record.index].id)
    record.until=clock.absolute_minutes+float(activities[record.index].minutes)-phase
    if not _is_virtual(record.scene):record.position=_point(record.scene,activities[record.index].point)
    record.mode=&"offsite" if _is_virtual(record.scene) else &"local"
    record.updated=clock.absolute_minutes
    record.travel_end=0
    if exact:record.snapshot.clear()

func _active(record: HutorDailyResidentState) -> bool:
    return is_instance_valid(record.actor) and record.actor.is_inside_tree() and record.scene==active_scene()

func active_scene() -> StringName:
    return &"village" if travel.active_id==&"" else travel.active_id

func _event(record: HutorDailyResidentState, kind: String, detail: String = "") -> void:
    var row:={"minute":clock.absolute_minutes,"id":String(record.id) if record else "","event":kind,"detail":detail}
    if record:record.count_event(kind)
    if record and kind in ["activity","virtual_activity","virtual_work"]:activity_changed.emit(record.id,record.activity)
    if record and kind in ["scene_changed","left_for_work","return_from_work"]:residency_changed.emit(record.id,record.scene)
    events.append(row)
    if events.size()>1024:events.pop_front()

func _tick(_minute: float) -> void:
    _update_widget()
    if not initialized or switching or travel.busy:return
    for record:HutorDailyResidentState in states.values():
        if not is_instance_valid(record.actor):continue
        _choose(record)
        if _active(record) and record.actor.state==HutorResident.State.TALKING:
            record.updated=clock.absolute_minutes
            continue
        _reconcile(record)
        if not _active(record):_advance_virtual(record)
        if record.scene==active_scene() and not record.actor.is_inside_tree() and not _is_virtual(record.scene):_materialize(record)

func _reconcile(record: HutorDailyResidentState) -> void:
    if record.mode==&"boundary_out" or record.mode==&"boundary_in":return
    if record.scene!=record.desired_scene:
        if record.mode!=&"travel" or (record.scene==&"village" and record.hop!=record.desired_scene):_start_journey(record)
        return
    var requested:=_requested(record)
    if record.block_stamp!=_block_start(requested) or record.mode==&"travel":
        record.block=requested;record.block_stamp=_block_start(requested)
        record.mode=&"offsite" if _is_virtual(record.scene) else &"local"
        record.index=0;record.snapshot.clear()
        record.activity=StringName(record.block.activities[0].id)
        record.until=clock.absolute_minutes+record.block.activities[0].minutes
        _event(record,"activity_block",String(record.activity))
        if _active(record):_apply_local(record,record.actor.position)
        elif not _is_virtual(record.scene):_virtual_target(record,clock.absolute_minutes)

func _door(building: StringName) -> Vector2:
    var data:HutorBuildingDefinition=travel.buildings[building]
    return travel.exterior.get_node(data.exterior_anchor).global_position+data.door_offset

func _gate(record: HutorDailyResidentState) -> Vector2:
    var definition:=_gateway(record)
    return Vector2(definition.position[0]+record.schedule.get("portal_lane",0),definition.position[1])

func _start_journey(record: HutorDailyResidentState) -> void:
    record.snapshot.clear()
    if _is_virtual(record.scene):
        var passage:=_gateway(record)
        record.scene=&"village";record.mode=&"boundary_in"
        record.position=_gate(record)+Vector2(passage.direction[0],passage.direction[1])*float(passage.outside_distance)
        record.portal_target=_gate(record);record.portal_direction=-Vector2(passage.direction[0],passage.direction[1])
        record.travel_end=clock.absolute_minutes+float(passage.outside_distance)/record.original.speed*_minutes_per_second()
        _event(record,"return_from_work",String(passage.id))
        if record.scene==active_scene():_materialize(record)
        return
    record.mode=&"travel";record.activity=&"travel"
    if record.scene==&"village":
        record.hop=record.desired_scene
        record.goal=_gate(record) if _is_virtual(record.hop) else _door(record.hop)
    else:
        record.hop=&"village";record.goal=_point(record.scene,"Exit")
    var position:Vector2=record.actor.position if _active(record) else record.position
    record.position=position
    record.travel_end=clock.absolute_minutes+maxf(1,position.distance_to(record.goal)/record.original.speed*_minutes_per_second())
    _event(record,"walk_to_gateway",String(record.hop))
    if _active(record):_apply_travel(record,position)

func _minutes_per_second() -> float:return 1440.0/clock.real_day_seconds

func _frames_for(record: HutorDailyResidentState) -> SpriteFrames:
    return HutorNpcVisualLibrary.frames_for(record.id,record.original.frames)

func _definition(record: HutorDailyResidentState) -> HutorNpcDefinition:
    var definition:HutorNpcDefinition=record.original.duplicate()
    definition.frames=_frames_for(record);definition.routine=[]
    definition.speed=record.original.speed*clock.speed
    if record.id==&"woodcutter_son":definition.speed*=record.schedule.get("run_multiplier",1.0)
    definition.route_bounds=Rect2()
    if record.scene==&"village" and record.schedule.has("safe_village_rect"):
        var r:Array=record.schedule.safe_village_rect;definition.route_bounds=Rect2(r[0],r[1],r[2],r[3])
    return definition

func _apply_local(record: HutorDailyResidentState, position: Vector2) -> void:
    var definition:=_definition(record)
    for action in record.block.activities:
        var step:HutorNpcRoutineStep=STEP.new()
        step.label=String(action.id);step.position=_safe(record,_point(record.scene,action.point))
        step.duration=float(action.minutes)/_minutes_per_second();step.duration_variation=0
        step.animation=StringName(action.get("clip",""));step.facing=StringName(action.get("facing","down"))
        if action.has("talk_offset"):step.talk_offset=Vector2(action.talk_offset[0],action.talk_offset[1])
        step.look_at_npc=StringName(action.get("partner",""))
        definition.routine.append(step)
    record.actor.enter_location(definition,world_for(record.scene).get_node("Actors/Residents"),position)
    record.actor.wait_time_scale=clock.speed
    if record.index!=0:
        record.actor.step_index=record.index;record.actor._request_path()

func _apply_travel(record: HutorDailyResidentState, position: Vector2) -> void:
    var definition:=_definition(record)
    definition.route_bounds=Rect2() # A child changes scenes only through its own door.
    var step:HutorNpcRoutineStep=STEP.new();step.label="Переход к двери";step.action=HutorNpcRoutineStep.Action.MOVE
    step.position=_safe(record,record.goal);step.duration=3600;step.duration_variation=0
    definition.routine.append(step)
    record.actor.enter_location(definition,world_for(record.scene).get_node("Actors/Residents"),position)
    record.actor.wait_time_scale=clock.speed

func _materialize(record: HutorDailyResidentState) -> void:
    if _is_virtual(record.scene) or record.actor.is_inside_tree():return
    var world:=world_for(record.scene)
    if world == null:return
    var population:Node2D=world.get_node("Actors/Residents")
    record.actor.reparent(population,false)
    record.actor.set_physics_process(true)
    materializations+=1
    if record.mode==&"boundary_in" or record.mode==&"boundary_out":
        record.actor.director=population;population.adopt(record.actor)
        record.actor.position=record.position;_enable_boundary(record)
        return
    var position:=_safe(record,record.position)
    if record.mode==&"travel":_apply_travel(record,position)
    else:
        _apply_local(record,position)
        if not record.snapshot.is_empty() and record.snapshot_stamp==record.block_stamp and record.snapshot.state==HutorResident.State.WAITING:
            var remaining:float=record.snapshot.wait_left-(clock.absolute_minutes-record.parked_at)/_minutes_per_second()
            if remaining>0:
                record.actor.step_index=record.index;record.actor.state=HutorResident.State.WAITING
                record.actor.wait_left=remaining;record.actor.position=position
                record.actor._token+=1
                record.actor._present()
    record.updated=clock.absolute_minutes

func _park(record: HutorDailyResidentState) -> void:
    if not is_instance_valid(record.actor) or not record.actor.is_inside_tree():return
    record.actor.activity_controller.clear_props()
    # A boundary exception belongs only to a visible crossing, not a parked body.
    if is_instance_valid(travel.exterior):
        record.actor.remove_collision_exception_with(travel.exterior.get_node("MapBounds"))
    record.position=record.actor.position
    record.snapshot=record.actor.suspend_location();record.snapshot_stamp=record.block_stamp
    record.parked_at=clock.absolute_minutes;record.updated=clock.absolute_minutes
    if record.mode==&"travel":
        record.travel_end=clock.absolute_minutes+record.position.distance_to(record.goal)/record.original.speed*_minutes_per_second()
    if record.mode==&"local":
        record.index=record.actor.step_index
        if record.actor.state==HutorResident.State.WAITING:
            record.until=clock.absolute_minutes+record.actor.wait_left*_minutes_per_second();record.travel_end=0
        else:
            record.goal=record.actor.current_step().position
            record.travel_end=clock.absolute_minutes+record.position.distance_to(record.goal)/record.original.speed*_minutes_per_second()
            record.until=record.travel_end+float(record.block.activities[record.index].minutes)
    record.actor.reparent(_parking,false)

func before_scene_change() -> void:
    switching=true
    for record:HutorDailyResidentState in states.values():_park(record)

func after_scene_change(_scene: StringName) -> void:
    switching=false
    if not initialized:return
    for record:HutorDailyResidentState in states.values():
        _choose(record);_reconcile(record)
        if not _active(record):_advance_virtual(record)
        if record.scene==active_scene() and not _is_virtual(record.scene):_materialize(record)
    _update_widget()

func _advance_virtual(record: HutorDailyResidentState) -> void:
    virtual_updates+=1
    if record.mode==&"travel":
        if clock.absolute_minutes>=record.travel_end:
            record.position=record.goal;_transfer(record)
        else:
            var progress:float=clampf((clock.absolute_minutes-record.updated)/maxf(.001,record.travel_end-record.updated),0,1)
            record.position=record.position.lerp(record.goal,progress)
    elif record.mode==&"boundary_in":
        if clock.absolute_minutes>=record.travel_end:
            record.position=_gate(record);record.mode=&"local";_start_journey(record)
    elif record.mode==&"boundary_out":
        if clock.absolute_minutes>=record.travel_end:_offsite(record)
    elif record.mode==&"offsite":
        var old:=record.activity;_set_virtual_phase(record)
        if old!=record.activity:_event(record,"virtual_work",String(record.activity))
    elif record.mode==&"local":
        var consumed:=0
        while clock.absolute_minutes>=record.until and consumed<32:
            var began:=record.until
            record.index=(record.index+1)%record.block.activities.size()
            _virtual_target(record,began)
            record.snapshot.clear();consumed+=1
        if record.travel_end>0:
            if clock.absolute_minutes>=record.travel_end:
                record.position=record.goal;record.travel_end=0
                _event(record,"virtual_activity",String(record.activity))
            else:
                var fraction:float=clampf((clock.absolute_minutes-record.updated)/maxf(.001,record.travel_end-record.updated),0,1)
                record.position=record.position.lerp(record.goal,fraction)
    record.updated=clock.absolute_minutes

func _virtual_target(record: HutorDailyResidentState, began: float) -> void:
    var activity:Dictionary=record.block.activities[record.index]
    record.activity=StringName(activity.id);record.goal=_point(record.scene,activity.point)
    record.travel_end=began+record.position.distance_to(record.goal)/record.original.speed*_minutes_per_second()
    record.until=record.travel_end+float(activity.minutes)

func _transfer(record: HutorDailyResidentState) -> void:
    if record.mode!=&"travel":return
    if _is_virtual(record.hop):
        var passage:=_gateway(record)
        record.mode=&"boundary_out";record.portal_direction=Vector2(passage.direction[0],passage.direction[1])
        record.portal_target=_gate(record)+record.portal_direction*float(passage.outside_distance)
        record.travel_end=clock.absolute_minutes+float(passage.outside_distance)/record.original.speed*_minutes_per_second()
        if _active(record):_enable_boundary(record)
        return
    var from:=record.scene;_park(record)
    record.scene=record.hop
    record.position=_door(from) if record.scene==&"village" else _point(record.scene,"Entry")
    record.mode=&"local";record.snapshot.clear()
    _event(record,"scene_changed",String(from)+" -> "+String(record.scene))
    _reconcile(record)
    if record.scene==active_scene():_materialize(record)

func _offsite(record: HutorDailyResidentState) -> void:
    if _active(record):
        record.actor.remove_collision_exception_with(travel.exterior.get_node("MapBounds"))
    _park(record);record.actor.set_physics_process(true)
    var passage:=_gateway(record)
    record.scene=StringName(passage.virtual_destination);record.mode=&"offsite"
    for block in record.schedule.blocks:
        if StringName(block.scene)==record.scene:record.block=block
    record.block_stamp=_block_start(record.block)
    _set_virtual_phase(record);_event(record,"left_for_work",String(passage.id))

func _enable_boundary(record: HutorDailyResidentState) -> void:
    record.actor.set_physics_process(false)
    record.actor.add_collision_exception_with(travel.exterior.get_node("MapBounds"))
    record.actor.activity_controller.clear_props()
    record.portal_blocked=0

func _physics_process(delta: float) -> void:
    if not initialized or switching or travel.busy or get_tree().paused:return
    _update_widget()
    for record:HutorDailyResidentState in states.values():
        if not _active(record):continue
        var actor:HutorResident=record.actor
        if actor.state==HutorResident.State.TALKING:continue
        if record.mode==&"boundary_out" and not _is_virtual(record.desired_scene):
            record.mode=&"boundary_in";record.portal_target=_gate(record)
        if record.mode==&"travel" and actor.state==HutorResident.State.WAITING:
            _transfer.call_deferred(record)
        elif record.mode==&"boundary_out" or record.mode==&"boundary_in":
            if actor.position.distance_to(record.portal_target)<2:
                if record.mode==&"boundary_out":_offsite.call_deferred(record)
                else:
                    actor.remove_collision_exception_with(travel.exterior.get_node("MapBounds"))
                    actor.set_physics_process(true);record.position=actor.position;record.mode=&"local"
                    _start_journey(record)
                continue
            var direction:Vector2=record.portal_target-actor.position
            actor.face_point(record.portal_target)
            actor.velocity=direction.normalized()*minf(record.original.speed*clock.speed,direction.length()/maxf(delta,.001))
            var before:=actor.position;actor.move_and_slide()
            actor.animator.apply("walk",actor.facing,&"",false)
            record.position=actor.position
            if actor.position.distance_to(before)<.1:record.portal_blocked+=delta
            else:record.portal_blocked=0
            if record.portal_blocked>2:
                # Keep the actor in the village and retry; never teleport through a wall.
                actor.remove_collision_exception_with(travel.exterior.get_node("MapBounds"))
                actor.set_physics_process(true);record.mode=&"local";_start_journey(record)

func _arrived(id: StringName, index: int) -> void:
    var record:HutorDailyResidentState=states.get(id)
    if record==null or record.mode!=&"local":return
    record.index=index%record.block.activities.size()
    var action:Dictionary=record.block.activities[record.index]
    record.activity=StringName(action.id);record.until=clock.absolute_minutes+float(action.minutes)
    record.position=record.actor.position;_event(record,"activity",String(record.activity))
    record.travel_end=0

func _speed_changed(_value: float) -> void:
    if not initialized:return
    for record:HutorDailyResidentState in states.values():
        if _active(record):
            record.actor.definition.speed=record.original.speed*clock.speed*(record.schedule.get("run_multiplier",1.0) if record.id==&"woodcutter_son" else 1.0)
            record.actor.wait_time_scale=clock.speed
    _update_widget()

func _scrub() -> void:
    if not initialized:return
    for record:HutorDailyResidentState in states.values():
        if _active(record) and record.actor.state==HutorResident.State.TALKING:continue
        _park(record);_choose(record);record.block=_requested(record);record.block_stamp=_block_start(record.block)
        record.scene=record.desired_scene;_set_virtual_phase(record,true)
        if record.scene==active_scene() and not _is_virtual(record.scene):_materialize(record)

func _release_session() -> void:
    initialized=false;clock.running=false
    if is_instance_valid(travel) and travel.residency_driver==self:travel.residency_driver=null
    for record:HutorDailyResidentState in states.values():
        if is_instance_valid(record.actor):record.actor.activity_controller.clear_props()
    for actor in _parking.get_children():actor.free()
    states.clear();events.clear()
    if is_instance_valid(_widget):_widget.hide()

func _exit_tree() -> void:
    _release_session();_parking.free()
