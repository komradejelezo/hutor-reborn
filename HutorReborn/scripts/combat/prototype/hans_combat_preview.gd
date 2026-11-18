extends Control
## F6 viewer. Tuning is session-local; Inspector defaults live in HansCombatVisual.
const VISUAL = preload("res://scenes/combat/prototype/HansCombatVisual.tscn")
const STYLE = preload("res://scripts/combat/ui/style.gd")
var visual: HutorHansCombatPrototype
var backdrop: ColorRect
var status: Label
var speed: HSlider
var backgrounds: OptionButton
var dodge_button: Button
var pause_button: CheckButton
var idle_ms: SpinBox
var dodge_ms: SpinBox

func _ready() -> void:
    preload("res://scripts/input_setup.gd").ensure_actions()
    theme = STYLE.theme()
    var base := ColorRect.new()
    base.color = Color("101419")
    base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(base)
    STYLE.label(self,"Ганс · Combat Idle / Dodge · ПРОТОТИП v1",Vector2(20,15),Vector2(920,35),23,true)
    var warning := STYLE.label(self,"Исходные PNG не очищены: возможны дыры в одежде, каймы, рябь и обрезание деталей. Проверьте светлый фон. Это не финальная графика.",Vector2(20,58),Vector2(920,43),12)
    warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    backdrop = ColorRect.new()
    backdrop.position = Vector2(20,108); backdrop.size = Vector2(560,390)
    backdrop.color = Color("171b22"); add_child(backdrop)
    var ground := Line2D.new()
    ground.points = PackedVector2Array([Vector2(35,455),Vector2(565,455)])
    ground.default_color = Color("7a7d71"); ground.width = 1; add_child(ground)
    var origin := Line2D.new()
    origin.points = PackedVector2Array([Vector2(300,446),Vector2(300,466)])
    origin.default_color = Color("8c9877"); origin.width = 1; add_child(origin)
    visual = VISUAL.instantiate()
    visual.position = Vector2(300,455)
    visual.scale = Vector2.ONE * 0.7
    add_child(visual)
    STYLE.button(self,"Combat Idle",Vector2(610,112),Vector2(145,36),visual.play_idle)
    dodge_button = STYLE.button(self,"Dodge",Vector2(775,112),Vector2(145,36),func():visual.play_dodge())
    STYLE.label(self,"Скорость воспроизведения",Vector2(610,162),Vector2(310,22))
    speed = HSlider.new(); speed.position = Vector2(610,190); speed.size = Vector2(310,22)
    speed.min_value = 0.1; speed.max_value = 2; speed.step = 0.05; speed.value = 1; add_child(speed)
    speed.value_changed.connect(func(value:float):visual.playback_speed=value)
    STYLE.label(self,"Idle · мс/кадр",Vector2(610,224),Vector2(170,26))
    idle_ms = timing_box(Vector2(800,220),115)
    idle_ms.value_changed.connect(func(value:float):visual.idle_frame_ms=value)
    STYLE.label(self,"Dodge · мс/кадр",Vector2(610,266),Vector2(170,26))
    dodge_ms = timing_box(Vector2(800,262),52)
    dodge_ms.value_changed.connect(func(value:float):visual.dodge_frame_ms=value)
    backgrounds = OptionButton.new(); backgrounds.position = Vector2(610,310); backgrounds.size = Vector2(310,34)
    backgrounds.add_item("Тёмный фон"); backgrounds.add_item("Светлый фон"); add_child(backgrounds)
    backgrounds.item_selected.connect(func(index:int):backdrop.color=Color("171b22") if index==0 else Color("e5e0d6"))
    pause_button = CheckButton.new(); pause_button.text = "Пауза для проверки кадра"
    pause_button.position = Vector2(610,357); pause_button.size = Vector2(310,32); add_child(pause_button)
    pause_button.toggled.connect(visual.set_paused)
    status = STYLE.label(self,"",Vector2(25,505),Vector2(925,25),12)
    STYLE.button(self,"В тестовую арену с прототипом",Vector2(610,412),Vector2(310,38),func():get_tree().change_scene_to_file("res://scenes/combat/prototype/HansCombatPrototypeArena.tscn"))
    STYLE.button(self,"В главное меню",Vector2(610,462),Vector2(310,36),func():get_tree().change_scene_to_file("res://scenes/menu/MainMenu.tscn"))

func timing_box(at: Vector2, value: float) -> SpinBox:
    var box := SpinBox.new()
    box.position = at; box.size = Vector2(120,32)
    box.min_value = 20; box.max_value = 500; box.step = 1; box.value = value
    add_child(box)
    return box

func _process(_delta: float) -> void:
    if not is_instance_valid(visual): return
    dodge_button.disabled = visual.dodging
    var sprite := visual.current_sprite()
    var frame := sprite.frame
    var source: int = frame+1 if frame<12 else 23-frame
    status.text = "%s · шаг %02d/22 · исходный PNG %02d · ×%.2f · опора стоп отмечена линией" % [sprite.animation,frame+1,source,visual.playback_speed]
