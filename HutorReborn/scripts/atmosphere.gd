extends Node2D
## Low particle counts; fog is a single viewport pass. F3 toggles the effects.
var effects_enabled := true
@onready var fog: ColorRect = $Screen/Fog
@onready var actor: CharacterBody2D = get_node("../Actors/Hans")

func _process(_delta: float) -> void:
    if is_instance_valid(actor):
        fog.material.set_shader_parameter("camera_world", actor.get_node("Camera2D").get_screen_center_position())

func set_effects_enabled(enabled: bool) -> void:
    effects_enabled = enabled
    fog.visible = enabled
    for particle in get_tree().get_nodes_in_group("ambient_particles"):
        particle.emitting = enabled
        particle.visible = enabled
    for plant in get_tree().get_nodes_in_group("wind_plants"):
        plant.use_parent_material = false
        if plant.material:
            plant.material.set_shader_parameter("strength", 1.0 if enabled else 0.0)
