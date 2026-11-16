extends Node
## Test-only read-only observer. Never registered in project.godot.
var output:=""
var elapsed:=0.0
func _ready() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--combat-output="):output=arg.trim_prefix("--combat-output=")
func _process(delta:float) -> void:
    elapsed+=delta
    if output=="" or elapsed<.06:return
    elapsed=0
    var scene:Node=get_tree().current_scene
    if not is_instance_valid(scene):return
    var life:Node=get_node("/root/VillageLife")
    var state:Dictionary={"tick":Engine.get_process_frames(),"scene":scene.scene_file_path,"clock":life.clock.absolute_minutes,"clock_running":life.clock.running,"npc_count":life.states.size(),"buttons":[]}
    for b in scene.find_children("*","Button",true,false):
        if not b.is_visible_in_tree():continue
        if scene.scene_file_path=="res://scenes/combat/CombatTestArena.tscn" and is_instance_valid(scene.modal) and not scene.modal.is_ancestor_of(b):continue
        var rect:Rect2=b.get_global_rect()
        state.buttons.append({"text":b.text,"unit":b.unit.id if b.has_signal("chosen") and b.unit else "","disabled":b.disabled,"center":[rect.get_center().x,rect.get_center().y]})
    if scene.scene_file_path=="res://scenes/combat/CombatTestArena.tscn":
        var b:RefCounted=scene.battle
        state["arena"]={"busy":scene.busy,"picker":b==null,"fast":scene.fast.button_pressed,"events":scene.events_log.duplicate()}
        if b:
            var units:Dictionary={}
            for u in b.units.values():units[u.id]={"name":u.name,"team":u.team,"hp":u.hp,"max_hp":u.max_hp,"row":u.row,"lane":u.lane,"raven":u.raven,"weakened":u.weakened}
            state.arena.merge({"scenario":scene.scenario_id,"round":b.round,"actions":b.actions,"active":b.active,"team":b.actor().team if b.actor() else -1,"result":b.result,"potions":b.potions,"roots":b.roots_left,"raven":b.raven_left,"units":units,"order":b.order.duplicate()})
    var f:=FileAccess.open(output+".tmp",FileAccess.WRITE);f.store_string(JSON.stringify(state,"  "));f.close();DirAccess.rename_absolute(output+".tmp",output)
