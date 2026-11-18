extends Control
const DRIVER=preload("res://scripts/combat/animation/combat_animation.gd")
const STYLE=preload("res://scripts/combat/ui/style.gd")
var drivers:Array=[]
var panels:Array[ColorRect]=[]
var rate:=1.0
func _ready() -> void:
    preload("res://scripts/input_setup.gd").ensure_actions();theme=STYLE.theme()
    var bg:=ColorRect.new();bg.color=Color("101419");bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(bg)
    STYLE.label(self,"Ганс · Волк · Леший — боевые анимации",Vector2(20,12),Vector2(640,35),22,true)
    STYLE.label(self,"Предварительные кадры: дефекты alpha и фактуры описаны в отчёте. Death удерживает последний кадр; для повтора — Сброс.",Vector2(20,55),Vector2(925,30),11)
    var backgrounds:=OptionButton.new();backgrounds.position=Vector2(700,14);backgrounds.size=Vector2(230,32)
    backgrounds.add_item("Тёмный фон");backgrounds.add_item("Светлый фон");add_child(backgrounds)
    backgrounds.item_selected.connect(func(index:int):
        for panel in panels:panel.color=Color("171c23") if index==0 else Color("e5e0d6"))
    for i in 3:
        var unit:String=["hans","wolf","beast"][i];var x:=20+i*310
        STYLE.label(self,["Ганс","Волк","Леший (beast)"][i],Vector2(x,88),Vector2(280,24),17,true)
        var panel:=ColorRect.new();panel.position=Vector2(x,158);panel.size=Vector2(290,290);panel.color=Color("171c23");add_child(panel);panels.append(panel)
        var line:=Line2D.new();line.points=PackedVector2Array([Vector2(x+10,425),Vector2(x+280,425)]);line.width=1;line.default_color=Color("777d71");add_child(line)
        var rig:=Node2D.new();rig.position=Vector2(x+145,425);rig.scale=Vector2.ONE*1.4;add_child(rig)
        var sprite:=AnimatedSprite2D.new();rig.add_child(sprite)
        var driver:=DRIVER.new();rig.add_child(driver)
        if not driver.configure(sprite,unit,0):
            STYLE.label(self,"Ресурсы недоступны",Vector2(x+10,200),Vector2(270,40));continue
        drivers.append(driver)
        var options:=OptionButton.new();options.position=Vector2(x,118);options.size=Vector2(205,32);add_child(options)
        for clip in driver.clips:options.add_item(String(clip))
        STYLE.button(self,"▶",Vector2(x+215,118),Vector2(75,32),func():driver.play(options.get_item_text(options.selected),rate))
    var speed:=SpinBox.new();speed.position=Vector2(20,480);speed.size=Vector2(100,32);speed.min_value=.25;speed.max_value=3;speed.step=.25;speed.value=1;add_child(speed)
    speed.value_changed.connect(func(value:float):rate=value)
    STYLE.label(self,"× скорость действия",Vector2(125,485),Vector2(180,24),12)
    STYLE.button(self,"Сброс",Vector2(310,480),Vector2(120,36),func():get_tree().reload_current_scene())
    STYLE.button(self,"В боевую арену",Vector2(450,480),Vector2(230,36),func():get_tree().change_scene_to_file("res://scenes/combat/CombatTestArena.tscn"))
    STYLE.button(self,"В меню",Vector2(700,480),Vector2(230,36),func():get_tree().change_scene_to_file("res://scenes/menu/MainMenu.tscn"))
