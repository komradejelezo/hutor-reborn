extends SceneTree
## Authoring only: saved TileMapLayers, individual props, colliders and NPC routes.
const WORLD = preload("res://scripts/interiors/interior_world.gd")
const NAV = preload("res://scripts/npc/navigation_service.gd")
const DATA = preload("res://scripts/npc/navigation_data.gd")
const STEP = preload("res://scripts/npc/routine_step.gd")
const BUILDING = preload("res://scripts/interiors/building_definition.gd")
const PROP = preload("res://scenes/interiors/interior_prop.tscn")
const DOOR = preload("res://scripts/interiors/door.gd")
const ART := "res://assets/interiors/stage44/"
var solids: Array[Rect2] = []
func _initialize() -> void: call_deferred("run")
func own(node: Node, root_node: Node) -> void:
    for child in node.get_children():
        # Keep inherited ownership: flattening it creates replacement children
        # beside the PackedScene's originals and leaks those originals on load.
        if child.owner == null: child.owner = root_node
        own(child, root_node)
func node(name: String, type: String, parent: Node) -> Node:
    var result: Node = ClassDB.instantiate(type)
    result.name = name; parent.add_child(result)
    return result
func art(name: String) -> Texture2D: return load(ART+name+".png")
func solid(parent: Node, position: Vector2, size: Vector2) -> void:
    var body := StaticBody2D.new(); parent.add_child(body)
    body.position = position; body.collision_mask = 6
    var shape := CollisionShape2D.new(); body.add_child(shape)
    var rectangle := RectangleShape2D.new(); rectangle.size = size
    shape.shape = rectangle
    solids.append(Rect2(position-size*.5,size))
func prop(root_node: Node2D, name: String, kind: String, point: Vector2, footprint: Vector2 = Vector2.ZERO, scale_value: float = 1.0) -> Node2D:
    var item: Node2D = PROP.instantiate()
    item.name = name
    root_node.get_node("Actors/Props").add_child(item)
    root_node.set_editable_instance(item, true)
    item.position = point
    item.set_meta("interior_asset",kind)
    var sprite: Sprite2D = item.get_node("Art")
    sprite.texture = art(kind); sprite.scale = Vector2.ONE*scale_value
    sprite.position = Vector2(-sprite.texture.get_width()*.5,-sprite.texture.get_height()+4)*scale_value
    if footprint.is_zero_approx(): item.get_node("Solid/Feet").disabled = true
    else:
        var shape: CollisionShape2D = item.get_node("Solid/Feet")
        var rectangle := RectangleShape2D.new(); rectangle.size = footprint
        shape.shape = rectangle; shape.position = Vector2(0,-footprint.y*.5+2)
        solids.append(Rect2(point+shape.position-footprint*.5,footprint))
    return item
func light(parent: Node, point: Vector2, energy: float, radius: float) -> void:
    var lamp := PointLight2D.new(); parent.add_child(lamp)
    lamp.position = point
    lamp.texture = load("res://assets/environment/krivaya_sosna/stage33/soft_light.tres")
    lamp.texture_scale = radius; lamp.color = Color(1,.74,.43)
    lamp.set_script(load("res://scripts/components/warm_light.gd"))
    lamp.base_energy = energy; lamp.flicker = .018; lamp.update_interval = .12
func layer(root_node: Node, name: String, texture: Texture2D, full_atlas: bool = false) -> TileMapLayer:
    var result := TileMapLayer.new(); result.name = name; root_node.add_child(result)
    result.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    var tiles := TileSet.new(); tiles.tile_size = Vector2i(32,32)
    var atlas := TileSetAtlasSource.new(); atlas.texture = texture; atlas.texture_region_size = Vector2i(32,32)
    for y in range(texture.get_height()/32 if full_atlas else 1):
        for x in range(texture.get_width()/32 if full_atlas else 1):atlas.create_tile(Vector2i(x,y))
    tiles.add_source(atlas,0)
    result.tile_set = tiles
    return result
func populate_tiles(target: TileMapLayer, rect: Rect2, full_atlas: bool = false) -> void:
    for y in range(int(rect.position.y/32),int(rect.end.y/32)):
        for x in range(int(rect.position.x/32),int(rect.end.x/32)):
            target.set_cell(Vector2i(x,y),0,Vector2i(x-int(rect.position.x/32),y-int(rect.position.y/32)) if full_atlas else Vector2i.ZERO)
func routine(id: String, steps: Array, nav: Node) -> HutorNpcDefinition:
    var data: HutorNpcDefinition = load("res://assets/npc/stage43/"+id+"/definition.tres").duplicate()
    data.route_bounds = Rect2(); data.routine = []
    var grid: AStarGrid2D = nav.grid_for(Rect2())
    for entry in steps:
        var step: HutorNpcRoutineStep = STEP.new()
        step.label = entry[0]
        var cell: Vector2i = nav.closest_cell(grid,entry[1])
        assert(cell != Vector2i(-1,-1),id+" lacks a safe indoor point")
        step.position = grid.get_point_position(cell)
        step.duration = entry[2]; step.action = HutorNpcRoutineStep.Action.REST
        if entry.size()>3:
            step.animation = entry[3]; step.action = HutorNpcRoutineStep.Action.WORK
        if entry.size()>4: step.talk_offset = entry[4]
        data.routine.append(step)
    for i in data.routine.size():
        assert(not grid.get_point_path(nav.cell(data.routine[i].position),nav.cell(data.routine[(i+1)%data.routine.size()].position)).is_empty(),id+" indoor route disconnected")
    return data
func bake(rect: Rect2) -> HutorNpcNavigationData:
    var data: HutorNpcNavigationData = DATA.new()
    data.world_size = Vector2i(960,640);data.cell_size = 16
    data.costs.resize(60*40);data.costs.fill(1)
    for y in 40:
        for x in 60:
            var point := Vector2(x*16+8,y*16+5)
            var blocked := not rect.grow(-12).has_point(point)
            for footprint in solids:
                if footprint.grow(8).has_point(point):blocked = true;break
            if blocked: data.blocked.append(y*60+x)
    return data
func build(id: String, title: String, rect: Rect2, floor_name: String, tint: Color, inventory: Array, routes: Dictionary, anchor: String, permanent: Array[StringName]) -> void:
    solids.clear()
    var root_node := Node2D.new();root_node.name = id.to_pascal_case()
    root_node.set_script(WORLD);root_node.building_id = id;root_node.room_bounds = rect
    root_node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    var background := Polygon2D.new();root_node.add_child(background)
    background.name = "Void";background.polygon = PackedVector2Array([Vector2.ZERO,Vector2(960,0),Vector2(960,640),Vector2(0,640)])
    background.color = Color("0f1110")
    populate_tiles(layer(root_node,"Floor",art("floor_atlas_"+id),true),rect,true)
    var walls := layer(root_node,"Walls",art("wall_old" if id=="herbalist" else "wall"))
    populate_tiles(walls,Rect2(rect.position-Vector2(0,32),Vector2(rect.size.x,32)))
    populate_tiles(walls,Rect2(rect.position-Vector2(32,32),Vector2(32,rect.size.y+64)))
    populate_tiles(walls,Rect2(Vector2(rect.end.x,rect.position.y-32),Vector2(32,rect.size.y+64)))
    # Bottom wall stays low; it does not hide the entry sprite or an interactable.
    populate_tiles(walls,Rect2(Vector2(rect.position.x,rect.end.y),Vector2(rect.size.x,32)))
    var actors: Node2D = node("Actors","Node2D",root_node);actors.y_sort_enabled = true
    var props: Node2D = node("Props","Node2D",actors);props.y_sort_enabled = true
    var population: Node2D = node("Residents","Node2D",actors);population.y_sort_enabled = true
    population.set_script(load("res://scripts/npc/npc_population.gd"))
    var navigation: Node = node("Navigation","Node",population);navigation.set_script(NAV)
    var hero: CharacterBody2D = load("res://scenes/player/hans.tscn").instantiate()
    hero.name = "Hans";actors.add_child(hero)
    var entry: Marker2D = node("Entry","Marker2D",root_node)
    entry.position = Vector2(rect.get_center().x,rect.end.y-46);hero.position = entry.position
    var exit: HutorInteractable = HutorInteractable.new();exit.set_script(DOOR)
    exit.name="Exit";exit.building_id=id;exit.exit_to_village=true;exit.title="Выйти на улицу"
    exit.position=Vector2(rect.get_center().x,rect.end.y-12);exit.reach=52;root_node.add_child(exit)
    prop(root_node,"FrontDoor","door",Vector2(rect.get_center().x,rect.end.y+18))
    solid(root_node,rect.position+Vector2(rect.size.x*.5,0),Vector2(rect.size.x+64,16))
    solid(root_node,Vector2(rect.position.x,rect.get_center().y),Vector2(16,rect.size.y))
    solid(root_node,Vector2(rect.end.x,rect.get_center().y),Vector2(16,rect.size.y))
    solid(root_node,Vector2(rect.get_center().x,rect.end.y+4),Vector2(rect.size.x+64,16))
    var atmosphere: Node2D = node("Atmosphere","Node2D",root_node)
    atmosphere.set_script(load("res://scripts/interiors/interior_atmosphere.gd"))
    var canvas: CanvasModulate = node("Evening","CanvasModulate",root_node);canvas.color=tint
    var hud: CanvasLayer = node("HUD","CanvasLayer",root_node)
    hud.set_script(load("res://scripts/ui/hud.gd"));hud.location_title=title
    hud.location_subtitle="Тёплый зал у дороги" if id=="inn" else "Доски хранят следы долгой жизни"
    hud.chapter_label="IV · КРИВАЯ СОСНА";hud.pause_caption=title
    for spec in inventory:
        var foot: Vector2 = spec[4] if spec.size()>4 else Vector2.ZERO
        var scale_value: float = spec[5] if spec.size()>5 else 1.0
        prop(root_node,spec[0],spec[1],rect.position+Vector2(spec[2],spec[3]),foot,scale_value)
    if id=="inn":
        light(atmosphere,rect.position+Vector2(665,175),.72,.8)
        for p in [Vector2(190,270),Vector2(400,310),Vector2(384,120)]:light(atmosphere,rect.position+p,.36,.55)
        var back: HutorInteractable = HutorInteractable.new()
        back.name="BackRoom";back.title="Подсобная дверь";back.description="За дверью — припасы. Пока туда не войти."
        back.position=rect.position+Vector2(690,80);root_node.add_child(back)
    elif id=="elder":
        light(atmosphere,rect.position+Vector2(480,145),.6,.68)
        light(atmosphere,rect.position+Vector2(288,135),.32,.5)
    else:
        light(atmosphere,rect.position+Vector2(470,105),.55,.65)
        light(atmosphere,rect.position+Vector2(355,165),.22,.4)
    var data := bake(rect)
    navigation.data = data
    var helper: Node = NAV.new();helper.data=data
    var definitions: Array[HutorNpcDefinition] = []
    for resident_id in routes:
        var local: Array = []
        for step in routes[resident_id]:
            var record: Array = step.duplicate();record[1] += rect.position;local.append(record)
        var definition := routine(resident_id,local,helper)
        var path: String = "res://data/interiors/"+id+"_"+resident_id+".tres"
        assert(ResourceSaver.save(definition,path)==OK)
        definitions.append(load(path))
    root_node.resident_definitions=definitions;helper.free()
    own(root_node,root_node)
    var packed := PackedScene.new();assert(packed.pack(root_node)==OK)
    var path := "res://scenes/interiors/"+id+".tscn"
    assert(ResourceSaver.save(packed,path)==OK)
    var building: HutorBuildingDefinition = BUILDING.new()
    building.id=id;building.display_name=title;building.interior_scene=path
    building.exterior_anchor=NodePath("Actors/Structures/"+anchor+"/Entrance")
    building.residents.assign(routes.keys());building.always_inside=permanent
    assert(ResourceSaver.save(building,"res://data/interiors/"+id+".tres")==OK)
    print("SAVED ",id,": ",inventory.size()," modular objects; ",data.blocked.size()," blocked cells; ",definitions.size()," NPC route resources")
    root_node.free()
func run() -> void:
    build("inn","Большой трактир",Rect2(96,96,768,448),"floor_warm",Color(.79,.75,.67),[
        ["Counter","counter",384,150,Vector2(226,30)],
        ["Cups","shelf_cups",300,28],["Dishes","shelf_cups",440,28],
        ["BarrelA","barrel",50,72,Vector2(35,25)],["BarrelB","barrel",95,72,Vector2(35,25)],
        ["Fireplace","fireplace",665,210,Vector2(55,35)],
        ["TableA","table_set",190,280,Vector2(52,32)],
        ["TableB","table_set",400,335,Vector2(52,32)],
        ["TableC","table_round",600,305,Vector2(56,24)],
        ["BenchA","bench",190,330,Vector2(52,12)],["BenchB","bench",400,385,Vector2(52,12)],
        ["BenchC","bench",600,350,Vector2(52,12)],
        ["StoreDoor","door",690,38],["Food","dry_food",570,44],
        ["Sacks","sacks",710,330,Vector2(45,20),.7],
        ["SupplyBasket","basket",710,383,Vector2(30,19),.65],
        ["KitchenPots","hanging_pots",720,96],
        ["CandleA","candle",190,244,Vector2.ZERO,.35],["CandleB","candle",400,300,Vector2.ZERO,.35],
        ["Lamp","lantern",120,45]
    ],{
        "innkeeper":[["За стойкой",Vector2(360,106),9,"work_wipe",Vector2(0,70)],["Проверить посуду",Vector2(430,106),6,"work_wipe",Vector2(0,70)]],
        "innkeeper_wife":[["Хозяйственная зона",Vector2(705,260),4],["У очага",Vector2(590,210),5],["Между столами",Vector2(290,360),5,"work_sweep"],["Припасы",Vector2(690,350),4]]
    },"Inn",[&"innkeeper",&"innkeeper_wife"])
    build("elder","Дом старосты",Rect2(192,128,576,384),"floor_dark",Color(.72,.69,.62),[
        ["Desk","desk",288,175,Vector2(62,28)],
        ["Chair","chair",288,95,Vector2(27,16)],
        ["GuestChair","chair",220,220,Vector2(27,16)],
        ["GuestChair2","chair",355,220,Vector2(27,16)],
        ["BooksA","shelf_books",355,28],["BooksB","shelf_books",425,28],
        ["Documents","documents",288,133,Vector2.ZERO,.65],
        ["Chest","chest",100,280,Vector2(45,25)],
        ["Bed","bed",80,160,Vector2(44,70)],
        ["Hearth","fireplace",480,170,Vector2(55,35)],
        ["WallCloth","wall_hanging",160,45,Vector2.ZERO,.6],
        ["CandleA","candle",265,134,Vector2.ZERO,.35],["CandleB","candle",310,134,Vector2.ZERO,.35]
    ],{"elder":[["За рабочим столом",Vector2(288,126),8,"",Vector2(0,76)],["У книг",Vector2(415,85),6],["Осмотреть комнату",Vector2(150,260),5],["У выхода",Vector2(288,330),.6]]},"ElderHouse",[])
    build("herbalist","Дом травницы и её брата",Rect2(192,128,576,384),"floor_worn",Color(.61,.60,.54),[
        ["BedA","bed_old",75,180,Vector2(42,65)],
        ["BedB","bed_old",140,180,Vector2(42,65)],
        ["Table","table_small",365,200,Vector2(36,40)],
        ["Stove","fireplace",500,150,Vector2(55,35)],
        ["HerbShelf","shelf_books",375,35],["HerbLine","herb_line",270,60,Vector2.ZERO,.65],
        ["Bottles","bottles",440,265,Vector2(30,19),.65],
        ["BasketA","basket",240,250,Vector2(30,20),.65],
        ["BasketB","basket",495,295,Vector2(30,20),.65],
        ["Cauldron","cauldron",450,170,Vector2(39,25),.75],
        ["ClayPotA","pot",415,220,Vector2(25,16),.7],
        ["ClayPotB","pot",405,255,Vector2(25,16),.6],
        ["DryHerbs","herbs",357,163,Vector2.ZERO,.6],
        ["KitchenPots","hanging_pots",500,40,Vector2.ZERO,.8],
        ["WornBoardsA","broken_boards",210,220],["WornBoardsB","broken_boards",150,290],
        ["Candle","candle",350,160,Vector2.ZERO,.35]
    ],{
        "herbalist":[["Работа с травами",Vector2(330,215),8,"work_gather"],["У полки",Vector2(355,85),6],["Проверить котёл",Vector2(460,220),5],["У двери",Vector2(288,330),.6]],
        "herbalist_brother":[["Отдохнуть дома",Vector2(120,230),6],["Прибрать у постели",Vector2(175,210),7],["У двери",Vector2(300,330),.6]]
    },"HerbalistHouse",[])
    var registry := FileAccess.open("res://data/interiors/registry.json",FileAccess.WRITE)
    registry.store_string(JSON.stringify(["res://data/interiors/inn.tres","res://data/interiors/elder.tres","res://data/interiors/herbalist.tres"],"  ")+"\n")
    registry.close();quit()
