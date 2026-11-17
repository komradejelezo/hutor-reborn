extends Node
## One chapter session. Reuses DialogueManager, InteriorTravel and VillageLife.
const STATE=preload("res://scripts/chapter/chapter_state.gd")
const CONTENT=preload("res://scripts/chapter/chapter_content.gd")
const ACTIONS=preload("res://scripts/chapter/chapter_actions.gd")
const SAVE=preload("res://scripts/chapter/chapter_save.gd")
const WORLD=preload("res://scripts/chapter/chapter_world.gd")
var state:RefCounted=STATE.new()
var active:=false
var test_mode:=false
var busy:=false
var life:Node
var travel:Node
var dialogue:Node
var ui:CanvasLayer
var _pending:=""
var _speaker:CharacterBody2D
var _reserved:Dictionary={}
var _battle_world:Node2D
var _battle_clock:=false
var _wife_interrupted:=false
var _trail_actor:WeakRef
var _trail_left:=0.0
var _wife_visit_delay:=0.0
var _elder_visit_left:=0.0
func _ready() -> void:
    process_mode=Node.PROCESS_MODE_ALWAYS
    life=get_node("/root/VillageLife");travel=get_node("/root/InteriorTravel");dialogue=get_node("/root/DialogueManager")
    ui=preload("res://scripts/chapter/chapter_journal.gd").new();ui.name="ChapterJournal";add_child(ui)
    dialogue.choice_selected.connect(_choice);dialogue.dialogue_finished.connect(_finished)
    travel.transition_finished.connect(_transition_finished)
    travel.transition_started.connect(func(_id:StringName,_exiting:bool):release_all())
    get_tree().root.child_entered_tree.connect(func(node:Node):
        if active and node.scene_file_path==travel.VILLAGE:_attach.call_deferred(node))
func _register_locations() -> void:
    for id in ["logging_camp","abandoned"]:
        var d:=HutorBuildingDefinition.new();d.id=StringName(id)
        d.display_name="Старые лесозаготовки" if id=="logging_camp" else "Дом без хозяина"
        d.interior_scene="res://scenes/chapter/"+id+".tscn"
        d.exterior_anchor=NodePath("ChapterWorld/Story_north" if id=="logging_camp" else "Actors/Structures/AbandonedHouse/Entrance")
        d.door_offset=Vector2.ZERO if id=="logging_camp" else Vector2(0,26)
        d.camera_zoom=1.0 if id=="logging_camp" else 1.3;travel.buildings[d.id]=d
func _attach(world:Node2D) -> void:
    if not active or not is_instance_valid(world) or world.has_node("ChapterWorld"):return
    _register_locations()
    var additions:=WORLD.new();additions.name="ChapterWorld";world.add_child(additions)
func _transition_finished(id:StringName,exiting:bool) -> void:
    if not active:return
    _attach(travel.active_world)
    if id==&"abandoned" and not exiting and state.decisions.get("approach")=="herbalist":
        reserve("herbalist",travel.active_world.get_node("Actors/Residents"),travel.active_world.player.position+Vector2(-30,-35))
        if state.mark("herbalist_involved","Травница вошла в запертый дом. Староста узнает о её участии."):state.relate("elder",-1)
func reset_session() -> void:
    ui.close();release_all()
    if dialogue.is_active():dialogue._context_exiting()
    life._release_session();life.switching=false
    var worlds:Array=[]
    for w in [travel.active_world,travel.exterior]+travel.rooms.values():
        if is_instance_valid(w) and w not in worlds:worlds.append(w)
    travel.rooms.clear();travel.resident_locations.clear();travel.active_world=null;travel.exterior=null;travel.active_id=&"";travel.busy=false;travel._held_gate=false
    for w in worlds:
        if get_tree().current_scene==w:get_tree().current_scene=null
        w.free()
    travel.buildings.erase(&"logging_camp");travel.buildings.erase(&"abandoned")
    _pending="";_speaker=null;_wife_interrupted=false;_wife_visit_delay=0;_elder_visit_left=0
func start_new(test:bool=false,index:int=0) -> void:
    if busy:return
    busy=true;reset_session();active=true;test_mode=test;state=STATE.new()
    if test:state.prepare(index if index<6 else 5)
    state.journal.append("Поздний осенний вечер. Нужно найти работу и ночлег. J — журнал, I — сумка.")
    get_tree().paused=false
    var error:=get_tree().change_scene_to_file(travel.VILLAGE)
    if error!=OK:busy=false;active=false;return
    await get_tree().scene_changed
    for i in 5:await get_tree().process_frame
    life.clock.seek(17*60+20);_attach(travel.active_world)
    travel.active_world.player.position=Vector2(1378,2460)
    travel.active_world.player.get_node("Camera2D").reset_smoothing()
    if index==0:reserve("woodcutter",travel.active_world.get_node("Actors/Residents"),Vector2(1410,2410))
    if test and index==6:
        state.choose("approach","alone");state.mark("house_open");state.mark("diary_found");state.give("diary")
        life.clock.seek(22*60+30);travel.active_world.player.position=Vector2(560,952)
    busy=false;ui.notice("Глава I — Тени Кривой Сосны"+(" · тестовый прогресс" if test else ""))
func available(a:String) -> bool:
    if not active:return false
    match a:
        "take_dishes":return state.has("inn_work") and not state.has("dishes_taken")
        "deliver_dishes":return state.has("dishes_taken") and not state.has("dishes_delivered")
        "axe_found","tools","tracks":return state.has("night") and not state.has(a)
        "valerian","thyme","poison":return state.has("herbs_started") and not state.has("herbs_done") and state.count(a)==0
        "north":return state.has("ban_known")
        "pine_symbol":return state.has("herbs_done") and not state.has(a)
        "finale":return state.has("diary_found") and not state.has("finale")
        "wheel":return state.has("toy_started") and not state.has("wheel_found")
        "repair":return state.has("toy_started") and not state.has("toy_done")
        "collect_logs":return state.has("wood_started") and not state.has("logs_taken")
        "deliver_logs":return state.count("logs")>=2
        "take_mug":return state.has("mug_started") and not state.has("mug_taken")
        "dry_take":return state.has("dry_started") and not state.has("dry_taken")
        "dry_sort":return state.count("dry")>0
        "archive":return state.has("herbs_done") and not state.has("archive")
        "official_copy":return state.decisions.get("approach")=="elder" and not state.has("official_copy")
        "struggle","handle","cloth","vanishing":return state.has("wolves_clear") and not state.has(a)
        "floor_cache":return not state.has(a)
        "cabinet":return not state.has("diary_found")
        "wolves":return not state.has("wolves_clear")
    return true
func interact(a:String) -> void:
    if busy or not available(a) or dialogue.is_active():return
    var message:="";var options:Array=[]
    match a:
        "sign":message="Кривая Сосна — 1 верста. Ниже, на коре: «Не ходи за деревьями после заката». Надпись свежая, а последняя буква дрожит.";options=[["sign","Запомнить предупреждение.","Трактир должен быть рядом. Надо спросить дорогу."]]
        "leave":message="Южная дорога свободна. Можно уйти, пока свет ещё держится в небе.";options=[["leave_end","Уйти из Кривой Сосны.","Ты выбираешь дорогу, а не чужую тайну."],["stay","Вернуться в деревню.","Сначала — ночлег. Утром решу."]]
        "sleep":
            message="Тюфяк у нижней стены, рядом с корзиной. "+("Ночлег оплачен трудом или монетой." if state.has("lodging") else "Сначала нужно договориться с трактирщиком.")
            if state.has("lodging"):options=[["sleep","Отдохнуть до утра.","Ганс закрывает глаза. За стеной шуршит лес."]]
        "wait":message="У печи тепло. Можно дождаться нужного времени.";options=[["wait_evening","Подождать до 17:30.","Вечер подходит к деревне."],["wait_night","Подождать до 22:15.","За окнами темнеет."]]
        "axe_found":message="На лезвии засохла чёрная смола. У обуха — три зарубки. Рукоять ещё пахнет дымом.";options=[[a,"Обернуть топор тканью и взять.","Находка убрана в сумку. Решить её судьбу можно через осмотр в инвентаре или разговор со старостой/братом травницы."]]
        "valerian","thyme","poison":
            message={"valerian":"Белые соцветия и резкий запах светлого корня. Совпадает с описанием травницы.","thyme":"Куст низкий, листья мелкие, пахнут дымом и мёдом. Похоже на чабрец.","poison":"Белый зонтик похож на валериану, но на стебле тёмные пятна. Травница предупреждала о таком растении."}[a]
            options=[[a,"Собрать растение.","Ганс осторожно срезает растение и кладёт отдельно от пищи."]]
        "repair":
            if state.count("fixed_toy")>0:message="Лошадка уже починена. Пора вернуть её мальчику."
            elif state.count("toy")==0:message="Для ремонта нужна сломанная лошадка. Поговори с сыном дровосека."
            elif state.count("wheel")==0:message="Не хватает колеса. Оно укатилось к колодцу; больше ничего приносить не нужно."
            else:
                message="Лошадка и колесо на месте. На верстаке есть деревянный штифт — других материалов не нужно."
                options=[[a,"Закрепить колесо деревянным штифтом.","Колесо держится и свободно крутится. Теперь можно вернуть лошадку мальчику."]]
        "north":message="За северной тропой лежит овраг и старые лесозаготовки.";options=[["go_camp","Продолжить по тропе.","Под ногами становятся видны глубокие следы телеги."]]
        "camp_exit":message="Дорога обратно в деревню ещё видна.";options=[["exit_location","Вернуться в хутор.","Ганс оставляет за спиной тихую вырубку."]]
        "house_exit":message="Дверь ведёт во двор.";options=[["exit_location","Выйти.","Ночной воздух кажется теплее, чем воздух в доме."]]
        "wolves":
            message="Два волка держатся поперёк старой колеи. Западнее есть обход вдоль оврага: держись левой кромки, затем поверни к навесу. Можно вернуться позже."
            options=[["fight","Вступить в бой.","Ганс крепче берёт дорожный нож."],["exit_location","Отступить в деревню.","Лучше вернуться подготовленным."]]
            if state.count("bait")>0:options.insert(1,["bait","Бросить мясо в боковую ложбину.","Волки уходят на запах. Можно пройти к навесу."])
        "abandoned":
            if not state.has("camp_done"):message="Ставни заколочены. Под щелью двери пахнет сырой золой. Без причины ломать чужой дом Ганс не станет."
            elif not state.decisions.has("approach"):
                message="Три зарубки есть и на гнилой ставне. Можно открыть засов самому, попросить травницу пойти с тобой или сообщить старосте."
                options=[["approach_alone","Решить идти одному.","Травница не будет рисковать из-за тебя. Ключ к засову — гнилая ставня с тремя зарубками."]]
            elif life.clock.phase_name()!=&"night":message="Окна тёмные. Следует вернуться ночью. Подождать можно у печи в трактире."
            else:
                message="В доме горит свеча. Ставня со знаком поддаётся, и засов можно приподнять через щель."
                options=[["go_house","Открыть засов и войти.","За дверью тихо. Слишком тихо для дома с горящей свечой."]]
        "cabinet":
            message="У старого шкафа целый замок. Ключ мог остаться в доме."
            if state.count("key")>0:options=[[a,"Открыть шкаф ключом.","Внутри — дневник. Последняя запись: «Мы думали, что оно живёт в лесу. Но лес лишь держит его снаружи»."]]
        "floor_cache":message="Пыль у одной половицы стёрта недавно. Из щели проступает чёрная смола.";options=[[a,"Поднять половицу.","Под доской лежит ключ. На нижней стороне дерева отпечатаны пальцы — с той стороны, где никто не мог держаться."]]
        "family":message="На полке детская рубаха и три деревянные ложки. Семья собиралась ужинать, а не уходить. На полу — свежая грязь, поверх старой пыли.";options=[[a,"Осмотреть следы присутствия.","Кто-то недавно ходил здесь босиком. Следы ведут от шкафа к стене."]]
        "house_symbol":message="Три зарубки на стене направлены внутрь комнаты.";options=[[a,"Сопоставить знак с найденными уликами.","Знак повторяет топор и сосну. "+("Травница шепчет: это не приглашение. Так отмечали границу, которую нельзя открывать." if state.has("herbalist_involved") else "Из описи и слов старика становится ясно: это знак закрытой границы.")]]
        "official_copy":message="Выписка из закрытой описи: семья Саввы пыталась запереть границу изнутри. Ключ от шкафа спрятан под половицами. Староста вычеркнул строку о ночном свете, но её ещё можно прочесть.";options=[[a,"Переписать уцелевшие строки.","Староста ограничил доступ к архиву, но выдал документ, которого раньше не показывал."]]
        "finale":message="Теперь нужно вернуться к старому знаку на сосне.";options=[["finale","Остановиться и прислушаться.","Лес замолкает."]]
        _:
            message={"tools":"Инструменты сложены бережно, будто хозяин отошёл на минуту.","tracks":"Шаги ведут на север. В мокрой земле проступают необычно длинные корни.","pine_symbol":"На коре — три старых зарубки. Их края заросли, но дерево словно отворачивает ветви от знака.","archive":"В описи упомянута исчезнувшая семья Саввы, запретная вырубка и ключ под половицами. Запрет старше самого старосты.","take_dishes":"Посуда осталась на гостевом столе.","deliver_dishes":"Кухонная стойка свободна. Здесь хозяйка принимает посуду.","wheel":"В грязи возле колодца деревянное колесо.","repair":"На верстаке хватает обрезков и деревянных штифтов.","collect_logs":"Две сухие связки можно перенести к домашней печи.","deliver_logs":"У печи есть место для зимних дров.","take_mug":"На ручке кружки буква М. Кто-то долго держал её возле огня.","dry_take":"Сухие связки висят отдельно от зерна.","dry_sort":"Тёмные листья в сторону, светлые в чистую корзину.","struggle":"Под навесом взрыта земля. Два человека пытались удержаться за край телеги.","handle":"Рукоять выкручена поперёк волокон.","cloth":"Синий лён зажат в корнях. Такой цвет описал брат травницы.","vanishing":"Следы человека заканчиваются у дерева. Вверх на кору не ведёт ни одной царапины."}.get(a,"Осмотреть находку.")
            options=[[a,"Осмотреть и запомнить." if a in ["tools","tracks","pine_symbol","struggle","vanishing","archive"] else "Выполнить действие.",message]]
    talk("Ганс",message,options)
func speak(id:String) -> void:
    if busy or dialogue.is_active():return
    var r:RefCounted=life.states.get(StringName(id))
    if not r or not r.actor.is_inside_tree():return
    _speaker=r.actor;_speaker.begin_conversation()
    var options:Array=CONTENT.options(state,id,life.clock.phase_name()==&"evening")
    options.append(["legacy:"+id,"Поговорить о повседневном.","Есть вещи, о которых здесь всё ещё можно говорить спокойно."])
    var greeting:="Что ты хотел узнать, путник?"
    if state.has("finale"):greeting="После ночных ударов хутор кажется другим. Но людям всё ещё нужно топить печи."
    if id=="elder" and state.decisions.get("axe")=="keep":greeting="Говорят, ты нашёл кое-что в лесу и оставил себе. Любопытство бывает дорогим."
    if id=="herbalist_brother" and state.decisions.get("axe")=="elder":greeting="Староста забрал топор? Тогда запомни всё, что видел на железе. Вещи у него умеют пропадать."
    if id=="elder" and state.has("herbalist_involved"):greeting="Ты привёл туда травницу. Теперь отвечать придётся и ей. Я предупреждал, что дом должен стоять запертым."
    talk(r.actor.definition.display_name,greeting,options,id)
func talk(speaker:String,text:String,options:Array,id:String="") -> void:
    var portraits:Dictionary={};var portrait:=""
    if id!="":
        var original:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://dialogues/residents/"+id+".json"))
        if original and not original.nodes.is_empty():portraits=original.nodes[0].get("portraits",{});portrait=original.nodes[0].get("portrait","")
    var choices:Array=[];var nodes:Array=[]
    for i in options.size():
        var o:Array=options[i];choices.append({"id":o[0],"text":o[1],"next":"reply_"+str(i)})
        var replies:Array=o[2] if o[2] is Array else [o[2]]
        for j in replies.size():
            var key:String="reply_"+str(i)+( "_"+str(j) if j>0 else "")
            var node:Dictionary={"id":key,"speaker":speaker,"text":replies[j],"portrait":portrait,"portraits":portraits,"emotion":"anxious" if id!="" else "neutral"}
            if j==replies.size()-1:node["end"]=true
            else:node["next"]="reply_"+str(i)+"_"+str(j+1)
            nodes.append(node)
    choices.append({"id":"close","text":"На этом всё.","end":true})
    nodes.push_front({"id":"start","speaker":speaker,"text":text,"portrait":portrait,"portraits":portraits,"emotion":"neutral","choices":choices})
    var data:=HutorDialogueData.from_dictionary({"id":"chapter_i","start":"start","nodes":nodes})
    if not dialogue.start_dialogue(data,travel.active_world.player,travel.active_world.hud):
        if is_instance_valid(_speaker):_speaker.end_conversation()
        _speaker=null
func _choice(id:String,_line:String,choice:String) -> void:
    if id=="chapter_i" and choice!="close":_pending=choice
func _finished(id:String,_reason:String) -> void:
    if id!="chapter_i":return
    if is_instance_valid(_speaker):_speaker.end_conversation()
    _speaker=null
    var a:=_pending;_pending=""
    if a!="":apply.call_deferred(a)
func apply(a:String) -> void:
    if not active:return
    if a.begins_with("legacy:"):
        var id:=a.trim_prefix("legacy:");var r:RefCounted=life.states.get(StringName(id))
        if r and r.actor.is_inside_tree():
            r.actor.begin_conversation();_speaker=r.actor
            dialogue.dialogue_finished.connect(_legacy_done,CONNECT_ONE_SHOT)
            dialogue.start_file(r.actor.definition.dialogue_path,travel.active_world.player,travel.active_world.hud)
        return
    match a:
        "sleep":
            if not state.has("lodging"):return
            busy=true
            if not state.has("night"):
                life.clock.seek(maxf(life.clock.absolute_minutes,floor(life.clock.absolute_minutes/1440)*1440+1330))
                await ui.sequence("Три удара",["Из леса доносится первый удар.","Второй удар. За стеной перестают шуршать листья.","Третий. Никто в трактире не отвечает."],true)
                state.mark("night","Ночью из леса донеслись три удара топора. Дровосек может знать, кто работает в темноте.")
            var morning:float=floor(life.clock.absolute_minutes/1440)*1440+420
            if morning<=life.clock.absolute_minutes:morning+=1440
            life.clock.seek(morning);state.health=108;busy=false
        "wait_evening","wait_night":
            var target:=1050 if a=="wait_evening" else 1335
            var day:float=floor(life.clock.absolute_minutes/1440)*1440
            if life.clock.minute_of_day()>=target:day+=1440
            life.clock.seek(day+target)
        "go_camp":
            if state.has("ban_known"):_go(&"logging_camp")
        "go_house":
            if state.has("camp_done") and state.decisions.has("approach") and life.clock.phase_name()==&"night":state.mark("house_open");_go(&"abandoned")
        "exit_location":_go(travel.active_id,true)
        "fight":
            if travel.active_id==&"logging_camp" and not state.has("wolves_clear"):start_encounter()
        "finale":
            if not state.has("diary_found") or state.has("finale"):return
            if SAVE.write(self,"checkpoint")!=OK:ui.notice("Не удалось создать контрольное сохранение. Проверьте место на диске.");return
            busy=true;state.mark("finale","У сосны появились свежие зарубки. Голос из леса: «Они снова открыли дорогу».")
            await ui.sequence("Тени Кривой Сосны",["Старое дерево вздрагивает. На коре проступают три свежие зарубки.","«Они снова открыли дорогу».","Между стволами стоит неподвижный человек. В следующее мгновение его уже нет."],true)
            busy=false;ui.ending(false)
        "leave_end":
            if SAVE.write(self,"checkpoint")!=OK:ui.notice("Не удалось сохранить возвращение к развилке.");return
            state.mark("left_village");ui.ending(true)
        _:
            var r:Dictionary=ACTIONS.apply(state,a)
            if r.ok:
                if a=="greeted":release("woodcutter")
                ui.notice("Журнал и сумка обновлены · J / I")
            else:ui.notice("Сейчас это действие недоступно.")
    state.changed.emit()
func _legacy_done(_id:String,_reason:String) -> void:
    if is_instance_valid(_speaker):_speaker.end_conversation()
    _speaker=null
func _go(id:StringName,exit:bool=false) -> void:
    release_all();travel._held_gate=false
    if not travel.request_transition(id,exit):ui.notice("Переход недоступен. Закройте окна и повторите.")
func reserve(id:String,population:Node2D,at:Vector2) -> void:
    if _reserved.has(id):return
    var r:RefCounted=life.states.get(StringName(id))
    if not r:return
    life._park(r);var actor:HutorResident=r.actor
    _reserved[id]=true;actor.set_meta("chapter_reserved",true);actor.reparent(population,false);actor.position=at
    actor.director=population;population.adopt(actor)
    actor.motion_paused=true;actor.set_physics_process(false);actor.activity_controller.clear_props();actor.animator.apply("idle",&"down",&"",false)
func release(id:String) -> void:
    if not _reserved.has(id):return
    var record:RefCounted=life.states[StringName(id)];var actor:HutorResident=record.actor
    if id in ["woodcutter","old_man"] and travel.active_id==&"" and actor.is_inside_tree():
        # Visible story pauses end with a real walk to the scheduled destination.
        record.scene=&"village";record.position=actor.position;record.mode=&"local";record.snapshot.clear();record.travel_end=0
    if id=="elder" and travel.active_id==&"inn" and is_instance_valid(travel.exterior):
        record.scene=&"village";record.position=travel.exterior.get_node(travel.buildings[&"inn"].exterior_anchor).global_position+Vector2(0,54)
        record.mode=&"local";record.snapshot.clear();record.travel_end=0
    actor.remove_meta("chapter_reserved");actor.reparent(life._parking,false);actor.motion_paused=false;actor.set_physics_process(true)
    _reserved.erase(id);life.after_scene_change(life.active_scene())
func release_all() -> void:
    for id in _reserved.keys():release(id)
func save_game(slot:String="manual") -> bool:
    if busy or not active or dialogue.is_active() or travel.busy:return false
    var ok:bool=SAVE.write(self,slot)==OK;ui.notice("Игра сохранена." if ok else "Не удалось сохранить игру.");return ok
func load_game(test:bool=false,slot:String="manual") -> bool:
    if busy:return false
    var value:Dictionary=SAVE.read(test,slot)
    if value.is_empty():ui.notice("Сохранение отсутствует или повреждено. Текущая игра сохранена без изменений.");return false
    for id in value.people:
        if not life._profiles.has(StringName(id)):return false
    await start_new(test,0)
    busy=true;release_all();life.clock.running=false;life.clock.seek(value.minute);life.before_scene_change()
    state.unpack(value.chapter)
    for id in value.people:
        var r:RefCounted=life.states[StringName(id)];var row:Dictionary=value.people[id]
        for field in SAVE.FIELDS:r.set(field,row[field])
        r.snapshot=row.snapshot.duplicate(true);r.actor._rng.state=row.rng
    life.after_scene_change(&"village")
    if value.location!="":
        _go(StringName(value.location))
        while travel.busy:await get_tree().process_frame
    travel.active_world.player.position=travel.active_world.get_node("ChapterWorld").saved_floor_position(value.position);travel.active_world.player.facing=value.facing
    travel.active_world.player.get_node("Camera2D").reset_smoothing();busy=false;life.clock.running=true;state.changed.emit();ui.notice("Сохранение загружено.");return true
func start_encounter() -> void:
    busy=true;release_all();life.before_scene_change();_battle_world=travel.active_world;_battle_clock=life.clock.running;life.clock.running=false
    if is_instance_valid(life._widget):life._widget.hide()
    _battle_world.player.controls_locked=true;get_tree().root.remove_child(_battle_world)
    var arena:Control=load("res://scenes/chapter/ForestEncounter.tscn").instantiate();get_tree().root.add_child(arena);get_tree().current_scene=arena
func finish_encounter(result:String,hp:int,potions:int) -> void:
    var arena:Node=get_tree().current_scene;get_tree().root.remove_child(arena);arena.queue_free()
    get_tree().root.add_child(_battle_world);get_tree().current_scene=_battle_world;travel.active_world=_battle_world
    life.clock.running=_battle_clock;life.after_scene_change(&"logging_camp")
    if result=="victory":state.mark("wolves_clear","Волки прогнаны в бою.");state.choose("wolves","fight")
    state.health=maxi(1,hp);state.items.erase("tincture")
    if potions>0:state.give("tincture",potions)
    if result=="defeat":state.health=54;state.money=maxi(0,state.money-2);ui.notice("Ганс очнулся у края тропы: потеряны две монеты. Есть обход на западе.")
    _battle_world.player.position=Vector2(590,970) if result!="victory" else Vector2(600,580)
    _battle_world.player.controls_locked=false;_battle_world.player.get_node("Camera2D").reset_smoothing();busy=false;state.changed.emit()
func _input(event:InputEvent) -> void:
    if not active or not event is InputEventKey or not event.pressed or event.echo:return
    var key:int=event.physical_keycode if event.physical_keycode else event.keycode
    if ui.is_open():
        if not busy and not ui.blocking and key in [KEY_ESCAPE,KEY_J,KEY_I]:ui.close()
        get_viewport().set_input_as_handled();return
    if busy:return
    if dialogue.is_active() or travel.busy or get_tree().paused:return
    match key:
        KEY_J:ui.journal()
        KEY_I:ui.inventory()
        KEY_F5:save_game()
        KEY_F9:load_game(test_mode)
        _:return
    get_viewport().set_input_as_handled()
func _process(delta:float) -> void:
    if not active or busy or get_tree().paused:return
    if state.has("herbs_done") and not state.has("old_met") and life.clock.phase_name()==&"evening" and travel.active_id==&"" and is_instance_valid(travel.active_world):
        reserve("old_man",travel.active_world.get_node("Actors/Residents"),Vector2(560,945))
    if _reserved.has("old_man") and (state.has("old_met") or life.clock.phase_name()!=&"evening"):release("old_man")
    if is_instance_valid(_speaker) and _speaker.definition.id==&"innkeeper_wife" and not state.has("elder_visit") and life.clock.minute_of_day()>=1020 and life.clock.minute_of_day()<1320:
        _wife_visit_delay+=delta
        if _wife_visit_delay>2.4:
            reserve("elder",travel.active_world.get_node("Actors/Residents"),travel.active_world.get_node("Entry").position+Vector2(-24,0))
            _elder_visit_left=3;state.mark("elder_visit","Староста вошёл в трактир. Хозяйка оборвала разговор.")
    else:_wife_visit_delay=0
    if _reserved.has("elder") and travel.active_id==&"inn":
        _elder_visit_left-=delta
        if _elder_visit_left<=0:
            var visitor:HutorResident=life.states[&"elder"].actor
            var exit_point:Vector2=travel.active_world.get_node("Exit").position
            if visitor.position.distance_to(exit_point)<5:release("elder")
            else:
                visitor.face_point(exit_point);visitor.velocity=(exit_point-visitor.position).normalized()*24
                visitor.move_and_slide();visitor.animator.apply("walk",visitor.facing,&"",false)
    if _trail_left>0:
        _trail_left-=delta
        var waiting:CharacterBody2D=_trail_actor.get_ref() if _trail_actor else null
        if _trail_left<=0 and is_instance_valid(waiting):waiting.motion_paused=false
    elif state.has("night") and not state.has("wood_trail_pause") and life.states.has(&"woodcutter"):
        var worker:HutorResident=life.states[&"woodcutter"].actor
        if worker.is_inside_tree() and life.states[&"woodcutter"].scene==&"village" and worker.position.distance_to(Vector2(1384,190))<130 and worker.state!=HutorResident.State.TALKING:
            worker.motion_paused=true;_trail_actor=weakref(worker);_trail_left=4
            state.mark("wood_trail_pause","Дровосек задержался у северной тропы и долго смотрел в лес.")
    if _reserved.has("herbalist") and travel.active_id==&"abandoned" and not dialogue.is_active():
        var a:HutorResident=life.states[&"herbalist"].actor;var v:Vector2=travel.active_world.player.position-a.position
        a.velocity=v.normalized()*minf(34,(v.length()-45)/maxf(delta,.001)) if v.length()>55 else Vector2.ZERO
        a.move_and_slide();a.face_point(travel.active_world.player.position);a.animator.apply("walk" if a.velocity.length()>1 else "idle",a.facing,&"",false)
    if is_instance_valid(_speaker) and _speaker.definition.id==&"innkeeper_wife" and not _wife_interrupted:
        var elder:HutorResident=life.states[&"elder"].actor
        if elder.is_inside_tree() and elder.get_parent()==_speaker.get_parent():
            _wife_interrupted=true;_pending="wife_interrupted";dialogue.close_dialogue("elder_arrived")
            ui.notice("Хозяйка умолкает при появлении старосты.")
func _exit_tree() -> void:
    if is_instance_valid(_battle_world) and _battle_world.get_parent()==null:_battle_world.free()
