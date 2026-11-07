extends SceneTree
var passed := 0
var failed := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
    if ok:
        passed += 1; print("PASS: ", message)
    else:
        failed += 1; push_error("FAIL: " + message)
func ticks(count: int = 3) -> void:
    for i in range(count): await physics_frame
func cell(p: Vector2) -> Vector2i: return Vector2i(floor(p.x/16),floor(p.y/16))
func run() -> void:
    var world: Node2D = load("res://scenes/world/krivaya_sosna/krivaya_sosna.tscn").instantiate()
    root.add_child(world); current_scene = world
    await ticks()
    var player: CharacterBody2D = world.player
    player.set_physics_process(false)
    var spawn := player.position
    var camera: Camera2D = player.get_node("Camera2D")
    var buildings: Array[Node2D] = []
    for node in world.get_node("Actors/Structures").get_children():
        if node.has_meta("building_role"): buildings.append(node)
    check(buildings.size() == 7, "seven role-tagged buildings, excluding the gate")
    var expected := {"ElderHouse":[Vector2(912,708),"elder"],"MillerHouse":[Vector2(1689,708),"woodcutter"],"CommonHouse":[Vector2(1287,1162),"storehouse"],"CarpenterHouse":[Vector2(834,1587),"old_man"],"HerbalistHouse":[Vector2(1739,1587),"herbalist"]}
    for name in expected:
        var node: Node2D = world.get_node("Actors/Structures/"+name)
        check(node.position == expected[name][0] and node.scale == Vector2.ONE and node.get_meta("building_role") == expected[name][1], "preserved location/scale and new role: "+name)
    check(world.get_node("Actors/Nature/CrookedPine").position == Vector2(485,885), "landmark remains at its approved anchor")
    check(world.map_size == Vector2i(2976,2560) and camera.zoom == Vector2.ONE and camera.limit_right == 2976 and camera.limit_bottom == 2560, "local east/south extension with updated limits and unchanged camera zoom")
    check(world.get_node("Ground").get_used_cells().size() == 5576 and world.get_node("Extension Ground").get_used_cells().size() == 1864, "legacy ground retained, exactly 1864 new editable cells appended")
    check(world.get_node("New Paths").get_used_cells().size() > 0 and world.get_node("New Paths").texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "separate native Nearest path additions")
    var inn: Node2D = world.get_node("Actors/Structures/Inn")
    var abandoned: Node2D = world.get_node("Actors/Structures/AbandonedHouse")
    check(inn.position == Vector2(1688,2264) and abandoned.position == Vector2(2700,1030), "inn by the approach road; abandoned house at the eastern woodland edge")
    check(inn.y_sort_enabled and inn.has_node("LeftWing") and inn.has_node("RightWing"), "inn has independent architectural wings and nested depth sorting")
    check(inn.find_children("*","CollisionShape2D",true,false).size() == 3, "inn has three actual wall footprints and a clear central courtyard")
    check(inn.find_children("*","PointLight2D",true,false).size() == 3, "inn uses three modest existing-type warm lights")
    check(abandoned.find_children("*","PointLight2D",true,false).is_empty(), "abandoned windows have no artificial lighting")
    check(world.find_children("*","CharacterBody2D",true,false).size() == 1, "only Hans exists; no NPCs added")
    check(get_nodes_in_group("interactables").size() == 8, "existing inspections retained; no new dialogue/quest triggers")
    var herb_garden: Node2D = world.get_node("Ground Objects/Garden104")
    check(herb_garden.get_meta("plot_role", "") == "medicinal_herbs" and herb_garden.find_children("*","CollisionShape2D",true,false).is_empty(), "medicinal herbs replace the vegetable plot without adding obstacles")
    # Full physics-derived grid, independent of the authoring road metadata.
    var grid := AStarGrid2D.new()
    grid.region = Rect2i(0,0,2976/16,2560/16)
    grid.cell_size = Vector2(16,16); grid.offset = Vector2(8,8)
    grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER; grid.update()
    var circle := CircleShape2D.new(); circle.radius = 7
    var query := PhysicsShapeQueryParameters2D.new()
    query.shape = circle; query.collision_mask = 1
    var space := player.get_world_2d().direct_space_state
    for y in range(grid.region.size.y):
        for x in range(grid.region.size.x):
            query.transform = Transform2D(0,Vector2(x*16+8,y*16+5))
            grid.set_point_solid(Vector2i(x,y),not space.intersect_shape(query,1).is_empty())
    var destinations: Dictionary = {}
    for building in buildings:
        check(building.has_node("Entrance"), "future interior anchor: "+str(building.name))
        if building.has_node("Entrance"): destinations[str(building.name)] = building.get_node("Entrance").global_position
    for target in get_nodes_in_group("interactables"): destinations["inspect: "+target.title] = target.global_position+Vector2(0,10)
    for marker in world.get_node("Future NPC Space").get_children():
        circle.radius = 24
        query.transform = Transform2D(0,marker.position+Vector2(0,-3))
        check(space.intersect_shape(query,1).is_empty(), "free future standing area: "+str(marker.name))
        destinations["space: "+str(marker.name)] = marker.position
    circle.radius = 7
    for name in destinations:
        var path := grid.get_point_path(cell(spawn),cell(destinations[name]))
        check(not path.is_empty(), "reachable: "+name)
        if path.is_empty(): continue
        player.position = spawn
        var clear := true
        for p in path:
            var contact := player.move_and_collide(p-player.position)
            if contact:
                print("CONTACT ",name,": ",player.position," with ",contact.get_collider().get_path())
                clear = false; break
            await physics_frame
        check(clear, "real Hans swept route: "+name)
    # Check the intended new road centres too, not just arbitrary detours.
    var plan: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/environment/krivaya_sosna/stage42/layout.json"))
    for road in plan.roads:
        player.position = Vector2(road.points[0][0],road.points[0][1])
        var clear := true
        for i in range(1,road.points.size()):
            var target := Vector2(road.points[i][0],road.points[i][1])
            # The last point at the edge deliberately exits through the world border.
            if target.y == 2560: target.y = 2538
            while player.position.distance_to(target) > .1:
                var next := player.position.move_toward(target,8)
                var contact := player.move_and_collide(next-player.position)
                if contact:
                    print("ROAD CONTACT ",road.name,": ",player.position," with ",contact.get_collider().get_path())
                    clear = false; break
                await physics_frame
            if not clear: break
        check(clear, "intended road centre unobstructed: "+str(road.name))
    # Physical collisions actually stop Hans, not only metadata rectangles.
    for building in [inn.get_node("Body"),inn.get_node("LeftWing"),inn.get_node("RightWing"),abandoned]:
        var footprint: CollisionShape2D = building.get_node("Solid/Footprint")
        player.position = footprint.global_position+Vector2(0,95)
        var contact := player.move_and_collide(Vector2(0,-150))
        check(contact != null, "solid building stops Hans: "+str(building.name))
    camera.position_smoothing_enabled = false
    for p in [Vector2(10,10),Vector2(2966,10),Vector2(10,2550),Vector2(2966,2550)]:
        player.position = p; camera.force_update_scroll(); await ticks()
        var center := camera.get_screen_center_position()
        var view := Rect2(center-Vector2(480,270),Vector2(960,540))
        check(Rect2(Vector2.ZERO,Vector2(2976,2560)).encloses(view), "camera stays within extended map: "+str(p))
    print("RESULT: ",passed," village checks passed, ",failed," failed")
    world.queue_free(); await process_frame
    quit(0 if failed == 0 else 1)
