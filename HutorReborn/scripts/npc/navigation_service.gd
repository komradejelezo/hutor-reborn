class_name HutorNpcNavigation
extends Node
## One shared static grid, a bounded queue and a bounded path cache for all NPCs.
@export var data: HutorNpcNavigationData
@export_range(1,4) var solves_per_tick := 2
var solve_count := 0
var cache_hits := 0
var max_solves_in_tick := 0
var dynamic_solves := 0
var dynamic_probes := 0
var _grids: Dictionary = {}
var _cache: Dictionary = {}
var _queue: Array[Dictionary] = []

func _ready() -> void:
    if data: grid_for(Rect2())
    set_physics_process(false)

func grid_for(bounds: Rect2) -> AStarGrid2D:
    var region := Rect2i(Vector2i.ZERO,data.world_size/data.cell_size)
    if bounds.has_area():
        var start := Vector2i(ceil(bounds.position.x/data.cell_size),ceil(bounds.position.y/data.cell_size))
        var end := Vector2i(floor(bounds.end.x/data.cell_size),floor(bounds.end.y/data.cell_size))
        region = region.intersection(Rect2i(start,end-start))
    var key := str(region)
    if _grids.has(key): return _grids[key]
    var grid := AStarGrid2D.new()
    grid.region = region
    grid.cell_size = Vector2.ONE*data.cell_size
    grid.offset = Vector2.ONE*data.cell_size*.5
    grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
    grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
    grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
    grid.update()
    var width := data.world_size.x/data.cell_size
    for index in data.blocked:
        var point := Vector2i(index%width,index/width)
        if region.has_point(point): grid.set_point_solid(point,true)
    for y in range(region.position.y,region.end.y):
        for x in range(region.position.x,region.end.x):
            var index := y*width+x
            grid.set_point_weight_scale(Vector2i(x,y),data.costs[index])
    _grids[key] = grid
    return grid

func cell(point: Vector2) -> Vector2i:
    return Vector2i(floor(point.x/data.cell_size),floor(point.y/data.cell_size))

func closest_cell(grid: AStarGrid2D, point: Vector2) -> Vector2i:
    var center := cell(point)
    if grid.is_in_boundsv(center) and not grid.is_point_solid(center): return center
    var candidates: Array[Vector2i] = []
    for y in range(center.y-4,center.y+5):
        for x in range(center.x-4,center.x+5):
            var candidate := Vector2i(x,y)
            if grid.is_in_boundsv(candidate) and not grid.is_point_solid(candidate): candidates.append(candidate)
    candidates.sort_custom(func(a: Vector2i,b: Vector2i): return Vector2(a-center).length_squared()<Vector2(b-center).length_squared())
    return candidates[0] if not candidates.is_empty() else Vector2i(-1,-1)

func request(actor: Node, token: int, start: Vector2, goal: Vector2, bounds: Rect2, avoid: Vector2i = Vector2i(-1,-1), dynamic: bool = false) -> void:
    for i in range(_queue.size()-1,-1,-1):
        if _queue[i].actor.get_ref() == actor: _queue.remove_at(i)
    _queue.append({"actor":weakref(actor),"token":token,"start":start,"goal":goal,"bounds":bounds,"avoid":avoid,"dynamic":dynamic})
    set_physics_process(true)

func _temporary_obstacles(actor: HutorResident, grid: AStarGrid2D, start: Vector2i) -> Array[Vector2i]:
    # Only on obstruction: 11x11 local cells, using the existing AStarGrid2D.
    # Never cache transient bodies or change the baked collision/navigation data.
    var cells: Array[Vector2i] = []
    var shape := CircleShape2D.new(); shape.radius = actor.definition.foot_radius+4
    var query := PhysicsShapeQueryParameters2D.new()
    query.shape=shape; query.collision_mask=7; query.exclude=[actor.get_rid()]
    var space := actor.get_world_2d().direct_space_state
    for y in range(start.y-5,start.y+6):
        for x in range(start.x-5,start.x+6):
            var point := Vector2i(x,y)
            if point==start or not grid.is_in_boundsv(point) or grid.is_point_solid(point):continue
            query.transform=Transform2D(0,grid.get_point_position(point)+Vector2(0,-3))
            dynamic_probes+=1
            if not space.intersect_shape(query,1).is_empty():
                grid.set_point_solid(point,true);cells.append(point)
    return cells

func _physics_process(_delta: float) -> void:
    var solved := 0
    var handled := 0
    while not _queue.is_empty() and handled < solves_per_tick:
        var task: Dictionary = _queue.pop_front()
        handled += 1
        var actor: Node = task.actor.get_ref()
        if not is_instance_valid(actor) or not actor.is_inside_tree() or actor.get("_token")!=task.token: continue
        var grid := grid_for(task.bounds)
        var start := closest_cell(grid,task.start)
        var goal := closest_cell(grid,task.goal)
        var key := str(grid.region)+str(start)+str(goal)+str(task.avoid)
        var path := PackedVector2Array()
        if start != Vector2i(-1,-1) and goal != Vector2i(-1,-1):
            if not task.dynamic and _cache.has(key):
                path = _cache[key].duplicate()
                cache_hits += 1
            else:
                var temporary: Array[Vector2i] = []
                if task.dynamic:
                    temporary=_temporary_obstacles(actor,grid,start)
                    dynamic_solves+=1
                elif task.avoid != Vector2i(-1,-1):
                    for y in range(task.avoid.y-1,task.avoid.y+2):
                        for x in range(task.avoid.x-1,task.avoid.x+2):
                            var p := Vector2i(x,y)
                            if p != start and p != goal and grid.is_in_boundsv(p) and not grid.is_point_solid(p):
                                grid.set_point_solid(p,true); temporary.append(p)
                if not grid.is_point_solid(goal):path = grid.get_point_path(start,goal)
                for p in temporary: grid.set_point_solid(p,false)
                solved += 1; solve_count += 1
                if not task.dynamic:
                    if _cache.size() >= 128: _cache.erase(_cache.keys()[0])
                    _cache[key] = path.duplicate()
            if not path.is_empty():
                path[0] = task.start
                if cell(task.goal) == goal: path[path.size()-1] = task.goal
        actor.call_deferred("_path_received",task.token,path)
    max_solves_in_tick = maxi(max_solves_in_tick,solved)
    if _queue.is_empty(): set_physics_process(false)
