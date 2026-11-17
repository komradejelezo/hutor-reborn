extends "res://tools/build_interiors.gd"
## Rebuild only the inn's static mask after changing seats/mattress footprints.
func run() -> void:
    var path:="res://scenes/interiors/inn.tscn"
    var room:Node2D=load(path).instantiate()
    for item in room.get_node("Actors/Props").get_children():
        var feet:CollisionShape2D=item.get_node_or_null("Solid/Feet")
        if feet and not feet.disabled:solids.append(Rect2(item.position+feet.position-feet.shape.size*.5,feet.shape.size))
    for body in room.get_children():
        if body is StaticBody2D:
            var feet:CollisionShape2D=body.get_child(0)
            solids.append(Rect2(body.position+feet.position-feet.shape.size*.5,feet.shape.size))
    var data:HutorNpcNavigationData=bake(room.room_bounds)
    var source:=FileAccess.get_file_as_string(path)
    var regex:=RegEx.new();regex.compile("(?m)^blocked = PackedInt32Array\\(.*\\)$")
    assert(regex.search_all(source).size()==1)
    source=regex.sub(source,"blocked = PackedInt32Array("+", ".join(Array(data.blocked).map(func(i:int):return str(i)))+")")
    var file:=FileAccess.open(path,FileAccess.WRITE);file.store_string(source);file.close()
    print("BAKED: inn only, ",data.blocked.size()," solid cells; furniture and existing routes retained")
    room.free();quit()
