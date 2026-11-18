extends Control
## Cancellable presentation loop; the battle engine remains synchronous and isolated.
const CATALOG=preload("res://scripts/combat/combat_catalog.gd")
const BATTLE=preload("res://scripts/combat/combat_battle.gd")
const AI=preload("res://scripts/combat/combat_ai.gd")
const STYLE=preload("res://scripts/combat/ui/style.gd")
const EFFECTS=preload("res://scripts/combat/ui/combat_effects.gd")
const VIEW=preload("res://scenes/combat/CombatantView.tscn")
const MENU="res://scenes/menu/MainMenu.tscn"
signal animation_keyframe(event:Dictionary)
signal delay_finished
var _impact_audio:AudioStreamPlayer
var _timer:Timer
var catalog:RefCounted
var battle:RefCounted
var views:Dictionary={}
var selected_action:="attack"
var scenario_id:=""
var busy:=true
var epoch:=0
var fast:CheckButton
var round_label:Label
var turn_label:Label
var queue_label:Label
var hint_label:Label
var log_label:RichTextLabel
var restart_button:Button
var actions:Dictionary={}
var modal:Control
var events_log:Array[String]=[]
func _ready() -> void:
    preload("res://scripts/input_setup.gd").ensure_actions()
    _timer=Timer.new();_timer.one_shot=true;add_child(_timer);_timer.timeout.connect(func():delay_finished.emit())
    _impact_audio=AudioStreamPlayer.new();_impact_audio.volume_db=-26;add_child(_impact_audio)
    theme=STYLE.theme();STYLE.background(self);catalog=CATALOG.new()
    STYLE.label(self,"Испытание боем",Vector2(22,12),Vector2(380,35),25,true)
    round_label=STYLE.label(self,"",Vector2(416,18),Vector2(170,28),13)
    STYLE.button(self,"Сценарии",Vector2(610,14),Vector2(104,30),_open_picker)
    restart_button=STYLE.button(self,"Заново",Vector2(722,14),Vector2(98,30),_restart)
    STYLE.button(self,"В меню",Vector2(828,14),Vector2(110,30),_menu)
    queue_label=STYLE.label(self,"",Vector2(22,55),Vector2(912,24),12)
    turn_label=STYLE.label(self,"",Vector2(22,86),Vector2(688,28),16,true)
    for entry in [[22,"ТЫЛ"],[170,"ПЕРЕДНИЙ РЯД"],[425,"ПЕРЕДНИЙ РЯД"],[573,"ТЫЛ"]]:
        var l:=STYLE.label(self,entry[1],Vector2(entry[0],119),Vector2(118,16),10);l.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    STYLE.label(self,"ПРОТИВ",Vector2(308,119),Vector2(100,18),10)
    var journal:=PanelContainer.new();journal.position=Vector2(720,118);journal.size=Vector2(218,298);add_child(journal)
    var inside:=Control.new();inside.custom_minimum_size=Vector2(192,270);journal.add_child(inside)
    STYLE.label(inside,"Ход сражения",Vector2.ZERO,Vector2(192,26),17,true)
    log_label=RichTextLabel.new();log_label.position=Vector2(0,32);log_label.size=Vector2(192,238);log_label.scroll_following=true
    log_label.add_theme_font_size_override("normal_font_size",11);log_label.mouse_filter=Control.MOUSE_FILTER_STOP;inside.add_child(log_label)
    hint_label=STYLE.label(self,"",Vector2(22,430),Vector2(916,18),11)
    var buttons:Array=[
        ["attack","Атака",22,98,"Выбрать доступного противника. Ближняя атака не проходит через живой передний ряд."],
        ["defend","Защита",128,108,"Уменьшить урон вдвое до начала своего следующего хода. Ход будет потрачен."],
        ["item","Настойка",244,112,"Восстановить до 30 HP живому союзнику. Общий ограниченный запас на бой."],
        ["retreat","Отступить",364,112,"Попытаться уйти всей группой. При неудаче ход потрачен, враги продолжают по инициативе."],
        ["heal","Лечение",484,120,"Травница восстанавливает до 32 HP. Два применения в «Последней настойке»."],
        ["roots","Корни",484,112,"Однократно: лес удержит выбранного противника на один его ход."],
        ["raven","Ворон",604,112,"Однократно: следующие две атаки по Гансу получают −25 к точности."]]
    for item in buttons:actions[item[0]]=STYLE.button(self,item[1],Vector2(item[2],453),Vector2(item[3],38),_select_action.bind(String(item[0])),item[4])
    fast=CheckButton.new();fast.text="Анимации ×3";fast.position=Vector2(764,455);fast.size=Vector2(176,34);fast.tooltip_text="Быстрее показывать действия";add_child(fast)
    STYLE.label(self,"Наведите курсор на бойца или действие, чтобы узнать подробности",Vector2(22,503),Vector2(906,24),11)
    _open_picker()
func _slot(u:RefCounted) -> Vector2:
    return Vector2((170 if u.row=="front" else 22) if u.team==0 else (425 if u.row=="front" else 573),138+146*u.lane)
func _clear_board() -> void:
    for view in views.values():remove_child(view);view.queue_free()
    views.clear()
func _clear_modal() -> void:
    if is_instance_valid(modal):remove_child(modal);modal.queue_free()
    modal=null
func _panel(pos:Vector2,size_value:Vector2) -> Control:
    _clear_modal();modal=Control.new();modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);modal.mouse_filter=Control.MOUSE_FILTER_STOP;modal.z_index=20;add_child(modal)
    var shade:=ColorRect.new();shade.color=Color(0,0,0,.72);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);modal.add_child(shade)
    var panel:=PanelContainer.new();panel.position=pos;panel.size=size_value;modal.add_child(panel)
    var content:=Control.new();content.custom_minimum_size=size_value-Vector2(24,16);panel.add_child(content);return content
func _open_picker() -> void:
    _cancel();busy=true;battle=null;_clear_board();events_log.clear();log_label.clear();restart_button.disabled=true
    round_label.text="6 отдельных испытаний";turn_label.text="Выберите столкновение";queue_label.text="Два ряда · очередность по инициативе · максимум два спутника"
    for button in actions.values():button.disabled=true;button.hide()
    hint_label.text="Каждый бой начинается с полным здоровьем и новым запасом настоек."
    var content:=_panel(Vector2(160,90),Vector2(640,382))
    STYLE.label(content,"Испытание боем",Vector2(6,0),Vector2(590,40),26,true)
    STYLE.label(content,"Выберите ситуацию",Vector2(6,44),Vector2(590,22),13)
    if catalog.error!="":STYLE.label(content,catalog.error,Vector2(6,100),Vector2(590,80),15);return
    for i in catalog.data.scenarios.size():
        var s:Dictionary=catalog.data.scenarios[i];var pos:=Vector2(6+(i%2)*306,82+(i/2)*86)
        var b:=STYLE.button(content,s.name,pos,Vector2(294,34),_start_scenario.bind(String(s.id)),s.description)
        # Configure wrapping before assigning text: Label's old minimum width
        # otherwise survives the initial non-wrapped layout.
        var desc:=Label.new();desc.name="ScenarioDescription_"+String(s.id)
        desc.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;desc.max_lines_visible=2
        desc.add_theme_font_size_override("font_size",11);desc.text=s.description
        desc.position=pos+Vector2(6,37);desc.size=Vector2(282,40)
        desc.mouse_filter=Control.MOUSE_FILTER_IGNORE;content.add_child(desc)
        if i==0:b.grab_focus()
    STYLE.button(content,"В меню",Vector2(464,328),Vector2(140,30),_menu)
func _restart() -> void:
    if scenario_id!="":_start_scenario(scenario_id)
func _start_scenario(id:String) -> void:
    _cancel();var token:=epoch;busy=true;_clear_modal();_clear_board();events_log.clear();log_label.clear()
    scenario_id=id;battle=BATTLE.new(catalog,id);selected_action="attack"
    for u in battle.units.values():
        var v:Button=VIEW.instantiate();add_child(v);v.setup(u);v.position=_slot(u);v.chosen.connect(_target);views[u.id]=v
    restart_button.disabled=false;_render();_drive(token)
func _valid(token:int) -> bool:return is_inside_tree() and token==epoch
func _speed() -> float:return 3.0 if fast.button_pressed else 1.0
func _append(text:String) -> void:
    events_log.append(text)
    if events_log.size()>80:events_log.pop_front()
    log_label.text="\n\n".join(events_log)
func _render(reposition:bool=true) -> void:
    if not battle:return
    round_label.text="РАУНД "+str(battle.round)
    var u:RefCounted=battle.actor();var player_turn:bool=u!=null and u.team==0 and not busy and battle.result==""
    turn_label.text=("Ход: "+u.name+(" · выберите действие" if player_turn else "")) if u else "Сражение завершено" if battle.result!="" else "Начало сражения"
    var names:PackedStringArray=[]
    for i in battle.order.size():
        var fighter:RefCounted=battle.units[battle.order[i]]
        if fighter.alive():names.append(("›" if fighter==u else "·" if i<battle.cursor else "")+fighter.name+" "+str(fighter.initiative))
    queue_label.text="ИНИЦИАТИВА   "+"   /   ".join(names)
    for id in views:
        var view:Button=views[id]
        if reposition:view.position=_slot(view.unit)
        var reason:String=battle.target_reason(selected_action,id)
        if player_turn and reason=="" and selected_action=="attack":reason="Доступная цель · попадание "+str(battle.hit_chance(u,view.unit))+"%"
        view.refresh(view.unit==u,player_turn and battle.target_reason(selected_action,id)=="",reason)
    for key in actions:
        var b:Button=actions[key];b.show();b.disabled=not player_turn
        if key in ["roots","raven","heal"]:
            b.visible=key in battle.scenario.get("specials",[])
            b.disabled=not player_turn or not battle.special_available(key) or battle.targets(key).is_empty()
        if key=="item":b.text="Настойка ·"+str(battle.potions);b.disabled=not player_turn or battle.targets("item").is_empty()
        if key=="attack":b.disabled=not player_turn or battle.targets("attack").is_empty()
        if key=="retreat":b.text="Уйти ·"+str(int(battle.scenario.retreat))+"%"
        if key=="heal" and u:b.text="Лечение ·"+str(u.heals)
        b.modulate=Color("f1d69b") if key==selected_action else Color.WHITE
    if not ("heal" in battle.scenario.get("specials",[]) or "roots" in battle.scenario.get("specials",[])):
        actions.heal.show();actions.heal.disabled=true;actions.heal.text="Особое —";actions.heal.tooltip_text="В этом испытании особое действие недоступно."
    else:actions.heal.tooltip_text="Травница восстанавливает до 32 HP. Два применения за бой."
    hint_label.text="Противник выбирает действие…" if busy else {"attack":"Атака: выберите подсвеченного противника. Недоступные цели объяснены в подсказках.","item":"Настойка: выберите раненого союзника, включая активного бойца.","heal":"Лечение: выберите раненого союзника.","roots":"Помощь корней: выберите противника. Он пропустит один ход.","raven":"Покровительство ворона: нажмите на Ганса."}.get(selected_action,"")
    if player_turn and selected_action=="attack" and battle.targets("attack").is_empty():
        hint_label.text="Нет доступных целей для атаки. Выберите защиту, настойку или отступление."
func _select_action(action:String) -> void:
    if busy or not battle or battle.result!="":return
    if action in ["defend","retreat"]:_perform(action,"");return
    selected_action=action;_render()
func _target(id:String) -> void:
    if busy or not battle:return
    _perform(selected_action,id)
func _perform(action:String,target:String) -> void:
    if busy or not battle or battle.result!="" or not battle.actor() or battle.actor().team!=0:return
    var response:Dictionary=battle.act(action,target)
    if not response.ok:hint_label.text=response.reason;return
    busy=true;var token:=epoch
    for b in actions.values():b.disabled=true
    for v in views.values():v.disabled=true
    await _play(response.events,token)
    if _valid(token):_drive(token)
func _drive(token:int) -> void:
    while _valid(token):
        if battle.result!="":
            if battle.result=="victory" and views.has("hans") and battle.units.hans.alive() and views.hans.animation:
                var victory_time:float=views.hans.animation.play("victory",_speed())
                if victory_time>0:await _wait(victory_time)
                if not _valid(token):return
            busy=false;_render();_result();return
        busy=true
        var events:Array=battle.advance()
        await _play(events,token)
        if not _valid(token):return
        _render()
        if battle.result!="":continue
        var u:RefCounted=battle.actor()
        if not u:return
        if u.team==0:busy=false;selected_action="attack";_render();return
        await _wait(.45/_speed())
        if not _valid(token):return
        var choice:Dictionary=AI.choose(battle);var response:Dictionary=battle.act(choice.action,choice.target)
        if not response.ok:response=battle.act("defend")
        await _play(response.events,token)
func _play(events:Array,token:int) -> void:
    for e in events:
        if not _valid(token):return
        var rate:=_speed();var duration:=.32/rate
        var target:Button=views.get(e.get("target",""))
        if target and e.type in ["attack","heal"]:target.health_staged=true
        if e.type=="attack":
            var attacker:Button=views.get(e.actor)
            var whole:=duration*2.2;var key:=duration
            if attacker and attacker.animation:
                whole=attacker.animation.play("attack",rate)
                key=attacker.animation.key_time("attack",rate)
            if whole<=0:whole=duration*2.2;key=duration
            if attacker and not attacker.animation:EFFECTS.strike(attacker,1 if attacker.unit.team==0 else -1,duration)
            if key>0:await _wait(key)
            if not _valid(token):return
            _append(e.text)
            var reaction:=0.0
            if target:
                target.reveal_health()
                EFFECTS.popup(target,("−"+str(e.damage)) if e.hit else "Промах",Color("e69270") if e.hit else Color("b9d6d5"),duration*2)
                if target.animation:
                    reaction=target.animation.play("death" if e.killed else "hit" if e.hit else "dodge",rate)
                if e.hit and reaction<=0:EFFECTS.hit(target,e.killed,duration)
            if attacker and attacker.animation and attacker.animation.kind=="leshy" and target:
                var bolt:=preload("res://scripts/combat/animation/combat_magic.gd").new()
                bolt.source=attacker.animation.socket()-global_position
                bolt.destination=target.body.global_position-global_position+Vector2(0,-26)
                bolt.lifetime=.22/rate;bolt.remaining=bolt.lifetime;bolt.set_meta("combat_transient",true);add_child(bolt)
            _sound("leaves_1" if attacker and attacker.unit.kind in ["beast","wolf"] else "axe_1")
            animation_keyframe.emit(e)
            _render()
            var tail:float=maxf(maxf(0,whole-key),reaction)
            if tail>0:await _wait(minf(tail,4.0))
        elif e.type=="betray" and target:
            _append(e.text);EFFECTS.popup(target,"Предательство",Color("e5a76a"),duration*2)
            var t:=create_tween();t.tween_property(target,"position",_slot(target.unit),duration*2.5).set_trans(Tween.TRANS_CUBIC)
            await _wait(duration*2.5)
        elif e.type in ["heal","guard","roots","raven","whisper"] and target:
            var performer:Button=views.get(e.get("actor",battle.active))
            var whole:=duration*1.5;var key:=0.0
            if performer and performer.animation and e.type in ["heal","roots","raven"]:
                whole=performer.animation.play("use_invoke",rate)
                key=performer.animation.key_time("use_invoke",rate)
            if key>0:await _wait(key)
            if not _valid(token):return
            _append(e.text);target.reveal_health()
            var word:String={"heal":"+"+str(e.get("amount",0)),"guard":"Защита","roots":"Корни","raven":"Ворон","whisper":"Ослаблен"}[e.type]
            EFFECTS.popup(target,word,Color("c5dca5"),duration*2)
            if e.type=="roots":EFFECTS.roots(target,duration*2)
            if e.type in ["heal","roots","raven"]:_sound("leaves_2")
            animation_keyframe.emit(e);_render()
            if whole-key>0:await _wait(minf(whole-key,4.0))
        else:_append(e.text)
        if not _valid(token):return
func _sound(id:String) -> void:
    var path:="res://assets/audio/ambient/"+id+".ogg"
    if is_instance_valid(_impact_audio) and ResourceLoader.exists(path):
        _impact_audio.stream=load(path);_impact_audio.play()
func _result() -> void:
    var names:Dictionary={"victory":"Победа","defeat":"Поражение","retreated":"Удалось отступить","error":"Испытание остановлено"}
    hint_label.text="Сражение завершено. Можно начать заново или выбрать другое испытание."
    var content:=_panel(Vector2(242,152),Vector2(476,230))
    STYLE.label(content,names.get(battle.result,"Завершено"),Vector2(6,0),Vector2(432,48),30,true)
    STYLE.label(content,"Раундов: "+str(battle.round)+" · действий: "+str(battle.actions),Vector2(6,58),Vector2(432,24),14)
    STYLE.button(content,"Повторить",Vector2(6,116),Vector2(136,40),_restart)
    STYLE.button(content,"Другой сценарий",Vector2(150,116),Vector2(166,40),_open_picker)
    STYLE.button(content,"В меню",Vector2(324,116),Vector2(112,40),_menu)
func _menu() -> void:
    _cancel();busy=true
    var code:=get_tree().change_scene_to_file(MENU)
    if code!=OK:hint_label.text="Не удалось открыть меню ("+str(code)+")."
func _unhandled_input(event:InputEvent) -> void:
    if event.is_action_pressed("ui_cancel") and not event.is_echo():
        if battle:_open_picker()
        else:_menu()
        get_viewport().set_input_as_handled()
func _wait(seconds:float) -> void:
    _timer.start(seconds)
    await delay_finished
func _cancel() -> void:
    epoch+=1
    if is_instance_valid(_impact_audio):_impact_audio.stop()
    for child in get_children():
        if child.has_meta("combat_transient"):child.queue_free()
    if is_instance_valid(_timer):_timer.stop()
    delay_finished.emit()
func _exit_tree() -> void:_cancel()
