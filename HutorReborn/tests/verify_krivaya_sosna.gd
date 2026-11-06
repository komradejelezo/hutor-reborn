extends SceneTree
## Tests the saved map, physics and actual routes to all inspection points.
var world: Node2D
var player: CharacterBody2D
var passed:=0
var failed:=0
func _initialize() -> void:call_deferred("run")
func check(value: bool, description: String) -> void:
    if value:
        passed+=1
        print("PASS: ",description)
    else:
        failed+=1
        push_error("FAIL: "+description)
func ticks(count: int) -> void:
    for i in range(count):await physics_frame
func key(action: StringName) -> void:
    var event:=InputEventAction.new()
    event.action=action
    event.pressed=true
    Input.parse_input_event(event)
    await process_frame
    event=InputEventAction.new()
    event.action=action
    event.pressed=false
    Input.parse_input_event(event)
    await process_frame
func cell(point: Vector2) -> Vector2i:
    return Vector2i(floori(point.x/16),floori(point.y/16))
func run() -> void:
    world=load("res://scenes/world/krivaya_sosna/krivaya_sosna.tscn").instantiate()
    root.add_child(world)
    current_scene=world
    player=world.get_node("Actors/Hans")
    await ticks(5)
    var spawn:=player.position
    check(world.get_node("Ground") is TileMapLayer and world.get_node("Ground Details") is TileMapLayer,"native editable ground layers")
    check(world.get_node("Ground").get_used_cells().size()==58*48,"complete 1856 × 1536 ground")
    check(world.get_node("Actors/Structures").y_sort_enabled and world.get_node("Actors/Nature").y_sort_enabled and world.get_node("Actors/Props").y_sort_enabled,"shared actor Y-sort groups")
    check(world.has_node("Foreground/GateLintel") and world.has_node("Lighting"),"foreground arch and lighting groups")
    var elder:Node2D=world.get_node("Actors/Structures/ElderHouse")
    var miller:Node2D=world.get_node("Actors/Structures/MillerHouse")
    var common:Node2D=world.get_node("Actors/Structures/CommonHouse")
    var carpenter:Node2D=world.get_node("Actors/Structures/CarpenterHouse")
    var herbalist:Node2D=world.get_node("Actors/Structures/HerbalistHouse")
    check(elder.position.x<miller.position.x and elder.position.y==miller.position.y,"two upper houses: elder left, miller right")
    check(common.position.y>elder.position.y and common.position.y<carpenter.position.y,"common house in the middle row")
    check(carpenter.position.x<herbalist.position.x and carpenter.position.y==herbalist.position.y,"two lower houses: carpenter left, herbalist right")
    var pine:Node2D=world.get_node("Actors/Nature/CrookedPine")
    var well:Node2D=world.get_node("Actors/Props/VillageWell")
    check(pine.position.x<elder.position.x and well.position.y>common.position.y,"landmark pine left and well in lower centre")
    check(world.get_node("Actors/Structures/MainGate").position.y>well.position.y,"main entrance at the bottom")
    check(player.speed==94 and player.get_node("AnimatedSprite2D").sprite_frames==load("res://assets/characters/hans_frames.tres"),"existing Hans movement and original animation resource")
    var camera:Camera2D=player.get_node("Camera2D")
    check(camera.limit_right==1856 and camera.limit_bottom==1536 and camera.position_smoothing_enabled,"map camera bounds and smooth following")
    check(get_nodes_in_group("ambient_particles").size()==5,"five modest chimney smoke emitters")
    check(get_nodes_in_group("interactables").size()==8,"five houses, pine, well and open gate inspectable")
    # Derive a walkability grid from real collision shapes, not the builder's metadata.
    var grid:=AStarGrid2D.new()
    grid.region=Rect2i(0,0,116,96)
    grid.cell_size=Vector2(16,16)
    grid.offset=Vector2(8,8)
    grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_NEVER
    grid.update()
    var circle:=CircleShape2D.new()
    circle.radius=7
    var query:=PhysicsShapeQueryParameters2D.new()
    query.shape=circle
    query.collision_mask=1
    var space:=player.get_world_2d().direct_space_state
    for y in range(96):
        for x in range(116):
            query.transform=Transform2D(0,Vector2(x*16+8,y*16+5))
            grid.set_point_solid(Vector2i(x,y),not space.intersect_shape(query,1).is_empty())
    check(not grid.is_point_solid(cell(spawn)),"spawn is outside all solid footprints")
    var routes:Array=[]
    for target in get_nodes_in_group("interactables"):
        var approach:Vector2=target.global_position+Vector2(0,10)
        var destination:=cell(approach)
        var path:=grid.get_point_path(cell(spawn),destination)
        check(not path.is_empty(),"reachable from spawn: "+target.title)
        routes.append({"title":target.title,"path_points":path.size()})
        if path.is_empty():continue
        # Follow the physics-derived route with CharacterBody2D.move_and_slide().
        player.set_physics_process(false)
        player.position=spawn
        var collision_free:=true
        for point in path:
            var contact:=player.move_and_collide(point-player.position)
            collision_free=collision_free and contact==null
            await physics_frame
        check(collision_free,"collision-free swept route: "+target.title)
        player.velocity=Vector2.ZERO
        await ticks(4)
        check(player.position.distance_to(approach)<27,"physical route completed: "+target.title)
        check(is_instance_valid(player.sensor.target),"interaction sensor focuses after route: "+target.title)
        if is_instance_valid(player.sensor.target):
            await key("interact")
            check(world.hud.dialogue.visible,"E description opens: "+target.title)
            await key("interact")
            check(not world.hud.dialogue.visible,"E description closes: "+target.title)
        player.set_physics_process(true)
    # The gate itself is an opening, not a solid crossbar across the route.
    player.position=Vector2(910,1332)
    await ticks(3)
    Input.action_press("move_up")
    await ticks(65)
    Input.action_release("move_up")
    check(player.position.y<1260,"Hans can enter through the open main gate")
    # Physical contacts with representative large objects and the perimeter.
    for pair in [[Vector2(669,550),"elder"],[Vector2(910,1140),"well"]]:
        player.position=pair[0]
        await ticks(3)
        var start:Vector2=player.position
        Input.action_press("move_up")
        await ticks(50)
        Input.action_release("move_up")
        check(player.position.y>start.y-70,"collision blocks entry into "+pair[1])
    player.position=Vector2(343,690)
    await ticks(3)
    Input.action_press("move_up")
    await ticks(60)
    Input.action_release("move_up")
    check(player.position.y>=641,"crooked pine trunk blocks movement")
    player.position=Vector2(270,760)
    await ticks(3)
    Input.action_press("move_left")
    await ticks(40)
    Input.action_release("move_left")
    check(player.position.x>=249 and player.position.x<260,"vertical perimeter fence blocks crossing")
    player.position=Vector2(803,940)
    await ticks(3)
    Input.action_press("move_up")
    await ticks(50)
    Input.action_release("move_up")
    check(player.position.y>=908,"horizontal yard fence blocks crossing")
    player.position=spawn
    await ticks(3)
    Input.action_press("move_left")
    await ticks(5)
    check(player.get_node("AnimatedSprite2D").flip_h,"left movement preserves mirrored Hans")
    Input.action_release("move_left")
    world.atmosphere.set_effects_enabled(false)
    check(not world.atmosphere.fog.visible,"F3 atmosphere components disable")
    world.atmosphere.set_effects_enabled(true)
    await key("pause")
    check(paused and world.hud.pause_panel.visible,"pause preserved")
    await key("pause")
    check(not paused,"resume preserved")
    for corner in [Vector2(8,8),Vector2(1848,8),Vector2(8,1528),Vector2(1848,1528)]:
        player.position=corner
        camera.reset_smoothing()
        camera.force_update_scroll()
        await process_frame
        var center:=camera.get_screen_center_position()
        check(center.x>=479 and center.x<=1377 and center.y>=269 and center.y<=1267,"camera remains in map at "+str(corner))
    print("ROUTES: ",JSON.stringify(routes))
    print("RESULT: ",passed," passed, ",failed," failed")
    world.queue_free()
    await process_frame
    quit(0 if failed==0 else 1)
