extends SceneTree
## Run after importing: godot --headless --path . --script res://tests/verify_stage1.gd
var world: Node2D
var player: CharacterBody2D
var passed := 0
var failed := 0

func _initialize() -> void:
    call_deferred("run")

func check(condition: bool, message: String) -> void:
    if condition:
        passed += 1
        print("PASS: ",message)
    else:
        failed += 1
        push_error("FAIL: "+message)

func ticks(count: int) -> void:
    for i in range(count):
        await physics_frame

func warp(pos: Vector2) -> void:
    player.position = pos
    player.velocity = Vector2.ZERO
    await ticks(3)

func key(action: StringName) -> void:
    var event := InputEventAction.new()
    event.action = action
    event.pressed = true
    Input.parse_input_event(event)
    await process_frame
    event = InputEventAction.new()
    event.action = action
    event.pressed = false
    Input.parse_input_event(event)
    await process_frame

func run() -> void:
    world = load("res://scenes/world/outskirts.tscn").instantiate()
    root.add_child(world)
    current_scene = world
    player = world.get_node("Actors/Hans")
    await ticks(5)
    check(world.get_node("01_Ground") is TileMapLayer and world.get_node("02_MudAndPaths") is TileMapLayer and world.get_node("03_GroundDetails") is TileMapLayer,"three editable TileMapLayer nodes")
    check(world.get_node("01_Ground").get_used_cells().size()==48*36,"1536 × 1152 terrain populated")
    check(player.collision_mask==1 and player.collision_layer==2,"world and player collision layers")
    var sprite: AnimatedSprite2D = player.get_node("AnimatedSprite2D")
    check(sprite.sprite_frames.get_animation_names().size()==8,"four idle and four walking animations")
    for dir in ["up","down","left","right"]:
        check(sprite.sprite_frames.get_frame_count("walk_"+dir)==6,"six real walking frames: "+dir)
    await warp(Vector2(700,800))
    var start := player.position
    Input.action_press("move_up")
    await ticks(20)
    check(player.position.y < start.y-20,"forward movement")
    check(sprite.animation==&"walk_up","upward walking animation")
    Input.action_release("move_up")
    await ticks(3)
    check(player.facing=="up" and sprite.animation==&"idle_up","last facing direction retained at rest")
    await warp(Vector2(700,800))
    Input.action_press("move_up")
    Input.action_press("move_right")
    await ticks(4)
    check(absf(player.velocity.length()-player.speed)<0.01,"normalized diagonal movement")
    Input.action_release("move_up")
    Input.action_release("move_right")
    await warp(Vector2(526,548))
    Input.action_press("move_up")
    await ticks(80)
    Input.action_release("move_up")
    check(player.position.y>495 and player.position.y<500,"house collision blocks passage at the doorway")
    await ticks(4)
    check(player.sensor.target!=null and player.sensor.target.title=="Старая изба","door interaction reachable outside collision")
    await key("interact")
    check(world.hud.dialogue.visible and player.controls_locked,"E opens description and locks walking")
    await key("interact")
    check(not world.hud.dialogue.visible and not player.controls_locked,"second E closes without immediately reopening")
    for pair in [[Vector2(740,603),"Старый колодец"],[Vector2(943,487),"Хозяйственный сарай"],[Vector2(558,701),"Тлеющий костёр"],[Vector2(1200,767),"Дорога к хутору"]]:
        await warp(pair[0])
        check(player.sensor.target!=null and player.sensor.target.title==pair[1],"reachable interaction: "+pair[1])
    await warp(Vector2(840,620))
    Input.action_press("move_left")
    await ticks(30)
    Input.action_release("move_left")
    check(player.position.x>830,"fence blocks crossing")
    await warp(Vector2(9,1050))
    Input.action_press("move_left")
    await ticks(30)
    Input.action_release("move_left")
    check(player.position.x>=5.9,"map boundary collision")
    var camera: Camera2D = player.get_node("Camera2D")
    check(camera.position_smoothing_enabled and camera.limit_right==1536 and camera.limit_bottom==1152,"smooth camera and map limits")
    for corner in [Vector2(10,10),Vector2(1526,10),Vector2(10,1142),Vector2(1526,1142)]:
        await warp(corner)
        camera.reset_smoothing()
        camera.force_update_scroll()
        await process_frame
        var center := camera.get_screen_center_position()
        check(center.x>=479.0 and center.x<=1057.0 and center.y>=269.0 and center.y<=883.0,"camera viewport stays in bounds at "+str(corner))
    # Test every distinct solid footprint in isolation, away from the existing map.
    for object in ["shed","well","pine_0","birch_0","rock","stump","barrel","logs","sign","lantern","fence_v"]:
        var obstacle: Node2D = load("res://scenes/objects/"+object+".tscn").instantiate()
        obstacle.position = Vector2(2000,2000)
        world.add_child(obstacle)
        await warp(Vector2(2000,2050))
        Input.action_press("move_up")
        await ticks(65)
        Input.action_release("move_up")
        check(player.position.y>2000,"solid collision: "+object)
        obstacle.queue_free()
        await ticks(2)
    await warp(Vector2(700,648))
    check(get_nodes_in_group("interactables").size()==5,"five interaction components")
    check(get_nodes_in_group("ambient_particles").size()==3,"smoke, embers and atmospheric motes")
    world.atmosphere.set_effects_enabled(false)
    check(not world.atmosphere.fog.visible,"atmosphere toggle disables fog")
    world.atmosphere.set_effects_enabled(true)
    check(world.atmosphere.fog.visible,"atmosphere toggle restores fog")
    await key("pause")
    check(paused and world.hud.pause_panel.visible,"Esc pauses simulation")
    await key("pause")
    check(not paused and not world.hud.pause_panel.visible,"Esc resumes simulation")
    print("RESULT: ",passed," passed, ",failed," failed")
    world.queue_free()
    await process_frame
    quit(0 if failed==0 else 1)
