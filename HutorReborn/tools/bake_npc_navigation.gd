extends SceneTree
const DATA = preload("res://scripts/npc/navigation_data.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
    var world: Node2D = load("res://scenes/world/krivaya_sosna/krivaya_sosna.tscn").instantiate()
    # Re-baking never includes moving residents in the static obstacle mask.
    if world.has_node("Actors/Residents"):
        var residents := world.get_node("Actors/Residents")
        residents.get_parent().remove_child(residents); residents.free()
    root.add_child(world); current_scene = world
    for i in range(3): await physics_frame
    var data := DATA.new()
    data.world_size = world.map_size
    var map_text := FileAccess.get_file_as_string("res://scenes/world/krivaya_sosna/krivaya_sosna.tscn")
    map_text = map_text.replace('[ext_resource type="PackedScene" path="res://scenes/npc/residents.tscn" id="stage43_residents"]\n\n','')
    map_text = map_text.replace('[node name="Residents" parent="Actors" instance=ExtResource("stage43_residents")]\n\n','')
    data.source_scene_sha256 = map_text.sha256_text()
    var width: int = data.world_size.x/16
    var height: int = data.world_size.y/16
    var shape := CircleShape2D.new(); shape.radius = 7
    var query := PhysicsShapeQueryParameters2D.new()
    query.shape = shape; query.collision_mask = 1
    query.exclude = [world.player.get_rid()]
    var roads: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/environment/krivaya_sosna/expanded_layout.json")).roads
    roads.append_array(JSON.parse_string(FileAccess.get_file_as_string("res://assets/environment/krivaya_sosna/stage42/layout.json")).roads)
    data.costs.resize(width*height)
    var space := world.get_world_2d().direct_space_state
    for y in range(height):
        for x in range(width):
            var point := Vector2(x*16+8,y*16+8)
            query.transform = Transform2D(0,point+Vector2(0,-3))
            if not space.intersect_shape(query,1).is_empty(): data.blocked.append(y*width+x)
            var distance := INF
            for road in roads:
                for i in range(1,road.points.size()):
                    var a := Vector2(road.points[i-1][0],road.points[i-1][1])
                    var b := Vector2(road.points[i][0],road.points[i][1])
                    distance = minf(distance,point.distance_to(Geometry2D.get_closest_point_to_segment(point,a,b))-float(road.radius))
            data.costs[y*width+x] = 1 if distance<16 else 3
    assert(ResourceSaver.save(data,"res://assets/npc/stage43/navigation.tres") == OK)
    print("BAKED: ",width*height," cells; ",data.blocked.size()," static obstacles; roads preferred; map untouched")
    world.queue_free(); await process_frame
    quit()
