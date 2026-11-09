extends SceneTree
var passed:=0
var failed:=0
func _initialize()->void:call_deferred("run")
func check(value:bool,label:String)->void:
    if value:passed+=1;print("PASS: ",label)
    else:failed+=1;push_error(label)
func run()->void:
    var result:Dictionary={}
    for id in [&"inn",&"elder",&"herbalist",&"woodcutter",&"old_man",&"storehouse"]:
        var path:="res://scenes/interiors/"+String(id)+".tscn"
        var packed:=load(path) as PackedScene
        check(packed!=null,String(id)+" exists as separate PackedScene")
        if packed==null:continue
        var room:Node2D=packed.instantiate()
        var floor:TileMapLayer=room.get_node_or_null("Floor")
        var walls:TileMapLayer=room.get_node_or_null("Walls")
        var props:Node=room.get_node_or_null("Actors/Props")
        var bodies:=room.find_children("*","StaticBody2D",true,false).size()
        var shapes:=room.find_children("*","CollisionShape2D",true,false).size()+room.find_children("*","CollisionPolygon2D",true,false).size()
        var lights:=room.find_children("*","PointLight2D",true,false).size()
        var markers:=room.find_children("*","Marker2D",true,false).size()
        check(floor!=null and floor.get_used_cells().size()>=64,String(id)+" nonempty editable floor")
        check(walls!=null and walls.get_used_cells().size()>20,String(id)+" nonempty walls")
        check(props!=null and props.get_child_count()>=8,String(id)+" furnished room rather than placeholder")
        check(bodies>=5 and shapes>=5,String(id)+" substantial physical collisions")
        check(lights>=1,String(id)+" real interior lighting")
        check(room.has_node("Entry") and room.has_node("Exit") and room.has_node("Actors/Hans/Camera2D"),String(id)+" entry, exit and playable Hans/camera")
        check(room.has_node("Actors/Residents/Navigation") and (markers>=3 or room.resident_definitions.size()>0),String(id)+" navigation and defined NPC places")
        check(room.building_id==id,String(id)+" matches registered building identity")
        result[id]={"scene":path,"floor_cells":floor.get_used_cells().size(),"wall_cells":walls.get_used_cells().size(),"props":props.get_child_count(),"static_bodies":bodies,"collision_shapes":shapes,"lights":lights,"markers":markers,"local_npc_definitions":room.resident_definitions.size(),"entry":str(room.get_node("Entry").position)}
        room.free()
    if not OS.get_cmdline_user_args().is_empty():
        var file:=FileAccess.open(OS.get_cmdline_user_args()[0],FileAccess.WRITE);file.store_string(JSON.stringify(result,"  "))
    print("RESULT: ",passed," interior-content checks passed, ",failed," failed")
    quit(0 if failed==0 else 1)
