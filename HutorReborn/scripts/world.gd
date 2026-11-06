extends Node2D
var paused := false
@onready var player: CharacterBody2D = $Actors/Hans
@onready var hud: CanvasLayer = $HUD
@onready var atmosphere: Node2D = $Atmosphere

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    # The world controller handles Esc while paused; actors and effects remain pausable.
    for child in get_children():
        if child != hud:
            child.process_mode = Node.PROCESS_MODE_PAUSABLE
    preload("res://scripts/input_setup.gd").ensure_actions()
    player.interaction_requested.connect(_show_description)
    player.sensor.focus_changed.connect(hud.set_focus)
    hud.resume_requested.connect(func(): _set_paused(false))
    hud.quit_requested.connect(func(): get_tree().quit())
    player.get_node("Camera2D").reset_smoothing()

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("pause"):
        if hud.dialogue.visible:
            _close_description()
        else:
            _set_paused(not paused)
        get_viewport().set_input_as_handled()
    elif not paused and event.is_action_pressed("interact") and not event.is_echo():
        if hud.dialogue.visible:
            _close_description()
        elif is_instance_valid(player.sensor.target):
            player.interaction_requested.emit(player.sensor.target.interact())
        get_viewport().set_input_as_handled()
    elif not paused and event.is_action_pressed("atmosphere"):
        atmosphere.set_effects_enabled(not atmosphere.effects_enabled)
        hud.show_effects(atmosphere.effects_enabled)

func _show_description(payload: Dictionary) -> void:
    if get_node("/root/DialogueManager").is_active():
        return
    if payload.has("dialogue_path"):
        get_node("/root/DialogueManager").start_file(str(payload.dialogue_path), player, hud)
        return
    player.controls_locked = true
    hud.show_description(payload)

func _close_description() -> void:
    hud.close_description()
    player.controls_locked = false
    hud.set_focus(player.sensor.target)

func _set_paused(value: bool) -> void:
    paused = value
    get_tree().paused = value
    hud.set_paused(value)
    if not value:
        hud.set_focus(player.sensor.target)
