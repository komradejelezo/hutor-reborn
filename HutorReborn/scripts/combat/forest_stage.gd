extends Control
## The master texture never moves. Atmosphere has independent, bounded layers.
@export var atmosphere_enabled:=true:
    set(value):
        atmosphere_enabled=value
        if is_node_ready():_apply_settings()
@export_range(0.0,1.0) var intensity:=0.65:
    set(value):
        intensity=clampf(value,0,1)
        if is_node_ready():_apply_settings()
func _ready() -> void:_apply_settings()
func _apply_settings() -> void:
    $Atmosphere.visible=atmosphere_enabled
    $Atmosphere.modulate.a=intensity
    $Atmosphere.set_process(atmosphere_enabled and intensity>0)
    $Atmosphere/DistantMist.visible=atmosphere_enabled and intensity>0
    $Atmosphere/DistantMist.material.set_shader_parameter("density",.075*intensity)
