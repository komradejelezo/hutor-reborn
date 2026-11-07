extends Node2D
## Local lights only; the village's atmosphere and F3 state remain untouched.
var effects_enabled := true
func set_effects_enabled(value: bool) -> void:
    effects_enabled = value
    for light in get_children():
        if light is PointLight2D: light.set_process(value)
