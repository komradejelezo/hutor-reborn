extends "res://tests/verify_interiors.gd"
## Real physics, same AStarGrid and resident bodies. Fixtures never edit the map.
var population: Node2D
var world: Node2D
var first: HutorResident
var second: HutorResident
var trace: Array[Dictionary] = []
var bad_motion := ""
var minimum_gap := INF

func configure(actor: HutorResident, start: Vector2, goal: Vector2) -> void:
    var data: HutorNpcDefinition=actor.definition.duplicate()
    data.speed=32;data.notices_player=false;data.routine=[]
    var step:=HutorNpcRoutineStep.new();step.position=goal;step.duration=120;step.duration_variation=0
    data.routine.append(step)
    actor.enter_location(data,population,start)
    actor.wait_time_scale=1

func watch(actors: Array, seconds: float, label: String) -> void:
    var end:=Time.get_ticks_msec()+int(seconds*1000)
    var previous: Dictionary={}
    for actor in actors:previous[actor.get_instance_id()]=actor.position
    while Time.get_ticks_msec()<end:
        await physics_frame
        for actor: HutorResident in actors:
            var before:Vector2=previous[actor.get_instance_id()]
            if actor.position.distance_to(before)>actor.definition.speed*actor.get_physics_process_delta_time()+.6:
                bad_motion="teleport in "+label
            if not free_at(world,actor.position,actor.definition.foot_radius):bad_motion="world collision in "+label
            previous[actor.get_instance_id()]=actor.position
        if actors.size()==2:minimum_gap=minf(minimum_gap,actors[0].position.distance_to(actors[1].position))
        if int(Engine.get_physics_frames())%12==0:
            var points:Array=[]
            for actor in actors:points.append({"x":actor.position.x,"y":actor.position.y,"state":actor.state})
            trace.append({"case":label,"points":points})
        var done:=true
        for actor in actors:done=done and actor.state==HutorResident.State.WAITING
        if done:return

func barrier(point: Vector2, size: Vector2) -> StaticBody2D:
    var body:=StaticBody2D.new();body.collision_layer=1
    var collider:=CollisionShape2D.new();var box:=RectangleShape2D.new();box.size=size
    collider.shape=box;body.add_child(collider);world.add_child(body);body.position=point
    return body

func run() -> void:
    root.get_node("VillageLife").enabled=false
    change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"));await frames(12)
    world=current_scene;population=world.get_node("Actors/Residents")
    for other in population.residents.values():other.set_motion_paused(true)
    first=population.resident(&"innkeeper");second=population.resident(&"woodcutter")
    var start:=Vector2(1688,2328);var goal:=Vector2(1816,2328)
    world.player.position=Vector2(1712,2328)
    configure(first,start,goal)
    await frames(3)
    world.player.position=first._path[mini(first._path_index+1,first._path.size()-1)]
    await frames(18)
    check(first.state==HutorResident.State.YIELDING or first.state==HutorResident.State.MOVING,"friendly short wait does not shove Hans")
    var hero_pos:Vector2=world.player.position
    await watch([first],10,"stationary_hans")
    check(first.state==HutorResident.State.WAITING and first.position.distance_to(goal)<2,"NPC passes stationary Hans without requiring him to leave")
    check(world.player.position==hero_pos,"NPC never displaces Hans")
    check(population.navigation.dynamic_solves>0,"existing grid performs a dynamic detour")
    # The unchanged player collision mask also permits Hans to stand on an NPC.
    world.player.position=start
    configure(first,start,goal)
    await frames(3) # Allow native initial-overlap recovery, not an authored warp.
    await watch([first],10,"overlapping_hans")
    check(first.state==HutorResident.State.WAITING,"NPC escapes an initial overlap with Hans without a permanent yield")
    first.set_motion_paused(true)
    world.player.position=Vector2(1100,2300)
    configure(first,start,goal);configure(second,goal,start)
    minimum_gap=INF
    await watch([first,second],14,"head_on")
    check(first.state==HutorResident.State.WAITING and second.state==HutorResident.State.WAITING,"head-on residents both reach their destinations")
    check(minimum_gap>=first.definition.foot_radius+second.definition.foot_radius-.25,"residents never overlap feet while passing")
    second.set_motion_paused(true);second.position=Vector2(1744,2328)
    configure(first,start,goal)
    await watch([first],10,"waiting_neighbor")
    check(first.state==HutorResident.State.WAITING,"walking resident passes stationary neighbor")
    second.position=Vector2(2000,2300)
    var wall:=barrier(Vector2(1712,2325),Vector2(12,40));await frames(3)
    configure(first,start,goal)
    var recovery_before:=first.recovery_count
    await watch([first],12,"temporary_barrier")
    check(first.state==HutorResident.State.WAITING and first.recovery_count>recovery_before,"unbaked static barrier is bypassed after bounded recovery")
    wall.free();await frames(3)
    wall=barrier(goal+Vector2(0,-3),Vector2(20,64));await frames(3)
    configure(first,goal-Vector2(48,0),goal)
    var solves_before:int=population.navigation.solve_count
    await watch([first],7,"occupied_goal")
    check(first.state!=HutorResident.State.WAITING and first.step_index==0,"blocked destination is not falsely completed or silently skipped")
    check(population.navigation.solve_count-solves_before<=12,"closed goal uses bounded backoff rather than continuous search")
    wall.free();await frames(3)
    await watch([first],9,"barrier_removed")
    check(first.state==HutorResident.State.WAITING and first.position.distance_to(goal)<2,"same task resumes when the obstacle is removed")
    check(bad_motion.is_empty(),"no visible teleport or passage through world geometry: "+bad_motion)
    check(population.navigation.max_solves_in_tick<=2 and population.navigation._cache.size()<=128,"dynamic paths respect existing solver/cache budgets")
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--trace="):
            var file:=FileAccess.open(arg.trim_prefix("--trace="),FileAccess.WRITE)
            file.store_string(JSON.stringify(trace,"  "))
    print("RESULT: ",passed," obstacle checks passed, ",failed," failed")
    quit(0 if failed==0 else 1)
