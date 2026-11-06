extends SceneTree
## Extra physical verification of every newly solid decorative instance.
var passed:=0
var failed:=0
func _initialize() -> void:call_deferred("run")
func check(ok:bool,message:String) -> void:
    if ok:
        passed+=1
        print("PASS: ",message)
    else:
        failed+=1
        push_error("FAIL: "+message)
func run() -> void:
    var world:Node2D=load("res://scenes/world/krivaya_sosna/krivaya_sosna.tscn").instantiate()
    root.add_child(world)
    current_scene=world
    var player:CharacterBody2D=world.get_node("Actors/Hans")
    player.set_physics_process(false)
    for i in range(4):await physics_frame
    var plan:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/environment/krivaya_sosna/stage32/layout.json"))
    var space:=player.get_world_2d().direct_space_state
    var circle:=CircleShape2D.new()
    circle.radius=7
    var query:=PhysicsShapeQueryParameters2D.new()
    query.shape=circle
    query.collision_mask=1
    var solids:=0
    var native_instances:=0
    for object in world.find_children("*","Node2D",true,false):
        if object.scene_file_path.begins_with("res://scenes/objects/krivaya_sosna/"):native_instances+=1
    check(native_instances==703,"same 703 environment scene instances; no object-count growth")
    check(world.map_size==Vector2i(2624,2176),"approved map dimensions retained")
    check(world.get_node("Actors/Nature/CrookedPine").position==Vector2(485,885),"unique original pine retains its anchor")
    var door_titles:Array=[]
    for point in get_nodes_in_group("interactables"):door_titles.append(point.title)
    check(door_titles.has("Дом охотника") and door_titles.size()==8,"existing lower-left inspection label follows hunter theme; no new dialogues")
    var placements_valid:=true
    for change in plan.changes:
        var object:Node2D=world.get_node(str(change.parent)+"/"+str(change.name))
        placements_valid=placements_valid and object.position==Vector2(change.position[0],change.position[1])
        if not str(change.name).begins_with("S32_") or not object.has_node("Solid/Footprint"):continue
        solids+=1
        var body:StaticBody2D=object.get_node("Solid")
        var foot:CollisionShape2D=object.get_node("Solid/Footprint")
        var center:=foot.global_position
        var detected:=false
        var swept:=false
        var point_query:=PhysicsPointQueryParameters2D.new()
        point_query.position=center
        point_query.collision_mask=1
        for hit in space.intersect_point(point_query,16):
            if hit.collider==body:detected=true
        # Near and far approaches cover compact yards and larger forest trunks.
        for distance in [44,70,94]:
            for direction in [Vector2.UP,Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT,Vector2(-1,-1).normalized(),Vector2(1,-1).normalized(),Vector2(-1,1).normalized(),Vector2(1,1).normalized()]:
                var start:Vector2=center+direction*distance
                query.transform=Transform2D(0,start)
                if not space.intersect_shape(query,1).is_empty():continue
                player.position=start+Vector2(0,3)
                var contact:=player.move_and_collide(center+Vector2(0,3)-player.position)
                if contact and contact.get_collider()==body:
                    swept=true
                    break
            if swept:break
        var art:Sprite2D=object.get_node("Art")
        var image:=art.texture.get_image()
        var visible_box:=image.get_used_rect()
        var scaled_box:=Rect2((Vector2(visible_box.position)+art.offset)*art.scale,Vector2(visible_box.size)*art.scale).grow(8)
        var shape:RectangleShape2D=foot.shape
        var physical_box:=Rect2(foot.position-shape.size/2,shape.size)
        if not (detected and swept and scaled_box.encloses(physical_box)):
            print("FOOTPRINT DIAGNOSTIC: ",change.name," detected=",detected," swept=",swept," art=",scaled_box," body=",physical_box)
        check(detected and swept and scaled_box.encloses(physical_box),"visible footprint and real Hans collision: "+str(change.name))
    check(solids==30,"30 solid detail instances; low litter and herbs remain passable")
    check(placements_valid,"all planned placements survive save/import")
    var mirrored:=0
    for change in plan.changes:
        if not str(change.kind).begins_with("mirror_"):continue
        var tree:Node2D=world.get_node(str(change.parent)+"/"+str(change.name))
        if tree.get_node("Art").flip_h:mirrored+=1
    check(mirrored>100,"mirrored native tree variations survive save/import")
    print("RESULT: ",passed," environment checks passed, ",failed," failed")
    world.queue_free()
    await process_frame
    quit(0 if failed==0 else 1)
