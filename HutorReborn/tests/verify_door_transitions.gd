extends "res://tests/verify_interiors.gd"
## Live Stage 4.7 population; actual input events drive every door, twice.
var life: Node
var started := 0
var finished := 0
var failures := 0
var results: Array[Dictionary] = []
var captures := ""

func wait_transition() -> void:
    var previous: Node2D = travel.active_world
    var deadline := Time.get_ticks_msec()+8000
    while travel.busy and Time.get_ticks_msec()<deadline:
        await process_frame
        if travel.active_world != previous:
            check(travel._fade.visible and travel._fade.modulate.a>=.99,"scene and camera switch under full black")
            previous=travel.active_world
    check(not travel.busy,"transition completes within deadline")
    await frames()

func key_e(pressed: bool, echo: bool = false) -> void:
    var event := InputEventKey.new()
    event.physical_keycode = KEY_E; event.keycode = KEY_E
    event.pressed = pressed; event.echo = echo
    Input.parse_input_event(event)
    Input.flush_buffered_events()
    await frames(2)

func capture(label: String) -> void:
    if captures.is_empty(): return
    # Test teleports must settle the camera before recording a playable view.
    var camera: Camera2D = travel.active_world.player.get_node("Camera2D")
    camera.reset_smoothing(); camera.force_update_scroll()
    await frames(3)
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(captures.path_join(label+".png"))

func identities() -> Dictionary:
    var result := {}
    for id in life.states: result[id] = life.states[id].actor.get_instance_id()
    return result

func priority_checks(world: Node2D, hero: CharacterBody2D) -> void:
    # An isolated road position makes selection/ray tests independent of resident routes.
    hero.position = Vector2(1100,2300)
    var info := HutorInteractable.new(); info.position = hero.position+Vector2(5,0)
    var door := HutorInteractable.new(); door.set_script(travel.DOOR)
    door.position = hero.position+Vector2(35,0)
    var talk := HutorDialogueInteractable.new(); talk.position=hero.position+Vector2(20,0)
    world.add_child(info); world.add_child(door)
    await frames()
    check(hero.sensor.target==door,"door beats closer inspection")
    world.add_child(talk); await frames()
    check(hero.sensor.target==talk,"closer NPC action remains selectable beside door")
    talk.position=hero.position+Vector2(45,0); await frames()
    check(hero.sensor.target==door,"closer door beats more distant NPC action")
    var wall := StaticBody2D.new(); wall.collision_layer=1
    var shape := CollisionShape2D.new(); var box := RectangleShape2D.new(); box.size=Vector2(4,30)
    shape.shape=box; wall.add_child(shape); wall.position=hero.position+Vector2(28,-5)
    world.add_child(wall); await frames()
    check(hero.sensor.target==info,"blocked high-priority actions never interact through walls")
    door.reach=10; talk.reach=10; await frames()
    check(hero.sensor.target==info,"unavailable actions fall back to nearby inspection")
    wall.free(); info.free(); door.free(); talk.free(); await frames()

func failure_checks(world: Node2D, hero: CharacterBody2D) -> void:
    var id := &"storehouse"
    var data: HutorBuildingDefinition=travel.buildings[id]
    var path := data.interior_scene
    var cached: Node2D=travel.rooms[id]; travel.rooms.erase(id)
    var before: Dictionary = travel._camera_snapshot(hero)
    var pos := hero.position
    data.interior_scene="res://scenes/interiors/missing_stage491.tscn"
    check(not travel.request_transition(id),"missing scene rejected before lock/fade")
    check(not travel.busy and not hero.controls_locked and not travel.last_error.is_empty(),"missing scene leaves controls available and reason recorded")
    check(world.hud.prompt_label.text=="Переход временно недоступен","nonmodal failure feedback uses existing prompt")
    var wrong := Resource.new(); ResourceSaver.save(wrong,"user://stage491_wrong.tres")
    data.interior_scene="user://stage491_wrong.tres"
    check(not travel.request_transition(id),"non-scene resource rejected safely")
    var fixture := Node2D.new(); var packed := PackedScene.new(); packed.pack(fixture); fixture.free()
    ResourceSaver.save(packed,"user://stage491_invalid.tscn")
    data.interior_scene="user://stage491_invalid.tscn"
    var finish_before := finished
    check(travel.request_transition(id),"invalid scene enters guarded loading path")
    await wait_transition()
    check(travel.active_world==world and not hero.controls_locked and finished==finish_before,"invalid room aborts without moving Hans or success signal")
    check(not travel._fade.visible and travel.last_error.contains("структура"),"failed load reveals current scene and records contract error")
    data.interior_scene=travel.buildings[&"elder"].interior_scene
    check(travel.request_transition(id),"wrong building scene enters guarded validation")
    await wait_transition()
    check(travel.active_id==&"" and not hero.controls_locked and not travel.rooms.has(id),"wrong room identity rejected without caching")
    check(hero.position==pos and travel._camera_snapshot(hero)==before,"failure preserves spawn and camera")
    data.interior_scene=path; travel.rooms[id]=cached
    await create_timer(2.1).timeout
    check(world.hud._notice_left==0,"failure notice expires without blocking input")
    check(failures==4,"all four load failures reported")
    for file in ["user://stage491_wrong.tres","user://stage491_invalid.tscn"]: DirAccess.remove_absolute(file)

func run() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--captures="): captures=arg.trim_prefix("--captures=")
    if not captures.is_empty(): DirAccess.make_dir_recursive_absolute(captures)
    travel=root.get_node("InteriorTravel"); life=root.get_node("VillageLife")
    travel.transition_started.connect(func(_id,_exiting):started+=1)
    travel.transition_finished.connect(func(_id,_exiting):finished+=1)
    travel.transition_failed.connect(func(_id,_reason):failures+=1)
    change_scene_to_file(travel.VILLAGE); await frames(12)
    var world: Node2D=travel.active_world
    var hero: CharacterBody2D=world.player
    var hero_id := hero.get_instance_id()
    life.clock.running=false
    var people := identities()
    var camera_before: Dictionary=travel._camera_snapshot(hero)
    check(life.enabled and life.initialized and people.size()==9,"live Stage 4.7 residency enabled with nine unique residents")
    await priority_checks(world,hero)
    for id in [&"inn",&"elder",&"herbalist",&"woodcutter",&"old_man",&"storehouse"]:
        var failures_before := failed
        var data: HutorBuildingDefinition=travel.buildings[id]
        var anchor: Node2D=world.get_node(data.exterior_anchor)
        var door: HutorInteractable=anchor.get_node("InteriorDoor")
        var inspection := anchor.get_parent().get_node_or_null("InteractionPoint") as HutorInteractable
        if inspection:
            check(door.global_position.distance_to(inspection.global_position)>door.reach+inspection.reach,String(id)+" inspection zone separated from door")
            hero.position=inspection.global_position; await frames()
            check(free_at(world,hero.position),String(id)+" inspection point physically clear")
            check(hero.sensor.target==inspection,String(id)+" relocated inspection reachable")
            await tap_e()
            check(world.hud.dialogue.visible and not travel.busy,String(id)+" description preserved at separate point")
            await tap_e(); check(not world.hud.dialogue.visible,String(id)+" description closes normally")
        var cached_id := 0
        for visit in range(2):
            # Reproduce the old conflict: five pixels below the original inspection.
            hero.position=anchor.global_position+Vector2(0,5); await frames()
            check(hero.sensor.target==door,String(id)+" original conflict approach now chooses door")
            check(world.hud.prompt.visible and world.hud.prompt_label.text=="E — Войти",String(id)+" exact entry prompt")
            check(free_at(world,hero.position),String(id)+" approach is clear")
            if visit==0: await capture(String(id)+"_door")
            var starts_before := started
            await key_e(true)
            check(travel.busy and hero.controls_locked,String(id)+" E locks movement during fade")
            check(not travel.request_transition(id),String(id)+" simultaneous request rejected")
            await key_e(true,true)
            await wait_transition()
            var room: Node2D=travel.active_world
            check(travel.active_id==id and room.scene_file_path==data.interior_scene,String(id)+" matching existing interior loaded")
            if room==world: quit(1); return
            if visit==0: cached_id=room.get_instance_id()
            check(room.get_instance_id()==cached_id,String(id)+" repeated visit reuses room")
            check(hero.get_instance_id()==hero_id and identities()==people,String(id)+" Hans and all nine NPC identities retained")
            check(hero.position==room.get_node("Entry").position and free_at(room,hero.position),String(id)+" clear Entry spawn")
            check(not hero.controls_locked and not room.hud.dialogue.visible,String(id)+" controls restored with no information card")
            check(hero.get_node("Camera2D").zoom==Vector2.ONE*data.camera_zoom,String(id)+" interior camera zoom")
            check(hero.sensor.target==room.get_node("Exit") and room.hud.prompt_label.text=="E — Выйти",String(id)+" exact exit prompt")
            if visit==0: await capture(String(id)+"_inside")
            await key_e(true,true); await frames(8)
            check(not travel.busy and started==starts_before+1 and travel.active_id==id,String(id)+" held E cannot retrigger exit")
            await key_e(false); await frames()
            var position_before := hero.position
            Input.action_press("move_up"); await frames(8); Input.action_release("move_up"); await frames()
            check(hero.position.y<position_before.y-5,String(id)+" movement works inside")
            hero.position=room.get_node("Entry").position; await frames()
            await tap_e(); await wait_transition()
            check(travel.active_world==world and travel.active_id==&"",String(id)+" exit returns to village")
            check(hero.position==door.global_position+Vector2(0,28) and free_at(world,hero.position),String(id)+" correct clear outdoor return")
            check(travel._camera_snapshot(hero)==camera_before,String(id)+" full outdoor camera restored")
            check(not hero.controls_locked and not world.hud.dialogue.visible,String(id)+" outdoor input restored without card")
            check(started==starts_before+2 and finished==started,String(id)+" exactly one completed transition per press")
            check(identities()==people,String(id)+" no NPC identity duplication on exit")
        results.append({"building":String(id),"passed":failed==failures_before,"visits":2})
    var abandoned: Node2D=world.get_node("Actors/Structures/AbandonedHouse")
    check(abandoned.find_children("InteriorDoor","",true,false).is_empty(),"abandoned building has no transition door")
    hero.position=abandoned.get_node("Entrance").global_position+Vector2(0,12);await frames()
    var starts_before := started
    await tap_e();await frames(8)
    check(started==starts_before and travel.active_world==world,"abandoned house stays closed under E")
    if world.hud.dialogue.visible: await tap_e()
    hero.position=Vector2(1100,2300); await frames()
    await failure_checks(world,hero)
    if not captures.is_empty():
        var file:=FileAccess.open(captures.path_join("results.json"),FileAccess.WRITE)
        file.store_string(JSON.stringify({"passed":passed,"failed":failed,"buildings":results},"  "))
    print("RESULT: ",passed," door transition checks passed, ",failed," failed")
    quit(0 if failed==0 else 1)
