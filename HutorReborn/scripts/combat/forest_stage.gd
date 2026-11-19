extends Control
## Presentation-only settings. No camera movement or displacement of master art.
@export var atmosphere_enabled:=true:
    set(value):
        atmosphere_enabled=value
        if is_node_ready():_apply_settings()
@export_enum("Off","Low","Standard") var quality:=2:
    set(value):
        quality=clampi(value,0,2)
        if is_node_ready():_apply_settings()
@export_range(0.0,1.0) var intensity:=0.65:
    set(value):
        intensity=clampf(value,0,1)
        if is_node_ready():_apply_settings()
var effects:Dictionary={"wind":true,"fog":true,"leaves":true,"lighting":true,"smoke":true}
func _ready() -> void:
    # Independent shader instances and different drift phases, all behind actors.
    for i in 2:
        var mist:ColorRect=$Atmosphere/DistantMist.duplicate()
        mist.name="DistantMist"+str(i+2);mist.material=mist.material.duplicate()
        mist.position+=Vector2(-60+i*110,-14+i*28)
        mist.size+=Vector2(70,-9)
        mist.material.set_shader_parameter("phase",float(i+1)*2.3)
        mist.material.set_shader_parameter("drift_speed",.016+float(i)*.012)
        $Atmosphere.add_child(mist)
    _apply_settings()
func set_effect(effect:String,enabled:bool) -> void:
    if not effects.has(effect):return
    effects[effect]=enabled
    if is_node_ready():_apply_settings()
func _apply_settings() -> void:
    var enabled:=atmosphere_enabled and quality>0 and intensity>0
    $Atmosphere.visible=enabled;$Atmosphere.modulate.a=intensity
    $Atmosphere.set_process(enabled);$Atmosphere.quality=quality;$Atmosphere.effects=effects
    var index:=0
    for child in $Atmosphere.get_children():
        if child is ColorRect:
            child.visible=enabled and effects.fog and (quality==2 or index==0)
            child.material.set_shader_parameter("density",[.045,.035,.025][index]*intensity)
            index+=1
    $Atmosphere.queue_redraw()
