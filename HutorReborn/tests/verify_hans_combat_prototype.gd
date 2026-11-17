extends SceneTree
const ROOT = "res://assets/characters/hans_combat_prototype_v1/"
const VISUAL = preload("res://scenes/combat/prototype/HansCombatVisual.tscn")
var passed := 0
var failed := 0

func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
    if ok: passed += 1; print("PASS: ",message)
    else: failed += 1; push_error(message)
func frames(n: int = 4) -> void:
    for i in n: await process_frame
func idle_turn(arena: Control) -> void:
    for i in 5000:
        if not arena.busy: return
        await process_frame
    check(false,"prototype arena reaches player turn")

func run() -> void:
    var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROOT+"animation_manifest.json"))
    var alignment: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROOT+"alignment.json"))
    var resource: SpriteFrames = load(ROOT+"frames.tres")
    for kind in ["idle","dodge"]:
        var clip: StringName = &"combat_idle" if kind=="idle" else &"dodge"
        check(resource.get_frame_count(clip)==22,"22 ping-pong steps: "+kind)
        check(resource.get_animation_loop(clip)==(kind=="idle"),"loop only idle: "+kind)
        check(is_equal_approx(resource.get_animation_speed(clip),1000.0/manifest[kind].frame_duration_ms),"manifest timing: "+kind)
        var order: Array = manifest[kind].pingpong_order_1_based.map(func(n:float):return int(n))
        check(order.count(1)==1 and order.count(12)==1,"end indices are not doubled: "+kind)
        var strip: Texture2D = load(ROOT+kind+"/"+kind+"_strip.png")
        check(strip.get_size()==Vector2(manifest[kind].size[0]*12,manifest[kind].size[1]),"strip is horizontal, never a grid: "+kind)
        for step in order.size():
            var name: String = "%s_%02d" % [kind,order[step]]
            var tex: AtlasTexture = resource.get_frame_texture(clip,step)
            check(tex.atlas.resource_path==ROOT+kind+"/"+name+".png","exact manifest source: "+clip+"/"+str(step))
            var anchor: Array = alignment.frames[name].anchor
            check(Vector2(anchor[0],anchor[1])+tex.margin.position==Vector2(256,480) and tex.get_size()==Vector2(512,512),"foot origin in padded canvas: "+name)
        for i in range(1,13):
            var path: String = ROOT+kind+"/%s_%02d.png" % [kind,i]
            var raw := Image.load_from_file(path)
            var imported: Image = (load(path) as Texture2D).get_image()
            check(raw.get_size()==Vector2i(manifest[kind].size[0],manifest[kind].size[1]),"PNG dimensions: "+path.get_file())
            check(raw.get_format()==Image.FORMAT_RGBA8 and imported.get_data()==raw.get_data(),"import preserves every RGBA pixel: "+path.get_file())
    var actor: HutorHansCombatPrototype = VISUAL.instantiate()
    var other: HutorHansCombatPrototype = VISUAL.instantiate()
    root.add_child(actor); root.add_child(other)
    check(actor.current_sprite().animation==&"combat_idle" and actor.idle_sprite.is_playing(),"continuous idle starts automatically")
    check(actor.idle_sprite.texture_filter==CanvasItem.TEXTURE_FILTER_NEAREST and actor.dodge_sprite.texture_filter==CanvasItem.TEXTURE_FILTER_NEAREST,"nearest on both fixed-scale rigs")
    actor.idle_frame_ms=130;actor.dodge_frame_ms=60;actor.playback_speed=0.5
    check(is_equal_approx(actor.idle_sprite.sprite_frames.get_animation_speed(&"combat_idle"),1000.0/130) and other.idle_frame_ms==115 and is_equal_approx(other.idle_sprite.sprite_frames.get_animation_speed(&"combat_idle"),1000.0/115),"inspector timing is isolated per instance")
    actor.idle_frame_ms=115;actor.dodge_frame_ms=52;actor.playback_speed=1
    # Expensive synchronous PNG checks above must not become the first animation delta.
    await frames(5)
    var seen: Array[int] = []
    actor.dodge_sprite.frame_changed.connect(func():seen.append(actor.dodge_sprite.frame))
    check(actor.play_dodge() and not actor.play_dodge(),"dodge is one-shot with repeated-trigger protection")
    var began := Time.get_ticks_msec()
    await actor.dodge_finished
    var elapsed := Time.get_ticks_msec()-began
    check(elapsed>=1050 and elapsed<=1400,"22 × 52 ms dodge duration: "+str(elapsed)+" ms")
    check(seen.has(21) and not actor.dodging and actor.idle_sprite.frame==0 and actor.idle_sprite.visible and not actor.dodge_sprite.visible,"full dodge returns to idle frame zero without overlapping sprites")
    actor.play_dodge();actor.set_paused(true);var at: int=actor.dodge_sprite.frame
    await create_timer(.15).timeout
    check(actor.dodge_sprite.frame==at,"pause holds exact dodge frame")
    actor.set_paused(false);await actor.dodge_finished
    actor.play_dodge();actor.play_idle();await create_timer(.15).timeout
    check(not actor.dodging and not actor.dodge_sprite.is_playing(),"Idle button cancels dodge safely")
    actor.queue_free();other.queue_free();await frames()
    change_scene_to_file("res://scenes/combat/prototype/HansCombatPreview.tscn");await scene_changed;await frames()
    var viewer: Control = current_scene
    check(InputMap.has_action("interact"),"F6 viewer initializes existing autoload input bindings")
    viewer.backgrounds.select(1);viewer.backgrounds.item_selected.emit(1)
    check(viewer.backdrop.color==Color("e5e0d6"),"light background reveals source transparency")
    viewer.speed.value=0.5;viewer.idle_ms.value=125;viewer.dodge_ms.value=70
    check(viewer.visual.playback_speed==0.5 and viewer.visual.idle_frame_ms==125 and viewer.visual.dodge_frame_ms==70,"viewer controls tune actual animation")
    change_scene_to_file("res://scenes/combat/prototype/HansCombatPrototypeArena.tscn");await scene_changed;await frames()
    var arena: Control = current_scene;arena.fast.button_pressed=true
    arena._start_scenario("duel");await idle_turn(arena)
    check(is_instance_valid(arena.hans_visual) and not arena.views.hans.sprite.visible,"opt-in arena replaces only Hans presentation")
    arena.battle.act("defend");arena.battle.advance()
    arena.battle.units.wolf_a.accuracy=5
    # Choose a deterministic real miss, preserving the battle's own roll procedure.
    var seed_value:=1
    while true:
        arena.battle.rng.seed=seed_value
        if arena.battle.rng.randi_range(1,100)>5:break
        seed_value+=1
    arena.battle.rng.seed=seed_value
    var hp: int=arena.battle.units.hans.hp
    var response: Dictionary=arena.battle.act("attack","hans")
    check(response.ok and not response.events[0].hit,"battle engine produces a real resolved miss")
    arena._play(response.events,arena.epoch);await frames()
    check(arena.hans_visual.dodging,"resolved battle miss invokes dodge")
    check(arena.hans_visual.playback_speed==3.0,"arena ×3 presentation speed is respected")
    await create_timer(.55).timeout
    check(not arena.hans_visual.dodging and arena.battle.units.hans.hp==hp,"animation returns to idle and never changes HP")
    arena.battle.advance();arena.battle.act("defend");arena.battle.advance()
    arena.battle.units.wolf_a.accuracy=100
    arena.hans_visual.play_dodge()
    response=arena.battle.act("attack","hans")
    check(response.ok and response.events[0].hit and arena.battle.units.hans.hp<hp,"visible Dodge never grants invulnerability to an actual hit")
    await arena._play(response.events,arena.epoch)
    for id in ["ambush","companions","tincture","betrayal","forest"]:
        arena._start_scenario(id);await idle_turn(arena)
        check(is_instance_valid(arena.hans_visual),"original scenario works with visual adapter: "+id)
    arena._start_scenario("duel");await idle_turn(arena)
    arena.hans_visual.play_dodge();arena._restart();await idle_turn(arena)
    check(is_instance_valid(arena.hans_visual) and not arena.hans_visual.dodging,"restart during dodge discards only old visual")
    check(not root.get_node("VillageLife").initialized and not root.get_node("ChapterI").active,"viewer and prototype battles do not start quests, time or NPCs")
    change_scene_to_file("res://scenes/menu/MainMenu.tscn");await scene_changed;await frames()
    print("RESULT: ",passed," Hans combat prototype checks passed, ",failed," failed")
    quit(0 if failed==0 else 1)
