extends "res://tests/verify_interiors.gd"
## Conditional home occupancy, restoration, hold gating, repeat entry and physics.
func run() -> void:
    # Isolate the approved pre-schedule component fixture. Live residency has separate integration coverage.
    root.get_node("VillageLife").enabled=false
    travel=root.get_node("InteriorTravel")
    var village:Node2D=load("res://scenes/world/krivaya_sosna/krivaya_sosna.tscn").instantiate()
    root.add_child(village);current_scene=village;await frames(8)
    var hero:CharacterBody2D=village.player
    var population:Node2D=village.get_node("Actors/Residents")
    var brother:HutorResident=population.resident(&"herbalist_brother")
    brother.set_physics_process(false);brother.step_index=2
    brother.position=brother.current_step().position
    var herbalist:HutorResident=population.resident(&"herbalist")
    var previous_definition:HutorNpcDefinition=herbalist.definition
    var previous_position:=herbalist.position
    var previous_step:=herbalist.step_index
    var previous_wait:=herbalist.wait_left
    var original_id:=herbalist.get_instance_id()
    travel.request_transition(&"herbalist");await wait_transition()
    var room:Node2D=travel.active_world
    check(room.get_node("Actors/Residents").resident(&"herbalist_brother")==null,"brother working in the forest is absent indoors")
    check(room.get_node("Actors/Residents").resident(&"herbalist")==herbalist,"at-home herbalist is the original object")
    hero.position=room.room_bounds.position+Vector2(270,270)
    var indoor_walk_start:=herbalist.distance_walked
    Engine.time_scale=6
    for i in range(750):await physics_frame
    Engine.time_scale=1
    check(herbalist.distance_walked>indoor_walk_start+100,"real indoor routine traverses the furnished room")
    check(not travel.resident_locations.has(&"herbalist"),"household resident reaches door and resumes outdoor context")
    check(herbalist.get_instance_id()==original_id and herbalist.definition==previous_definition,"departure restores original ID and shared definition")
    check(herbalist.position==previous_position and herbalist.step_index==previous_step,"saved outdoor waypoint and position restored")
    check(absf(herbalist.wait_left-previous_wait)<.4,"outdoor waiting state preserved while interior runs")
    travel.request_transition(&"herbalist",true);await wait_transition()
    brother.set_physics_process(true)
    check(population.resident(&"herbalist")==herbalist and population.residents.size()==9,"all outside directors rebuild correctly on re-entry")
    var fog_before:bool=village.atmosphere.effects_enabled
    var data:HutorBuildingDefinition=travel.buildings[&"inn"]
    hero.position=village.get_node(data.exterior_anchor).get_node("InteriorDoor").global_position+Vector2(0,12)
    await frames()
    var press:=InputEventKey.new();press.physical_keycode=KEY_E;press.keycode=KEY_E;press.pressed=true
    Input.parse_input_event(press);await frames(3);await wait_transition()
    check(travel.active_id==&"inn","held E entered the inn once")
    if travel.active_id!=&"inn":quit(1);return
    check(not travel.request_transition(&"inn",true),"holding E cannot trigger the reverse transition")
    var release:=InputEventKey.new();release.physical_keycode=KEY_E;release.keycode=KEY_E;release.pressed=false
    Input.parse_input_event(release);await process_frame
    var inn:Node2D=travel.active_world
    var inn_id:=inn.get_instance_id()
    var keeper:HutorResident=inn.get_node("Actors/Residents").resident(&"innkeeper")
    var keeper_id:=keeper.get_instance_id()
    for i in range(3):
        inn.atmosphere.set_effects_enabled(i%2==0)
        travel.request_transition(&"inn",true);await wait_transition()
        check(village.atmosphere.effects_enabled==fog_before,"indoor F3 state never changes street fog/light")
        check(not population.residents.has(&"innkeeper"),"keeper remains inside while Hans is outside")
        travel.request_transition(&"inn");await wait_transition()
        check(travel.active_world.get_instance_id()==inn_id,"repeat visit reuses cached interior scene")
        check(inn.get_node("Actors/Residents").resident(&"innkeeper").get_instance_id()==keeper_id,"repeat visit retains the exact keeper object")
    # Every baked NPC step is clear in real physics; all furniture solids exist.
    var shape_checks:=0
    var point_checks:=0
    travel._room(&"elder")
    for cached in travel.rooms.values():
        if cached!=travel.active_world:
            travel.request_transition(&"inn",true);await wait_transition()
            travel.request_transition(cached.building_id);await wait_transition()
        var active:Node2D=travel.active_world
        for prop in active.get_node("Actors/Props").get_children():
            var body:StaticBody2D=prop.get_node_or_null("Solid")
            if not body:continue
            var collision:CollisionShape2D=body.get_node("Feet")
            if collision.disabled:continue
            check(not free_at(active,collision.global_position+Vector2(0,3),1),"solid furniture: "+String(active.building_id)+"/"+prop.name)
            shape_checks+=1
        for definition in active.resident_definitions:
            for step in definition.routine:
                check(free_at(active,step.position,6),"baked indoor waypoint is physically free: "+String(definition.id))
                point_checks+=1
        var navigation:HutorNpcNavigation=active.get_node("Actors/Residents/Navigation")
        var grid:AStarGrid2D=navigation.grid_for(Rect2())
        var start:Vector2i=navigation.closest_cell(grid,active.get_node("Entry").position)
        var connected:=true
        for definition in active.resident_definitions:
            for step in definition.routine:
                connected=connected and not grid.get_point_path(start,navigation.cell(step.position)).is_empty()
        check(connected,"entry connects to every authored indoor destination")
        # World geometry, not texture bounds, stops Hans at the four walls.
        var rect:Rect2=active.room_bounds
        var positions:=[Vector2(rect.get_center().x,rect.position.y+20),Vector2(rect.position.x+20,rect.get_center().y),Vector2(rect.end.x-20,rect.get_center().y),Vector2(rect.get_center().x,rect.end.y-20)]
        var actions:=["move_up","move_left","move_right","move_down"]
        for index in range(4):
            hero.position=positions[index]
            Input.action_press(actions[index]);await frames(30);Input.action_release(actions[index])
            check(rect.has_point(hero.position),"wall collision stops Hans: "+actions[index])
        travel.request_transition(active.building_id,true);await wait_transition()
        if cached!=travel.rooms.values().back():
            travel.request_transition(&"inn");await wait_transition()
    print("RESULT: ",passed," lifecycle/physics checks passed, ",failed," failed; ",shape_checks," furniture bodies, ",point_checks," waypoints")
    quit(0 if failed==0 else 1)
