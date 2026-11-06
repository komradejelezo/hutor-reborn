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
    var size:Vector2i=world.map_size
    var layout:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/environment/krivaya_sosna/expanded_layout.json"))
    var expected_art:Dictionary={}
    for info in JSON.parse_string(FileAccess.get_file_as_string("res://assets/environment/krivaya_sosna/extraction.json")).objects:expected_art[info.name]=float(info.scale)
    var native_scales:=world.scale==Vector2.ONE
    for instance in world.find_children("*","Node2D",true,false):
        var key:String=instance.scene_file_path.get_file().get_basename()
        if expected_art.has(key):
            native_scales=native_scales and instance.scale==Vector2.ONE and instance.get_node("Art").scale.is_equal_approx(Vector2.ONE*expected_art[key])
    check(native_scales,"all houses, trees and props retain native scales")
    var area_ratio:float=float(size.x*size.y)/(1856.0*1536.0)
    check(area_ratio>1.98 and area_ratio<2.02,"map area approximately doubled")
    check(world.get_node("Ground") is TileMapLayer and world.get_node("Ground Details") is TileMapLayer,"native editable ground layers")
    check(world.get_node("Ground").get_used_cells().size()==(size.x/32)*(size.y/32),"complete expanded ground")
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
    check(camera.limit_right==size.x and camera.limit_bottom==size.y and camera.position_smoothing_enabled,"map camera bounds and smooth following")
    check(get_nodes_in_group("ambient_particles").size()==5,"five modest chimney smoke emitters")
    check(get_nodes_in_group("interactables").size()==8,"five houses, pine, well and open gate inspectable")
    # Derive a walkability grid from real collision shapes, not the builder's metadata.
    var grid:=AStarGrid2D.new()
    grid.region=Rect2i(0,0,size.x/16,size.y/16)
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
    for y in range(size.y/16):
        for x in range(size.x/16):
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
    var gate_position:Vector2=world.get_node("Actors/Structures/MainGate").global_position
    player.position=gate_position+Vector2(0,52)
    await ticks(3)
    Input.action_press("move_up")
    await ticks(65)
    Input.action_release("move_up")
    check(player.position.y<gate_position.y-20,"Hans can enter through the open main gate")
    # Physical contacts with representative large objects and the perimeter.
    for pair in [[elder.global_position+Vector2(24,50),"elder"],[well.global_position+Vector2(0,40),"well"]]:
        player.position=pair[0]
        await ticks(3)
        var start:Vector2=player.position
        Input.action_press("move_up")
        await ticks(50)
        Input.action_release("move_up")
        check(player.position.y>start.y-70,"collision blocks entry into "+pair[1])
    player.position=pine.global_position+Vector2(0,65)
    await ticks(3)
    Input.action_press("move_up")
    await ticks(60)
    Input.action_release("move_up")
    check(player.position.y>=pine.global_position.y+17,"crooked pine trunk blocks movement")
    var first_vertical:Node2D
    var first_horizontal:Node2D
    for object in world.get_node("Actors/Props").get_children():
        if not first_vertical and object.scene_file_path.ends_with("fence_v.tscn"):first_vertical=object
        if not first_horizontal and object.scene_file_path.ends_with("fence_h.tscn"):first_horizontal=object
    player.position=first_vertical.position+Vector2(32,-40)
    await ticks(3)
    Input.action_press("move_left")
    await ticks(40)
    Input.action_release("move_left")
    check(player.position.x>=first_vertical.position.x+11 and player.position.x<first_vertical.position.x+20,"vertical perimeter fence blocks crossing")
    player.position=first_horizontal.position+Vector2(0,40)
    await ticks(3)
    Input.action_press("move_up")
    await ticks(50)
    Input.action_release("move_up")
    check(player.position.y>=first_horizontal.position.y+8.5,"horizontal yard fence blocks crossing")
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
    for corner in [Vector2(8,8),Vector2(size.x-8,8),Vector2(8,size.y-8),Vector2(size.x-8,size.y-8)]:
        player.position=corner
        camera.reset_smoothing()
        camera.force_update_scroll()
        await process_frame
        var center:=camera.get_screen_center_position()
        check(center.x>=479 and center.x<=size.x-479 and center.y>=269 and center.y<=size.y-269,"camera remains in map at "+str(corner))
    # Every road centreline must be physically open, not merely bypassable over grass.
    var road_hits:Array=[]
    for road in layout.roads:
        for i in range(road.points.size()-1):
            var a:=Vector2(road.points[i][0],road.points[i][1])
            var b:=Vector2(road.points[i+1][0],road.points[i+1][1])
            var steps:int=ceili(a.distance_to(b)/8.0)
            for j in range(steps+1):
                var point:=a.lerp(b,float(j)/maxi(steps,1))
                if point.x<8 or point.y<8 or point.x>size.x-8 or point.y>size.y-8:continue
                query.transform=Transform2D(0,point+Vector2(0,-3))
                var hit:=space.intersect_shape(query,1)
                if not hit.is_empty():
                    road_hits.append({"road":road.name,"point":point,"collider":str(hit[0].collider.get_path())})
                    break
    print("ROAD HITS: ",JSON.stringify(road_hits))
    check(road_hits.is_empty(),"all road centrelines free of hidden solid obstacles")
    for point in layout.exploration_points:
        var path:=grid.get_point_path(cell(spawn),cell(Vector2(point.position[0],point.position[1])))
        check(not path.is_empty(),"forest exploration reachable: "+point.name)
    var blocked_plaza:=0
    for y in range(1365,1506,20):
        for x in range(1160,1481,20):
            if ((Vector2(x,y)-Vector2(1320,1435))/Vector2(220,105)).length()>.65:continue
            query.transform=Transform2D(0,Vector2(x,y-3))
            if not space.intersect_shape(query,1).is_empty():blocked_plaza+=1
    check(blocked_plaza==0,"central square has a clear open interior")
    var tiles:TileSet=world.get_node("Ground").tile_set
    check(tiles.resource_path=="res://assets/environment/krivaya_sosna/surfaces/expanded_surfaces.tres" and tiles==world.get_node("Ground Details").tile_set,"both ground layers share the external editable TileSet")
    check(tiles.get_terrain_sets_count()==2,"native road and mud Terrain Sets")
    var painted:=TileMapLayer.new()
    painted.tile_set=tiles
    world.add_child(painted)
    for terrain in range(2):
        painted.clear()
        var cells:Array[Vector2i]=[Vector2i(2,2),Vector2i(3,2),Vector2i(4,2),Vector2i(3,3),Vector2i(3,4)]
        painted.set_cells_terrain_connect(cells,terrain,0)
        var correct:=true
        for p in cells:correct=correct and painted.get_cell_source_id(p)==2 and painted.get_cell_tile_data(p).terrain_set==terrain
        check(correct,"native Terrain painting selects reusable brushes: "+str(terrain))
    painted.queue_free()
    print("ROUTES: ",JSON.stringify(routes))
    print("RESULT: ",passed," passed, ",failed," failed")
    world.queue_free()
    await process_frame
    quit(0 if failed==0 else 1)
