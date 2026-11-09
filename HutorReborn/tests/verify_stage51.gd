extends "res://tests/verify_interiors.gd"
## Test the real saved room collision world, not a snapped approximation of goals.
var report: Dictionary = {}

func reachable(room: Node2D, point: Vector2, label: String) -> void:
    var nav: HutorNpcNavigation=room.get_node("Actors/Residents/Navigation")
    var grid:=nav.grid_for(Rect2())
    var cell:=nav.cell(point)
    check(grid.is_in_boundsv(cell) and not grid.is_point_solid(cell),label+" exact point is navigable")
    check(free_at(room,point,8),label+" physical foot clearance")
    var entry:=nav.cell(room.get_node("Entry").position)
    if grid.is_in_boundsv(cell) and not grid.is_point_solid(cell):
        check(not grid.get_point_path(entry,cell).is_empty(),label+" connected to door")

func run() -> void:
    travel=root.get_node("InteriorTravel")
    change_scene_to_file(travel.VILLAGE);await frames(12)
    var life: Node=root.get_node("VillageLife")
    life.clock.running=false
    var identities: Dictionary={}
    for id in life.states:identities[id]=life.states[id].actor.get_instance_id()
    var hero_id: int=travel.active_world.player.get_instance_id()
    var specs:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tools/stage51_layout.json"))
    for id in specs:
        check(travel.request_transition(id),id+" existing transition starts")
        await wait_transition()
        var room: Node2D=travel.active_world
        check(room.building_id==StringName(id) and current_scene==room,id+" real current_scene interior")
        check(room.player.get_instance_id()==hero_id,id+" same Hans")
        check(room.player.get_node("Camera2D").zoom.is_equal_approx(Vector2(1.3,1.3)),id+" camera scale preserved")
        check(room.room_bounds.size.x*room.room_bounds.size.y < room.get_meta("previous_floor_size").x*room.get_meta("previous_floor_size").y,id+" smaller floor area")
        reachable(room,room.get_node("Entry").position,id+" spawn")
        check(room.player.sensor.target==room.get_node("Exit"),id+" exit actually selected")
        for marker in room.find_children("*","Marker2D",true,false):
            if marker.get_parent().name=="NPCPoints":reachable(room,marker.position,id+"/"+String(marker.name))
        for definition in room.resident_definitions:
            for step in definition.routine:reachable(room,step.position,id+" preview "+String(definition.id)+" "+step.label)
        for resident_id in life.states:
            var profile:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/life/residents/"+resident_id+".json"))
            for block in profile.blocks:
                if block.scene!=id:continue
                for action in block.activities:
                    var value: Vector2=Vector2(action.point[0],action.point[1]) if action.point is Array else room.get_node(NodePath(action.point)).position
                    reachable(room,value,id+" schedule "+resident_id+"/"+action.id)
        var shadow_count:=0
        for item in room.get_node("Actors/Props").get_children():
            var sprite: Sprite2D=item.get_node("Art")
            check(is_equal_approx(sprite.scale.x,sprite.scale.y),id+" proportional "+String(item.name))
            var feet: CollisionShape2D=item.get_node("Solid/Feet")
            if not feet.disabled:
                var shadow: Polygon2D=item.get_node_or_null("ContactShadow")
                check(shadow!=null and shadow.polygon.size()==12,id+" contact shadow "+String(item.name))
                shadow_count+=1
        for resident_id in identities:check(life.states[resident_id].actor.get_instance_id()==identities[resident_id],id+" persistent "+resident_id)
        report[id]={"bounds":str(room.room_bounds),"old_size":str(room.get_meta("previous_floor_size")),"props":room.get_node("Actors/Props").get_child_count(),"contact_shadows":shadow_count,"lights":room.get_node("Atmosphere").get_child_count()}
        check(travel.request_transition(id,true),id+" exit transition starts")
        await wait_transition()
        check(current_scene.scene_file_path==travel.VILLAGE and not current_scene.player.controls_locked,id+" returned outside with control")
    if not OS.get_cmdline_user_args().is_empty():
        var file:=FileAccess.open(OS.get_cmdline_user_args()[0],FileAccess.WRITE)
        file.store_string(JSON.stringify(report,"  "))
    print("RESULT: ",passed," stage51 room checks passed, ",failed," failed")
    quit(0 if failed==0 else 1)
