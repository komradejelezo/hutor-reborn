extends Node
## Single modal session; signals are extension points, not quest implementation.
signal dialogue_started(dialogue_id: String)
signal line_started(dialogue_id: String, line_id: String)
signal choice_selected(dialogue_id: String, line_id: String, choice_id: String)
signal dialogue_finished(dialogue_id: String, reason: String)
const DATA = preload("res://scripts/dialogue/dialogue_data.gd")
const WINDOW_PATH = "res://scenes/ui/dialogue_window.tscn"
enum Phase { IDLE, OPENING, READING, CLOSING }
var phase := Phase.IDLE
var data: HutorDialogueData
var current_line := ""
var window: CanvasLayer
var last_error := ""
var _actor: CharacterBody2D
var _hud: CanvasLayer
var _sensor: Node
var _camera: Camera2D
var _previous_lock := false
var _previous_sensor_physics := true
var _previous_camera_mode: ProcessMode
var _previous_focus: WeakRef
var _held_keys: Dictionary = {}
var _close_reason := "completed"

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    set_process_input(false)

func is_active() -> bool:
    return phase != Phase.IDLE

func start_file(path: String, actor: CharacterBody2D, hud: CanvasLayer = null) -> bool:
    return start_dialogue(DATA.from_file(path), actor, hud)

func start_dialogue(conversation: HutorDialogueData, actor: CharacterBody2D, hud: CanvasLayer = null) -> bool:
    last_error = ""
    if is_active() or get_tree().paused or not is_instance_valid(actor):
        last_error = "Разговор сейчас недоступен"
        return false
    if conversation == null or not conversation.is_valid():
        last_error = "Неверные данные диалога" if conversation == null else "; ".join(conversation.errors)
        return false
    if is_instance_valid(hud) and (hud.dialogue.visible or hud.pause_panel.visible):
        last_error = "Уже открыто другое окно"
        return false
    if not is_instance_valid(window):
        # Lazy loading also permits the editor's very first asset import.
        var scene: PackedScene = load(WINDOW_PATH)
        window = scene.instantiate()
        add_child(window)
        window.opened.connect(func():
            if phase == Phase.OPENING: phase = Phase.READING)
        window.closed.connect(_finish)
        window.answer_pressed.connect(choose)
    data = conversation
    _actor = actor
    _hud = hud
    _previous_lock = actor.controls_locked
    actor.controls_locked = true
    _sensor = actor.get_node_or_null("InteractionSensor")
    if is_instance_valid(_sensor):
        _previous_sensor_physics = _sensor.is_physics_processing()
        _sensor.set_physics_process(false)
    _camera = actor.get_node_or_null("Camera2D")
    if is_instance_valid(_camera):
        _previous_camera_mode = _camera.process_mode
        _camera.process_mode = Node.PROCESS_MODE_DISABLED
    if is_instance_valid(_hud): _hud.set_focus(null)
    var focused := get_viewport().gui_get_focus_owner()
    _previous_focus = weakref(focused) if focused else null
    if focused: focused.release_focus()
    actor.tree_exiting.connect(_context_exiting, CONNECT_ONE_SHOT)
    _held_keys.clear()
    for key in [KEY_E, KEY_ENTER, KEY_KP_ENTER]:
        if Input.is_physical_key_pressed(key): _held_keys[key] = true
    phase = Phase.OPENING
    set_process_input(true)
    current_line = data.start
    window.show_line(data.nodes[current_line])
    window.open_window()
    dialogue_started.emit(data.id)
    if phase == Phase.OPENING: line_started.emit(data.id, current_line)
    return true

func _input(event: InputEvent) -> void:
    if not is_active() or not event is InputEventKey: return
    get_viewport().set_input_as_handled()
    var key: int = event.physical_keycode if event.physical_keycode else event.keycode
    if not event.pressed:
        _held_keys.erase(key)
        return
    if event.echo or _held_keys.has(key): return
    if phase != Phase.READING: return
    match key:
        KEY_ESCAPE: close_dialogue("cancelled")
        KEY_UP:
            if not window.typing: window.select_relative(-1)
        KEY_DOWN:
            if not window.typing: window.select_relative(1)
        KEY_E, KEY_ENTER, KEY_KP_ENTER: advance(key != KEY_E)

func advance(confirm_answer: bool = false) -> void:
    if phase != Phase.READING: return
    if window.typing:
        window.reveal_all()
        return
    var line: Dictionary = data.nodes[current_line]
    if not line.get("choices", []).is_empty():
        if confirm_answer: choose(window.selected)
    elif line.get("end", false): close_dialogue()
    else: _go_to(line.next)

func choose(index: int) -> void:
    if phase != Phase.READING or window.typing: return
    var choices: Array = data.nodes[current_line].get("choices", [])
    if index < 0 or index >= choices.size(): return
    var choice: Dictionary = choices[index]
    choice_selected.emit(data.id, current_line, choice.id)
    if phase != Phase.READING: return
    if choice.get("end", false): close_dialogue()
    else: _go_to(choice.next)

func _go_to(id: String) -> void:
    current_line = id
    window.show_line(data.nodes[id])
    line_started.emit(data.id, current_line)

func close_dialogue(reason: String = "completed") -> void:
    if phase == Phase.IDLE or phase == Phase.CLOSING: return
    _close_reason = reason
    phase = Phase.CLOSING
    window.close_window()

func _context_exiting() -> void:
    _close_reason = "context_exited"
    if is_instance_valid(window): window.hide_immediately()
    _finish()

func _finish() -> void:
    if phase == Phase.IDLE: return
    var finished_id := data.id
    if is_instance_valid(_actor):
        _actor.controls_locked = _previous_lock
        if _actor.tree_exiting.is_connected(_context_exiting): _actor.tree_exiting.disconnect(_context_exiting)
    if is_instance_valid(_sensor): _sensor.set_physics_process(_previous_sensor_physics)
    if is_instance_valid(_camera): _camera.process_mode = _previous_camera_mode
    if is_instance_valid(_hud) and is_instance_valid(_sensor):
        _hud.set_focus(_sensor.target if is_instance_valid(_sensor.target) else null)
    if _previous_focus:
        var focused: Control = _previous_focus.get_ref()
        if is_instance_valid(focused) and focused.is_visible_in_tree(): focused.grab_focus()
    phase = Phase.IDLE
    set_process_input(false)
    data = null
    _actor = null
    _hud = null
    _camera = null
    _sensor = null
    _previous_focus = null
    _held_keys.clear()
    dialogue_finished.emit(finished_id, _close_reason)

func _exit_tree() -> void:
    if is_active(): _context_exiting()
