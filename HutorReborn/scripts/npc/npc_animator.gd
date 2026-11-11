extends Node
## Sprite playback only; no schedule, navigation or dialogue ownership here.
@onready var sprite: AnimatedSprite2D = get_node("../AnimatedSprite2D")
@onready var smoke: CPUParticles2D = get_node("../PipeSmoke")
var prefer_run := false

func is_locomotion(clip: StringName) -> bool:
    return String(clip).begins_with("walk_") or String(clip).begins_with("run_")

func apply(mode: String, facing: StringName, work: StringName, allow_smoke: bool) -> void:
    if sprite.sprite_frames == null: return
    var clip: StringName = StringName(mode+"_"+String(facing))
    if mode=="walk" and prefer_run and sprite.sprite_frames.has_animation("run_"+String(facing)):
        clip=StringName("run_"+String(facing))
    if mode == "work" and work != &"": clip = work
    if not sprite.sprite_frames.has_animation(clip): clip = StringName("idle_"+String(facing))
    var native_left:PackedStringArray=sprite.sprite_frames.get_meta("native_left_clips",PackedStringArray())
    sprite.flip_h = facing == &"left" and not String(clip) in native_left
    if sprite.animation != clip:
        # Direction changes must not restart every step at its contact pose.
        var phase := 0.0
        var carry_phase := is_locomotion(sprite.animation) and is_locomotion(clip)
        if carry_phase:
            phase = (sprite.frame + sprite.frame_progress) / float(sprite.sprite_frames.get_frame_count(sprite.animation))
        sprite.play(clip)
        if carry_phase:
            var cursor := phase * sprite.sprite_frames.get_frame_count(clip)
            sprite.set_frame_and_progress(int(cursor), fposmod(cursor, 1.0))
    elif sprite.sprite_frames.get_frame_count(clip)>1 and not sprite.is_playing(): sprite.play(clip)
    var smoking := mode == "work" and work == &"work_smoke" and allow_smoke
    if smoke.emitting != smoking: smoke.emitting = smoking
    smoke.visible = smoking
    smoke.position.x = -7 if sprite.flip_h else 7
