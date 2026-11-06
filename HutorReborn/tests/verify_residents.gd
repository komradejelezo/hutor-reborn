extends SceneTree
const DATA = preload("res://scripts/dialogue/dialogue_data.gd")
var passed := 0
var failed := 0
var world: Node2D
var population: Node2D
var manager: Node
var visits: Dictionary = {}
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
    if ok:
        passed += 1; print("PASS: ",message)
    else:
        failed += 1; push_error("FAIL: "+message)
func ticks(count: int = 3) -> void:
    for i in range(count): await physics_frame
func key(code: Key, down: bool) -> void:
    var event := InputEventKey.new()
    event.physical_keycode = code; event.keycode = code; event.pressed = down
    Input.parse_input_event(event)
    await process_frame
func tap(code: Key) -> void:
    await key(code,true); await key(code,false)
func run() -> void:
    world = load("res://scenes/world/krivaya_sosna/krivaya_sosna.tscn").instantiate()
    root.add_child(world); current_scene = world
    population = world.get_node("Actors/Residents")
    manager = root.get_node("DialogueManager")
    world.player.position = Vector2(1250,2450)
    await ticks(16)
    var residents: Array = population.residents.values()
    check(residents.size()==9 and get_nodes_in_group("residents").size()==9,"exactly nine registered residents")
    check(world.find_children("*","CharacterBody2D",true,false).size()==10,"Hans plus nine NPC bodies; no extra residents")
    check(get_nodes_in_group("interactables").size()==17,"nine talk markers plus eight existing inspections")
    check(population.y_sort_enabled and world.get_node("Actors").y_sort_enabled,"population shares the existing world depth hierarchy")
    check(world.map_size==Vector2i(2976,2560) and world.player.speed==94 and world.player.collision_mask==1,"approved map and Hans movement/collision settings retained")
    var starts: Dictionary = {}
    for npc in residents:
        var id: String = npc.definition.id
        starts[id] = npc.global_position
        visits[id] = {}
        npc.routine_step_changed.connect(func(who: StringName,index: int): visits[String(who)][index]=true)
        var frames: SpriteFrames = npc.definition.frames
        var real_walk := true
        var honest_idle := true
        for direction in ["down","up","right","left"]:
            real_walk = real_walk and frames.has_animation("walk_"+direction) and frames.get_frame_count("walk_"+direction)>=2 and frames.get_animation_loop("walk_"+direction)
            honest_idle = honest_idle and frames.get_frame_count("idle_"+direction)==1 and not frames.get_animation_loop("idle_"+direction)
        check(real_walk and npc.get_node("AnimatedSprite2D").texture_filter==CanvasItem.TEXTURE_FILTER_NEAREST,"original animated four-way walk/Nearest: "+id)
        check(honest_idle,"one-frame idle is explicitly a non-looping fallback: "+id)
        var dialogue := DATA.from_file(npc.definition.dialogue_path)
        check(dialogue.is_valid() and dialogue.nodes.greeting.choices.size()>=2 and dialogue.id==npc.definition.dialogue_id,"valid independent branched dialogue: "+id)
        check(npc.definition.routine.size()>=3 and npc.collision_layer==4 and npc.collision_mask==1,"one shared controller, cyclic resource and non-blocking friendly layer: "+id)
        var grid: AStarGrid2D = population.navigation.grid_for(npc.definition.route_bounds)
        var valid := true
        var previous: Vector2i = population.navigation.closest_cell(grid,npc.global_position)
        for step in npc.definition.routine:
            var goal: Vector2i = population.navigation.cell(step.position)
            valid = valid and grid.is_in_boundsv(goal) and not grid.is_point_solid(goal) and not grid.get_point_path(previous,goal).is_empty()
            previous = goal
        check(valid,"every routine leg accounts for baked static obstacles: "+id)
    check(population.resident(&"woodcutter_son").definition.foot_radius < population.resident(&"woodcutter").definition.foot_radius,"child has its own proportions and smaller feet")
    # Actual simultaneous runtime, not a sequence of isolated teleports.
    Engine.time_scale = 6.0
    var inside := true
    var no_static_overlap := true
    var shape := CircleShape2D.new(); shape.radius = 4.5
    var query := PhysicsShapeQueryParameters2D.new(); query.shape=shape; query.collision_mask=1
    query.exclude = [world.player.get_rid()]
    var space: PhysicsDirectSpaceState2D = world.player.get_world_2d().direct_space_state
    for tick in range(1800):
        await physics_frame
        if tick%20: continue
        for npc in residents:
            inside = inside and Rect2(Vector2.ZERO,Vector2(world.map_size)).has_point(npc.global_position)
            if npc.definition.route_bounds.has_area(): inside = inside and npc.definition.route_bounds.has_point(npc.global_position)
            query.transform = Transform2D(0,npc.global_position+Vector2(0,-3))
            no_static_overlap = no_static_overlap and space.intersect_shape(query,1).is_empty()
        if tick%300==0: print("SIMULATION: ",tick/10," seconds; path solves ",population.navigation.solve_count)
    Engine.time_scale = 1.0
    check(inside,"180 simulated seconds: all residents stay inside the map and child/pine zones")
    check(no_static_overlap,"simultaneous residents never enter static walls, fences or trees")
    for npc in residents:
        var id: String = npc.definition.id
        check(npc.distance_walked>100 and npc.steps_completed>=npc.definition.routine.size(),"movement, waits and a complete schedule: "+id+" ("+str(npc.steps_completed)+" stops, "+str(npc.recovery_count)+" recoveries)")
        check(visits[id].size()==npc.definition.routine.size(),"all individual route stops visited: "+id)
    check(population.navigation.max_solves_in_tick<=2 and population.navigation._cache.size()<=128 and population.navigation.cache_hits>0,"bounded path budget and cache; no frame-by-frame recomputation")
    # All nine conversations go through real E, the existing sensor/world bridge,
    # and DialogueManager. Freeze only movement while arranging repeatable input.
    for npc in residents: npc.set_physics_process(false)
    await ticks()
    for npc in residents:
        var id: String = npc.definition.id
        var found := false
        for offset in [Vector2(0,18),Vector2(18,0),Vector2(-18,0),Vector2(0,-18),Vector2(0,10)]:
            world.player.position = npc.global_position+offset
            await ticks()
            if world.player.sensor.target == npc.get_node("Interaction"):
                found = true; break
        check(found,"existing E talk prompt can focus: "+id)
        if not found: continue
        var before: Vector2 = npc.global_position
        var step_index: int = npc.step_index
        var wait_left: float = npc.wait_left
        await tap(KEY_E)
        await create_timer(.23).timeout
        check(manager.is_active() and manager.data.id==npc.definition.dialogue_id and npc.state==npc.State.TALKING,"real E starts the existing dialogue and stops speaker: "+id)
        check(world.player.controls_locked and npc.global_position==before and npc.velocity==Vector2.ZERO,"Hans and speaker remain stopped: "+id)
        if not manager.is_active(): continue
        manager.window.reveal_all()
        manager.choose(0)
        check(manager.current_line=="reply_1","first reply branch: "+id)
        manager.window.reveal_all(); manager.advance()
        manager.window.reveal_all(); manager.advance()
        await create_timer(.16).timeout
        check(not manager.is_active() and not world.player.controls_locked and npc.state!=npc.State.TALKING and npc.step_index==step_index and is_equal_approx(npc.wait_left,wait_left),"closing restores player and suspended routine state: "+id)
        # A second branch is traversed too; use the same universal interaction API.
        world.player.interaction_requested.emit(npc.get_node("Interaction").interact())
        await create_timer(.23).timeout
        if manager.is_active():
            manager.window.reveal_all(); manager.choose(1)
            check(manager.current_line=="reply_2","second reply branch: "+id)
            manager.close_dialogue("cancelled"); await create_timer(.16).timeout
    # Smoke is tiny and respects F3 without editing the global atmosphere code.
    var old_man = population.resident(&"old_man")
    old_man.state = old_man.State.WAITING
    old_man.step_index = 0
    old_man._present()
    check(old_man.get_node("PipeSmoke").amount==3 and old_man.get_node("PipeSmoke").emitting,"old man smokes with only three optional particles")
    world.atmosphere.set_effects_enabled(false); old_man._present()
    check(not old_man.get_node("PipeSmoke").emitting,"F3 also disables the local pipe effect")
    world.atmosphere.set_effects_enabled(true)
    # Resume real motion after conversations, with Hans out of the way.
    world.player.position=Vector2(1250,2450)
    var before_distances: Dictionary = {}
    for npc in residents:
        before_distances[npc.definition.id]=npc.distance_walked
        npc.set_physics_process(true)
    Engine.time_scale=6
    await ticks(220)
    Engine.time_scale=1
    for npc in residents: check(npc.distance_walked>before_distances[npc.definition.id]+5,"routine movement resumes after dialogue: "+String(npc.definition.id))
    print("RESULT: ",passed," resident checks passed, ",failed," failed")
    world.queue_free(); await process_frame
    quit(0 if failed==0 else 1)
