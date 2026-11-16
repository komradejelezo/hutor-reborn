extends RefCounted
## Pure, synchronous battle rules; UI explicitly advances after showing an action.
const UNIT=preload("res://scripts/combat/combat_unit.gd")
var catalog:RefCounted
var scenario:Dictionary
var units:Dictionary={}
var order:Array[String]=[]
var cursor:=-1
var round:=0
var active:String=""
var result:=""
var potions:=0
var roots_left:=1
var raven_left:=1
var betrayed:=false
var waiting:=false
var rng:=RandomNumberGenerator.new()
var actions:=0
func _init(definitions:RefCounted,id:String,seed_value:int=-1) -> void:
    catalog=definitions;scenario=catalog.scenario(id)
    if seed_value<0:rng.randomize()
    else:rng.seed=seed_value
    if catalog.error!="" or scenario.is_empty():result="error";return
    potions=int(scenario.potions)
    var counts:Dictionary={}
    for slot in scenario.units:
        var u:RefCounted=UNIT.new(catalog.data.units[slot.kind],slot);u.serial=units.size();units[u.id]=u
        counts[u.kind]=int(counts.get(u.kind,0))+1
        if scenario.units.filter(func(s:Dictionary):return s.kind==u.kind).size()>1:u.name+=" "+str(counts[u.kind])
func living(team:int) -> Array:
    return units.values().filter(func(u:RefCounted):return u.team==team and u.alive())
func actor() -> RefCounted:return units.get(active)
func _end() -> void:
    if living(0).is_empty():result="defeat"
    elif living(1).is_empty():result="victory"
    if result!="":waiting=false;active=""
func _event(type:String,text:String,extra:Dictionary={}) -> Dictionary:
    var e:Dictionary={"type":type,"text":text};e.merge(extra);return e
func _new_round() -> Array:
    round+=1;cursor=-1
    var events:Array=[_event("round","Раунд "+str(round))]
    if not betrayed and int(scenario.get("betray_round",0))==round:
        betrayed=true
        var merc:RefCounted=units.get("mercenary")
        if merc and merc.alive():
            merc.team=1;merc.guarding=false
            var occupied:Dictionary={}
            for u in units.values():
                if u!=merc and u.team==1:occupied[u.row+str(u.lane)]=true
            for slot in ["front0","front1","back0","back1"]:
                if not occupied.has(slot):merc.row="front" if slot.begins_with("front") else "back";merc.lane=int(slot[-1]);break
            events.append(_event("betray","Наёмник: «Прости, путник. Они платят больше». Он переходит к врагам.",{"target":merc.id}))
        else:events.append(_event("log","Наёмник погиб. Предательство не состоялось."))
    order.clear()
    for u in units.values():
        if u.alive():order.append(u.id)
    # Stable scene insertion order resolves equal initiative, without extra rolls.
    order.sort_custom(func(a:String,b:String):return units[a].initiative>units[b].initiative if units[a].initiative!=units[b].initiative else units[a].serial<units[b].serial)
    return events
func advance() -> Array:
    if result!="" or waiting:return []
    var events:Array=[]
    _end()
    if result!="":return events
    for safety in 32:
        if cursor+1>=order.size():events.append_array(_new_round())
        cursor+=1
        var u:RefCounted=units[order[cursor]]
        if not u.alive():continue
        u.guarding=false;u.cooldown=maxi(0,u.cooldown-1)
        if u.skips>0:
            u.skips-=1;events.append(_event("skip",u.name+" задержан корнями и пропускает ход.",{"target":u.id}));continue
        active=u.id;waiting=true
        events.append(_event("turn","Ход: "+u.name,{"actor":u.id}));return events
    result="error";events.append(_event("log","Не удалось выбрать следующего бойца."));return events
func special_available(kind:String) -> bool:
    var u:RefCounted=actor()
    if not u or not u.alive():return false
    if kind=="whisper":return u.kind=="spirit" and u.cooldown==0
    if not kind in scenario.get("specials",[]):return false
    if kind=="heal":return u.kind=="herbalist" and u.heals>0
    if kind=="roots":return u.kind=="hans" and roots_left>0
    if kind=="raven":return u.kind=="hans" and raven_left>0
    return false
func target_reason(action:String,id:String) -> String:
    var u:RefCounted=actor();var t:RefCounted=units.get(id)
    if result!="" or not waiting or not u:return "Ход завершён"
    if not t or not t.alive():return "Цель погибла"
    if action in ["item","heal"]:
        if t.team!=u.team:return "Нужен союзник"
        if t.hp==t.max_hp:return "Полное здоровье"
        if action=="item" and (u.team!=0 or potions<=0):return "Настойки закончились"
        if action=="heal" and not special_available("heal"):return "Лечение недоступно"
        return ""
    if action=="raven":return "" if t==u and special_available(action) else "Покровительство доступно Гансу"
    if t.team==u.team:return "Нужен противник"
    if action in ["roots","whisper"]:return "" if special_available(action) else "Помощь недоступна"
    if action!="attack":return "Выберите действие"
    if u.reach=="melee":
        if u.row=="back" and living(u.team).any(func(v:RefCounted):return v.row=="front"):return "Свой передний ряд закрывает ближнюю атаку"
        if t.row=="back" and living(t.team).any(func(v:RefCounted):return v.row=="front"):return "Передний ряд защищает эту цель"
    return ""
func targets(action:String) -> Array[String]:
    var out:Array[String]=[]
    for id in units:
        if target_reason(action,id)=="":out.append(id)
    return out
func hit_chance(attacker:RefCounted,target:RefCounted) -> int:
    return clampi(attacker.accuracy-(int(catalog.data.raven_penalty) if target.raven>0 else 0),5,100)
func act(action:String,target:String="") -> Dictionary:
    var u:RefCounted=actor()
    if result!="" or not waiting or not u:return {"ok":false,"reason":"Сейчас нет активного хода","events":[]}
    if action not in ["attack","defend","item","retreat","heal","roots","raven","whisper"]:return {"ok":false,"reason":"Неизвестное действие","events":[]}
    if action=="retreat" and u.team!=0:return {"ok":false,"reason":"Враги не отступают","events":[]}
    if action not in ["defend","retreat"]:
        var reason:=target_reason(action,target)
        if reason!="":return {"ok":false,"reason":reason,"events":[]}
    var events:Array=[];var t:RefCounted=units.get(target)
    if action=="attack":
        var chance:=hit_chance(u,t);var roll:=rng.randi_range(1,100);var hit:=roll<=chance;var damage:=0
        if t.raven>0:t.raven-=1
        if hit:
            var power:=maxi(1,u.damage-(int(catalog.data.spirit_weaken) if u.weakened>0 else 0))
            var spread:float=float(catalog.data.damage_variation)
            damage=maxi(1,roundi(power*rng.randf_range(1-spread,1+spread))-t.armor)
            if t.guarding:damage=maxi(1,ceili(damage*float(catalog.data.guard_multiplier)))
            damage=mini(t.hp,damage);t.hp-=damage
        var text:String=u.name+" → "+t.name+": "+(str(damage)+" урона" if hit else "промах")+" (шанс "+str(chance)+"%)."
        if not t.alive():text+=" "+t.name+" погибает."
        events.append(_event("attack",text,{"actor":u.id,"target":t.id,"hit":hit,"damage":damage,"killed":not t.alive(),"chance":chance,"roll":roll}))
    elif action=="defend":
        u.guarding=true;events.append(_event("guard",u.name+" защищается: входящий урон −50% до следующего хода.",{"target":u.id}))
    elif action in ["item","heal"]:
        var amount:=int(catalog.data.potion_heal) if action=="item" else int(u.data.heal)
        amount=mini(amount,t.max_hp-t.hp);t.hp+=amount
        if action=="item":potions-=1
        else:u.heals-=1
        events.append(_event("heal",u.name+" помогает "+t.name+": +"+str(amount)+" здоровья.",{"actor":u.id,"target":t.id,"amount":amount}))
    elif action=="roots":
        roots_left-=1;t.skips+=1
        events.append(_event("roots","Корни леса удерживают "+t.name+" на один ход.",{"target":t.id}))
    elif action=="raven":
        raven_left-=1;u.raven=int(catalog.data.raven_attacks)
        events.append(_event("raven","Ворон заслоняет Ганса: следующие две атаки по нему менее точны (−25).",{"target":u.id}))
    elif action=="whisper":
        t.weakened=int(catalog.data.spirit_duration);u.cooldown=3
        events.append(_event("whisper",u.name+" шепчет: урон "+t.name+" снижен на "+str(int(catalog.data.spirit_weaken))+" на два действия.",{"target":t.id}))
    elif action=="retreat":
        var success:=rng.randi_range(1,100)<=int(scenario.retreat)
        if success:result="retreated"
        events.append(_event("retreat",("Отступление удалось." if success else "Отступление сорвалось. Ход потрачен; противники продолжают по инициативе.")+" Шанс "+str(int(scenario.retreat))+"%.",{"success":success,"actor":u.id}))
    if u.weakened>0:u.weakened-=1
    actions+=1;waiting=false;_end()
    return {"ok":true,"events":events}
