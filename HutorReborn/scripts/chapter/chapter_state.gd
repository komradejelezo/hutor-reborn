extends RefCounted
## Serializable chapter rules. No nodes, scene travel, UI or persistent side effects.
signal changed
var flags:Dictionary={}
var items:Dictionary={}
var clues:Dictionary={}
var trust:Dictionary={}
var decisions:Dictionary={}
var money:=6
var health:=108
var journal:Array=[]
const QUESTS=[
    ["lodging","Ночлег для чужака","Найти ночлег в трактире и пережить первую ночь.","Доберитесь до трактира. Дровосек может подсказать дорогу.","night"],
    ["miron","Пропавший Мирон","Четверо жителей помнят разные части исчезновения.","Расспросите дровосека, его жену и сына, брата травницы. Осмотрите северную тропу и решите судьбу топора.","investigation"],
    ["roots","Горькие корни","Травница узнаёт смолу с топора.","Попросите травницу описать растения; соберите валериану и чабрец, затем вернитесь к ней.","herbs_done"],
    ["strikes","Три удара","Символ связывает топор, старую сосну и пустой дом.","Поговорите со стариком. Осмотрите сосну и документы старосты, если старик молчит.","ban_known"],
    ["logging","По ту сторону тропы","Мирона видели за северным оврагом.","Идите по северной тропе к лесозаготовкам. Преодолейте волчий дозор и осмотрите четыре следа.","camp_done"],
    ["house","Дом без хозяина","Теперь можно проверить свет в запертом доме.","Выберите, идти ли одному, с травницей или с ведома старосты. Ночью откройте дом, найдите дневник и вернитесь к сосне.","finale"]]
const SIDES=[
    ["toy","Сломанная игрушка","Найдите деревянное колесо у колодца, отнесите к верстаку склада и верните игрушку мальчику.","toy_done"],
    ["wood","Дрова к зиме","Перенесите две связки из поленницы у дома дровосека к домашней печи.","wood_done"],
    ["mug","Последняя кружка","Осмотрите забытую кружку в трактире, узнайте у брата травницы её владельца и вернитесь к трактирщику.","mug_done"],
    ["dry","Сухие травы","Снимите сухие связки на складе, отсортируйте их на столе травницы и отчитайтесь.","dry_done"]]
func has(key:String) -> bool:return bool(flags.get(key,false))
func count(id:String) -> int:return int(items.get(id,0))
func mark(key:String,text:String="") -> bool:
    if has(key):return false
    flags[key]=true
    if text!="":journal.append(text)
    _reconcile();changed.emit();return true
func clue(id:String,text:String) -> void:
    if clues.has(id):return
    clues[id]=text;journal.append(text);changed.emit()
func give(id:String,n:int=1) -> void:
    items[id]=count(id)+n;changed.emit()
func take(id:String,n:int=1) -> bool:
    if count(id)<n:return false
    items[id]=count(id)-n
    if items[id]==0:items.erase(id)
    changed.emit();return true
func relate(id:String,n:int) -> void:trust[id]=int(trust.get(id,0))+n;changed.emit()
func choose(key:String,value:String) -> bool:
    if decisions.has(key):return false
    decisions[key]=value;changed.emit();return true
func _reconcile() -> void:
    if ["w_woodcutter","w_herbalist_brother","w_woodcutter_wife","w_woodcutter_son","axe_found","tools","tracks"].all(func(k:String):return has(k)) and decisions.has("axe"):
        flags.investigation=true
    if has("herbs_done") and has("pine_symbol") and has("warning") and has("old_met"):flags.ban_known=true
    if ["struggle","handle","cloth","vanishing"].all(func(k:String):return has(k)):flags.camp_done=true
func stage() -> int:
    for i in QUESTS.size():
        if not has(QUESTS[i][4]):return i
    return 6
func reward(key:String,id:String="",n:int=1,npc:String="") -> bool:
    if not mark(key):return false
    if id!="":give(id,n)
    if npc!="":relate(npc,1)
    return true
func pack() -> Dictionary:
    return {"flags":flags.duplicate(true),"items":items.duplicate(true),"clues":clues.duplicate(true),"trust":trust.duplicate(true),"decisions":decisions.duplicate(true),"money":money,"health":health,"journal":journal.duplicate()}
func unpack(value:Dictionary) -> bool:
    if not value.has_all(["flags","items","clues","trust","decisions","money","health","journal"]):return false
    for k in ["flags","items","clues","trust","decisions"]:
        if not value[k] is Dictionary:return false
    if not value.journal is Array or int(value.money)<0 or int(value.health)<1 or int(value.health)>108:return false
    for id in value.items:
        if not value.items[id] is int or value.items[id]<1:return false
    flags=value.flags.duplicate(true);items=value.items.duplicate(true);clues=value.clues.duplicate(true)
    trust=value.trust.duplicate(true);decisions=value.decisions.duplicate(true)
    money=int(value.money);health=int(value.health);journal=value.journal.duplicate();_reconcile();changed.emit();return true
func prepare(index:int) -> void:
    # Developer-only fixtures are built through the same inventory/flag rules.
    for i in mini(index,6):flags[QUESTS[i][4]]=true
    if index>=1:
        flags.lodging=true;decisions.lodging="work";flags.inn_work=true;flags.dishes_taken=true;flags.dishes_delivered=true
    if index>=2:
        for k in ["w_woodcutter","w_woodcutter_wife","w_woodcutter_son","w_herbalist_brother","axe_found","tools","tracks"]:flags[k]=true
        decisions.axe="keep";flags.axe_decided=true;items.axe=1;clues.resin="Топор покрыт чёрной смолой.";clues.notches="На металле три зарубки."
        for id in ["woodcutter","woodcutter_wife","woodcutter_son","herbalist_brother"]:clues["w_"+id]=preload("res://scripts/chapter/chapter_content.gd").WITNESSES[id]
    if index>=3:
        flags.herbs_started=true;items.tincture=2;items.root=1;trust.herbalist=1;clues.root_story="Чёрная смола встречалась у корней сосны. Человек после контакта с ними не узнавал свою семью."
    if index>=4:
        flags.warning=true;flags.pine_symbol=true;flags.old_met=true;clues.ban="Запрет рубить за оврагом связан со знаком трёх зарубок.";clues.pine_symbol="На сосне повторяется знак с топора."
    if index>=5:
        for k in ["struggle","handle","cloth","vanishing"]:flags[k]=true
        items.cloth=1;items.handle=1;flags.wolves_clear=true;decisions.wolves="bypass"
        clues.struggle="У навеса следы борьбы.";clues.handle="Рукоять скручена поперёк волокон.";clues.cloth="Синий лён зажат в корнях.";clues.vanishing="Следы человека обрываются у дерева."
    _reconcile();changed.emit()
