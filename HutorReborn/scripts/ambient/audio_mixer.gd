extends Node
## Fixed pool: two crossfade beds, one spatial hearth, three spatial details.
var settings: Dictionary
var catalog: Dictionary
var beds: Array[AudioStreamPlayer] = []
var details: Array[AudioStreamPlayer2D] = []
var hearth: AudioStreamPlayer2D
var _streams: Dictionary = {}
var _last_variant: Dictionary = {}
var _targets := [-80.0,-80.0]
var _active_bed := 0
var _bed_key := ""
var _rng := RandomNumberGenerator.new()
var events_played := 0
var dropped_events := 0
var max_playing := 0
var _scope := "outdoor"
var _fade_rate:=400.0
var _hearth_target:=-80.0
var _clearing:=false
var _retiring: Dictionary={}

func _ready() -> void:
    _rng.randomize()
    for name in ["HutorAmbient","HutorOutdoors","HutorIndoors"]:
        if AudioServer.get_bus_index(name)<0:
            AudioServer.add_bus();AudioServer.set_bus_name(AudioServer.bus_count-1,name)
        AudioServer.set_bus_send(AudioServer.get_bus_index(name),"Master" if name=="HutorAmbient" else "HutorAmbient")
    for i in 2:
        var player:=AudioStreamPlayer.new();player.name="Bed"+str(i);player.bus="HutorOutdoors"
        add_child(player);_own(player);beds.append(player);player.volume_db=-80
    hearth=AudioStreamPlayer2D.new();hearth.name="Hearth";add_child(hearth)
    _own(hearth)
    hearth.max_distance=520;hearth.attenuation=1.4;hearth.panning_strength=.65
    for i in 3:
        var player:=AudioStreamPlayer2D.new();player.name="Detail"+str(i)
        player.panning_strength=.65;player.max_polyphony=1
        add_child(player);_own(player);details.append(player)

func _own(player: Node) -> void:
    # Stop spatial streams while their viewport still exists, before the player's
    # EXIT_TREE notification can suspend a playback during editor/F6 teardown.
    player.tree_exiting.connect(func():player.stop();player.stream=null)

func configure(values: Dictionary, sounds: Dictionary) -> void:
    settings=values;catalog=sounds
    AudioServer.set_bus_volume_db(AudioServer.get_bus_index("HutorAmbient"),settings.master_volume_db)
    AudioServer.set_bus_volume_db(AudioServer.get_bus_index("HutorOutdoors"),settings.outdoor_volume_db)
    AudioServer.set_bus_volume_db(AudioServer.get_bus_index("HutorIndoors"),settings.interior_volume_db)
    for i in range(details.size()-1,-1,-1):
        if playing_count()<=int(settings.max_voices):break
        details[i].stop()

func available(key: String) -> bool:
    return catalog.has(key) and not catalog[key].get("files",[]).is_empty()

func stream(key: String, looped: bool=false) -> AudioStream:
    if not available(key):return null
    var files: Array=catalog[key].files
    var index:=_rng.randi_range(0,files.size()-1)
    if files.size()>1 and index==_last_variant.get(key,-1):index=(index+1)%files.size()
    _last_variant[key]=index
    var file: String=files[index]
    var cache_key:=file+("_loop" if looped else "_once")
    if not _streams.has(cache_key):
        var path:="res://assets/audio/ambient/"+file+".ogg"
        if not ResourceLoader.exists(path):return null
        var original:=load(path) as AudioStreamOggVorbis
        if original==null:return null
        var copy:=original.duplicate() as AudioStreamOggVorbis
        copy.loop=looped;_streams[cache_key]=copy
    return _streams[cache_key]

func set_bed(key: String, scope: String) -> void:
    _scope=scope
    _clearing=false;_fade_rate=80.0/maxf(.3,float(settings.crossfade_seconds))
    if key==_bed_key:return
    _bed_key=key
    for i in 2:_targets[i]=-80
    if key.is_empty() or not available(key):return
    _active_bed=1-_active_bed
    var player:=beds[_active_bed]
    player.stop();player.stream=stream(key,true);player.volume_db=-80
    _reserve_slot()
    player.bus="HutorOutdoors" if scope=="outdoor" else "HutorIndoors"
    if player.stream:player.play();_targets[_active_bed]=catalog[key].db

func _reserve_slot() -> void:
    for i in range(details.size()-1,-1,-1):
        if playing_count()<int(settings.max_voices):break
        details[i].stop()

func set_hearth(point: Vector2, active: bool, scope: String) -> void:
    hearth.position=point;hearth.bus="HutorOutdoors" if scope=="outdoor" else "HutorIndoors"
    if not active or not available("fire"):_hearth_target=-80;return
    _hearth_target=catalog.fire.db
    if not hearth.playing:
        _reserve_slot()
        hearth.stream=stream("fire",true);hearth.volume_db=-80
        if hearth.stream:hearth.play()

func play_detail(key: String, point: Vector2, scope: String) -> bool:
    if not available(key) or playing_count()>=int(settings.max_voices):return false
    for player in details:
        if player.playing:continue
        player.stream=stream(key)
        if player.stream==null:return false
        player.position=point;player.bus="HutorOutdoors" if scope=="outdoor" else "HutorIndoors"
        player.volume_db=catalog[key].get("db",-25);player.max_distance=catalog[key].get("distance",650)
        player.attenuation=1.5;player.pitch_scale=1.0
        player.set_meta("ambient_key",key);_retiring.erase(player.get_instance_id())
        player.play();events_played+=1;return true
    dropped_events+=1;return false

func retain_details(allowed: Array) -> void:
    for player in details:
        if player.playing and not allowed.has(player.get_meta("ambient_key","")):
            _retiring[player.get_instance_id()]=true

func fade_out() -> void:
    _bed_key=""
    _clearing=true;_fade_rate=80/.18;_hearth_target=-80
    for i in 2:_targets[i]=-80

func silence() -> void:
    fade_out()
    hearth.stop()
    for player in details:player.stop()
    _retiring.clear()
    for player in beds:player.stop();player.volume_db=-80

func playing_count() -> int:
    var count:=int(hearth.playing)
    for player in beds:count+=int(player.playing)
    for player in details:count+=int(player.playing)
    return count

func _process(delta: float) -> void:
    if settings.is_empty():return
    var step:=_fade_rate*delta
    for i in 2:
        beds[i].volume_db=move_toward(beds[i].volume_db,_targets[i],step)
        if _targets[i]<=-80 and beds[i].volume_db<=-79.9:beds[i].stop()
    hearth.volume_db=move_toward(hearth.volume_db,_hearth_target,80/.12*delta)
    if _hearth_target<=-80 and hearth.volume_db<=-79.9:hearth.stop()
    for player in details:
        if _clearing or _retiring.has(player.get_instance_id()):
            player.volume_db=move_toward(player.volume_db,-80,80/.18*delta)
            if player.volume_db<=-79.9:
                player.stop();_retiring.erase(player.get_instance_id())
    max_playing=maxi(max_playing,playing_count())
