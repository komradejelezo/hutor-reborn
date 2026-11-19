extends RefCounted
const SHADER=preload("res://shaders/combat_readable.gdshader")
static func make(kind:String) -> ShaderMaterial:
    var material:=ShaderMaterial.new();material.shader=SHADER
    material.set_shader_parameter("green_magic",kind in ["beast","leshy"])
    if kind=="herbalist":
        material.set_shader_parameter("saturation",.86);material.set_shader_parameter("balance",Vector3(.97,1,.99))
    if kind=="woodcutter":
        var old:ShaderMaterial=load("res://assets/npc/woodcutter542/game/palette_543.tres")
        for key in ["saturation","balance","exposure"]:
            material.set_shader_parameter(key,old.get_shader_parameter(key))
    return material
static func height(kind:String) -> float:
    return {"hans":124.0,"wolf":76.0,"leshy":136.0,"beast":136.0,"herbalist":118.0,"woodcutter":128.0,"mercenary":116.0,"spirit":128.0}.get(kind,118.0)
