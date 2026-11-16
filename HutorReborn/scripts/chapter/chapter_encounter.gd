extends "res://scripts/combat/combat_arena.gd"
## Adapter only: shared battle rules and the original six-scenario arena are unchanged.
var story_ready:=false
func _ready() -> void:
    super._ready();story_ready=true;_clear_modal();_start_scenario("ambush")
    var c:Node=get_node("/root/ChapterI");battle.units.hans.hp=c.state.health;battle.potions=c.state.count("tincture")
    _render()
    for b in find_children("*","Button",true,false):
        if b.text in ["Сценарии","Заново","В меню"]:b.hide()
func _open_picker() -> void:
    if not story_ready:super._open_picker()
func _menu() -> void:pass
func _unhandled_input(_event:InputEvent) -> void:pass
func _result() -> void:
    hint_label.text="Бой завершён. Его последствия сохранятся в главе."
    var content:=_panel(Vector2(242,150),Vector2(476,240))
    STYLE.label(content,{"victory":"Волки отступили","defeat":"Тропа оказалась опаснее","retreated":"Ганс отступил"}.get(battle.result,"Бой окончен"),Vector2(6,0),Vector2(432,50),22,true)
    STYLE.label(content,"Можно вернуться к вырубке или найти обход.",Vector2(6,68),Vector2(432,28),12)
    STYLE.button(content,"Вернуться в лес",Vector2(100,130),Vector2(240,40),func():
        _cancel();get_node("/root/ChapterI").finish_encounter(battle.result,battle.units.hans.hp,battle.potions))
