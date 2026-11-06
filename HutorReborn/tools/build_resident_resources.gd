extends SceneTree
const DEFINITION = preload("res://scripts/npc/npc_definition.gd")
const STEP = preload("res://scripts/npc/routine_step.gd")
const NAVIGATION = preload("res://scripts/npc/navigation_service.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
    var roster: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/npc/stage43/roster.json"))
    var nav := NAVIGATION.new()
    nav.data = load("res://assets/npc/stage43/navigation.tres")
    var actions := {"HOME":0,"WORK":1,"WALK":2,"REST":3,"TALK":4,"MOVE":5}
    var behaviors := {"PATROL":0,"WORKER":1,"CHILD":2,"ELDER":3}
    var audit: Array = []
    var population := '[gd_scene format=3]\n[ext_resource type="Script" path="res://scripts/npc/npc_population.gd" id="p"]\n[ext_resource type="Script" path="res://scripts/npc/navigation_service.gd" id="n"]\n[ext_resource type="Resource" path="res://assets/npc/stage43/navigation.tres" id="d"]\n'
    for resident in roster:
        population += '[ext_resource type="PackedScene" path="res://scenes/npc/residents/%s.tscn" id="%s"]\n' % [resident.id,resident.id]
    population += '\n[node name="Residents" type="Node2D"]\ny_sort_enabled = true\nscript = ExtResource("p")\n\n[node name="Navigation" type="Node" parent="."]\nscript = ExtResource("n")\ndata = ExtResource("d")\n\n'
    for resident in roster:
        var definition := DEFINITION.new()
        definition.id = resident.id
        definition.display_name = resident.name
        definition.behavior = behaviors[resident.behavior]
        definition.speed = resident.speed
        definition.frames = load("res://assets/npc/stage43/%s/frames.tres" % resident.id)
        definition.dialogue_path = resident.dialogue_path
        definition.dialogue_id = resident.dialogue_id
        definition.foot_radius = resident.get("radius",5.0)
        definition.pipe_smoke = resident.get("pipe_smoke",false)
        definition.notices_player = resident.get("notices_player",false)
        definition.art_notes = "Four-way archived walk frames; idle directions are explicit static fallback poses. Portraits pending."
        if resident.id == "elder": definition.art_notes += " Elder design is provisional, from the archived older-man study."
        if resident.has("bounds"):
            var b: Array = resident.bounds
            definition.route_bounds = Rect2(b[0],b[1],b[2],b[3])
        var grid := nav.grid_for(definition.route_bounds)
        var desired_spawn := Vector2(resident.spawn[0],resident.spawn[1])
        var spawn_cell := nav.closest_cell(grid,desired_spawn)
        assert(spawn_cell != Vector2i(-1,-1),resident.id+" has no safe spawn")
        var spawn := grid.get_point_position(spawn_cell)
        var previous := spawn_cell
        var row := {"id":resident.id,"spawn":str(spawn),"points":[]}
        for entry in resident.routine:
            var desired := Vector2(entry.position[0],entry.position[1])
            var goal := nav.closest_cell(grid,desired)
            assert(goal != Vector2i(-1,-1),resident.id+" has no safe destination")
            var path := grid.get_point_path(previous,goal)
            assert(not path.is_empty(),resident.id+" has unreachable step: "+entry.label)
            var step := STEP.new()
            step.label = entry.label
            step.action = actions[entry.action]
            step.position = grid.get_point_position(goal)
            step.duration = entry.duration
            step.facing = entry.facing
            step.animation = entry.animation
            step.look_at_npc = entry.look_at_npc
            definition.routine.append(step)
            row.points.append({"label":step.label,"requested":str(desired),"position":str(step.position),"path_points":path.size()})
            previous = goal
        assert(not grid.get_point_path(previous,spawn_cell).is_empty(),resident.id+" cannot close its route")
        var resource_path: String = "res://assets/npc/stage43/%s/definition.tres" % resident.id
        assert(ResourceSaver.save(definition,resource_path) == OK)
        var scene_text := '[gd_scene format=3]\n[ext_resource type="PackedScene" path="res://scenes/npc/resident.tscn" id="1"]\n[ext_resource type="Resource" path="%s" id="2"]\n\n[node name="%s" instance=ExtResource("1")]\ndefinition = ExtResource("2")\n' % [resource_path,resident.id.to_pascal_case()]
        var scene_file := FileAccess.open("res://scenes/npc/residents/%s.tscn" % resident.id,FileAccess.WRITE)
        scene_file.store_string(scene_text); scene_file.close()
        population += '[node name="%s" parent="." instance=ExtResource("%s")]\nposition = Vector2(%s, %s)\n\n' % [resident.id.to_pascal_case(),resident.id,spawn.x,spawn.y]
        audit.append(row)
        print("ROUTE ",resident.id,": ",definition.routine.size()," safe cyclic points")
    var file := FileAccess.open("res://scenes/npc/residents.tscn",FileAccess.WRITE)
    file.store_string(population.strip_edges()+"\n"); file.close()
    file = FileAccess.open("res://assets/npc/stage43/route_audit.json",FileAccess.WRITE)
    file.store_string(JSON.stringify(audit,"  ",true)); file.close()
    nav.free()
    print("SAVED: nine resource-configured residents and one shared population")
    quit()
