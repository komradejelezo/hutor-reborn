extends "res://scripts/combat/combat_arena.gd"
## Opt-in presentation adapter; inherited battle rules/scenarios remain unchanged.
const PROTOTYPE_VISUAL = preload("res://scenes/combat/prototype/HansCombatVisual.tscn")
var hans_visual: HutorHansCombatPrototype

func _ready() -> void:
    super._ready()
    for label in find_children("*","Label",true,false):
        if label.text=="Испытание боем":label.text="Бой · Ганс ПРОТОТИП"

func _start_scenario(id: String) -> void:
    super._start_scenario(id)
    hans_visual = null
    if not views.has("hans"): return
    var view: Button = views.hans
    view.sprite.hide()
    hans_visual = PROTOTYPE_VISUAL.instantiate()
    # ~79 px standing height, matching Hans's existing arena presentation.
    hans_visual.scale = Vector2.ONE * 0.184
    view.body.add_child(hans_visual)
    hint_label.text += " · Ганс: предварительный визуальный прототип"

func _play(events: Array, token: int) -> void:
    for event in events:
        if not _valid(token): return
        # Observe an existing resolved miss. Never roll a dodge or alter damage.
        if event.type=="attack" and event.get("target","")=="hans" and not event.hit and is_instance_valid(hans_visual):
            hans_visual.playback_speed = _speed()
            hans_visual.play_dodge()
        await super._play([event],token)

func _process(_delta: float) -> void:
    if is_instance_valid(hans_visual) and views.has("hans"):
        hans_visual.modulate = views.hans.sprite.modulate

func _menu() -> void:
    _cancel(); busy = true
    get_tree().change_scene_to_file("res://scenes/combat/prototype/HansCombatPreview.tscn")
