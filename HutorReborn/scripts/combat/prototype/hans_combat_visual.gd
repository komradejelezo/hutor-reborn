class_name HutorHansCombatPrototype
extends Node2D
## Presentation only. No hit calculation, health, input actions or invulnerability.
signal motion_changed(motion: StringName)
signal dodge_finished

@export_range(20.0, 500.0, 1.0) var idle_frame_ms: float = 115.0:
    set(value):
        idle_frame_ms = clampf(value, 20, 500)
        if is_node_ready(): _update_timing()
@export_range(20.0, 500.0, 1.0) var dodge_frame_ms: float = 52.0:
    set(value):
        dodge_frame_ms = clampf(value, 20, 500)
        if is_node_ready(): _update_timing()
@export_range(0.1, 3.0, 0.05) var playback_speed: float = 1.0:
    set(value):
        playback_speed = clampf(value, 0.1, 3.0)
        if is_node_ready(): _update_timing()

@onready var idle_sprite: AnimatedSprite2D = $Idle
@onready var dodge_sprite: AnimatedSprite2D = $Dodge
var dodging := false
var paused := false

func _ready() -> void:
    # Inspector/viewer tuning must not mutate a shared SpriteFrames resource.
    var frames := idle_sprite.sprite_frames.duplicate() as SpriteFrames
    idle_sprite.sprite_frames = frames
    dodge_sprite.sprite_frames = frames
    dodge_sprite.animation_finished.connect(_finish_dodge)
    _update_timing()
    play_idle()

func _update_timing() -> void:
    idle_sprite.sprite_frames.set_animation_speed(&"combat_idle", 1000.0 / idle_frame_ms)
    idle_sprite.sprite_frames.set_animation_speed(&"dodge", 1000.0 / dodge_frame_ms)
    idle_sprite.speed_scale = playback_speed
    dodge_sprite.speed_scale = playback_speed

func current_sprite() -> AnimatedSprite2D:
    return dodge_sprite if dodging else idle_sprite

func play_idle() -> void:
    dodging = false
    dodge_sprite.stop()
    dodge_sprite.hide()
    idle_sprite.show()
    idle_sprite.stop()
    idle_sprite.play(&"combat_idle")
    if paused: idle_sprite.pause()
    motion_changed.emit(&"combat_idle")

func play_dodge() -> bool:
    if dodging or not is_node_ready(): return false
    dodging = true
    idle_sprite.pause()
    idle_sprite.hide()
    dodge_sprite.show()
    dodge_sprite.stop()
    dodge_sprite.play(&"dodge")
    if paused: dodge_sprite.pause()
    motion_changed.emit(&"dodge")
    return true

func _finish_dodge() -> void:
    if not dodging: return
    play_idle()
    dodge_finished.emit()

func set_paused(value: bool) -> void:
    paused = value
    if paused: current_sprite().pause()
    else: current_sprite().play()
