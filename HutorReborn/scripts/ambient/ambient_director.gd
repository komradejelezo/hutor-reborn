extends Node
## Session ambience owns no NPC state, clock, route, collision or saved geometry.
const MIXER=preload("res://scripts/ambient/audio_mixer.gd")
const EFFECTS=preload("res://scripts/ambient/scene_effects.gd")
var settings: Dictionary
var sounds: Dictionary
var profiles: Dictionary
var mixer: Node
var effects: Node2D
var world: Node2D
var scene_id: String=""
var phase: String=""
var events: Array[Dictionary]=[]
var glance_count:=0
var _life: Node
var _travel: Node
var _rng:=RandomNumberGenerator.new()
var _elapsed:=0.0
var _audio_left:=10.0
var _visual_left:=12.0
var _last_event:=""
var _muted:=false
var _glances: Dictionary={}
var _effects_by_world: Dictionary={}

func _ready() -> void:
    process_mode=Node.PROCESS_MODE_PAUSABLE
    settings=_json("settings");sounds=_json("sounds");profiles=_json("profiles")
    _load_preferences();_validate_settings();_rng.randomize()
    mixer=MIXER.new();mixer.name="AudioMixer";add_child(mixer);mixer.configure(settings,sounds)
    _life=get_node("/root/VillageLife");_travel=get_node("/root/InteriorTravel")
    _travel.transition_started.connect(func(_id:StringName,_exit:bool):mixer.fade_out())
    _travel.transition_finished.connect(func(_id:StringName,_exit:bool):_sync_world(true))
    _travel.transition_failed.connect(func(_id:StringName,_reason:String):_sync_world(true))
    _life.clock.phase_changed.connect(func(_phase:StringName):_refresh_audio())
    _life.activity_changed.connect(_occupation)
    _sync_world.call_deferred()

func _json(name: String) -> Dictionary:
    return JSON.parse_string(FileAccess.get_file_as_string("res://data/atmosphere/"+name+".json"))

func _validate_settings() -> void:
    settings.max_voices=clampi(int(settings.max_voices),3,6)
    settings.max_new_particles=clampi(int(settings.max_new_particles),15,24)
    settings.crossfade_seconds=clampf(float(settings.crossfade_seconds),.3,5)
    for key in ["master_volume_db","outdoor_volume_db","interior_volume_db"]:settings[key]=clampf(float(settings[key]),-60,0)

func configure(values: Dictionary) -> void:
    for key in values:
        if settings.has(key):settings[key]=values[key]
    _validate_settings();mixer.configure(settings,sounds);_refresh_audio()
    if is_instance_valid(effects):effects.settings=settings;effects.step(0)

func set_volume_db(value: float, scope: String="master", persist: bool=true) -> void:
    var key:=scope+"_volume_db"
    if not settings.has(key):return
    configure({key:value})
    if persist:
        var preferences:=ConfigFile.new()
        for field in ["master_volume_db","outdoor_volume_db","interior_volume_db"]:preferences.set_value("volume",field,settings[field])
        preferences.save("user://ambient_audio.cfg")

func _load_preferences() -> void:
    var preferences:=ConfigFile.new()
    if preferences.load("user://ambient_audio.cfg")!=OK:return
    for key in ["master_volume_db","outdoor_volume_db","interior_volume_db"]:
        if preferences.has_section_key("volume",key):settings[key]=preferences.get_value("volume",key)

func _process(delta: float) -> void:
    _elapsed+=delta
    if _elapsed<.2:return
    var step:=_elapsed;_elapsed=0
    _sync_world()
    if not is_instance_valid(world) or not world.is_inside_tree():mixer.silence();return
    if _travel.busy:return
    var muted:=not _audio_allowed()
    if muted!=_muted:_muted=muted;_refresh_audio()
    effects.step(step)
    _refresh_hearth()
    _audio_left-=step;_visual_left-=step
    if _audio_left<=0:
        trigger_audio_event();_audio_left=_interval(settings.outdoor_event_seconds if scene_id=="village" else settings.indoor_event_seconds)
    if _visual_left<=0:
        var kind: String=effects.trigger()
        if not kind.is_empty():_record("visual",kind)
        _visual_left=_interval(settings.visual_event_seconds)

func _interval(pair: Array) -> float:return _rng.randf_range(maxf(8,pair[0]),maxf(8,pair[1]))

func _sync_world(force: bool=false) -> void:
    var candidate:=get_tree().current_scene as Node2D
    if candidate==null or not candidate.has_node("Actors/Hans") or not candidate.has_node("Atmosphere"):return
    var id: String="village"
    if candidate.scene_file_path!=_travel.VILLAGE:
        var building: Variant=candidate.get("building_id")
        if building==null:return
        id=String(building)
    if not profiles.has(id):return
    if candidate==world:
        if force:_refresh_audio()
        return
    if is_instance_valid(world):mixer.silence()
    world=candidate;scene_id=id
    var atmosphere: Node2D=world.get_node("Atmosphere")
    effects=atmosphere.get_node_or_null("LivingAtmosphere")
    if effects==null:
        effects=EFFECTS.new();effects.name="LivingAtmosphere";effects.world=world;effects.settings=settings
        atmosphere.add_child(effects)
    for key in _effects_by_world.keys():
        if _effects_by_world[key].get_ref()==null:_effects_by_world.erase(key)
    _effects_by_world[world.get_instance_id()]=weakref(effects)
    effects.settings=settings
    var hero: Node2D=world.get_node("Actors/Hans")
    var listener:=hero.get_node_or_null("AmbientListener") as AudioListener2D
    if listener==null:
        listener=AudioListener2D.new();listener.name="AmbientListener";hero.add_child(listener)
        listener.position=Vector2(0,-3)
    listener.make_current()
    _glances.clear();_last_event="";_audio_left=10;_visual_left=12
    _refresh_audio();effects.step(0);_record("scene",id)

func _audio_allowed() -> bool:
    return settings.audio_enabled and is_instance_valid(world) and world.is_inside_tree() and (not settings.follow_f3 or world.atmosphere.effects_enabled) and not _travel.busy

func _refresh_audio() -> void:
    if not is_instance_valid(mixer) or not is_instance_valid(_life):return
    phase=String(_life.clock.phase_name())
    if not _audio_allowed():mixer.fade_out();return
    var profile: Dictionary=profiles[scene_id][phase] if scene_id=="village" else profiles[scene_id]
    mixer.retain_details(profile.events)
    mixer.set_bed(profile.get("bed",""),"outdoor" if scene_id=="village" else "interior")

func _refresh_hearth() -> void:
    if not _audio_allowed():mixer.set_hearth(Vector2.ZERO,false,"interior");return
    var point:=Vector2.ZERO;var distance:=INF
    var active:=false
    if scene_id=="village":
        if phase in ["evening","night"]:
            for chimney in effects.chimneys:
                var gap: float=chimney.global_position.distance_squared_to(world.player.global_position)
                if gap<distance:point=chimney.global_position+Vector2(0,110);distance=gap;active=true
    elif profiles[scene_id].get("fire",false):
        for prop in world.get_node("Actors/Props").get_children():
            if prop.get_meta("interior_asset","")=="fireplace":point=prop.global_position-Vector2(0,24);active=true;break
    mixer.set_hearth(point,active,"outdoor" if scene_id=="village" else "interior")

func trigger_audio_event() -> bool:
    if not _audio_allowed() or get_node("/root/DialogueManager").is_active():return false
    var profile: Dictionary=profiles[scene_id][phase] if scene_id=="village" else profiles[scene_id]
    var choices: Array[String]=[]
    for key: String in profile.events:
        if not mixer.available(key):continue
        if key=="axe" and not _workers_away():continue
        if key==_last_event:continue
        choices.append(key)
    if choices.is_empty():
        # A room with one available recording gets a silent interval between
        # repeats, rather than being permanently silenced after its first creak.
        _last_event=""
        return false
    var key:=choices[_rng.randi_range(0,choices.size()-1)]
    var at: Vector2=world.player.global_position
    if scene_id=="village":
        if key=="axe":at=Vector2(_life.gateway.position[0],_life.gateway.position[1])+Vector2(0,120)
        elif key=="wood_creak":
            var nearest:=INF
            for building in world.get_node("Actors/Structures").get_children():
                if not building is Node2D:continue
                var gap:float=building.global_position.distance_squared_to(world.player.global_position)
                if gap<nearest:nearest=gap;at=building.global_position
        elif key=="leaves" and not effects.vegetation_points.is_empty():
            var nearest:=INF
            for position:Vector2 in effects.vegetation_points:
                var gap:=position.distance_squared_to(world.player.global_position)
                if gap<nearest:nearest=gap;at=position
        else:at+=Vector2(_rng.randf_range(-400,400),_rng.randf_range(-250,250))
    else:
        var rect: Rect2=world.room_bounds
        at=rect.position+Vector2(_rng.randf_range(30,rect.size.x-30),_rng.randf_range(30,rect.size.y-30))
    var played: bool=mixer.play_detail(key,at,"outdoor" if scene_id=="village" else "interior")
    if played:_last_event=key;_record("audio",key)
    return played

func _workers_away() -> bool:
    for id in [&"woodcutter",&"herbalist_brother"]:
        if _life.states.has(id) and _life.states[id].scene==&"logging":return true
    return false

func _occupation(id: StringName, activity: StringName) -> void:
    if not _audio_allowed() or _audio_left>8 or not _life.states.has(id):return
    var record: HutorDailyResidentState=_life.states[id]
    if not record.actor.is_inside_tree() or record.actor.state!=HutorResident.State.WAITING:return
    var sounds_by_activity:={"wipe_mug":"dishes","clean_tables":"dishes","read_documents":"paper","cook":"brew","brew":"brew","dry_plants":"dry_herbs","household":"wood","take_tool":"wood"}
    var key: String=sounds_by_activity.get(String(activity),"")
    if key.is_empty():return
    if mixer.play_detail(key,record.actor.global_position,"outdoor" if scene_id=="village" else "interior"):
        _audio_left=maxf(_audio_left,12);_record("occupation",String(id)+":"+key)

func glance_direction(actor: HutorResident, record: HutorDailyResidentState) -> StringName:
    if not settings.npc_glances_enabled or not settings.visuals_enabled or _travel.busy or get_tree().paused:return &""
    if not is_instance_valid(world) or not world.is_inside_tree() or not world.atmosphere.effects_enabled:return &""
    if actor.state!=HutorResident.State.WAITING or actor.motion_paused or record.mode!=&"local" or phase=="night":return &""
    if get_node("/root/DialogueManager").is_active():return &""
    var targets:={"innkeeper":"Actors/Props/Cups","elder":"Actors/Props/Window"}
    var target: Node2D=world.get_node_or_null(targets.get(String(record.id),"NoAmbientTarget"))
    if target==null:return &""
    var now:=Time.get_ticks_msec()/1000.0
    if not _glances.has(record.id):_glances[record.id]={"next":now+_rng.randf_range(18,35),"until":0.0}
    var cue: Dictionary=_glances[record.id]
    if now>=float(cue.next):
        cue.until=now+.55;cue.next=now+_rng.randf_range(22,45);glance_count+=1
        _record("glance",String(record.id))
    if now>=float(cue.until):return &""
    var axis:=target.global_position-actor.global_position
    return (&"right" if axis.x>0 else &"left") if absf(axis.x)>absf(axis.y) else (&"down" if axis.y>0 else &"up")

func _record(kind: String, detail: String) -> void:
    events.append({"kind":kind,"detail":detail,"scene":scene_id,"phase":phase})
    if events.size()>64:events.pop_front()

func diagnostics() -> Dictionary:
    var active_components:=0;var cached_components:=0
    for reference in _effects_by_world.values():
        var component:Node=reference.get_ref()
        if not is_instance_valid(component):continue
        if component.is_inside_tree():active_components+=1
        else:cached_components+=1
    var data:={"scene":scene_id,"phase":phase,"voices":mixer.playing_count(),"peak_voices":mixer.max_playing,"pool_size":mixer.get_child_count(),"bed":mixer._bed_key,"hearth":mixer.hearth.playing,"active_components":active_components,"cached_components":cached_components,"glances":glance_count,"events":events.duplicate(),"master_db":settings.master_volume_db}
    if is_instance_valid(effects):
        data["visual_events"]=effects.decorative_events
        data["gust_left"]=effects._gust_left
        data["dust"]=effects.dust.emitting
        data["motes"]=effects.motes.emitting
        data["puff"]=effects.puff.emitting
        data["particle_capacity"]=effects.dust.amount+effects.motes.amount+effects.puff.amount
    return data

func _exit_tree() -> void:
    if is_instance_valid(mixer):
        mixer.silence()
        for player in mixer.beds:player.stream=null
        for player in mixer.details:player.stream=null
        mixer.hearth.stream=null;mixer._streams.clear()
        # AudioServer retires stopped Ogg playbacks on its mixing thread. Drain
        # that queue before engine teardown (also when --quit-after is very short).
        OS.delay_msec(60)
    _effects_by_world.clear();_glances.clear()
