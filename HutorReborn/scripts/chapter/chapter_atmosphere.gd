extends "res://scripts/interiors/interior_atmosphere.gd"
func set_effects_enabled(value:bool) -> void:
    super.set_effects_enabled(value)
    var mist:CanvasLayer=get_parent().get_node_or_null("Mist")
    if mist:mist.visible=value
