extends SceneTree
const STATE=preload("res://scripts/chapter/chapter_state.gd")
const ACTION=preload("res://scripts/chapter/chapter_actions.gd")
const CONTENT=preload("res://scripts/chapter/chapter_content.gd")
var passes:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok:bool,message:String) -> void:
    if ok:passes+=1;print("PASS: ",message)
    else:failures+=1;push_error(message)
func act(s:RefCounted,key:String) -> void:ACTION.apply(s,key)
func run() -> void:
    for axe in ["keep","elder","brother"]:
        for reverse in [false,true]:
            var s:RefCounted=STATE.new()
            check(s.stage()==0 and not s.has("night"),"new chapter has no future stages")
            act(s,"pay");act(s,"pay");check(s.money==3 and s.has("lodging"),"lodging paid once")
            s.mark("night");check(s.stage()==1,"first night unlocks investigation")
            var witnesses:Array=["woodcutter","herbalist_brother","woodcutter_wife","woodcutter_son"]
            if reverse:witnesses.reverse()
            if reverse:act(s,"axe_found")
            for id in witnesses:act(s,"w_"+id)
            act(s,"axe_found");act(s,"tools");act(s,"tracks");act(s,"axe_"+axe)
            check(s.stage()==2 and s.count("axe")== (0 if axe=="elder" else 1),"all witness orders and axe decision: "+axe)
            var chosen:String=s.decisions.axe;act(s,"axe_keep");check(s.decisions.axe==chosen,"axe decision cannot be rewritten")
            act(s,"herbs_started");act(s,"poison");act(s,"herbs_done");check(not s.has("herbs_done"),"wrong plant cannot complete collection")
            act(s,"discard_poison");act(s,"thyme");act(s,"valerian");act(s,"herbs_done");act(s,"herbs_done")
            check(s.stage()==3 and s.count("tincture")==2 and s.count("poison")==0,"plant mistake recoverable and reward unique")
            act(s,"pine_symbol");act(s,"warning");check(s.stage()==4,"old man and pine open logging")
            for a in ["cloth","struggle","vanishing","handle"]:act(s,a)
            check(s.stage()==5 and not s.has("house_open"),"camp findings open final investigation, not door automatically")
            for approach in ["alone","herbalist","elder"]:
                var branch:RefCounted=STATE.new();branch.unpack(s.pack());act(branch,"approach_"+approach)
                act(branch,"cabinet");check(not branch.has("diary_found"),"cabinet really requires key")
                act(branch,"floor_cache");act(branch,"floor_cache");act(branch,"cabinet");act(branch,"cabinet")
                check(branch.count("key")==1 and branch.count("diary")==1 and branch.has("diary_found"),"single diary for branch "+approach)
                branch.mark("finale");check(branch.stage()==6 and not branch.mark("finale"),"finale terminal and one-shot")
    var s:RefCounted=STATE.new();act(s,"inn_work");act(s,"take_dishes");act(s,"deliver_dishes");act(s,"work_paid")
    check(s.has("lodging") and s.money==6,"physical inn errand replaces payment")
    for a in ["toy_started","wheel","repair","toy_done","toy_done","wood_started","collect_logs","deliver_logs","wood_done","wood_done","mug_started","take_mug","mug_owner","mug_done","mug_done","dry_started","dry_take","dry_sort","dry_done","dry_done"]:act(s,a)
    check(s.stage()==0 and s.money==10 and s.count("tincture")==1 and s.SIDES.all(func(q:Array):return s.has(q[3])),"four side quests independent, no duplicate money or items")
    s.health=70;act(s,"tincture");check(s.health==100 and s.count("tincture")==0,"story consumable has actual health consequence")
    var copy:RefCounted=STATE.new();check(copy.unpack(s.pack()) and copy.pack()==s.pack(),"chapter state roundtrip retains every flag/item/relation")
    check(not copy.unpack({}) and copy.pack()==s.pack(),"invalid state does not overwrite progress")
    for id in CONTENT.ITEMS:check(ResourceLoader.exists(CONTENT.ITEMS[id][3]),"item icon exists: "+id)
    print("RESULT: ",passes," chapter rule checks passed, ",failures," failed");quit(0 if failures==0 else 1)
