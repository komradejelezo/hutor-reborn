extends Node
## Sprite playback only; no schedule, navigation or dialogue ownership here.
@onready var sprite: AnimatedSprite2D = get_node("../AnimatedSprite2D")
@onready var smoke: CPUParticles2D = get_node("../PipeSmoke")

func apply(mode: String, facing: StringName, work: StringName, allow_smoke: bool) -> void:
    if sprite.sprite_frames == null: return
    var clip: StringName = StringName(mode+"_"+String(facing))
    if mode=="walk" and sprite.sprite_frames.has_animation("run_"+String(facing)):
        clip=StringName("run_"+String(facing))
    if mode == "work" and work != &"": clip = work
    if not sprite.sprite_frames.has_animation(clip): clip = StringName("idle_"+String(facing))
    sprite.flip_h = facing == &"left"
    if sprite.animation != clip: sprite.play(clip)
    elif sprite.sprite_frames.get_frame_count(clip)>1 and not sprite.is_playing(): sprite.play(clip)
    var smoking := mode == "work" and work == &"work_smoke" and allow_smoke
    if smoke.emitting != smoking: smoke.emitting = smoking
    smoke.visible = smoking
    smoke.position.x = -7 if sprite.flip_h else 7
