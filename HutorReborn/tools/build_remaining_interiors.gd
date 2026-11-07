extends "res://tools/build_interiors.gd"
## Stage 4.5 authoring. Reuse 4.4 helpers; never rebuild its three saved rooms.
const NEW_ART := "res://assets/interiors/stage45/"

func art(name: String) -> Texture2D:
    if FileAccess.file_exists(NEW_ART+name+".png"): return load(NEW_ART+name+".png")
    if FileAccess.file_exists(ART+name+".png"): return super.art(name)
    return load("res://assets/environment/krivaya_sosna/objects/"+name+".png")

func action_marker(parent: Node, name: String, point: Vector2, id: StringName, action: String, facing: StringName = &"down") -> void:
    var marker: Marker2D = node(name,"Marker2D",parent)
    marker.position=point
    marker.set_meta("npc_id",id);marker.set_meta("future_action",action);marker.set_meta("facing",facing)

func make_room(id: String, title: String, rect: Rect2, tint: Color, inventory: Array, routes: Dictionary, slots: Array, anchor: String, lights: Array) -> void:
    solids.clear()
    var room:=Node2D.new();room.name=id.to_pascal_case()
    room.set_script(WORLD);room.building_id=id;room.room_bounds=rect
    room.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
    room.set_meta("stage",4.5)
    var background: Polygon2D=node("Void","Polygon2D",room)
    background.polygon=PackedVector2Array([Vector2.ZERO,Vector2(960,0),Vector2(960,640),Vector2(0,640)])
    background.color=Color("0f1110")
    populate_tiles(layer(room,"Floor",art("floor_atlas_"+id),true),rect,true)
    var walls:=layer(room,"Walls",art("wall" if id=="woodcutter" else "wall_old"))
    for region in [Rect2(rect.position-Vector2(0,32),Vector2(rect.size.x,32)),Rect2(rect.position-Vector2(32,32),Vector2(32,rect.size.y+64)),Rect2(Vector2(rect.end.x,rect.position.y-32),Vector2(32,rect.size.y+64)),Rect2(Vector2(rect.position.x,rect.end.y),Vector2(rect.size.x,32))]:populate_tiles(walls,region)
    var actors:Node2D=node("Actors","Node2D",room);actors.y_sort_enabled=true
    var props:Node2D=node("Props","Node2D",actors);props.y_sort_enabled=true
    var population:Node2D=node("Residents","Node2D",actors);population.y_sort_enabled=true
    population.set_script(load("res://scripts/npc/npc_population.gd"))
    var navigation:Node=node("Navigation","Node",population);navigation.set_script(NAV)
    var hero:CharacterBody2D=load("res://scenes/player/hans.tscn").instantiate()
    hero.name="Hans";actors.add_child(hero)
    var entry:Marker2D=node("Entry","Marker2D",room)
    entry.position=Vector2(rect.get_center().x,rect.end.y-46);hero.position=entry.position
    var exit:HutorInteractable=HutorInteractable.new();exit.set_script(DOOR)
    exit.name="Exit";exit.building_id=id;exit.exit_to_village=true;exit.title="Выйти на улицу"
    exit.position=Vector2(rect.get_center().x,rect.end.y-12);exit.reach=52;room.add_child(exit)
    prop(room,"FrontDoor","door",Vector2(rect.get_center().x,rect.end.y+18))
    solid(room,rect.position+Vector2(rect.size.x*.5,0),Vector2(rect.size.x+64,16))
    solid(room,Vector2(rect.position.x,rect.get_center().y),Vector2(16,rect.size.y))
    solid(room,Vector2(rect.end.x,rect.get_center().y),Vector2(16,rect.size.y))
    solid(room,Vector2(rect.get_center().x,rect.end.y+4),Vector2(rect.size.x+64,16))
    for spec in inventory:
        prop(room,spec[0],spec[1],rect.position+Vector2(spec[2],spec[3]),spec[4] if spec.size()>4 else Vector2.ZERO,spec[5] if spec.size()>5 else 1.0)
    var atmosphere:Node2D=node("Atmosphere","Node2D",room)
    atmosphere.set_script(load("res://scripts/interiors/interior_atmosphere.gd"))
    for spec in lights:
        light(atmosphere,rect.position+spec[0],spec[1],spec[2])
        if spec.size()>3:
            var window:PointLight2D=atmosphere.get_child(-1)
            window.color=spec[3];window.flicker=0
    var modulation:CanvasModulate=node("Evening","CanvasModulate",room);modulation.color=tint
    var hud:CanvasLayer=node("HUD","CanvasLayer",room);hud.set_script(load("res://scripts/ui/hud.gd"))
    hud.location_title=title;hud.location_subtitle="Тепло печи и запах дерева" if id=="woodcutter" else "Тишина старого дома" if id=="old_man" else "Общие припасы хутора"
    hud.chapter_label="IV · КРИВАЯ СОСНА";hud.pause_caption=title
    navigation.data=bake(rect)
    var helper:Node=NAV.new();helper.data=navigation.data
    var definitions:Array[HutorNpcDefinition]=[]
    for resident_id in routes:
        var steps:Array=[]
        for entry_data in routes[resident_id]:
            var step_data:Array=entry_data.duplicate();step_data[1]+=rect.position;steps.append(step_data)
        var definition:=routine(resident_id,steps,helper)
        if resident_id=="old_man":definition.routine[0].facing=&"right"
        var path:String="res://data/interiors/"+id+"_"+resident_id+".tres"
        assert(ResourceSaver.save(definition,path)==OK);definitions.append(load(path))
    room.resident_definitions=definitions
    var points:Node2D=node("NPCPoints","Node2D",room)
    for spec in slots:action_marker(points,spec[0],rect.position+spec[1],spec[2],spec[3],spec[4] if spec.size()>4 else &"down")
    if id=="old_man":
        var chair:Node2D=room.get_node("Actors/Props/Armchair")
        action_marker(chair,"SeatPose",Vector2.ZERO,&"old_man","sit",&"right")
        var seat:Marker2D=chair.get_node("SeatPose")
        seat.set_meta("pose_source","res://assets/npc/stage2/Страрик/Sprite-0012.png")
        seat.set_meta("access_root_path","NPCPoints/ChairRest")
        seat.set_meta("hide_empty_chair_when_occupied",true)
        room.set_meta("presence_note","Old man keeps his existing pine-side route; HOME scheduling is prepared for the next stage.")
    elif id=="woodcutter":
        points.get_node("Cooking").set_meta("future_animation_source","res://assets/npc/stage2/Жена дровосека/Sprite-0010.png")
    var grid:AStarGrid2D=helper.grid_for(Rect2())
    var start:Vector2i=helper.closest_cell(grid,entry.position)
    assert(start!=Vector2i(-1,-1),id+" entry blocked")
    for point in points.get_children():
        var goal:Vector2i=helper.closest_cell(grid,point.position)
        assert(goal!=Vector2i(-1,-1) and not grid.get_point_path(start,goal).is_empty(),id+" marker unreachable: "+point.name)
    helper.free();own(room,room)
    var packed:=PackedScene.new();assert(packed.pack(room)==OK)
    var scene_path:="res://scenes/interiors/"+id+".tscn"
    assert(ResourceSaver.save(packed,scene_path)==OK)
    var building:HutorBuildingDefinition=BUILDING.new()
    building.id=id;building.display_name=title;building.interior_scene=scene_path
    building.exterior_anchor=NodePath("Actors/Structures/"+anchor+"/Entrance")
    building.residents.assign(routes.keys())
    assert(ResourceSaver.save(building,"res://data/interiors/"+id+".tres")==OK)
    print("SAVED ",id,": ",rect.size,"; ",inventory.size()," props; ",slots.size()," prepared action/access points")
    room.free()

func run() -> void:
    make_room("woodcutter","Дом семьи дровосека",Rect2(256,160,448,320),Color(.72,.68,.59),[
        ["ParentsBed","parents_bed",65,150,Vector2(70,60),.85],
        ["SonBed","bed",140,150,Vector2(30,46),.65],
        ["Stove","fireplace",377,110,Vector2(55,35)],
        ["DiningTable","desk",260,195,Vector2(60,28)],
        ["ChairA","chair",211,209,Vector2(24,14),.65],
        ["ChairB","chair",309,209,Vector2(24,14),.65],
        ["ChairC","chair",260,125,Vector2(24,14),.65],
        ["RestBench","bench",155,265,Vector2(42,12),.9],
        ["ClothesChest","chest",62,250,Vector2(40,22),.85],
        ["Dishes","shelf_cups",320,28,Vector2.ZERO,.75],
        ["Utensils","hanging_pots",385,30,Vector2.ZERO,.6],
        ["KitchenPot","cauldron",332,120,Vector2(26,16),.55],
        ["Linen","linen_line",73,37,Vector2.ZERO,.45],
        ["Boots","work_boots",62,186,Vector2.ZERO,.8],
        ["AxeByWall","axe",413,186,Vector2.ZERO,.48],
        ["ToyCart","cart",148,185,Vector2.ZERO,.15],
        ["ToyBlocks","crate",167,178,Vector2.ZERO,.22],
        ["Window","window",194,25,Vector2.ZERO,.65],
        ["Lamp","candle",260,149,Vector2.ZERO,.35]
    ],{
        "woodcutter":[["Отдых у лавки",Vector2(155,232),7],["У семейного стола",Vector2(260,148),6],["У выхода",Vector2(224,266),.6]],
        "woodcutter_wife":[["Кухонная зона",Vector2(326,153),7],["Прибрать комнату",Vector2(355,253),5,"work_sweep"],["У выхода",Vector2(235,266),.6]],
        "woodcutter_son":[["Игрушки рядом с постелью",Vector2(159,204),5,"work_play"],["У стола",Vector2(328,190),3],["Обратно во двор",Vector2(220,266),.6]]
    },[
        ["FatherRest",Vector2(155,232),&"woodcutter","rest_after_work"],
        ["Cooking",Vector2(326,153),&"woodcutter_wife","cook",&"up"],
        ["Housekeeping",Vector2(355,253),&"woodcutter_wife","housekeeping"],
        ["ChildPlay",Vector2(159,204),&"woodcutter_son","play"],
        ["YardExit",Vector2(224,266),&"woodcutter_son","go_to_yard"]
    ],"MillerHouse",[[Vector2(377,80),.63,.65],[Vector2(194,25),.12,.4,Color(.72,.76,.8)]])
    make_room("old_man","Дом старика",Rect2(320,192,352,288),Color(.59,.60,.56),[
        ["OldBed","bed",46,140,Vector2(32,52),.8],
        ["OldStove","fireplace",292,118,Vector2(55,35)],
        ["Armchair","armchair",237,156,Vector2(36,22),.85],
        ["SideTable","table_small",146,184,Vector2(30,24),.8],
        ["Pipe","pipe",152,149,Vector2.ZERO,.3],
        ["SmokingPouch","sacks",162,155,Vector2.ZERO,.15],
        ["Books","shelf_books",123,26,Vector2.ZERO,.75],
        ["OldPapers","papers",139,139,Vector2.ZERO,.25],
        ["Chest","chest",61,235,Vector2(34,20),.75],
        ["KeepsakeCloth","wall_hanging",49,31,Vector2.ZERO,.4],
        ["KeepsakeBox","crate",115,60,Vector2.ZERO,.2],
        ["Window","window",278,26,Vector2.ZERO,.55],
        ["Lamp","candle",137,147,Vector2.ZERO,.3],
        ["WornBoards","broken_boards",99,199]
    ],{"old_man":[["Отдых возле кресла",Vector2(197,158),12,"work_smoke"],["У столика с книгами",Vector2(146,144),8],["К прогулке у сосны",Vector2(176,234),.6]]},[
        ["ChairRest",Vector2(197,158),&"old_man","sit_or_rest",&"right"],
        ["Reading",Vector2(146,144),&"old_man","read"],
        ["PineWalkExit",Vector2(176,234),&"old_man","go_to_crooked_pine"]
    ],"CarpenterHouse",[[Vector2(292,86),.47,.55],[Vector2(137,141),.17,.35]])
    make_room("storehouse","Общий склад припасов",Rect2(288,160,416,320),Color(.57,.60,.57),[
        ["ShelfA","shelf_cups",75,40,Vector2(76,20),.75],
        ["ShelfB","shelf_cups",210,40,Vector2(76,20),.75],
        ["ShelfC","shelf_cups",342,40,Vector2(76,20),.75],
        ["GrainA","grain_sack",50,120,Vector2(30,20),.65],
        ["GrainB","grain_sack",98,120,Vector2(30,20),.65],
        ["GrainC","grain_sack",50,176,Vector2(30,20),.65],
        ["GrainD","sacks",346,132,Vector2(38,20),.65],
        ["GrainE","grain_sack",346,188,Vector2(30,20),.65],
        ["BarrelA","barrel",40,235,Vector2(30,24),.85],
        ["BarrelB","barrel",93,235,Vector2(30,24),.85],
        ["BasketA","basket",278,113,Vector2(30,20),.65],
        ["BasketB","basket",347,286,Vector2(30,20),.65],
        ["CrateA","crate",205,178,Vector2(38,24),.8],
        ["CrateB","crate",205,142,Vector2(38,24),.8],
        ["CrateC","crate",346,237,Vector2(38,24),.8],
        ["Firewood","wood_store",65,296,Vector2(60,26),.55],
        ["Ropes","rope_block",385,276,Vector2.ZERO,.45],
        ["Tools","tool_rack",30,78,Vector2.ZERO,.4],
        ["Shovel","shovel",390,95,Vector2.ZERO,.45],
        ["WorkTable","desk",145,268,Vector2(54,24),.85],
        ["Utensils","hanging_pots",144,219,Vector2.ZERO,.45],
        ["WindowA","window",125,24,Vector2.ZERO,.6],
        ["WindowB","window",285,24,Vector2.ZERO,.6],
        ["Lantern","lantern",259,35,Vector2.ZERO,.7]
    ],{},[
        ["BackAisle",Vector2(265,76),&"","access"],
        ["RightAisle",Vector2(282,212),&"","access"],
        ["LeftAisle",Vector2(145,184),&"","access"],
        ["WorkAccess",Vector2(190,273),&"","workbench_access"]
    ],"CommonHouse",[[Vector2(259,36),.3,.5],[Vector2(125,25),.18,.4,Color(.68,.76,.82)],[Vector2(285,25),.18,.4,Color(.68,.76,.82)]])
    var registry_path:="res://data/interiors/registry.json"
    var registry:Array=JSON.parse_string(FileAccess.get_file_as_string(registry_path))
    for id in ["woodcutter","old_man","storehouse"]:
        var path:String="res://data/interiors/"+id+".tres"
        if not registry.has(path):registry.append(path)
    var file:=FileAccess.open(registry_path,FileAccess.WRITE)
    file.store_string(JSON.stringify(registry,"  ")+"\n");file.close();quit()
