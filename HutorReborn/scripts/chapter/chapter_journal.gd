extends CanvasLayer
const STYLE=preload("res://scripts/combat/ui/style.gd")
const CONTENT=preload("res://scripts/chapter/chapter_content.gd")
var panel:Control
var toast:Label
var hotkeys:Label
var toast_left:=0.0
var c:Node
var _was_paused:=false
var blocking:=false
func _ready() -> void:
    layer=30;process_mode=Node.PROCESS_MODE_ALWAYS;c=get_parent()
    toast=Label.new();toast.position=Vector2(220,116);toast.size=Vector2(660,30)
    toast.add_theme_font_override("font",STYLE.SANS);toast.add_theme_font_size_override("font_size",12);toast.add_theme_color_override("font_color",Color("dfc794"));add_child(toast);toast.hide()
    hotkeys=Label.new();hotkeys.position=Vector2(30,487);hotkeys.text="J — журнал   I — сумка   F5 — сохранить   F9 — загрузить"
    hotkeys.add_theme_font_override("font",STYLE.SANS);hotkeys.add_theme_font_size_override("font_size",11);hotkeys.add_theme_color_override("font_color",Color("cabd97"));add_child(hotkeys)
func _process(delta:float) -> void:
    if toast_left>0:toast_left-=delta;toast.visible=toast_left>0
    if hotkeys:hotkeys.visible=c.active and not c.busy and not c.dialogue.is_active() and not is_open()
func notice(text:String) -> void:toast.text=text;toast.show();toast_left=5
func is_open() -> bool:return is_instance_valid(panel)
func close() -> void:
    if is_instance_valid(panel):
        remove_child(panel);panel.queue_free();panel=null;get_tree().paused=_was_paused
    blocking=false
func shell(title:String) -> VBoxContainer:
    close();_was_paused=get_tree().paused;get_tree().paused=true
    panel=Control.new();panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);panel.theme=STYLE.theme();add_child(panel)
    var dim:=ColorRect.new();dim.color=Color(0,0,0,.83);dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);panel.add_child(dim)
    var frame:=PanelContainer.new();frame.position=Vector2(60,38);frame.size=Vector2(840,460);panel.add_child(frame)
    var box:=VBoxContainer.new();box.add_theme_constant_override("separation",8);frame.add_child(box)
    var header:=HBoxContainer.new();box.add_child(header)
    var heading:=Label.new();heading.text=title;heading.add_theme_font_override("font",STYLE.SERIF);heading.add_theme_font_size_override("font_size",23);heading.size_flags_horizontal=Control.SIZE_EXPAND_FILL;header.add_child(heading)
    button(header,"Закрыть · Esc",close)
    return box
func button(parent:Node,text:String,callback:Callable) -> Button:
    var b:=Button.new();b.text=text;b.pressed.connect(callback);parent.add_child(b);return b
func scroll(parent:Control) -> VBoxContainer:
    var sc:=ScrollContainer.new();sc.size_flags_vertical=Control.SIZE_EXPAND_FILL;sc.custom_minimum_size=Vector2(800,275);parent.add_child(sc)
    var v:=VBoxContainer.new();v.size_flags_horizontal=Control.SIZE_EXPAND_FILL;v.add_theme_constant_override("separation",10);sc.add_child(v);return v
func text(parent:Node,value:String) -> void:
    var l:=Label.new();l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;l.text=value;l.custom_minimum_size.x=730;parent.add_child(l)
func journal(category:String="Основные") -> void:
    var box:=shell("Журнал · Тени Кривой Сосны"+(" · ТЕСТ" if c.test_mode else ""))
    var tabs:=HBoxContainer.new();box.add_child(tabs)
    for name in ["Основные","Побочные","Завершённые","Улики","Жители"]:button(tabs,name,journal.bind(name))
    var list:=scroll(box);var s:RefCounted=c.state
    if category=="Улики":
        if s.clues.is_empty():text(list,"Пока нет записанных улик.")
        for clue in s.clues.values():text(list,"• "+clue)
    elif category=="Жители":
        var places:Dictionary={"village":"во дворах хутора","inn":"в трактире","elder":"у старосты","herbalist":"в доме травницы","woodcutter":"в доме семьи дровосека","old_man":"в доме старика","storehouse":"на складе","logging":"на лесных работах за северной границей"}
        for r in c.life.states.values():
            var place:String=places.get(String(r.scene),"в пути")
            if c._reserved.has(String(r.id)):place={"herbalist":"рядом с Гансом","woodcutter":"у южной дороги","old_man":"у Кривой Сосны","elder":"в трактире по делам"}.get(String(r.id),place)
            text(list,r.original.display_name+" — "+place+".")
        text(list,"Лесные работники возвращаются после 18:00. Дождаться вечера или ночи можно у печи в трактире.")
    elif category=="Побочные":
        var found:=false
        for q in s.SIDES:
            if s.has(q[0]+"_started") and not s.has(q[3]):found=true;text(list,q[1]+"\n"+q[2])
        if not found:text(list,"Сейчас нет незавершённых поручений. Расспросите жителей о помощи.")
    else:
        for i in s.QUESTS.size():
            var q:Array=s.QUESTS[i];var done:bool=s.has(q[4])
            if (category=="Завершённые" and done) or (category=="Основные" and i<=s.stage()):
                text(list,("✓ " if done else "→ ")+q[1]+"\n"+q[2]+("\nТекущая цель: "+q[3] if not done else "\nЗавершено."))
                var steps:Array=[[["lodging","Ночлег получен"],["night","Первая ночь пережита"]],[["w_woodcutter","Дровосек опрошен"],["w_herbalist_brother","Брат травницы опрошен"],["w_woodcutter_wife","Жена дровосека опрошена"],["w_woodcutter_son","Мальчик опрошен"],["tools","Инструменты осмотрены"],["tracks","След найден"],["axe_decided","Судьба топора решена"]],[["herbs_started","Растения описаны"],["herbs_done","Ингредиенты доставлены"]],[["old_met","Старик рассказал о запрете"],["pine_symbol","Символ на сосне осмотрен"]],[["wolves_clear","Волчий дозор преодолён"],["struggle","Место борьбы осмотрено"],["handle","Рукоять найдена"],["cloth","Ткань найдена"],["vanishing","Следы исследованы"]],[["house_open","Дом открыт"],["floor_cache","Тайник найден"],["diary_found","Дневник прочитан"],["finale","Глава завершена"]]][i]
                var achieved:Array=[]
                for step in steps:
                    if s.has(step[0]):achieved.append("✓ "+step[1])
                if not achieved.is_empty():text(list,"Выполненные этапы: "+"; ".join(achieved))
                var related:Array=[["night"],["resin","w_woodcutter","w_herbalist_brother","w_woodcutter_wife","w_woodcutter_son","tracks","tools"],["root_story","dry_resin"],["ban","archive","pine_symbol"],["struggle","handle","cloth","vanishing"],["floor_cache","diary","official_copy"]][i]
                var found:Array=[]
                for key in related:
                    if s.clues.has(key):found.append(s.clues[key])
                if not found.is_empty():text(list,"Связанные улики:\n"+"\n".join(found))
        if category=="Завершённые":
            for q in s.SIDES:
                if s.has(q[3]):text(list,"✓ "+q[1]+"\n"+q[2])
    text(list,"Последние записи:\n"+"\n".join(s.journal.slice(maxi(0,s.journal.size()-5))))
    footer(box)
func inventory() -> void:
    var box:=shell("Дорожная сумка · "+str(c.state.money)+" монет · "+str(c.state.health)+" / 108 HP")
    var list:=scroll(box)
    if c.state.items.is_empty():text(list,"В сумке пока нет находок. Улики остаются также в журнале.")
    for id in c.state.items:
        if not CONTENT.ITEMS.has(id):continue
        var item:Array=CONTENT.ITEMS[id];var row:=HBoxContainer.new();list.add_child(row)
        var icon:=TextureRect.new();icon.texture=load(item[3]);icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;icon.custom_minimum_size=Vector2(44,44);icon.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;row.add_child(icon)
        var b:=button(row,item[0]+" ×"+str(c.state.count(id))+" · "+item[1],inspect.bind(String(id)));b.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    footer(box)
func inspect(id:String) -> void:
    close();var item:Array=CONTENT.ITEMS[id];var options:Array=[]
    if id=="axe" and not c.state.decisions.has("axe"):options.append(["axe_keep","Сохранить находку у себя.","Топор останется у Ганса. Его можно описать травнице, даже не показывая старосте."])
    if id=="tincture" and c.state.health<108:options.append(["tincture","Выпить настойку.","Горечь обжигает язык. Сил становится больше."])
    if id=="poison":options.append(["discard_poison","Выбросить опасное растение.","Нужные кусты всё ещё на опушке."])
    c.talk(item[0],item[2],options)
func footer(box:VBoxContainer) -> void:
    var row:=HBoxContainer.new();box.add_child(row)
    button(row,"Сохранить · F5",func():close();c.save_game())
    button(row,"Загрузить · F9",func():close();c.load_game(c.test_mode))
    button(row,"Контрольная точка",func():close();c.load_game(c.test_mode,"checkpoint"))
    button(row,"Главное меню",menu)
func menu() -> void:
    close();c.reset_session();c.active=false;c.busy=false;get_tree().change_scene_to_file("res://scenes/menu/MainMenu.tscn")
func test_menu() -> void:
    var box:=shell("Тест главы I · отдельное сохранение")
    text(box,"Выберите начало задания. Предыдущие обязательные состояния будут подготовлены. Обычные сохранения не изменяются.")
    var list:=scroll(box)
    for i in c.state.QUESTS.size():button(list,str(i+1)+". "+c.state.QUESTS[i][1],func():close();c.start_new(true,i))
    button(list,"Финальное событие",func():close();c.start_new(true,6))
    button(list,"Сбросить тестовый прогресс",func():
        for slot in ["manual","checkpoint"]:
            var p:String=c.SAVE.path(true,slot)
            for suffix in ["",".bak",".tmp"]:
                if FileAccess.file_exists(p+suffix):DirAccess.remove_absolute(p+suffix)
        notice("Только тестовые сохранения удалены."))
func ending(left:bool) -> void:
    var box:=shell("Дорога дальше" if left else "ГЛАВА I ЗАВЕРШЕНА")
    blocking=left
    text(box,"Ты ушёл до темноты. К утру за спиной осталась деревня, где кто-то всё ещё ждал трёх ударов. Эта история продолжилась без Ганса." if left else "«ТЕНИ КРИВОЙ СОСНЫ»\n\nЛес больше не кажется пустым. Что именно держали деревья, Ганс пока не знает.")
    if not left:button(box,"Продолжить исследование",close)
    button(box,"Загрузить перед финальным решением",func():close();c.load_game(c.test_mode,"checkpoint"))
    button(box,"Главное меню",menu)
func sequence(title:String,lines:Array,axe:bool=false) -> void:
    close();_was_paused=get_tree().paused;get_tree().paused=true
    blocking=true
    toast_left=0;toast.hide();c.travel.active_world.hud.set_focus(null)
    panel=Control.new();panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);panel.theme=STYLE.theme();add_child(panel)
    var dim:=ColorRect.new();dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);dim.color=Color(0,0,0,.24);panel.add_child(dim)
    STYLE.label(panel,title,Vector2(70,100),Vector2(820,45),25,true)
    var label:=Label.new();label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;label.position=Vector2(70,380);label.size=Vector2(820,120);label.add_theme_font_size_override("font_size",20);label.add_theme_color_override("font_shadow_color",Color.BLACK);label.add_theme_constant_override("shadow_offset_x",2);label.add_theme_constant_override("shadow_offset_y",2);panel.add_child(label)
    # Cinematic owns input until completion; there is no mid-event save window.
    var ghost:Sprite2D
    if c.state.has("finale"):
        ghost=Sprite2D.new();ghost.texture=load("res://assets/npc/herbalist_brother5411/game/frames.tres").get_frame_texture("idle_down",0)
        ghost.centered=false;ghost.z_index=5
        ghost.position=c.travel.active_world.player.position+Vector2(-180,50);ghost.modulate=Color(.4,.48,.43,.9);ghost.offset=Vector2(-48,-82);c.travel.active_world.get_node("Actors").add_child(ghost)
    if ghost:ghost.hide()
    for i in lines.size():
        var line:String=lines[i]
        if ghost and i==lines.size()-1:ghost.show()
        label.text=line
        if axe:
            var player:=AudioStreamPlayer.new();player.stream=load("res://assets/audio/ambient/axe_1.ogg");player.volume_db=-12;add_child(player);player.play();player.finished.connect(player.queue_free)
        await get_tree().create_timer(1.3,true).timeout
    if is_instance_valid(ghost):ghost.queue_free()
    close()
