extends Node
## Sprite playback only; no schedule, navigation or dialogue ownership here.
@onready var sprite: AnimatedSprite2D = get_node("../AnimatedSprite2D")
@onready var smoke: CPUParticles2D = get_node("../PipeSmoke")
var prefer_run := false
var pilot_carrying := false
var _work_context := ""
var _work_cursors: Dictionary = {}
var _discard_outgoing_work := false

func set_work_context(value: String) -> void:
    if value != _work_context:
        _work_context = value
        _work_cursors.clear()
        _discard_outgoing_work = true

func reset_presentation() -> void:
    _work_context = ""
    _work_cursors.clear()
    _discard_outgoing_work = true

func _is_work(clip: StringName) -> bool:
    return String(clip).begins_with("work_") or String(clip).begins_with("gesture_")

func is_locomotion(clip: StringName) -> bool:
    return String(clip).begins_with("walk_") or String(clip).begins_with("run_") or (pilot_carrying and String(clip).begins_with("carry_") and not String(clip).begins_with("carry_idle_"))

func apply(mode: String, facing: StringName, work: StringName, allow_smoke: bool) -> void:
    if sprite.sprite_frames == null: return
    # Only the pilot finishes an already committed axe stroke before greeting.
    # The logical dialogue locks movement immediately; no delayed input/session.
    if int(sprite.sprite_frames.get_meta("woodcutter_version",0))==542 and mode=="talk" and not _discard_outgoing_work:
        if sprite.animation in [&"work_chop",&"chop_wood",&"work_pick_up",&"work_put_down"] and sprite.frame>0 and sprite.is_playing():return
    var clip: StringName = StringName(mode+"_"+String(facing))
    if mode=="walk" and prefer_run and sprite.sprite_frames.has_animation("run_"+String(facing)):
        clip=StringName("run_"+String(facing))
    if mode == "work" and work != &"": clip = work
    if pilot_carrying and int(sprite.sprite_frames.get_meta("woodcutter_version",0))==542:
        if mode=="walk":clip=StringName("carry_"+String(facing))
        elif mode in ["idle","talk","turn"]:clip=StringName("carry_idle_"+String(facing))
    if not sprite.sprite_frames.has_animation(clip): clip = StringName("idle_"+String(facing))
    var native_left:PackedStringArray=sprite.sprite_frames.get_meta("native_left_clips",PackedStringArray())
    sprite.flip_h = facing == &"left" and not String(clip) in native_left
    if sprite.animation != clip:
        # A conversation pauses the current chore; it must not restart its
        # swing/stroke at frame zero. Cursors belong only to this location/step.
        if not _discard_outgoing_work and _is_work(sprite.animation) and sprite.sprite_frames.has_animation(sprite.animation):
            _work_cursors[sprite.animation] = Vector2(sprite.frame, sprite.frame_progress)
        # Direction changes must not restart every step at its contact pose.
        var phase := 0.0
        var carry_phase := is_locomotion(sprite.animation) and is_locomotion(clip)
        if carry_phase:
            phase = (sprite.frame + sprite.frame_progress) / float(sprite.sprite_frames.get_frame_count(sprite.animation))
        sprite.play(clip)
        if carry_phase:
            var cursor := phase * sprite.sprite_frames.get_frame_count(clip)
            sprite.set_frame_and_progress(int(cursor), fposmod(cursor, 1.0))
        elif _is_work(clip) and _work_cursors.has(clip):
            var cursor: Vector2 = _work_cursors[clip]
            sprite.set_frame_and_progress(mini(int(cursor.x),sprite.sprite_frames.get_frame_count(clip)-1),cursor.y)
    elif _discard_outgoing_work and _is_work(clip):
        sprite.play(clip)
        sprite.set_frame_and_progress(0,0)
    elif sprite.sprite_frames.get_frame_count(clip)>1 and not sprite.is_playing():
        # Reviewed family one-shot actions hold their authored settle poses.
        # All other residents retain their existing playback contract.
        var authored_settle:bool=int(sprite.sprite_frames.get_meta("woodcutter_version",0))==542 or int(sprite.sprite_frames.get_meta("wife_version",0))==544 or int(sprite.sprite_frames.get_meta("son_version",0))==545 or int(sprite.sprite_frames.get_meta("innkeeper_version",0))==546
        var finished_pilot_action:bool=authored_settle and not sprite.sprite_frames.get_animation_loop(clip)
        if not finished_pilot_action:sprite.play(clip)
    _discard_outgoing_work = false
    var smoking := mode == "work" and work == &"work_smoke" and allow_smoke
    if smoke.emitting != smoking: smoke.emitting = smoking
    smoke.visible = smoking
    smoke.position.x = -7 if sprite.flip_h else 7
