extends "res://tools/build_remaining_interiors.gd"
## Editor authoring: edit the six existing scenes, never recreate the world/session.
## Only room geometry, decoration, local coordinates and baked navigation are saved.
var layout: Dictionary

func art(kind: String) -> Texture2D:
    if kind == "tableware":
        var atlas := AtlasTexture.new()
        atlas.atlas = load("res://assets/interiors/stage44/table_set.png")
        atlas.region = Rect2(23,0,20,20)
        return atlas
    if kind == "village_map":
        # A diegetic small wall map, never a playable/background location image.
        var atlas := AtlasTexture.new()
        atlas.atlas = load("res://assets/environment/krivaya_sosna/source/карта.png")
        atlas.region = Rect2(90,20,1310,810)
        return atlas
    if kind == "rug":
        var atlas := AtlasTexture.new()
        atlas.atlas = load("res://assets/environment/krivaya_sosna/source/Тайл дома.png")
        atlas.region = Rect2(1035, 582, 102, 90)
        return atlas
    return super.art(kind)

func point(value: Array) -> Vector2:
    return Vector2(value[0], value[1])

func safe_point(nav: Node, value: Vector2) -> Vector2:
    var grid: AStarGrid2D = nav.grid_for(Rect2())
    var cell: Vector2i = nav.closest_cell(grid, value)
    assert(cell != Vector2i(-1,-1), "No nearby free cell: " + str(value))
    var room: Node2D=nav.get_parent().get_parent().get_parent()
    var start: Vector2i=nav.closest_cell(grid,room.get_node("Entry").position)
    if grid.get_point_path(start,cell).is_empty():
        var candidates: Array[Vector2i]=[]
        for y in range(cell.y-4,cell.y+5):
            for x in range(cell.x-4,cell.x+5):
                var candidate:=Vector2i(x,y)
                if grid.is_in_boundsv(candidate) and not grid.is_point_solid(candidate):candidates.append(candidate)
        candidates.sort_custom(func(a:Vector2i,b:Vector2i):return grid.get_point_position(a).distance_squared_to(value)<grid.get_point_position(b).distance_squared_to(value))
        var found:=false
        for candidate in candidates:
            if not grid.get_point_path(start,candidate).is_empty():cell=candidate;found=true;break
        assert(found,"Nearby point is isolated from room door: "+str(value))
    return grid.get_point_position(cell)

func room_point(value: Vector2, old: Rect2, rect: Rect2) -> Vector2:
    return rect.position + (value-old.position)*rect.size/old.size

func decorate_shadow(item: Node2D) -> void:
    var feet: CollisionShape2D = item.get_node_or_null("Solid/Feet")
    if feet == null or feet.disabled: return
    var size: Vector2 = feet.shape.size
    var shadow: Polygon2D = item.get_node_or_null("ContactShadow")
    if shadow == null:
        shadow = Polygon2D.new();shadow.name = "ContactShadow"
        item.add_child(shadow); item.move_child(shadow,0)
    shadow.color = Color(0.025,0.018,0.012,0.25)
    var polygon := PackedVector2Array()
    for i in 12:
        var angle := TAU*i/12
        polygon.append(feet.position + Vector2(cos(angle)*(size.x*.55+3), sin(angle)*(size.y*.48+3)))
    shadow.polygon = polygon

func modify(id: String, spec: Dictionary) -> void:
    var path := "res://scenes/interiors/"+id+".tscn"
    var room: Node2D = load(path).instantiate()
    var old: Rect2 = room.room_bounds
    var rect := Rect2(spec.bounds[0],spec.bounds[1],spec.bounds[2],spec.bounds[3])
    room.room_bounds = rect
    room.set_meta("interior_detail_stage", "5.1")
    if not room.has_meta("previous_floor_size"):room.set_meta("previous_floor_size", old.size)
    var floor_layer: TileMapLayer = room.get_node("Floor")
    floor_layer.clear()
    populate_tiles(floor_layer,rect,true)
    var walls: TileMapLayer = room.get_node("Walls")
    walls.clear()
    for region in [Rect2(rect.position-Vector2(0,32),Vector2(rect.size.x,32)),Rect2(rect.position-Vector2(32,32),Vector2(32,rect.size.y+64)),Rect2(Vector2(rect.end.x,rect.position.y-32),Vector2(32,rect.size.y+64)),Rect2(Vector2(rect.position.x,rect.end.y),Vector2(rect.size.x,32))]:
        populate_tiles(walls,region)
    var props: Node2D = room.get_node("Actors/Props")
    for name in spec.positions:
        assert(props.has_node(NodePath(name)), "Existing furniture missing: "+id+"/"+name)
        props.get_node(NodePath(name)).position = rect.position+point(spec.positions[name])
    var entry: Vector2 = rect.position+Vector2(rect.size.x*.5,rect.size.y-46)
    room.get_node("Entry").position=entry
    room.get_node("Actors/Hans").position=entry
    room.get_node("Exit").position=rect.position+Vector2(rect.size.x*.5,rect.size.y-12)
    props.get_node("FrontDoor").position=rect.position+Vector2(rect.size.x*.5,rect.size.y+18)
    if room.has_node("BackRoom"):room.get_node("BackRoom").position=rect.position+Vector2(rect.size.x-65,55)
    var bodies: Array[Node] = []
    for child in room.get_children():
        if child is StaticBody2D: bodies.append(child)
    assert(bodies.size()==4, "Expected original four wall bodies")
    var centers := [rect.position+Vector2(rect.size.x*.5,0),Vector2(rect.position.x,rect.get_center().y),Vector2(rect.end.x,rect.get_center().y),Vector2(rect.get_center().x,rect.end.y+4)]
    var sizes := [Vector2(rect.size.x+64,16),Vector2(16,rect.size.y),Vector2(16,rect.size.y),Vector2(rect.size.x+64,16)]
    for i in 4:
        bodies[i].position=centers[i]
        var shape: CollisionShape2D=bodies[i].get_child(0)
        shape.shape=shape.shape.duplicate();shape.shape.size=sizes[i]
    var details: Node2D = room.get_node_or_null("FloorDetails")
    if details == null:details=node("FloorDetails","Node2D",room)
    room.move_child(details,room.get_node("Actors").get_index())
    for extra in spec.additions:
        var item: Node2D=props.get_node_or_null(NodePath(extra.name))
        if item==null:item=details.get_node_or_null(NodePath(extra.name))
        if item==null:item=prop(room,extra.name,extra.art,rect.position+point(extra.point),point(extra.foot),float(extra.scale))
        item.position=rect.position+point(extra.point)
        var sprite: Sprite2D=item.get_node("Art")
        sprite.texture=art(extra.art);sprite.scale=Vector2.ONE*float(extra.scale)
        sprite.position=Vector2(-sprite.texture.get_width()*.5,-sprite.texture.get_height()+4)*float(extra.scale)
        item.set_meta("interior_asset",extra.art)
        item.set_meta("detail_stage","5.1")
        if extra.ground and item.get_parent()!=details:item.reparent(details,true)
    for item in props.get_children():decorate_shadow(item)
    # Narrow contact shade follows walls; no per-object dynamic shadow maps.
    for child in details.get_children():
        if child is Polygon2D:child.free()
    for edge in [Rect2(rect.position,Vector2(rect.size.x,7)),Rect2(rect.position,Vector2(6,rect.size.y)),Rect2(Vector2(rect.end.x-6,rect.position.y),Vector2(6,rect.size.y))]:
        var shade: Polygon2D=node("WallShade","Polygon2D",details)
        shade.color=Color(0.025,0.018,0.012,.22)
        shade.polygon=PackedVector2Array([edge.position,Vector2(edge.end.x,edge.position.y),edge.end,Vector2(edge.position.x,edge.end.y)])
    var atmosphere: Node2D=room.get_node("Atmosphere")
    for i in spec.lights.size():
        var data: Array=spec.lights[i]
        if i>=atmosphere.get_child_count():light(atmosphere,Vector2.ZERO,float(data[2]),float(data[3]))
        var lamp: PointLight2D=atmosphere.get_child(i)
        lamp.position=rect.position+Vector2(data[0],data[1])
        lamp.base_energy=float(data[2]);lamp.texture_scale=float(data[3])
        lamp.color=Color(1,.74,.43);lamp.flicker=.018;lamp.update_interval=.12
    # Re-bake all actual enabled furniture footprints; decoration creates no obstacles.
    solids.clear()
    for item in props.get_children():
        var feet: CollisionShape2D=item.get_node_or_null("Solid/Feet")
        if feet and not feet.disabled:
            solids.append(Rect2(item.position+feet.position-feet.shape.size*.5,feet.shape.size))
    for i in 4:solids.append(Rect2(centers[i]-sizes[i]*.5,sizes[i]))
    var nav: Node=room.get_node("Actors/Residents/Navigation")
    nav.data=bake(rect)
    # The existing action markers and local F6 definitions stay connected.
    if room.has_node("NPCPoints"):
        for marker in room.get_node("NPCPoints").get_children():
            if marker is Marker2D:
                marker.position=safe_point(nav,rect.position+point(spec.points[String(marker.name)]) if spec.points.has(String(marker.name)) else room_point(marker.position,old,rect))
    var definitions: Array[HutorNpcDefinition]=[]
    for original: HutorNpcDefinition in room.resident_definitions:
        var definition: HutorNpcDefinition=original.duplicate(true)
        for step in definition.routine:step.position=safe_point(nav,room_point(step.position,old,rect))
        var local_path: String="res://data/interiors/"+id+"_"+String(definition.id)+".tres"
        assert(ResourceSaver.save(definition,local_path)==OK)
        definition.take_over_path(local_path)
        definitions.append(definition)
    room.resident_definitions=definitions
    # Change only indoor point values, preserving every schedule, clip and string.
    for resident_id in spec.actions:
        var profile_path: String="res://data/life/residents/"+resident_id+".json"
        var profile: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(profile_path))
        for block in profile.blocks:
            if block.scene!=id:continue
            for activity in block.activities:
                if activity.point is Array:
                    var value: Vector2=rect.position+point(spec.actions[resident_id][activity.id]) if spec.actions[resident_id].has(activity.id) else room_point(point(activity.point),old,rect)
                    var position:=safe_point(nav,value)
                    activity.point=[position.x,position.y]
        var file:=FileAccess.open(profile_path,FileAccess.WRITE)
        file.store_string(JSON.stringify(profile,"  ",false)+"\n");file.close()
    own(room,room)
    var packed:=PackedScene.new();assert(packed.pack(room)==OK)
    assert(ResourceSaver.save(packed,path)==OK)
    print("DETAILED ",id," ",old.size," -> ",rect.size,"; ",props.get_child_count()," furniture/decor nodes")
    room.free()

func run() -> void:
    layout=JSON.parse_string(FileAccess.get_file_as_string("res://tools/stage51_layout.json"))
    for id in layout:modify(id,layout[id])
    quit()
