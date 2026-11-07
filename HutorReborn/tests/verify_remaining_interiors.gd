extends "res://tests/verify_interiors.gd"
## Real doors/input/physics, prepared NPC actions and all nine retained identities.
func run() -> void:
    # Isolate the approved pre-schedule component fixture. Live residency has separate integration coverage.
    root.get_node("VillageLife").enabled=false
    travel=root.get_node("InteriorTravel")
    var village:Node2D=load("res://scenes/world/krivaya_sosna/krivaya_sosna.tscn").instantiate()
    root.add_child(village);current_scene=village;await frames(8)
    var hero:CharacterBody2D=village.player
    var hero_id:=hero.get_instance_id()
    var original_ids:=all_residents()
    var camera:Camera2D=hero.get_node("Camera2D")
    var outside:Dictionary=travel._camera_snapshot(hero)
    check(travel.buildings.size()==6,"one registry exposes six interiors")
    check(get_nodes_in_group("interactables").size()==23,"six doors preserve the nine conversations and eight inspections")
    for id in [&"woodcutter",&"old_man",&"storehouse"]:
        var data:HutorBuildingDefinition=travel.buildings[id]
        var door:HutorInteractable=village.get_node(data.exterior_anchor).get_node("InteriorDoor")
        hero.position=door.global_position+Vector2(0,12);await frames()
        check(free_at(village,hero.position),String(id)+" outside approach clear")
        check(hero.sensor.target==door,String(id)+" actual E selects entry")
        await tap_e();await wait_transition()
        var room:Node2D=travel.active_world
        check(room!=village and travel.active_id==id,String(id)+" entered through existing travel service")
        if room==village:quit(1);return
        check(hero.get_instance_id()==hero_id and room.player==hero,"same Hans instance")
        check(hero.position==room.get_node("Entry").position and free_at(room,hero.position),"safe precise indoor spawn")
        check(camera.zoom==Vector2(1.3,1.3) and not hero.controls_locked,"same indoor camera and restored control")
        var rect:Rect2=room.room_bounds
        check(rect.size.x<=448 and rect.size.y<=320,"compact single-room bounds: "+str(rect.size))
        check(room.get_node("Floor").get_used_cells().size()==int(rect.size.x*rect.size.y/1024),"complete editable 32px floor")
        check(room.get_node("Walls") is TileMapLayer,"saved modular wall layer")
        check(all_residents()==original_ids,"scene transfer creates no NPC copies")
        var lights:=room.find_children("*","PointLight2D",true,false)
        var local_lights:=not lights.is_empty()
        for lamp in lights:local_lights=local_lights and rect.grow(8).has_point(lamp.position) and lamp.base_energy>0
        check(local_lights,"all local lamps are inside this room and enabled")
        var solids_count:=0
        var decorative_count:=0
        for prop in room.get_node("Actors/Props").get_children():
            var shape:CollisionShape2D=prop.get_node("Solid/Feet")
            if shape.disabled:decorative_count+=1;continue
            check(not free_at(room,shape.global_position+Vector2(0,3),1),"actual furniture collision: "+prop.name)
            solids_count+=1
            var sprite:Sprite2D=prop.get_node("Art")
            check(is_equal_approx(sprite.scale.x,sprite.scale.y) and sprite.texture_filter==CanvasItem.TEXTURE_FILTER_NEAREST,"uniform Nearest art: "+prop.name)
        check(solids_count>=5 and decorative_count>0,"large objects solid, small decor nonblocking")
        var nav:HutorNpcNavigation=room.get_node("Actors/Residents/Navigation")
        var grid:AStarGrid2D=nav.grid_for(Rect2())
        var start:Vector2i=nav.closest_cell(grid,room.get_node("Entry").position)
        for point in room.get_node("NPCPoints").get_children():
            check(free_at(room,point.position),"prepared action/access point is physically clear: "+point.name)
            var goal:Vector2i=nav.closest_cell(grid,point.position)
            var path:PackedVector2Array=grid.get_point_path(start,goal)
            check(not path.is_empty(),"entry reaches prepared point: "+point.name)
            var route_clear:=not path.is_empty()
            for leg in range(1,path.size()):
                var samples:int=maxi(1,int(ceil(path[leg-1].distance_to(path[leg])/4)))
                for sample in range(samples+1):
                    route_clear=route_clear and free_at(room,path[leg-1].lerp(path[leg],float(sample)/samples))
            check(route_clear,"actual physics clears the entire access route: "+point.name)
        for definition in room.resident_definitions:
            check(original_ids.has(definition.id) and definition.dialogue_path=="res://dialogues/residents/"+String(definition.id)+".json","prepared route reuses original resident/data: "+String(definition.id))
            for step in definition.routine:
                check(free_at(room,step.position),"prepared indoor waypoint clear: "+String(definition.id))
        var population:Node2D=room.get_node("Actors/Residents")
        if id==&"woodcutter":
            check(population.residents.size()==3,"existing at-home family moved inside without new actors")
            for actor in population.residents.values():actor.set_physics_process(false)
            var manager:Node=root.get_node("DialogueManager")
            for actor in population.residents.values():
                var marker:HutorInteractable=actor.get_node("Interaction")
                var chosen:=false
                for offset in [Vector2(0,22),Vector2(22,0),Vector2(-22,0),Vector2(0,-22)]:
                    hero.position=marker.global_position+offset;await frames()
                    if free_at(room,hero.position) and hero.sensor.target==marker:chosen=true;break
                check(chosen,"reachable talk position: "+String(actor.definition.id))
                if not chosen:continue
                await tap_e();await create_timer(.26).timeout
                check(manager.is_active() and manager.data.id==actor.definition.dialogue_id,"original family dialogue opens through E")
                check(hero.controls_locked and actor.state==HutorResident.State.TALKING,"conversation locks both participants")
                manager.close_dialogue();await create_timer(.2).timeout
                check(not hero.controls_locked and actor.state!=HutorResident.State.TALKING,"conversation resumes original controller")
            for actor in population.residents.values():actor.set_physics_process(true)
        elif id==&"old_man":
            check(population.residents.is_empty(),"old man retains his approved pine-side route until future HOME scheduling")
            check(room.get_node("NPCPoints/ChairRest").get_meta("npc_id")==&"old_man","chair rest point carries the existing old_man ID")
            var seat:Marker2D=room.get_node("Actors/Props/Armchair/SeatPose")
            check(seat.global_position==seat.get_parent().global_position and seat.get_meta("future_action")=="sit","future seated pose is anchored to the actual chair")
            check(room.has_node(seat.get_meta("access_root_path")) and FileAccess.file_exists(seat.get_meta("pose_source")),"seat links a reachable approach and the original seated source")
        else:check(population.residents.is_empty() and room.resident_definitions.is_empty(),"storehouse has no permanent resident")
        # Ordinary movement must collide with every boundary, not leave the room.
        var positions:=[Vector2(rect.get_center().x,rect.position.y+20),Vector2(rect.position.x+20,rect.get_center().y),Vector2(rect.end.x-20,rect.get_center().y),Vector2(rect.get_center().x,rect.end.y-20)]
        var actions:=["move_up","move_left","move_right","move_down"]
        for i in 4:
            hero.position=positions[i];Input.action_press(actions[i]);await frames(25);Input.action_release(actions[i])
            check(rect.has_point(hero.position),"Hans remains inside physical wall: "+actions[i])
        hero.position=room.get_node("Entry").position;await frames()
        check(hero.sensor.target==room.get_node("Exit"),"existing exit is reachable")
        await tap_e();await wait_transition()
        check(travel.active_world==village and hero.position==door.global_position+Vector2(0,28),"returned to correct original building")
        check(travel._camera_snapshot(hero)==outside and not hero.controls_locked,"outside camera/input fully restored")
        check(free_at(village,hero.position) and all_residents()==original_ids,"return remains free and preserves nine identities")
        var cached_id:int=room.get_instance_id()
        check(travel.request_transition(id),"repeat entry accepted")
        await wait_transition()
        check(travel.active_world.get_instance_id()==cached_id,"repeat entry reuses same room")
        check(travel.request_transition(id,true),"repeat exit accepted")
        await wait_transition()
    print("RESULT: ",passed," remaining-interior checks passed, ",failed," failed")
    quit(0 if failed==0 else 1)
