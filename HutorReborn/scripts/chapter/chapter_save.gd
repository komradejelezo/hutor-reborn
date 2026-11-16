extends RefCounted
## Versioned Variant data only (no object deserialization), atomic replacement.
const FIELDS=["scene","desired_scene","position","mode","activity","index","until","updated","travel_end","hop","goal","block","block_stamp","snapshot_stamp","parked_at","portal_direction","portal_target","portal_blocked","pending_entry","event_counts"]
static func digest(bytes:PackedByteArray) -> PackedByteArray:
    var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(bytes);return hash.finish()
static func path(test:bool,slot:String) -> String:
    return "user://chapter_i/"+("test/" if test else "normal/")+slot+".save"
static func exists(test:bool,slot:String="manual") -> bool:return FileAccess.file_exists(path(test,slot))
static func write(chapter:Node,slot:String) -> Error:
    if slot not in ["manual","checkpoint"]:return ERR_INVALID_PARAMETER
    var travel:Node=chapter.travel;var life:Node=chapter.life;var world:Node2D=travel.active_world
    if not is_instance_valid(world) or travel.busy:return ERR_BUSY
    var people:Dictionary={}
    for id in life.states:
        var r:RefCounted=life.states[id];var row:Dictionary={}
        for field in FIELDS:row[field]=r.get(field)
        row.snapshot=r.snapshot.duplicate(true);row.snapshot.erase("definition")
        if r.actor.is_inside_tree() and not r.actor.has_meta("chapter_reserved"):
            row.position=r.actor.position;row.index=r.actor.step_index
            row.snapshot={"state":int(r.actor.state),"wait_left":r.actor.wait_left}
            row.snapshot_stamp=r.block_stamp;row.parked_at=life.clock.absolute_minutes
        row.rng=r.actor._rng.state;people[String(id)]=row
    var value:Dictionary={"version":1,"chapter":chapter.state.pack(),"location":String(travel.active_id),"position":world.player.position,"facing":world.player.facing,"minute":life.clock.absolute_minutes,"people":people}
    var file_path:=path(chapter.test_mode,slot)
    var error:=DirAccess.make_dir_recursive_absolute(file_path.get_base_dir())
    if error!=OK:return error
    var f:=FileAccess.open(file_path+".tmp",FileAccess.WRITE)
    if not f:return FileAccess.get_open_error()
    var bytes:=var_to_bytes(value)
    f.store_buffer("HTR7".to_utf8_buffer());f.store_32(bytes.size());f.store_buffer(digest(bytes));f.store_buffer(bytes)
    f.flush();var status:=f.get_error();f.close()
    if status!=OK:return status
    # Keep the previous complete save until replacement succeeds, including Windows.
    var backup:=file_path+".bak"
    if FileAccess.file_exists(backup):DirAccess.remove_absolute(backup)
    if FileAccess.file_exists(file_path):
        error=DirAccess.rename_absolute(file_path,backup)
        if error!=OK:return error
    error=DirAccess.rename_absolute(file_path+".tmp",file_path)
    if error!=OK and FileAccess.file_exists(backup):DirAccess.rename_absolute(backup,file_path)
    return error
static func read(test:bool,slot:String) -> Dictionary:
    if slot not in ["manual","checkpoint"]:return {}
    var f:=FileAccess.open(path(test,slot),FileAccess.READ)
    if not f or f.get_length()<40 or f.get_length()>4000000:return {}
    if f.get_buffer(4).get_string_from_utf8()!="HTR7":return {}
    var size:=f.get_32()
    if size!=f.get_length()-40:return {}
    var checksum:=f.get_buffer(32);var bytes:=f.get_buffer(size)
    if digest(bytes)!=checksum:return {}
    var value:Variant=bytes_to_var(bytes)
    if not value is Dictionary or not value.has_all(["version","chapter","location","position","facing","minute","people"]):return {}
    if value.version!=1 or not value.chapter is Dictionary or not value.people is Dictionary:return {}
    if not value.position is Vector2 or not is_finite(float(value.minute)) or value.minute<0:return {}
    if value.location not in ["","inn","elder","herbalist","woodcutter","old_man","storehouse","logging_camp","abandoned"]:return {}
    var probe:RefCounted=preload("res://scripts/chapter/chapter_state.gd").new()
    if not probe.unpack(value.chapter):return {}
    if value.people.size()!=9:return {}
    for id in value.people:
        var row:Variant=value.people[id]
        if not row is Dictionary or not row.has_all(FIELDS) or not row.has_all(["snapshot","rng"]):return {}
        if not row.position is Vector2 or not row.block is Dictionary or not row.snapshot is Dictionary:return {}
    return value
