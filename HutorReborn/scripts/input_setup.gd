extends RefCounted
## Physical keys preserve WASD on a Russian keyboard layout.
static func ensure_actions() -> void:
    var bindings = {
        "move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
        "move_up": [KEY_W, KEY_UP], "move_down": [KEY_S, KEY_DOWN],
        "interact": [KEY_E], "pause": [KEY_ESCAPE], "atmosphere": [KEY_F3]
    }
    for action in bindings:
        if not InputMap.has_action(action):
            InputMap.add_action(action, 0.2)
        for key in bindings[action]:
            var event := InputEventKey.new()
            event.physical_keycode = key
            if not InputMap.action_has_event(action, event):
                InputMap.action_add_event(action, event)
