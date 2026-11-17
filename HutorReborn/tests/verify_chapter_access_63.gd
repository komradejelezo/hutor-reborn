extends "res://tests/verify_chapter_flow_70.gd"
## Physics-derived routes from the entrance, rather than teleporting to furniture.
var baseline:=false
var routes:Dictionary={}
func grid() -> AStarGrid2D:
    var w:Node2D=c.travel.active_world
    var g:=AStarGrid2D.new();g.region=Rect2i(Vector2i.ZERO,w.map_size/8);g.cell_size=Vector2(8,8);g.offset=Vector2(4,4)
    g.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_NEVER;g.update()
    var q:=PhysicsShapeQueryParameters2D.new();var shape:=CircleShape2D.new();shape.radius=7
    q.shape=shape;q.collision_mask=1;q.exclude=[w.player.get_rid()]
    for y in g.region.size.y:
        for x in g.region.size.x:
            var cell:=Vector2i(x,y);q.transform=Transform2D(0,g.get_point_position(cell)+Vector2(0,-3))
            if not w.get_world_2d().direct_space_state.intersect_shape(q,1).is_empty():g.set_point_solid(cell)
    return g
func approach(action:String,g:AStarGrid2D) -> PackedVector2Array:
    var w:Node2D=c.travel.active_world;var hero:CharacterBody2D=w.player
    var m:Node2D=w.get_node("ChapterWorld/Story_"+action)
    var start:=Vector2i(hero.position/8);var candidates:Array[Vector2i]=[]
    for y in range(int(m.position.y/8)-6,int(m.position.y/8)+7):
        for x in range(int(m.position.x/8)-6,int(m.position.x/8)+7):
            var cell:=Vector2i(x,y)
            if not g.is_in_boundsv(cell) or g.is_point_solid(cell):continue
            var p:=g.get_point_position(cell)
            if p.distance_to(m.position)>m.reach-3:continue
            var ray:=PhysicsRayQueryParameters2D.create(p+Vector2(0,-5),m.position+Vector2(0,-5),1);ray.exclude=[hero.get_rid()]
            if not w.get_world_2d().direct_space_state.intersect_ray(ray).is_empty():continue
            var selected:Node2D=null;var priority:=-2147483648;var distance:=INF
            for other in get_nodes_in_group("interactables"):
                var d:float=p.distance_to(other.global_position);var pr:int=other.interaction_priority()
                if d>other.reach or pr<priority or (pr==priority and d>=distance):continue
                ray.to=other.position+Vector2(0,-5)
                if not w.get_world_2d().direct_space_state.intersect_ray(ray).is_empty():continue
                selected=other;priority=pr;distance=d
            if selected==m:candidates.append(cell)
    candidates.sort_custom(func(a:Vector2i,b:Vector2i):return g.get_point_position(a).distance_squared_to(m.position)<g.get_point_position(b).distance_squared_to(m.position))
    for cell in candidates:
        var path:=g.get_point_path(start,cell)
        if not path.is_empty():return path
    return PackedVector2Array()
func walk(path:PackedVector2Array) -> void:
    var hero:CharacterBody2D=c.travel.active_world.player
    for p in path:
        for frame in 40:
            var d:=p-hero.position
            if d.length()<2:break
            for a in ["move_left","move_right","move_up","move_down"]:Input.action_release(a)
            Input.action_press("move_right" if d.x>0 else "move_left",minf(1,absf(d.x)/2))
            Input.action_press("move_down" if d.y>0 else "move_up",minf(1,absf(d.y)/2))
            await physics_frame
        if hero.position.distance_to(p)>4:check(false,"physical route stuck at "+str(p));break
    for a in ["move_left","move_right","move_up","move_down"]:Input.action_release(a)
    for i in 6:await physics_frame
func use_from_floor(action:String,g:AStarGrid2D) -> void:
    var m:Node2D=c.travel.active_world.get_node("ChapterWorld/Story_"+action)
    var path:=approach(action,g)
    print("ACCESS ",c.travel.active_id,"/",action," marker=",m.position," path_cells=",path.size())
    check(not path.is_empty(),"connected floor and unobstructed E selection: "+action)
    if path.is_empty() or baseline:return
    await walk(path)
    check(c.travel.active_world.player.sensor.target==m,"WASD approach selects "+action)
    var key:=InputEventKey.new();key.physical_keycode=KEY_E;key.keycode=KEY_E;key.pressed=true
    Input.parse_input_event(key);Input.flush_buffered_events();await frames(4)
    key=InputEventKey.new();key.physical_keycode=KEY_E;key.keycode=KEY_E
    Input.parse_input_event(key);Input.flush_buffered_events();await frames(4)
    await answer(action)
func run() -> void:
    c=root.get_node("ChapterI")
    for arg in OS.get_cmdline_user_args():
        if arg=="--baseline":baseline=true
        if arg.begins_with("--captures="):captures=arg.trim_prefix("--captures=");DirAccess.make_dir_recursive_absolute(captures)
    await c.start_new(true);c.life.clock.running=false
    for a in ["toy_started","wood_started","inn_work","mug_started","dry_started"]:c.apply(a)
    c.apply("wheel");await frames()
    await go("storehouse");await snap("storehouse")
    var g:=grid()
    for a in ["repair","dry_take"]:await use_from_floor(a,g)
    await go("inn");await snap("inn");g=grid()
    for a in ["take_dishes","deliver_dishes","take_mug"]:
        if baseline and a=="deliver_dishes":c.apply("take_dishes");await frames()
        await use_from_floor(a,g)
    if not baseline:
        check(c.state.count("fixed_toy")==1 and c.state.count("toy")==0 and c.state.count("wheel")==0,"floor repair consumes exactly toy + wheel")
        check(c.state.has("dishes_delivered") and c.state.count("dishes")==0 and c.state.count("mug")==1,"two distinct tables and reachable counter update actual inventory")
        await npc("innkeeper","work_paid")
        c.travel.active_world.player.position=c.travel.active_world.get_node("Entry").position;await frames()
        var bed_path:=approach("sleep",g);check(not bed_path.is_empty(),"connected floor route to bed")
        await walk(bed_path);check(c.travel.active_world.player.sensor.target==c.travel.active_world.get_node("ChapterWorld/Story_sleep"),"full-size bed can be selected from floor")
    await go("");c.travel.active_world.player.position=Vector2(1700,880);await frames()
    await snap("woodpile");g=grid();await use_from_floor("collect_logs",g)
    if not baseline:
        check(c.state.count("logs")==2,"visible woodpile gives exactly two bundles")
        await go("woodcutter");g=grid();await use_from_floor("deliver_logs",g)
        check(c.state.count("logs")==0 and c.state.has("wood_delivered"),"both bundles delivered to real stove from entrance")
        await go("herbalist");g=grid();await use_from_floor("dry_sort",g)
        check(c.state.count("dry")==0 and c.state.has("dry_sorted"),"herbalist sorting table physically reachable")
        await npc("woodcutter_son","toy_done");await npc("woodcutter_wife","wood_done")
        await npc("herbalist","dry_done");await npc("herbalist_brother","mug_owner");await npc("innkeeper","mug_done")
        check(c.state.SIDES.all(func(q:Array):return c.state.has(q[3])),"four errands finished through existing scene/dialogue connections")
        var expected:Dictionary=c.state.pack()
        for action in ["repair","collect_logs","deliver_logs","toy_done","wood_done","take_dishes","deliver_dishes","work_paid","take_mug","mug_done","dry_sort","dry_done"]:c.apply(action)
        check(c.state.pack()==expected,"repeat attempts cannot duplicate inventory, journal, relationships or rewards")
        check(c.save_game() and await c.load_game(true),"completed errands save/load through unchanged v1 format")
        check(c.state.pack()==expected,"all four quest states and rewards survive actual disk roundtrip")
    c.ui.menu();await scene_changed;await frames()
    print("RESULT: ",passed," access checks passed, ",failed," failed; baseline=",baseline)
    quit(0 if failed==0 else 1)
