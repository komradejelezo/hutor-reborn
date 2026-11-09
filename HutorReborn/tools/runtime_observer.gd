extends Node
## Read-only observer, loaded ONLY by a temporary test override.cfg.
## It never creates the world, changes time, moves actors or injects input.
var output := ""
var query_path := ""
var once := false
var ticks := 0
var query_sequence := -1
var route: Dictionary = {}
var transitions: Array[Dictionary] = []
var _last_world := ""

func _ready() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--runtime-output="):output=arg.trim_prefix("--runtime-output=")
        elif arg.begins_with("--runtime-query="):query_path=arg.trim_prefix("--runtime-query=")
        elif arg=="--runtime-once":once=true

func vector(point: Vector2) -> Array:return [point.x,point.y]
func path_values(actor: HutorResident) -> Array:
    var values:Array=[]
    for i in range(actor._path_index,mini(actor._path.size(),actor._path_index+16)):values.append(vector(actor._path[i]))
    return values
func _physics_process(_delta: float) -> void:
    ticks+=1
    if ticks%6!=0:return
    var tree:=get_tree();var world:=tree.current_scene
    if not is_instance_valid(world) or not world.is_node_ready():return
    var travel:Node=get_node("/root/InteriorTravel")
    var life:Node=get_node("/root/VillageLife")
    var hero:CharacterBody2D=world.get_node_or_null("Actors/Hans")
    if hero==null:return
    var camera:Camera2D=hero.get_node("Camera2D")
    var target:HutorInteractable=hero.sensor.target
    var doors:Dictionary={}
    if is_instance_valid(travel.exterior):
        for id in travel.buildings:
            var data:HutorBuildingDefinition=travel.buildings[id]
            var anchor:Node2D=travel.exterior.get_node_or_null(data.exterior_anchor)
            var marker:Node2D=anchor.get_node_or_null("InteriorDoor") if anchor else null
            doors[id]={"registered":marker!=null,"position":vector(marker.global_position) if marker else [],"approach":vector(marker.global_position+Vector2(0,28)) if marker else [],"scene":data.interior_scene}
    var residents:Dictionary={}
    for id in life.states:
        var record:HutorDailyResidentState=life.states[id];var actor:HutorResident=record.actor
        residents[id]={"body":actor.get_instance_id(),"distance_walked":actor.distance_walked,"source_alias":actor.definition==record.original,"source_speed":record.original.speed,"runtime_speed":actor.definition.speed,"scene":String(record.scene),"home":String(record.schedule.home),"mode":String(record.mode),"activity":String(record.activity),"present":actor.is_inside_tree(),"position":vector(actor.position),"state":actor.state,"velocity":vector(actor.velocity),"pending_entry":record.pending_entry,"events":record.event_counts.duplicate(),"next_path":vector(actor._path[actor._path_index]) if actor._path_index<actor._path.size() else [],"upcoming_path":path_values(actor),"destination":vector(actor.current_step().position) if actor.current_step() else [],"clip":String(actor.get_node("AnimatedSprite2D").animation)}
    if world.scene_file_path!=_last_world:
        _last_world=world.scene_file_path
        transitions.append({"world":_last_world,"minute":life.clock.absolute_minutes,"hero":hero.get_instance_id(),"position":vector(hero.position)})
    if not query_path.is_empty() and FileAccess.file_exists(query_path):
        var query:Variant=JSON.parse_string(FileAccess.get_file_as_string(query_path))
        if query is Dictionary and int(query.sequence)!=query_sequence:
            query_sequence=int(query.sequence)
            var nav:HutorNpcNavigation=world.get_node("Actors/Residents/Navigation")
            var grid:=nav.grid_for(Rect2())
            var goal:=Vector2(query.goal[0],query.goal[1])
            var points:=grid.get_point_path(nav.closest_cell(grid,hero.position),nav.closest_cell(grid,goal))
            var values:Array=[]
            for point in points:values.append(vector(point))
            if not values.is_empty():values[0]=vector(hero.position);values[-1]=vector(goal)
            route={"sequence":query_sequence,"world":world.scene_file_path,"points":values}
    var hud:CanvasLayer=world.get_node("HUD")
    var checks:Dictionary={"configured_main":ProjectSettings.get_setting("application/run/main_scene")==travel.VILLAGE,"travel_bound":travel.active_world==world,"six_registered_doors":doors.size()==6,"life_initialized":life.initialized,"nine_residents":residents.size()==9,"clock_running":life.clock.running}
    for entry in doors.values():checks.six_registered_doors=checks.six_registered_doors and entry.registered
    var status:Dictionary={"tick":ticks,"project":ProjectSettings.globalize_path("res://"),"world":world.scene_file_path,"active_id":String(travel.active_id),"hero":hero.get_instance_id(),"position":vector(hero.position),"locked":hero.controls_locked,"busy":travel.busy,"clock":life.clock.absolute_minutes,"clock_speed":life.clock.speed,"target":String(target.get_path()) if is_instance_valid(target) else "","prompt":hud.prompt_label.text if hud.prompt.visible else "","info":hud.dialogue.visible,"dialogue":get_node("/root/DialogueManager").is_active(),"doors":doors,"residents":residents,"entry":vector(world.get_node("Entry").position) if world.has_node("Entry") else [],"camera_zoom":vector(camera.zoom),"route":route,"transitions":transitions,"checks":checks}
    if not output.is_empty():
        var file:=FileAccess.open(output+".tmp",FileAccess.WRITE)
        file.store_string(JSON.stringify(status,"  "));file.close()
        DirAccess.rename_absolute(output+".tmp",output)
    if once and ticks>=12:
        var valid:=true
        for key in checks:
            print("PASS: " if checks[key] else "FAIL: ","normal main startup / ",key)
            valid=valid and checks[key]
        print("RESULT: ",checks.size()," normal-start checks, success=",valid)
        tree.quit(0 if valid else 1)
