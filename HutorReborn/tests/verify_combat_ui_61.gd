extends SceneTree
const MENU="res://scenes/menu/MainMenu.tscn"
const ARENA="res://scenes/combat/CombatTestArena.tscn"
const WORLD="res://scenes/world/krivaya_sosna/krivaya_sosna.tscn"
var passed:=0
var failed:=0
func _initialize() -> void:
    call_deferred("run")
func check(ok:bool,message:String) -> void:
    if ok:passed+=1;print("PASS: ",message)
    else:failed+=1;push_error("FAIL: "+message)
func frames(n:int=5) -> void:for i in n:await physics_frame
func ready_turn(arena:Control) -> void:
    for i in 2000:
        await physics_frame
        if not is_instance_valid(arena) or (arena.battle and not arena.busy):return
    check(false,"UI drive deadline")
func run() -> void:
    check(ProjectSettings.get_setting("application/run/main_scene")==MENU,"main entry is actual menu")
    change_scene_to_file(MENU);await scene_changed;await frames()
    var life:Node=root.get_node("VillageLife");var original_minute:float=life.clock.absolute_minutes
    check(not life.initialized and life.states.is_empty() and not life.clock.running,"menu does not start world progression")
    current_scene.open_scene(ARENA);await scene_changed;await frames()
    var arena:Control=current_scene
    check(arena.name=="CombatTestArena" and is_instance_valid(arena.modal),"menu opens scenario picker")
    var descriptions:Array=arena.find_children("ScenarioDescription_*","Label",true,false)
    check(descriptions.size()==6 and descriptions.all(func(l:Label):return l.size.x<=282 and l.autowrap_mode==TextServer.AUTOWRAP_WORD_SMART),"all scenario descriptions wrap inside their own columns")
    arena.fast.button_pressed=true
    for id in ["duel","ambush","companions","tincture","betrayal","forest"]:
        arena._start_scenario(id);await ready_turn(arena)
        check(arena.battle.result=="" and arena.battle.actor().team==0,"playable player turn "+id)
        check(arena.views.size()==arena.battle.units.size() and arena.battle.living(0).size()<=3,"correct distinct views and party size "+id)
        check(arena.views.values().all(func(v:Control):return v.bar.size.y<=8 and v.status_label.position.y+v.status_label.size.y<=v.size.y),"health/status layout stays within fighter cards "+id)
        check(arena.actions.attack.visible and not arena.actions.attack.disabled,"attack action accessible "+id)
        var targets:Array=arena.battle.targets("attack")
        check(not targets.is_empty() and not arena.views[targets[0]].disabled,"legal target clickable "+id)
        if id=="companions":check(arena.views.spirit.disabled and arena.views.spirit.tooltip_text.contains("Передний ряд"),"inaccessible rear target visibly explained")
        arena._target(targets[0]);var count:int=arena.battle.actions;arena._target(targets[0])
        check(arena.battle.actions==count,"double click cannot repeat action "+id)
        await ready_turn(arena)
    arena._start_scenario("companions");await ready_turn(arena)
    arena.battle.units.hans.row="back";arena._render()
    check(arena.actions.attack.disabled and arena.hint_label.text.contains("Нет доступных целей"),"no available melee targets explained without wasting a turn")
    check(not arena.actions.defend.disabled and not arena.actions.retreat.disabled,"non-attack actions remain available with blocked attack")
    arena._start_scenario("duel");await ready_turn(arena)
    arena.battle.units.wolf_a.hp=1;arena.battle.actor().accuracy=100
    arena._target("wolf_a");await ready_turn(arena)
    check(arena.battle.result=="victory" and is_instance_valid(arena.modal),"victory screen shown after lethal hit")
    arena._restart();await ready_turn(arena);check(arena.battle.units.wolf_a.hp==64 and arena.battle.potions==2,"restart restores health and supplies")
    arena.battle.scenario.retreat=100;arena._select_action("retreat");await ready_turn(arena)
    check(arena.battle.result=="retreated" and is_instance_valid(arena.modal),"retreat result screen")
    arena._start_scenario("duel");arena.battle.units.hans.hp=1;arena.battle.units.wolf_a.accuracy=100;await ready_turn(arena)
    check(arena.battle.result=="defeat" and is_instance_valid(arena.modal),"defeat screen after ally dies")
    arena._start_scenario("ambush");arena._start_scenario("forest");await ready_turn(arena);await frames(120)
    check(arena.scenario_id=="forest" and arena.battle.units.size()==2 and arena.battle.actions==0,"restart during pending AI cannot mutate replacement fight")
    arena._open_picker();await frames(100);check(arena.battle==null and arena.views.is_empty(),"scenario picker cancels pending action and clears views")
    check(not life.initialized and life.states.is_empty() and not life.clock.running and life.clock.absolute_minutes==original_minute,"all six battles isolated from NPCs/time")
    arena._start_scenario("ambush");arena._menu();await scene_changed;await frames(150)
    check(current_scene.scene_file_path==MENU,"menu return during AI safely completes")
    current_scene.open_scene(ARENA);await scene_changed;await frames();arena=current_scene;arena.fast.button_pressed=true
    arena._start_scenario("forest");await ready_turn(arena);check(arena.battle.roots_left==1 and arena.battle.raven_left==1,"arena re-entry has fresh resources")
    arena._menu();await scene_changed;await frames();current_scene.open_scene(WORLD);await scene_changed;await frames(20)
    check(life.initialized and life.states.size()==9 and life.clock.running,"ordinary village still starts with nine original residents")
    var hero:CharacterBody2D=current_scene.player
    check(hero.speed==94 and hero.walk_sprite_scale==1.0/24 and not hero.controls_locked,"Hans controls and animations unchanged")
    check(root.get_node("InteriorTravel").active_world==current_scene,"existing door system bound after combat")
    print("RESULT: ",passed," combat UI/menu checks passed, ",failed," failed");quit(0 if failed==0 else 1)
