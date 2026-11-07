extends Node
## One session owns the same Hans and nine resident instances across cached scenes.
signal transition_started(building_id: StringName, exiting: bool)
signal transition_finished(building_id: StringName, exiting: bool)
const VILLAGE := "res://scenes/world/krivaya_sosna/krivaya_sosna.tscn"
const DOOR = preload("res://scripts/interiors/door.gd")
var buildings: Dictionary = {}
var exterior: Node2D
var active_world: Node2D
var active_id: StringName = &""
var rooms: Dictionary = {}
var resident_locations: Dictionary = {}
var busy := false
var _held_gate := false
var _outside_camera: Dictionary = {}
var _return_position := Vector2.ZERO
var _fade: ColorRect
var _overlay: CanvasLayer

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    var registry := "res://data/interiors/registry.json"
    if FileAccess.file_exists(registry):
        for path in JSON.parse_string(FileAccess.get_file_as_string(registry)):
            var data: HutorBuildingDefinition = load(path)
            if data: buildings[data.id] = data
    _overlay = CanvasLayer.new(); _overlay.layer = 100
    add_child(_overlay)
    _fade = ColorRect.new(); _fade.color = Color.BLACK
    _fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _overlay.add_child(_fade); _fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _fade.modulate.a = 0; _fade.hide()
    get_tree().root.child_entered_tree.connect(_root_added)

func _root_added(node: Node) -> void:
    if node.scene_file_path == VILLAGE: _bind_village.call_deferred(node)
    elif node.scene_file_path.begins_with("res://scenes/interiors/") and node.has_node("Entry") and node.has_node("Actors/Hans"):
        _preview_added.call_deferred(node)

func _preview_added(node: Node2D) -> void:
    if not is_instance_valid(exterior) and not busy:
        active_world = node; active_id = node.building_id
        rooms[active_id] = node

func _bind_village(world: Node2D) -> void:
    if not is_instance_valid(world) or world.has_meta("interior_doors_bound"): return
    exterior = world; active_world = world; active_id = &""
    world.set_meta("interior_doors_bound", true)
    for id in buildings:
        var data: HutorBuildingDefinition = buildings[id]
        var anchor: Node2D = world.get_node_or_null(data.exterior_anchor)
        if not anchor: continue
        var marker := HutorInteractable.new()
        marker.set_script(DOOR)
        marker.name = "InteriorDoor"
        marker.building_id = id
        marker.title = "Войти · " + data.display_name
        marker.reach = 58
        marker.position = data.door_offset
        anchor.add_child(marker)
        # Existing yard inspections remain available; the door has its own marker.

func request_transition(id: StringName, exiting: bool = false) -> bool:
    if busy or _held_gate or get_tree().paused or not buildings.has(id): return false
    if get_node("/root/DialogueManager").is_active(): return false
    if not is_instance_valid(active_world): return false
    if exiting and active_id != id: return false
    if not exiting and active_id != &"": return false
    busy = true
    _held_gate = Input.is_action_pressed("interact")
    active_world.player.controls_locked = true
    active_world.player.velocity = Vector2.ZERO
    active_world.hud.set_focus(null)
    transition_started.emit(id, exiting)
    _travel.call_deferred(id, exiting)
    return true

func _input(event: InputEvent) -> void:
    if event.is_action_released("interact"): _held_gate = false
    if busy or (_held_gate and event.is_action("interact")):
        get_viewport().set_input_as_handled()

func _fade_to(alpha: float) -> void:
    _fade.show()
    var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
    tween.tween_property(_fade, "modulate:a", alpha, .24)
    await tween.finished

func _camera_snapshot(hero: CharacterBody2D) -> Dictionary:
    var result := {}
    var camera: Camera2D = hero.get_node("Camera2D")
    for field in ["position", "zoom", "limit_left", "limit_top", "limit_right", "limit_bottom", "limit_smoothed", "position_smoothing_enabled", "position_smoothing_speed"]:
        result[field] = camera.get(field)
    return result

func _unbind(world: Node2D, hero: CharacterBody2D) -> void:
    if hero.interaction_requested.is_connected(world._show_description): hero.interaction_requested.disconnect(world._show_description)
    if hero.sensor.focus_changed.is_connected(world.hud.set_focus): hero.sensor.focus_changed.disconnect(world.hud.set_focus)
    if is_instance_valid(hero.sensor.target): hero.sensor.target.set_focused(false)
    hero.sensor.target = null; hero.sensor.target_id = 0
    world.hud.set_focus(null)
    world.hud.close_description()

func _bind(world: Node2D, hero: CharacterBody2D) -> void:
    if not hero.interaction_requested.is_connected(world._show_description): hero.interaction_requested.connect(world._show_description)
    if not hero.sensor.focus_changed.is_connected(world.hud.set_focus): hero.sensor.focus_changed.connect(world.hud.set_focus)
    world.player = hero
    world.get_node("Actors/Residents").player = hero

func _room(id: StringName) -> Node2D:
    if rooms.has(id) and is_instance_valid(rooms[id]): return rooms[id]
    var data: HutorBuildingDefinition = buildings[id]
    var packed: PackedScene = load(data.interior_scene)
    if packed == null: return null
    var room: Node2D = packed.instantiate()
    # The saved Hans is only for standalone F6 preview; runtime carries the original.
    room.get_node("Actors/Hans").free()
    rooms[id] = room
    return room

func _select_residents(id: StringName, room: Node2D) -> Array:
    var incoming: Array = []
    var data: HutorBuildingDefinition = buildings[id]
    var population: Node2D = exterior.get_node("Actors/Residents")
    for resident_id in data.residents:
        if resident_locations.has(resident_id): continue
        var actor: HutorResident = population.resident(resident_id)
        if not is_instance_valid(actor): continue
        var step := actor.current_step()
        var at_home: bool = step and step.action == HutorNpcRoutineStep.Action.HOME and actor.position.distance_to(step.position) < 110
        if not data.always_inside.has(resident_id) and not at_home: continue
        var local: HutorNpcDefinition = room.local_definition(resident_id)
        if not local: continue
        resident_locations[resident_id] = {"actor": actor, "snapshot": actor.suspend_location(), "room": id, "away": 0.0, "completed": actor.steps_completed}
        actor.reparent(room.get_node("Actors/Residents"), false)
        incoming.append(actor)
    return incoming

func _travel(id: StringName, exiting: bool) -> void:
    await _fade_to(1)
    var old: Node2D = active_world
    var hero: CharacterBody2D = old.player
    if exiting and not is_instance_valid(exterior):
        # Standalone F6 geometry preview returns to a normal village session.
        rooms.clear()
        get_tree().change_scene_to_file(VILLAGE)
        await get_tree().process_frame; await get_tree().process_frame
        await _fade_to(0); _fade.hide(); busy = false
        transition_finished.emit(id, true)
        return
    var destination: Node2D = exterior if exiting else _room(id)
    if not is_instance_valid(destination):
        await _fade_to(0); _fade.hide(); busy = false
        hero.controls_locked = false
        return
    var incoming: Array = []
    if not exiting:
        _outside_camera = _camera_snapshot(hero)
        var data: HutorBuildingDefinition = buildings[id]
        _return_position = exterior.get_node(data.exterior_anchor).global_position + data.door_offset + Vector2(0, 28)
        incoming = _select_residents(id, destination)
    _unbind(old, hero)
    hero.reparent(destination.get_node("Actors"), false)
    hero.position = _return_position if exiting else destination.get_node("Entry").position
    get_tree().root.remove_child(old)
    get_tree().root.add_child(destination)
    get_tree().current_scene = destination
    active_world = destination; active_id = &"" if exiting else id
    _bind(destination, hero)
    for actor in incoming:
        var data: HutorNpcDefinition = destination.local_definition(actor.definition.id)
        actor.enter_location(data, destination.get_node("Actors/Residents"), data.routine[0].position)
    var camera: Camera2D = hero.get_node("Camera2D")
    if exiting:
        for field in _outside_camera: camera.set(field, _outside_camera[field])
    else:
        camera.position = Vector2.ZERO
        camera.zoom = Vector2.ONE * buildings[id].camera_zoom
        camera.limit_left = 0; camera.limit_top = 0
        camera.limit_right = destination.map_size.x; camera.limit_bottom = destination.map_size.y
    camera.reset_smoothing(); camera.force_update_scroll()
    # Physics registration, sprite pose and sensor selection settle under black.
    hero.sensor.target = null; hero.sensor.target_id = 0
    for i in range(3): await get_tree().physics_frame
    camera.reset_smoothing(); camera.force_update_scroll()
    await _fade_to(0)
    _fade.hide(); hero.controls_locked = false; busy = false
    transition_finished.emit(id, exiting)

func _process(delta: float) -> void:
    if _held_gate and not Input.is_action_pressed("interact"): _held_gate = false
    if busy or get_tree().paused: return
    if not is_instance_valid(exterior): return
    for id in resident_locations.keys():
        var record: Dictionary = resident_locations[id]
        var data: HutorBuildingDefinition = buildings[record.room]
        if data.always_inside.has(id): continue
        var actor: HutorResident = record.actor
        if not is_instance_valid(actor):
            resident_locations.erase(id)
            continue
        if active_id == record.room:
            record.away = 0.0
            if actor.state != HutorResident.State.WAITING: continue
            if actor.step_index != actor.definition.routine.size()-1: continue
            # The last indoor waypoint is by the door. Conversations postpone departure.
        else:
            record.away += delta
            if record.away < data.return_delay: continue
        actor.reparent(exterior.get_node("Actors/Residents"), false)
        actor.restore_location(record.snapshot, exterior.get_node("Actors/Residents"))
        resident_locations.erase(id)

func _exit_tree() -> void:
    for room in rooms.values():
        if is_instance_valid(room) and room.get_parent() == null: room.free()
    if is_instance_valid(exterior) and exterior.get_parent() == null: exterior.free()
