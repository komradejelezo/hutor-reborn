extends SceneTree
var passed := 0
var failed := 0
var travel: Node
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
    if ok: passed += 1; print("PASS: ",message)
    else: failed += 1; push_error("FAIL: "+message)
func frames(count: int = 5) -> void:
    for i in count: await physics_frame
func wait_transition() -> void:
    var deadline := Time.get_ticks_msec()+8000
    while travel.busy and Time.get_ticks_msec()<deadline: await process_frame
    check(not travel.busy,"transition completes within deadline")
    await frames()
func tap_e() -> void:
    var event := InputEventKey.new();event.physical_keycode=KEY_E;event.keycode=KEY_E;event.pressed=true
    Input.parse_input_event(event);await process_frame
    event=InputEventKey.new();event.physical_keycode=KEY_E;event.keycode=KEY_E;event.pressed=false
    Input.parse_input_event(event);await process_frame
func free_at(world: Node2D, point: Vector2, radius: float = 6) -> bool:
    var shape:=CircleShape2D.new();shape.radius=radius
    var query:=PhysicsShapeQueryParameters2D.new();query.shape=shape;query.collision_mask=1
    query.transform=Transform2D(0,point+Vector2(0,-3))
    return world.get_world_2d().direct_space_state.intersect_shape(query,1).is_empty()
func all_residents() -> Dictionary:
    var ids: Dictionary={}
    var worlds: Array=[travel.exterior]
    worlds.append_array(travel.rooms.values())
    for world in worlds:
        if not is_instance_valid(world):continue
        for child in world.get_node("Actors/Residents").get_children():
            if child is CharacterBody2D:
                check(not ids.has(child.definition.id),"no duplicate identity "+String(child.definition.id))
                ids[child.definition.id]=child.get_instance_id()
    return ids
func run() -> void:
    # Isolate the approved pre-schedule component fixture. Live residency has separate integration coverage.
    root.get_node("VillageLife").enabled=false
    travel=root.get_node("InteriorTravel")
    var world:Node2D=load("res://scenes/world/krivaya_sosna/krivaya_sosna.tscn").instantiate()
    root.add_child(world);current_scene=world
    await frames(8)
    var hero:CharacterBody2D=world.player
    var hero_id:=hero.get_instance_id()
    var camera:Camera2D=hero.get_node("Camera2D")
    var original_zoom:=camera.zoom
    var original_limits:=[camera.limit_left,camera.limit_top,camera.limit_right,camera.limit_bottom,camera.position]
    var original_ids:=all_residents()
    check(original_ids.size()==9,"nine original resident objects")
    check(travel.buildings.size()==6,"six configured buildings, including the three unchanged 4.4 interiors")
    for id in [&"inn",&"elder",&"herbalist"]:
        var data:HutorBuildingDefinition=travel.buildings[id]
        var door:HutorInteractable=world.get_node(data.exterior_anchor).get_node("InteriorDoor")
        hero.position=door.global_position+Vector2(0,12)
        await frames()
        check(free_at(world,hero.position),String(id)+" outdoor approach clear")
        check(hero.sensor.target==door,String(id)+" E prompt selects actual door")
        await tap_e()
        check(travel.busy,String(id)+" real E starts fade")
        check(not travel.request_transition(id),"concurrent transition rejected")
        await wait_transition()
        var room:Node2D=travel.active_world
        check(travel.active_id==id and room!=world,String(id)+" interior loaded")
        if room==world:
            quit(1); return
        check(room.player.get_instance_id()==hero_id,"the same Hans object crossed scenes")
        check(hero.position.is_equal_approx(room.get_node("Entry").position),"correct indoor spawn")
        check(camera.zoom.is_equal_approx(Vector2(1.3,1.3)),"only camera zoom increased by 30 percent")
        check(hero.speed==94 and hero.walk_sprite_scale==1.0/24.0,"Hans movement and sprite scale unchanged")
        check(not hero.controls_locked,"control restored after fade")
        check(not world.is_inside_tree() and room.is_inside_tree(),"inactive village fully detached from physics/render/input")
        check(free_at(room,hero.position),"entry has no furniture collision")
        check(room.get_node("Floor") is TileMapLayer and room.get_node("Walls") is TileMapLayer,"editable floor/wall tile layers")
        var identities:=all_residents()
        check(identities==original_ids,"all nine identities retained across cached scenes")
        var manager:Node=root.get_node("DialogueManager")
        var population:Node2D=room.get_node("Actors/Residents")
        check(not population.residents.is_empty(),String(id)+" eligible residents are inside")
        for npc in population.residents.values():
            check(not world.get_node("Actors/Residents").residents.has(npc.definition.id),"indoor resident absent from village director")
            # Stop the routine at its actual free current position for deterministic input.
            npc.set_physics_process(false)
            var marker:HutorInteractable=npc.get_node("Interaction")
            hero.position=marker.global_position+Vector2(0,22)
            await frames()
            check(free_at(room,hero.position),String(npc.definition.id)+" talk approach is free")
            check(hero.sensor.target==marker,String(npc.definition.id)+" indoor E selects talk marker")
            await tap_e();await create_timer(.26).timeout
            check(manager.is_active() and manager.data.id==npc.definition.dialogue_id,"original dialogue ID opens indoors")
            check(hero.controls_locked and npc.state==HutorResident.State.TALKING,"both actors stop for indoor conversation")
            manager.window.reveal_all();manager.choose(0);manager.close_dialogue()
            await create_timer(.2).timeout
            check(not hero.controls_locked and npc.state!=HutorResident.State.TALKING,"indoor conversation releases movement")
            npc.set_physics_process(true)
        hero.position=room.get_node("Entry").position
        await frames()
        check(hero.sensor.target==room.get_node("Exit"),"exit prompt reachable")
        await tap_e();await wait_transition()
        check(travel.active_id==&"" and travel.active_world==world,"returned to original village scene")
        check(hero.position.distance_to(door.global_position+Vector2(0,28))<.1,"returned outside the correct building")
        check(camera.zoom==original_zoom and [camera.limit_left,camera.limit_top,camera.limit_right,camera.limit_bottom,camera.position]==original_limits,"exterior camera restored exactly")
        check(free_at(world,hero.position),"outdoor return is not inside a wall")
        check(all_residents()==original_ids,"leaving creates no resident copies")
        check(not hero.controls_locked and world.get_node("Actors/Residents").residents.size()>=4,"village controls and remaining residents resume")
    print("RESULT: ",passed," interior checks passed, ",failed," failed")
    quit(0 if failed==0 else 1)
