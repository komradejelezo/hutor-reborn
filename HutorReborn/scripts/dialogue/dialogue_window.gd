extends CanvasLayer
## Presentation only: no graph traversal, player access or world changes.
signal opened
signal closed
signal answer_pressed(index: int)
@export_range(1.0, 200.0) var characters_per_second := 42.0
const FALLBACK = preload("res://assets/ui/dialogue/empty_portrait.svg")
const ANSWER = preload("res://assets/ui/dialogue/answer_leather.svg")
@onready var surface: Control = $Root
@onready var speaker: Label = $Root/Panel/Margins/Columns/Content/Heading/Speaker
@onready var body: RichTextLabel = $Root/Panel/Margins/Columns/Content/Line
@onready var portrait: TextureRect = $Root/Panel/Margins/Columns/PortraitColumn/Frame/Portrait
@onready var choices_scroll: ScrollContainer = $Root/Panel/Margins/Columns/Content/ChoicesScroll
@onready var choices_box: VBoxContainer = $Root/Panel/Margins/Columns/Content/ChoicesScroll/Choices
@onready var footer: Label = $Root/Panel/Margins/Columns/Content/Footer
var typing := false
var selected := 0
var buttons: Array[Button] = []
var _elapsed_characters := 0.0
var _line: Dictionary = {}
var _tween: Tween
var _portrait_cache: Dictionary = {}
var _normal: StyleBoxTexture
var _highlight: StyleBoxTexture
var _interactive := false

func _ready() -> void:
    _normal = _answer_style(Color(0.86, 0.84, 0.75))
    _highlight = _answer_style(Color(1.35, 1.21, 0.91))
    portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    set_process(false)

func _answer_style(tint: Color) -> StyleBoxTexture:
    var style := StyleBoxTexture.new()
    style.texture = ANSWER
    style.modulate_color = tint
    for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
        style.set_texture_margin(side, 8)
        style.set_content_margin(side, 11 if side == SIDE_LEFT or side == SIDE_RIGHT else 6)
    return style

func open_window() -> void:
    if _tween: _tween.kill()
    _interactive = false
    surface.modulate.a = 0.0
    surface.show()
    _tween = create_tween()
    _tween.tween_property(surface, "modulate:a", 1.0, 0.18)
    _tween.tween_callback(func():
        _interactive = true
        opened.emit())

func close_window() -> void:
    _interactive = false
    typing = false
    set_process(false)
    if _tween: _tween.kill()
    _tween = create_tween()
    _tween.tween_property(surface, "modulate:a", 0.0, 0.12)
    _tween.tween_callback(func():
        surface.hide()
        closed.emit())

func hide_immediately() -> void:
    if _tween: _tween.kill()
    typing = false
    _interactive = false
    surface.hide()
    set_process(false)

func show_line(line: Dictionary) -> void:
    _line = line
    speaker.text = line.speaker
    body.text = line.text
    body.visible_characters = 0
    body.scroll_to_line(0)
    portrait.texture = _resolve_portrait(line)
    _elapsed_characters = 0.0
    typing = true
    selected = 0
    for button in buttons:
        choices_box.remove_child(button)
        button.queue_free()
    buttons.clear()
    var choices: Array = line.get("choices", [])
    choices_scroll.visible = not choices.is_empty()
    for i in range(choices.size()):
        var button := Button.new()
        button.text = "%02d   ·   %s" % [i + 1, choices[i].text]
        button.alignment = HORIZONTAL_ALIGNMENT_LEFT
        button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        button.custom_minimum_size.y = 31
        button.add_theme_font_size_override("font_size", 15)
        button.add_theme_color_override("font_color", Color("c7bda2"))
        button.add_theme_color_override("font_hover_color", Color("eee0bc"))
        button.add_theme_color_override("font_focus_color", Color("eee0bc"))
        button.add_theme_stylebox_override("hover", _highlight)
        button.add_theme_stylebox_override("pressed", _highlight)
        button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
        var index := i
        button.pressed.connect(func():
            if _interactive and not typing: answer_pressed.emit(index))
        button.mouse_entered.connect(func():
            if not typing: _select(index, false))
        buttons.append(button)
        choices_box.add_child(button)
    # Reserve the answer area while printing, without exposing active choices.
    choices_box.modulate.a = 0.0
    choices_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
    for button in buttons:
        button.disabled = true
        button.focus_mode = Control.FOCUS_NONE
    _refresh_footer()
    set_process(true)

func _resolve_portrait(line: Dictionary) -> Texture2D:
    var variants: Dictionary = line.get("portraits", {})
    var candidates: Array = [variants.get(line.get("emotion", "neutral"), ""), line.get("portrait", ""), variants.get("neutral", "")]
    for path: String in candidates:
        if path.begins_with("res://") and path.get_extension().to_lower() == "png" and ResourceLoader.exists(path, "Texture2D"):
            if not _portrait_cache.has(path): _portrait_cache[path] = load(path) as Texture2D
            if _portrait_cache[path] != null: return _portrait_cache[path]
    return FALLBACK

func _process(delta: float) -> void:
    if not typing: return
    _elapsed_characters += delta * characters_per_second
    body.visible_characters = int(_elapsed_characters)
    if body.visible_characters >= body.get_total_character_count(): reveal_all()

func reveal_all() -> void:
    typing = false
    body.visible_characters = -1
    choices_box.modulate.a = 1.0
    choices_box.mouse_filter = Control.MOUSE_FILTER_PASS
    for button in buttons:
        button.disabled = false
        button.focus_mode = Control.FOCUS_ALL
    if not buttons.is_empty(): _select(0, false)
    _refresh_footer()
    set_process(false)

func select_relative(direction: int) -> void:
    if not buttons.is_empty(): _select(posmod(selected + direction, buttons.size()), true)

func _select(index: int, focus: bool) -> void:
    selected = index
    for i in range(buttons.size()):
        buttons[i].add_theme_stylebox_override("normal", _highlight if i == selected else _normal)
    if focus: buttons[selected].grab_focus()
    choices_scroll.ensure_control_visible(buttons[selected])

func _refresh_footer() -> void:
    if typing: footer.text = "E / Enter — показать реплику целиком     ·     Esc — закрыть"
    elif not buttons.is_empty(): footer.text = "↑ ↓ — выбрать     ·     Enter — ответить     ·     Можно выбрать мышью"
    else: footer.text = "E / Enter — %s     ·     Esc — закрыть" % ("завершить разговор  ◇" if _line.get("end", false) else "продолжить  ▷")
