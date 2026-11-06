extends CanvasLayer
signal dismiss_requested
signal resume_requested
signal quit_requested
var prompt: PanelContainer
var prompt_label: Label
var dialogue: PanelContainer
var dialogue_title: Label
var dialogue_text: Label
var pause_panel: PanelContainer
var effect_label: Label
var sans: Font = preload("res://assets/fonts/DejaVuSans.ttf")
var serif: Font = preload("res://assets/fonts/DejaVuSerif.ttf")

func label(text: String, size: int = 13, color: Color = Color("c1c5ae"), heading: bool = false) -> Label:
    var item := Label.new()
    item.text = text
    item.add_theme_font_override("font", serif if heading else sans)
    item.add_theme_font_size_override("font_size", size)
    item.add_theme_color_override("font_color", color)
    return item

func panel() -> PanelContainer:
    var item := PanelContainer.new()
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.055, 0.085, 0.078, 0.95)
    style.border_color = Color(0.45, 0.43, 0.30, 0.8)
    style.set_border_width_all(1)
    style.content_margin_left = 18
    style.content_margin_right = 18
    style.content_margin_top = 13
    style.content_margin_bottom = 13
    item.add_theme_stylebox_override("panel", style)
    return item

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    var root := Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(root)
    var left := VBoxContainer.new()
    left.position = Vector2(30, 24)
    left.add_theme_constant_override("separation", 3)
    root.add_child(left)
    left.add_child(label("Х У Т О Р   /   В О З Р О Ж Д Е Н И Е", 10, Color("acaa81")))
    left.add_child(label("Окраина Хутора", 26, Color("e1d5af"), true))
    left.add_child(label("Вечереет. Лес становится тише.", 11, Color("a5b1a2")))
    var right := VBoxContainer.new()
    right.position = Vector2(750, 26)
    root.add_child(right)
    right.add_child(label("I  ·  ВОЗВРАЩЕНИЕ", 11, Color("c3b789")))
    right.add_child(label("Ганс · путник", 12))
    var footer := label("W A S D / ↑ ↓ ← →   идти       E   осмотреть       Esc   пауза", 11)
    footer.position = Vector2(30, 507)
    root.add_child(footer)
    effect_label = label("F3  ·  атмосфера вкл.", 10, Color("9aa78f"))
    effect_label.position = Vector2(787, 508)
    root.add_child(effect_label)
    prompt = panel()
    prompt.position = Vector2(338, 435)
    prompt.custom_minimum_size = Vector2(284, 44)
    prompt_label = label("", 13, Color("eddaaa"))
    prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    prompt.add_child(prompt_label)
    root.add_child(prompt)
    prompt.hide()
    dialogue = panel()
    dialogue.position = Vector2(180, 335)
    dialogue.custom_minimum_size = Vector2(600, 148)
    var content := VBoxContainer.new()
    content.add_theme_constant_override("separation", 8)
    dialogue.add_child(content)
    dialogue_title = label("", 20, Color("e5c989"), true)
    dialogue_text = label("", 13)
    dialogue_text.custom_minimum_size.x = 560
    dialogue_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    content.add_child(dialogue_title)
    content.add_child(dialogue_text)
    content.add_child(label("E / Esc   вернуться", 10, Color("9ca68f")))
    root.add_child(dialogue)
    dialogue.hide()
    pause_panel = panel()
    pause_panel.position = Vector2(320, 164)
    pause_panel.custom_minimum_size = Vector2(320, 210)
    var menu := VBoxContainer.new()
    menu.add_theme_constant_override("separation", 15)
    pause_panel.add_child(menu)
    menu.add_child(label("Тихая передышка", 22, Color("e5c989"), true))
    menu.add_child(label("Окраина Хутора · этап 1", 12))
    for text in ["Продолжить", "Выйти из игры"]:
        var button := Button.new()
        button.text = text
        button.add_theme_font_override("font", sans)
        button.add_theme_font_size_override("font_size", 14)
        if text == "Продолжить":
            button.pressed.connect(func(): resume_requested.emit())
        else:
            button.pressed.connect(func(): quit_requested.emit())
        menu.add_child(button)
    root.add_child(pause_panel)
    pause_panel.hide()

func set_focus(target: HutorInteractable) -> void:
    prompt.visible = target != null and not dialogue.visible and not pause_panel.visible
    if target:
        prompt_label.text = "[ E ]   " + target.title

func show_description(payload: Dictionary) -> void:
    dialogue_title.text = payload.title
    dialogue_text.text = payload.text
    dialogue.show()
    prompt.hide()

func close_description() -> void:
    dialogue.hide()

func set_paused(value: bool) -> void:
    pause_panel.visible = value
    prompt.hide()

func show_effects(enabled: bool) -> void:
    effect_label.text = "F3  ·  атмосфера " + ("вкл." if enabled else "выкл.")
