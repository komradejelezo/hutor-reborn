extends SceneTree
const CATALOG=preload("res://scripts/combat/combat_catalog.gd")
const BATTLE=preload("res://scripts/combat/combat_battle.gd")
const AI=preload("res://scripts/combat/combat_ai.gd")
var passed:=0
var failed:=0
var catalog:RefCounted
func _initialize() -> void:call_deferred("run")
func check(ok:bool,message:String) -> void:
    if ok:passed+=1;print("PASS: ",message)
    else:failed+=1;push_error("FAIL: "+message)
func create(id:String,seed_value:int=17) -> RefCounted:return BATTLE.new(catalog,id,seed_value)
func turn(b:RefCounted,id:String) -> void:
    for i in 80:
        if b.waiting and b.active==id:return
        if b.waiting:b.act("defend")
        b.advance()
func policy(b:RefCounted) -> Dictionary:
    var u:RefCounted=b.actor()
    if u.team==1:return AI.choose(b)
    var hurt:Array=b.living(0);hurt.sort_custom(func(a:RefCounted,c:RefCounted):return float(a.hp)/a.max_hp<float(c.hp)/c.max_hp)
    if b.special_available("heal") and hurt[0].hp<=hurt[0].max_hp-25:return {"action":"heal","target":hurt[0].id}
    if b.potions>0 and hurt[0].hp<hurt[0].max_hp*.42:return {"action":"item","target":hurt[0].id}
    if b.special_available("roots"):return {"action":"roots","target":b.targets("roots")[0]}
    if b.special_available("raven"):return {"action":"raven","target":u.id}
    var targets:Array=b.targets("attack")
    return {"action":"attack","target":targets[0]} if not targets.is_empty() else {"action":"defend","target":""}
func run() -> void:
    catalog=CATALOG.new();check(catalog.error=="","valid separate configuration")
    check(catalog.data.scenarios.size()==6 and catalog.data.units.size()==7,"six scenarios / seven unit types")
    var b:=create("duel");b.advance();check(b.active=="wolf_a","initiative starts with fast wolf")
    b.act("defend");b.advance();check(b.active=="hans","next initiative turn belongs to Hans")
    var hp:int=b.units.wolf_a.hp
    check(not b.act("attack","hans").ok and b.waiting and b.units.wolf_a.hp==hp,"invalid target consumes neither damage nor turn")
    b.act("attack","wolf_a");var action_count:int=b.actions
    check(not b.act("attack","wolf_a").ok and b.actions==action_count,"duplicate action rejected before advance")
    b=create("companions");turn(b,"hans")
    check(b.target_reason("attack","spirit")!="" and b.target_reason("attack","beast")=="","front row shields enemy back")
    b.units.beast.hp=0;check(b.target_reason("attack","spirit")=="","back row exposed when front dies")
    b.units.hans.row="back"
    check(b.targets("attack").is_empty(),"melee actor blocked behind own front row")
    b.units.woodcutter.hp=0;check(not b.targets("attack").is_empty(),"rear melee can fight after own front dies")
    var plain:=create("duel",37);var guarded:=create("duel",37)
    turn(plain,"hans");turn(guarded,"hans");plain.actor().accuracy=100;guarded.actor().accuracy=100
    plain.units.wolf_a.guarding=false;guarded.units.wolf_a.guarding=true
    var a:Dictionary=plain.act("attack","wolf_a");var g:Dictionary=guarded.act("attack","wolf_a")
    check(g.events[0].damage==ceili(a.events[0].damage*.5),"guard halves actual damage with same random roll")
    b=create("duel");turn(b,"hans");b.act("defend");check(b.units.hans.guarding,"guard activates")
    b.advance();check(b.units.hans.guarding,"guard persists during enemy turn");b.act("defend");b.advance();check(not b.units.hans.guarding,"guard expires at next own turn")
    b=create("duel");turn(b,"hans");b.units.hans.hp-=8;b.potions=1
    var heal:Dictionary=b.act("item","hans");check(heal.ok and heal.events[0].amount==8 and b.units.hans.hp==b.units.hans.max_hp and b.potions==0,"item heals up to max and consumes party charge")
    turn(b,"hans");b.units.hans.hp-=10;check(not b.act("item","hans").ok and b.waiting,"empty supplies do not consume turn")
    b=create("tincture");turn(b,"herbalist");b.units.hans.hp-=40
    check(b.special_available("heal") and b.act("heal","hans").ok and b.units.herbalist.heals==1,"scenario-specific herbalist support")
    turn(b,"herbalist");b.units.hans.hp=0;check(b.target_reason("heal","hans")!="","healing cannot revive dead allies")
    b=create("duel");turn(b,"hans");b.scenario.retreat=0
    check(b.act("retreat").ok and b.result=="" and not b.waiting,"failed retreat spends turn but combat continues")
    b.advance();check(b.actor().team==1,"enemy gets initiative after failed retreat")
    b=create("duel");turn(b,"hans");b.scenario.retreat=100;b.act("retreat")
    check(b.result=="retreated" and b.advance().is_empty() and not b.act("defend").ok,"successful retreat freezes battle")
    b=create("forest");turn(b,"hans");check(b.act("roots","beast").ok,"roots can target actual enemy")
    var ev:Array=b.advance();check(ev.any(func(e:Dictionary):return e.type=="skip") and b.active=="hans" and b.units.beast.skips==0,"roots skip exactly one enemy turn")
    check(not b.act("roots","beast").ok and b.waiting,"roots are single use")
    b.act("raven","hans");b.advance()
    var first:Dictionary=b.act("attack","hans");check(first.events[0].chance==55 and b.units.hans.raven==1,"raven reduces first incoming accuracy by25")
    b.advance();b.act("defend");b.advance();b.act("attack","hans")
    check(b.units.hans.raven==0 and b.hit_chance(b.units.beast,b.units.hans)==80,"raven expires after two attempts")
    b=create("companions");b.advance();check(b.active=="spirit" and b.act("whisper","hans").ok,"spirit has distinct weakening action")
    b.advance();check(b.active=="hans" and b.units.hans.weakened==2,"weakness reaches victim's next action")
    b.act("defend");turn(b,"hans");b.act("defend");check(b.units.hans.weakened==0,"weakness lasts two actions")
    b=create("betrayal");var retained_hp:int=b.units.mercenary.max_hp-9;b.units.mercenary.hp=retained_hp
    var betrayal_count:=0;var turns:Dictionary={};var duplicate:=false
    for i in 30:
        var events:Array=b.advance()
        for e in events:
            if e.type=="betray":betrayal_count+=1
        var key:String=str(b.round)+"/"+b.active
        if turns.has(key):duplicate=true
        turns[key]=true
        if b.round>=4:break
        b.act("defend")
    check(betrayal_count==1 and b.units.mercenary.team==1 and b.units.mercenary.hp==retained_hp,"traitor changes side once and retains damage")
    check(not duplicate and b.order.count("mercenary")==1,"betrayal never duplicates a scheduled turn")
    b=create("betrayal");b.units.mercenary.hp=0
    for i in 20:
        b.advance()
        if b.round>=3:break
        b.act("defend")
    check(b.betrayed and b.units.mercenary.team==0 and b.units.mercenary.hp==0,"dead mercenary never resurrects or betrays")
    b=create("duel");turn(b,"hans");b.units.wolf_a.hp=1;b.actor().accuracy=100;b.act("attack","wolf_a")
    check(b.result=="victory" and b.units.wolf_a.hp==0 and b.advance().is_empty(),"enemy death produces terminal victory")
    b=create("duel");b.units.hans.hp=1;b.advance();b.actor().accuracy=100;b.act("attack","hans")
    check(b.result=="defeat" and b.active=="","ally death produces terminal defeat")
    var trace1:=simulate("ambush",55);var trace2:=simulate("ambush",55)
    check(trace1==trace2,"battle-local seed reproduces complete fight")
    var results:Dictionary={};var invalid:=""
    for s in catalog.data.scenarios:
        var rounds:Array=[];var outcomes:Dictionary={}
        for seed_value in 50:
            var fight:=simulate(s.id,seed_value);rounds.append(fight.round)
            outcomes[fight.result]=int(outcomes.get(fight.result,0))+1
            if fight.result not in ["victory","defeat"]:invalid=s.id+" seed "+str(seed_value)
        rounds.sort();results[s.id]={"outcomes":outcomes,"median_round":rounds[rounds.size()/2],"min":rounds[0],"max":rounds[-1]}
        check(create(s.id).units.hans.hp==108 and create(s.id).round==0,"fresh independent restart "+s.id)
    check(invalid=="","all 300 seeded battles terminate through legal AI/player actions: "+invalid)
    check(catalog.data.units.hans.health==108,"runtime fights leave source configuration untouched")
    if not OS.get_cmdline_user_args().is_empty():
        var f:=FileAccess.open(OS.get_cmdline_user_args()[0],FileAccess.WRITE);f.store_string(JSON.stringify(results,"  "))
    print("BALANCE ",results);print("RESULT: ",passed," combat rules checks passed, ",failed," failed");quit(0 if failed==0 else 1)
func simulate(id:String,seed_value:int) -> Dictionary:
    var b:=create(id,seed_value);var trace:Array=[]
    for i in 220:
        b.advance()
        if b.result!="":break
        var c:=policy(b);var response:Dictionary=b.act(c.action,c.target)
        if not response.ok:return {"result":"illegal","round":b.round,"trace":trace}
        trace.append(response.events)
    return {"result":b.result,"round":b.round,"trace":trace}
