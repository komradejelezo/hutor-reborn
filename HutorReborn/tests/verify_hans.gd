extends SceneTree
## Tests supplied clips, mirroring and the foot pivot using real movement input.
var world: Node2D
var player: CharacterBody2D
var passed := 0
var failed := 0
func _initialize() -> void:
    call_deferred("run")
func ticks(count: int) -> void:
    for i in range(count):await physics_frame
func check(condition: bool, message: String) -> void:
    if condition:
        passed += 1
        print("PASS: ",message)
    else:
        failed += 1
        push_error("FAIL: "+message)
func run() -> void:
    world = load("res://scenes/world/outskirts.tscn").instantiate()
    root.add_child(world)
    current_scene = world
    player = world.get_node("Actors/Hans")
    await ticks(5)
    var sprite: AnimatedSprite2D = player.get_node("AnimatedSprite2D")
    var frames := sprite.sprite_frames
    for clip in ["walk_up","walk_down","walk_right","walk_left","idle_up","idle_down","idle_right","idle_left"]:
        var expected := 1 if clip in ["idle_up","idle_down"] else 3 if clip.begins_with("idle_") else 6 if clip in ["walk_up","walk_down"] else 8
        check(frames.get_frame_count(clip)==expected,"supplied frame count: "+clip)
        for index in range(expected):
            var texture := frames.get_frame_texture(clip,index)
            check(texture.get_size()==Vector2(960,1344),"native frame canvas: "+clip+" "+str(index))
    for mode in ["walk_","idle_"]:
        var shared := true
        for i in range(frames.get_frame_count(mode+"right")):
            shared = shared and frames.get_frame_texture(mode+"right",i)==frames.get_frame_texture(mode+"left",i)
        check(shared,"left reuses original right textures: "+mode)
    check(frames.get_frame_texture("idle_up",0)==frames.get_frame_texture("walk_up",2),"up idle uses a static original frame")
    check(frames.get_frame_texture("idle_down",0)==frames.get_frame_texture("walk_down",2),"down idle uses a static original frame")
    check(sprite.texture_filter==CanvasItem.TEXTURE_FILTER_NEAREST,"explicit nearest filtering")
    check(not sprite.centered and sprite.offset+Vector2(480,1280)==Vector2.ZERO,"native foot pivot maps to the body origin")
    for dir in ["left","right","up","down"]:
        player.position=Vector2(700,800)
        await ticks(3)
        Input.action_press("move_"+dir)
        await ticks(5)
        check(sprite.animation==StringName("walk_"+dir),"walking direction: "+dir)
        check(sprite.flip_h==(dir=="left"),"walking mirror: "+dir)
        check(sprite.scale.is_equal_approx(Vector2.ONE/24.0),"uniform walking scale: "+dir)
        var observed: Dictionary = {sprite.frame: true}
        var collect: Callable = func(): observed[sprite.frame] = true
        sprite.frame_changed.connect(collect)
        await ticks(65)
        sprite.frame_changed.disconnect(collect)
        check(observed.size()==frames.get_frame_count("walk_"+dir),"walking visits every supplied frame: "+dir)
        Input.action_release("move_"+dir)
        await ticks(3)
        check(sprite.animation==StringName("idle_"+dir),"idle keeps facing: "+dir)
        check(sprite.flip_h==(dir=="left"),"idle mirror: "+dir)
        var divisor := 21.0 if dir in ["left","right"] else 24.0
        check(sprite.scale.is_equal_approx(Vector2.ONE/divisor),"uniform idle scale: "+dir)
        if dir in ["left","right"]:
            var idle_frames: Dictionary = {sprite.frame: true}
            var collect_idle: Callable = func(): idle_frames[sprite.frame] = true
            sprite.frame_changed.connect(collect_idle)
            await ticks(85)
            sprite.frame_changed.disconnect(collect_idle)
            check(idle_frames.size()==3,"idle visits all three original frames: "+dir)
    check(player.speed==94.0 and player.collision_layer==2 and player.collision_mask==1,"movement speed and collision layers preserved")
    var feet: CollisionShape2D=player.get_node("CollisionShape2D")
    check(feet.position==Vector2(0,-3) and feet.shape.radius==6 and feet.shape.height==12,"original collision shape and anchor preserved")
    print("RESULT: ",passed," passed, ",failed," failed")
    world.queue_free()
    await process_frame
    quit(0 if failed==0 else 1)
