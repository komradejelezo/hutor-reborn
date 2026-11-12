class_name HutorNpcVisualLibrary
extends RefCounted
## Presentation data only: no time, scene residency or routine ownership.
static var _profiles: Dictionary = {}
static var _frames: Dictionary = {}
static func profile(id: StringName) -> Dictionary:
    if _profiles.is_empty():
        _profiles=JSON.parse_string(FileAccess.get_file_as_string("res://data/visuals/residents.json"))
    return _profiles.get(String(id),{})
static func frames_for(id: StringName, fallback: SpriteFrames) -> SpriteFrames:
    if not _frames.has(id):
        var path:="res://assets/npc/stage541/"+String(id)+"/frames.tres"
        if id==&"woodcutter":path="res://assets/npc/woodcutter542/game/frames.tres"
        if id==&"woodcutter_wife":path="res://assets/npc/woodcutter_wife544/game/frames.tres"
        if not ResourceLoader.exists(path):path="res://assets/npc/stage54/game/"+String(id)+"/frames.tres"
        if not ResourceLoader.exists(path):path="res://assets/npc/stage47/"+String(id)+".tres"
        _frames[id]=load(path) if ResourceLoader.exists(path) else fallback
    return _frames[id]
