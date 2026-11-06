extends SceneTree
const DATA = preload("res://scripts/dialogue/dialogue_data.gd")
const MARKER = preload("res://scripts/dialogue/dialogue_interactable.gd")
const DEMO = "res://dialogues/elder_demo.json"
var passed := 0
var failed := 0
var manager: Node
var world: Node2D
var choices: Array = []
var finished: Array = []

func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
    if ok:
        passed += 1
        print("PASS: ", message)
    else:
        failed += 1
        push_error("FAIL: " + message)
func frames(count: int = 2) -> void:
    for i in range(count): await process_frame
func key(code: Key, pressed: bool = true, echo: bool = false) -> void:
    var event := InputEventKey.new()
    event.physical_keycode = code
    event.keycode = code
    event.pressed = pressed
    event.echo = echo
    Input.parse_input_event(event)
    await frames()
func tap(code: Key) -> void:
    await key(code)
    await key(code, false)
func open_wait() -> void: await create_timer(0.22).timeout
func close_wait() -> void: await create_timer(0.16).timeout
func fixture() -> Dictionary:
    return {"id":"test", "start":"a", "nodes":[{"id":"a", "speaker":"Гость", "text":"Проверка кириллицы.", "end":true}]}

func run() -> void:
    manager = root.get_node("DialogueManager")
    manager.choice_selected.connect(func(d: String, line: String, answer: String): choices.append([d,line,answer]))
    manager.dialogue_finished.connect(func(d: String, reason: String): finished.append([d,reason]))
    var demo := DATA.from_file(DEMO)
    check(demo.is_valid() and demo.nodes.size() == 5, "external UTF-8 graph loads with three branches and a shared ending")
    check(not DATA.from_dictionary([]).is_valid(), "reject a non-object graph root")
    check(not DATA.from_dictionary({"id":"x"}).is_valid(), "reject incomplete graph metadata")
    var bad := fixture()
    bad.nodes.append(bad.nodes[0].duplicate(true))
    check(not DATA.from_dictionary(bad).is_valid(), "reject duplicate line IDs")
    bad = fixture(); bad.start = "missing"
    check(not DATA.from_dictionary(bad).is_valid(), "reject missing start")
    bad = fixture(); bad.nodes[0].erase("end"); bad.nodes[0].next = "missing"
    check(not DATA.from_dictionary(bad).is_valid(), "reject dangling transitions")
    bad = fixture(); bad.nodes[0].erase("end")
    check(not DATA.from_dictionary(bad).is_valid(), "reject nonterminal dead ends")
    bad = fixture(); bad.nodes[0].text = 42
    check(not DATA.from_dictionary(bad).is_valid(), "reject non-string text")
    bad = fixture(); bad.nodes[0].portraits = ["bad"]
    check(not DATA.from_dictionary(bad).is_valid(), "reject malformed emotion map")
    bad = fixture(); bad.nodes[0].next = "a"
    check(not DATA.from_dictionary(bad).is_valid(), "reject ambiguous terminal/next node")
    bad = fixture(); bad.nodes[0].erase("end"); bad.nodes[0].choices = [{"id":"c","text":"Ответ","next":"a","end":true}]
    check(not DATA.from_dictionary(bad).is_valid(), "reject an answer with both end and next")
    bad.nodes[0].choices = [{"id":"c","text":"Ответ","end":true},{"id":"c","text":"Повтор","end":true}]
    check(not DATA.from_dictionary(bad).is_valid(), "reject duplicate answer IDs")
    bad = fixture(); bad.nodes[0].choices = "bad"
    check(not DATA.from_dictionary(bad).is_valid(), "reject malformed choices")
    bad = fixture(); bad.nodes[0].end = "yes"
    check(not DATA.from_dictionary(bad).is_valid(), "reject non-boolean end flags")
    var malformed := FileAccess.open("user://stage41-invalid.json", FileAccess.WRITE)
    malformed.store_string("{broken JSON"); malformed.close()
    check(not DATA.from_file("user://stage41-invalid.json").is_valid(), "malformed JSON returns a validation error without opening UI")
    var source := fixture()
    var copied := DATA.from_dictionary(source)
    source.nodes[0].text = "Changed"
    check(copied.nodes.a.text != source.nodes[0].text, "validated graph owns a deep copy")
    world = load("res://scenes/world/krivaya_sosna/krivaya_sosna.tscn").instantiate()
    root.add_child(world)
    current_scene = world
    await frames(4)
    var player: CharacterBody2D = world.player
    var camera: Camera2D = player.get_node("Camera2D")
    var sensor: Node = player.sensor
    var original_camera_mode := camera.process_mode
    check(not manager.is_active() and manager.window == null and not manager.is_processing_input(), "normal F5 world has no dialogue window or idle input processing")
    check(not manager.start_file("res://dialogues/missing.json", player, world.hud) and not player.controls_locked, "missing JSON fails without locking the player")
    check(not manager.start_dialogue(DATA.from_dictionary({}), player, world.hud), "invalid graph cannot open a session")
    # Exercise the real existing world interaction route, without editing the map.
    var marker: HutorInteractable = MARKER.new()
    marker.title = "Поговорить"
    marker.dialogue_path = DEMO
    marker.position = player.position + Vector2(12, 0)
    world.add_child(marker)
    for i in range(4): await physics_frame
    check(sensor.target == marker, "new generic marker participates in the existing nearest/raycast sensor")
    # Begin before smoothing settles: dialogue must freeze the actual view.
    player.position.x += 2
    await key(KEY_E)
    check(manager.is_active() and manager.current_line == "greeting", "E opens through HutorInteractable and the existing world bridge")
    manager.window.characters_per_second = 1.0
    var frozen_center := camera.get_screen_center_position()
    await open_wait()
    check(manager.phase == manager.Phase.READING and manager.window.surface.modulate.a > .99, "window fades in and arms input")
    check(manager.window.typing and manager.window.body.visible_characters < manager.window.body.get_total_character_count(), "opening E does not skip the typewriter")
    await key(KEY_E, true, true)
    await key(KEY_E, true)
    check(manager.window.typing, "held opener and key-repeat cannot skip or double advance")
    check(not manager.start_file(DEMO, player, world.hud), "second conversation cannot replace an active session")
    var start_position := player.position
    Input.action_press("move_right")
    for i in range(12): await physics_frame
    check(player.position == start_position and player.velocity == Vector2.ZERO, "held WASD produces no movement during dialogue")
    check(camera.get_screen_center_position().is_equal_approx(frozen_center), "camera remains exactly still, even with pending smoothing")
    check(not sensor.is_physics_processing() and not world.hud.prompt.visible, "world interaction focus is suspended")
    world._show_description({"title":"Other", "text":"Must not open"})
    check(not world.hud.dialogue.visible, "other world interaction requests are blocked while speaking")
    await key(KEY_E, false)
    await tap(KEY_E)
    check(not manager.window.typing and manager.window.buttons.size() == 3, "released E reveals the full Cyrillic line and three answers")
    check(manager.window.portrait.texture.resource_path.ends_with("empty_portrait.svg"), "missing character portrait uses the decorative fallback")
    await tap(KEY_E)
    check(manager.current_line == "greeting", "E cannot accidentally confirm an answer")
    await tap(KEY_UP)
    check(manager.window.selected == 2, "up wraps from first answer to last")
    await tap(KEY_DOWN)
    await tap(KEY_DOWN)
    check(manager.window.selected == 1, "down chooses the second answer")
    await tap(KEY_ENTER)
    check(manager.current_line == "help_reply" and choices.back()[2] == "help", "Enter confirms the selected branch and emits its stable choice ID")
    await tap(KEY_ENTER)
    check(not manager.window.typing and manager.current_line == "help_reply", "one Enter reveals text without skipping its node")
    await tap(KEY_ENTER)
    check(manager.current_line == "farewell", "next links continue the sequence")
    await tap(KEY_ENTER)
    await tap(KEY_ENTER)
    check(manager.phase == manager.Phase.CLOSING and player.controls_locked, "input stays locked during fade-out")
    await close_wait()
    check(not manager.is_active() and not manager.window.surface.visible and not player.controls_locked, "terminal line closes the window and restores controls")
    check(camera.process_mode == original_camera_mode and sensor.is_physics_processing(), "camera and sensor processing states are restored")
    check(finished.back()[1] == "completed", "completion signal distinguishes a natural ending")
    for i in range(6): await physics_frame
    check(player.position.x > start_position.x, "previously held movement resumes after closing")
    Input.action_release("move_right")
    marker.queue_free()
    await frames()
    # Traverse every branch independently, including cancel/reopen cleanup.
    for i in range(3):
        check(manager.start_file(DEMO, player, world.hud), "reopen branch " + str(i))
        await open_wait()
        manager.window.reveal_all()
        manager.choose(99)
        check(manager.current_line == "greeting", "invalid choice index is ignored")
        manager.choose(i)
        check(manager.current_line == ["shelter_reply","help_reply","private_reply"][i], "branch " + str(i) + " has its own reply")
        await tap(KEY_ESCAPE)
        await close_wait()
        check(not manager.is_active() and not paused and finished.back()[1] == "cancelled", "Escape closes conversation without pausing the world")
    world._show_description({"title":"Колодец", "text":"Прежний осмотр"})
    check(world.hud.dialogue.visible and not manager.start_file(DEMO, player, world.hud), "old inspection remains modal and prevents dialogue overlap")
    await tap(KEY_E)
    check(not world.hud.dialogue.visible and not player.controls_locked, "old E inspection still closes and restores movement")
    await tap(KEY_ESCAPE)
    check(world.paused and not manager.start_file(DEMO, player, world.hud), "pause menu prevents starting a conversation")
    await tap(KEY_ESCAPE)
    check(not world.paused, "existing pause resumes normally")
    player.controls_locked = true
    sensor.set_physics_process(false)
    manager.start_file(DEMO, player, world.hud)
    await open_wait()
    manager.close_dialogue("cancelled")
    await close_wait()
    check(player.controls_locked and not sensor.is_physics_processing(), "pre-existing external lock and sensor state are preserved")
    player.controls_locked = false
    sensor.set_physics_process(true)
    # PNG/emotion selection is independent of any particular NPC art.
    var portrait_data := fixture()
    portrait_data.nodes[0].portrait = "res://assets/environment/smoke.png"
    portrait_data.nodes[0].emotion = "stern"
    portrait_data.nodes[0].portraits = {"stern":"res://assets/characters/hans.png"}
    manager.start_dialogue(DATA.from_dictionary(portrait_data), player, world.hud)
    await open_wait()
    check(manager.window.portrait.texture.resource_path.ends_with("characters/hans.png"), "emotion selects its own PNG texture")
    check(manager.window.portrait.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED and manager.window.portrait.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "portrait proportions and Nearest are explicit")
    manager.close_dialogue(); await close_wait()
    portrait_data.nodes[0].portraits.stern = "res://missing.png"
    manager.start_dialogue(DATA.from_dictionary(portrait_data), player, world.hud)
    await open_wait()
    check(manager.window.portrait.texture.resource_path.ends_with("environment/smoke.png"), "missing emotion falls back to the line's default PNG")
    manager.close_dialogue(); await close_wait()
    var end_choice := fixture()
    end_choice.nodes[0].erase("end")
    end_choice.nodes[0].choices = [{"id":"bye","text":"До свидания.","end":true}]
    manager.start_dialogue(DATA.from_dictionary(end_choice), player, world.hud)
    await open_wait()
    manager.window.reveal_all(); manager.choose(0)
    await close_wait()
    check(not manager.is_active(), "an answer may end a conversation directly")
    manager.start_file(DEMO, player, world.hud)
    await open_wait()
    manager.window.reveal_all()
    manager.choice_selected.connect(func(_d: String, _l: String, _c: String): manager.close_dialogue("external"), CONNECT_ONE_SHOT)
    manager.choose(0)
    check(manager.phase == manager.Phase.CLOSING and manager.current_line == "greeting", "an extension hook can cancel a choice without running a stale transition")
    await close_wait()
    manager.start_file(DEMO, player, world.hud)
    await open_wait()
    world.queue_free()
    await frames(4)
    check(not manager.is_active() and not manager.window.surface.visible and finished.back()[1] == "context_exited", "scene/actor removal safely tears down the modal session")
    print("RESULT: ", passed, " dialogue checks passed, ", failed, " failed")
    quit(0 if failed == 0 else 1)
