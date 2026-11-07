extends "res://tests/verify_interiors.gd"
var life: Node
func inspect_scene(scene: StringName) -> void:
    var world:Node2D=life.world_for(scene)
    var nav:HutorNpcNavigation=world.get_node("Actors/Residents/Navigation")
    for r:HutorDailyResidentState in life.states.values():
        var rect:=Rect2()
        if scene==&"village" and r.schedule.has("safe_village_rect"):
            var a:Array=r.schedule.safe_village_rect;rect=Rect2(a[0],a[1],a[2],a[3])
        var grid:=nav.grid_for(rect)
        var start:Vector2i=nav.closest_cell(grid,r.original.routine[0].position if scene==&"village" else world.get_node("Entry").position)
        for block in r.schedule.blocks:
            if StringName(block.scene)!=scene:continue
            for action in block.activities:
                var raw:Vector2=life._point(scene,action.point)
                var cell:=nav.closest_cell(grid,raw)
                var target:=grid.get_point_position(cell)
                var name:=String(r.id)+"/"+String(action.id)+"@"+String(scene)
                check(cell!=Vector2i(-1,-1) and target.distance_to(raw)<=32,"nearby valid waypoint: "+name)
                check(free_at(world,target,r.original.foot_radius),"physical feet clearance: "+name)
                var path:=grid.get_point_path(start,cell)
                check(not path.is_empty(),"connected route from entry: "+name)
                var clear:=true
                for i in range(1,path.size()):
                    var samples:=maxi(1,int(ceil(path[i-1].distance_to(path[i])/4)))
                    for n in range(samples+1):clear=clear and free_at(world,path[i-1].lerp(path[i],float(n)/samples),r.original.foot_radius)
                check(clear,"physics clears the entire route: "+name)
func run() -> void:
    travel=root.get_node("InteriorTravel")
    var world:Node2D=load(travel.VILLAGE).instantiate()
    root.add_child(world);current_scene=world;await frames(10)
    life=root.get_node("VillageLife");life.clock.running=false
    inspect_scene(&"village")
    for id in [&"inn",&"elder",&"herbalist",&"woodcutter",&"old_man",&"storehouse"]:
        travel.request_transition(id);await wait_transition()
        inspect_scene(id)
        travel.request_transition(id,true);await wait_transition()
    print("RESULT: ",passed," daily-route checks passed, ",failed," failed")
    quit(0 if failed==0 else 1)
