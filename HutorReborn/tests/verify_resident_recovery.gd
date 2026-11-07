extends SceneTree
var passed := 0
var failed := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
    if ok: passed+=1; print("PASS: ",message)
    else: failed+=1; push_error("FAIL: "+message)
func ticks(count: int) -> void:
    for i in range(count): await physics_frame
func run() -> void:
    var world: Node2D = load("res://scenes/world/krivaya_sosna/krivaya_sosna.tscn").instantiate()
    root.add_child(world); current_scene=world
    var population: Node2D=world.get_node("Actors/Residents")
    await ticks(15)
    var npc: HutorResident=population.resident(&"innkeeper")
    for other in population.residents.values(): other.set_motion_paused(true)
    world.player.position=Vector2(1250,2450)
    # Use a known open courtyard, without writing any change to the map.
    npc.position=Vector2(1688,2328)
    npc._path=PackedVector2Array([npc.position,Vector2(1784,2328)])
    npc._path_index=1; npc.state=npc.State.MOVING
    npc.set_motion_paused(false)
    var start:=npc.position
    world.player.position=npc.position+Vector2(16,0)
    await ticks(20)
    check(npc.state==npc.State.YIELDING and npc.position==start,"resident yields instead of pushing Hans")
    check(world.player.position==start+Vector2(16,0),"Hans is not displaced by a friendly NPC")
    world.player.position=Vector2(1250,2450)
    await ticks(55)
    check(npc.position.distance_to(start)>6,"resident resumes after Hans clears the route")
    npc.set_motion_paused(true)
    var paused_at:=npc.position
    var saved_step:=npc.step_index
    await ticks(25)
    check(npc.position==paused_at and npc.step_index==saved_step,"external pause preserves position and schedule")
    npc.position=Vector2(1688,2328)
    npc._path=PackedVector2Array([npc.position,Vector2(1784,2328)])
    npc._path_index=1; npc.state=npc.State.MOVING
    # A temporary obstacle absent from the bake must trigger bounded recovery.
    var barrier:=StaticBody2D.new()
    barrier.collision_layer=1
    var foot:=CollisionShape2D.new()
    var shape:=RectangleShape2D.new(); shape.size=Vector2(12,38)
    foot.shape=shape; barrier.add_child(foot)
    world.add_child(barrier); barrier.position=Vector2(1712,2325)
    await ticks(2)
    var recoveries:=npc.recovery_count
    npc.set_motion_paused(false)
    await ticks(160)
    check(npc.recovery_count>recoveries,"unexpected temporary obstruction triggers recovery")
    check(npc.position.x<1703 and npc.position.distance_to(Vector2(1688,2328))<28,"blocked actor neither tunnels through the obstacle nor teleports")
    barrier.queue_free(); await ticks(3)
    var before_distance:=npc.distance_walked
    Engine.time_scale=5
    await ticks(180)
    Engine.time_scale=1
    check(npc.distance_walked>before_distance+15,"safe recovery resumes a valid routine after obstruction removal")
    check(population.navigation.max_solves_in_tick<=2,"recovery respects the shared per-tick path budget")
    var manager: Node=root.get_node("DialogueManager")
    # Scene removal while talking must release the original modal lock too.
    world.player.interaction_requested.emit(npc.get_node("Interaction").interact())
    await create_timer(.23).timeout
    check(manager.is_active() and npc.state==npc.State.TALKING,"interaction adapter owns only its accepted dialogue session")
    npc.queue_free()
    await create_timer(.18).timeout
    check(not manager.is_active() and not world.player.controls_locked and population.resident(&"innkeeper")==null,"removing a speaker safely releases player and director references")
    print("RESULT: ",passed," resident recovery checks passed, ",failed," failed")
    world.queue_free(); await process_frame
    quit(0 if failed==0 else 1)
