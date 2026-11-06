extends SceneTree
## Real GUI input/layout, not just direct signal emission. Needs a display.
const DATA = preload("res://scripts/dialogue/dialogue_data.gd")
var passed := 0
var failed := 0
var output := "/tmp/hutor-dialogue"
func _initialize() -> void:
    if not OS.get_cmdline_user_args().is_empty(): output = OS.get_cmdline_user_args()[0]
    call_deferred("run")
func check(ok: bool, message: String) -> void:
    if ok:
        passed += 1; print("PASS: ", message)
    else:
        failed += 1; push_error("FAIL: " + message)
func frames(count: int = 4) -> void:
    for i in range(count): await process_frame
func capture(name: String) -> void:
    await frames()
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(output + "-" + name + ".png")
func click(control: Control) -> void:
    var point := control.get_global_rect().get_center()
    var motion := InputEventMouseMotion.new()
    motion.position = point; motion.global_position = point
    Input.parse_input_event(motion)
    await frames()
    for down in [true, false]:
        var event := InputEventMouseButton.new()
        event.position = point; event.global_position = point
        event.button_index = MOUSE_BUTTON_LEFT; event.pressed = down
        Input.parse_input_event(event)
        await frames()
func key(code: Key) -> void:
    for down in [true, false]:
        var event := InputEventKey.new()
        event.physical_keycode = code; event.keycode = code; event.pressed = down
        Input.parse_input_event(event)
        await frames()
func run() -> void:
    var demo: Node = load("res://scenes/demo/dialogue_demo.tscn").instantiate()
    root.add_child(demo); current_scene = demo
    var manager := root.get_node("DialogueManager")
    await frames(10)
    check(not manager.is_active() and demo.launcher.is_visible_in_tree(), "opt-in demo initially shows a launch interaction, not an NPC or forced conversation")
    await click(demo.launcher)
    await create_timer(.25).timeout
    check(manager.is_active(), "actual mouse click opens the demo conversation")
    if not manager.is_active(): quit(1); return
    var window: CanvasLayer = manager.window
    check(window.typing and window.body.visible_characters > 0 and window.body.visible_characters < window.body.get_total_character_count(), "real timewriter visibly advances before completion")
    await click(window.buttons[0])
    check(window.typing and manager.current_line == "greeting", "mouse cannot select an answer while its line is still printing")
    await key(KEY_E)
    check(not window.typing and manager.current_line == "greeting", "real keyboard E reveals exactly one line")
    await frames()
    check(window.body.get_theme_font("normal_font").has_char("Я".unicode_at(0)), "rendered font supports Cyrillic glyphs")
    check(window.body.get_line_count() >= 2, "greeting wraps naturally in the actual layout")
    var panel: Control = window.get_node("Root/Panel")
    var panel_rect := panel.get_global_rect()
    check(panel_rect.position.y > 0 and panel_rect.end.y <= 540 and panel_rect.size.y <= 310, "bottom window leaves the upper game world visible")
    check(window.body.get_global_rect().end.x < panel_rect.end.x and window.footer.get_global_rect().end.y < panel_rect.end.y, "text and continuation hint stay within the authored frame")
    var answer_rect: Rect2 = window.buttons[2].get_global_rect()
    check(window.choices_scroll.get_global_rect().encloses(answer_rect), "all three demo answers fit without clipping")
    await capture("demo")
    await click(window.buttons[2])
    check(manager.current_line == "private_reply", "actual mouse hit selects the third branch")
    check(not demo.world.hud.dialogue.visible, "mouse selection does not leak into the legacy inspection UI")
    await key(KEY_ENTER)
    check(not window.typing and manager.current_line == "private_reply", "Enter reveals the reply without double advancing via GUI focus")
    await capture("reply")
    await key(KEY_ESCAPE)
    await create_timer(.16).timeout
    check(not manager.is_active() and demo.launcher.visible, "Escape closes and restores the launch interaction")
    await key(KEY_ENTER)
    await create_timer(.22).timeout
    check(manager.is_active() and manager.current_line == "greeting" and window.typing, "focused launch interaction works with Enter without skipping the greeting")
    await key(KEY_ESCAPE)
    await create_timer(.16).timeout
    # Stress the same window with long text/answers; no truncation of source data.
    var answers: Array = []
    for i in range(12): answers.append({"id":"answer_" + str(i), "text":"Длинный ответ %d: спросить о дороге через лес, старой сосне и путниках, что приходили в хутор до заката." % i, "end":true})
    var long_text := "Путник остановился у старой сосны. Дорога терялась в сумерках, но в окнах ещё теплился огонь. ".repeat(18)
    var data := DATA.from_dictionary({"id":"layout_test", "start":"a", "nodes":[{"id":"a","speaker":"Хранитель старых преданий и забытых дорог", "text":long_text,"portrait":"res://assets/environment/smoke.png","choices":answers}]})
    manager.start_dialogue(data, demo.world.player, demo.world.hud)
    demo.launcher.hide()
    await create_timer(.22).timeout
    window.reveal_all()
    await frames()
    check(window.body.text == long_text and window.body.get_content_height() > window.body.size.y, "very long Cyrillic text is preserved and scrollable inside its area")
    check(window.buttons.size() == 12 and window.choices_scroll.get_v_scroll_bar().max_value > window.choices_scroll.size.y, "many wrapped answers use their own scroll area")
    window.select_relative(-1)
    await frames()
    check(window.selected == 11 and window.choices_scroll.get_global_rect().encloses(window.buttons[11].get_global_rect()), "keyboard navigation scrolls the last long answer into view")
    var portrait_pixels: Image = window.portrait.texture.get_image()
    check(portrait_pixels.get_pixel(0,0).a < .01 and window.portrait.texture.resource_path.ends_with("smoke.png"), "transparent PNG loads in the portrait slot without adding a background")
    await capture("long-text")
    await click(window.buttons[11])
    await create_timer(.16).timeout
    check(not manager.is_active(), "mouse hit on a scrolled answer can finish the conversation")
    # Check real GUI behavior under the project's approved integer window stretch.
    root.size = Vector2i(1920, 1080)
    await frames()
    manager.start_file("res://dialogues/elder_demo.json", demo.world.player, demo.world.hud)
    demo.launcher.hide()
    await create_timer(.22).timeout
    window.reveal_all()
    await frames()
    check(window.get_node("Root").size == Vector2(960, 540) and window.buttons.size() == 3, "integer 2x window stretch retains the approved 960x540 UI layout")
    await capture("2x")
    manager.close_dialogue()
    await create_timer(.16).timeout
    demo.queue_free(); await frames()
    print("RESULT: ", passed, " dialogue render checks passed, ", failed, " failed")
    quit(0 if failed == 0 else 1)
