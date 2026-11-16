extends Control
const STYLE=preload("res://scripts/combat/ui/style.gd")
const ARENA="res://scenes/combat/CombatTestArena.tscn"
const WORLD="res://scenes/world/krivaya_sosna/krivaya_sosna.tscn"
var error_label:Label
var opening:=false
func _ready() -> void:
    preload("res://scripts/input_setup.gd").ensure_actions()
    theme=STYLE.theme();STYLE.background(self)
    STYLE.label(self,"Х У Т О Р",Vector2(76,90),Vector2(650,70),58,true)
    STYLE.label(self,"ВОЗРОЖДЕНИЕ",Vector2(81,164),Vector2(600,42),26,true)
    STYLE.label(self,"За лесом всё ещё горят окна",Vector2(84,214),Vector2(620,28),15)
    STYLE.button(self,"Начать путь",Vector2(84,280),Vector2(330,48),func():open_scene(WORLD),"Вернуться на дороги Кривой Сосны")
    STYLE.button(self,"Испытание боем",Vector2(84,340),Vector2(330,48),func():open_scene(ARENA),"Шесть отдельных столкновений. У каждого — свои бойцы и припасы")
    STYLE.button(self,"Выйти из игры",Vector2(84,400),Vector2(330,40),func():get_tree().quit())
    STYLE.label(self,"Испытание боем · эксперимент 6.1",Vector2(84,484),Vector2(700,24),12)
    error_label=STYLE.label(self,"",Vector2(84,450),Vector2(780,30),13)
    get_tree().paused=false
func open_scene(path:String) -> void:
    if opening:return
    if not ResourceLoader.exists(path,"PackedScene"):error_label.text="Не удалось открыть сцену. Проверьте ресурсы проекта.";return
    opening=true
    var code:=get_tree().change_scene_to_file(path)
    if code!=OK:opening=false;error_label.text="Не удалось открыть сцену ("+str(code)+")."
