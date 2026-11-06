extends Node2D
## One viewport fog pass. Cache resources and restore authored wind strengths.
@export var world_space_fog := false
var effects_enabled := true
@onready var fog: ColorRect = $Screen/Fog
@onready var actor: CharacterBody2D = get_node("../Actors/Hans")
@onready var camera: Camera2D = actor.get_node("Camera2D")
var _last_camera := Vector2.INF
var _last_view_size := Vector2.INF
var _last_anchor := Vector2.INF
var _wind_materials: Array[ShaderMaterial] = []
var _wind_strengths: Array[float] = []
var _particles: Array = []

func _ready() -> void:
    # Camera's normal idle update precedes these visual uniforms.
    process_priority = 10
    _particles = get_tree().get_nodes_in_group("ambient_particles")
    for plant in get_tree().get_nodes_in_group("wind_plants"):
        var material: ShaderMaterial = plant.material as ShaderMaterial
        if material and not _wind_materials.has(material):
            _wind_materials.append(material)
            var strength: Variant = material.get_shader_parameter("strength")
            _wind_strengths.append(1.0 if strength == null else float(strength))

func _process(_delta: float) -> void:
    if not is_instance_valid(camera):
        return
    var center := camera.get_screen_center_position()
    if not center.is_equal_approx(_last_camera):
        fog.material.set_shader_parameter("camera_world", center)
        _last_camera = center
    if world_space_fog:
        var view_size := get_viewport().get_visible_rect().size / camera.zoom
        if not view_size.is_equal_approx(_last_view_size):
            fog.material.set_shader_parameter("viewport_world_size", view_size)
            _last_view_size = view_size
        var anchor := actor.global_position + Vector2(0, -24)
        if not anchor.is_equal_approx(_last_anchor):
            fog.material.set_shader_parameter("readability_anchor", anchor)
            _last_anchor = anchor

func set_effects_enabled(enabled: bool) -> void:
    effects_enabled = enabled
    fog.visible = enabled
    set_process(enabled)
    for particle in _particles:
        if is_instance_valid(particle):
            particle.emitting = enabled
            particle.visible = enabled
    for i in range(_wind_materials.size()):
        _wind_materials[i].set_shader_parameter("strength", _wind_strengths[i] if enabled else 0.0)
