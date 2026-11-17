extends "res://tools/chapter_observer_70.gd"
## Optional read-only navigation/quest observations for real X11 playtesting.
var query_sequence:=-1
var route:Dictionary={}
func _process(delta:float) -> void:
    if output=="":return
    var tick:=elapsed;var destination:=output
    # Keep the base observer's intermediate snapshot private to this extension.
    output=destination+".base"
    super._process(delta)
    output=destination
    if output=="" or elapsed!=0 or tick==elapsed or not FileAccess.file_exists(output+".base"):return
    var state:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(output+".base"))
    var c:Node=get_node("/root/ChapterI")
    if is_instance_valid(c.travel.active_world):
        var world:Node2D=c.travel.active_world
        state.clock=c.life.clock.absolute_minutes;state.items=c.state.items.duplicate();state.entry=[world.get_node("Entry").position.x,world.get_node("Entry").position.y] if world.has_node("Entry") else []
        state.residents={};state.doors={}
        for id in c.life.states:
            var r:RefCounted=c.life.states[id]
            state.residents[String(id)]={"scene":String(r.scene),"present":r.actor.is_inside_tree(),"position":[r.actor.position.x,r.actor.position.y]}
        if c.travel.active_id==&"":
            for id in c.travel.buildings:
                var d:Resource=c.travel.buildings[id];var anchor:Node2D=world.get_node(d.exterior_anchor)
                var p:Vector2=anchor.global_position+d.door_offset+Vector2(0,28)
                state.doors[String(id)]=[p.x,p.y]
        var query_path:=output.get_base_dir().path_join("query.json")
        if FileAccess.file_exists(query_path):
            var query:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(query_path))
            if int(query.sequence)!=query_sequence:
                query_sequence=int(query.sequence)
                var nav:Node=world.get_node("Actors/Residents/Navigation");var g:AStarGrid2D=nav.grid_for(Rect2())
                var goal:=Vector2(query.goal[0],query.goal[1]);var path:PackedVector2Array=g.get_point_path(nav.closest_cell(g,world.player.position),nav.closest_cell(g,goal))
                var values:Array=[]
                for p in path:values.append([p.x,p.y])
                if not values.is_empty():values[0]=state.position;values[-1]=[goal.x,goal.y]
                route={"sequence":query_sequence,"points":values}
        state.route=route
    var f:=FileAccess.open(output+".tmp",FileAccess.WRITE);f.store_string(JSON.stringify(state));f.close();DirAccess.rename_absolute(output+".tmp",output)
