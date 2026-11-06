extends Node
## Opt-in F6 scene. F5 and the saved map stay unchanged; no NPC is spawned.
const DEMO = "res://dialogues/elder_demo.json"
var world: Node2D
var launcher: Button

func _ready() -> void:
    world = preload("res://scenes/world/krivaya_sosna/krivaya_sosna.tscn").instantiate()
    add_child(world)
    var layer := CanvasLayer.new()
    layer.layer = 20
    add_child(layer)
    var root := Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    layer.add_child(root)
    launcher = Button.new()
    launcher.text = "◇  Поговорить со старостой"
    launcher.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
    launcher.position = Vector2(-164, 90)
    launcher.custom_minimum_size = Vector2(328, 40)
    launcher.add_theme_font_override("font", preload("res://assets/fonts/DejaVuSerif.ttf"))
    launcher.add_theme_font_size_override("font_size", 17)
    layer.get_child(0).add_child(launcher)
    launcher.pressed.connect(func():
        if get_node("/root/DialogueManager").start_file(DEMO, world.player, world.hud): launcher.hide())
    get_node("/root/DialogueManager").dialogue_finished.connect(func(_id: String, _reason: String):
        launcher.show()
        launcher.grab_focus())
    launcher.grab_focus()
