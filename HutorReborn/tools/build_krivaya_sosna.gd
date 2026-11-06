extends SceneTree
## Authoring utility. Packs a fully editable native map, not a runtime generator.
const BASE := "res://assets/environment/krivaya_sosna/"
const SCENES := "res://scenes/objects/krivaya_sosna/"
const SIZE := Vector2i(2624, 2176)
const POSITION_FACTOR := Vector2(2624.0/1856.0, 2176.0/1536.0)
var world: Node2D
var actors: Node2D
var structures: Node2D
var nature: Node2D
var props: Node2D
var foreground: Node2D
var lighting: Node2D
var ground_props: Node2D
var count := 0
var rng := RandomNumberGenerator.new()
var wind: ShaderMaterial
var assets: Dictionary
var solid_rects: Array[Rect2] = []
var roads: Array = []
var layout: Dictionary
var surfaces: Dictionary

func _initialize() -> void:
    rng.seed = 20261106
    assets = JSON.parse_string(FileAccess.get_file_as_string(BASE+"extraction.json"))
    layout=JSON.parse_string(FileAccess.get_file_as_string(BASE+"expanded_layout.json"))
    surfaces=JSON.parse_string(FileAccess.get_file_as_string(BASE+"surfaces/manifest.json"))
    if "--rebuild-objects" in OS.get_cmdline_user_args():
        object_scenes()
    build()
    print("BUILT Krivaya Sosna: ",count," original-asset objects; ",SIZE)
    quit()

func own(node: Node, parent: Node) -> void:
    parent.add_child(node)
    node.owner = world

func save_scene(node: Node, path: String) -> void:
    var packed := PackedScene.new()
    assert(packed.pack(node)==OK)
    assert(ResourceSaver.save(packed,path)==OK)

func object_scenes() -> void:
    var shapes := {
        "elder_house": [Vector2(231,88),Vector2(0,-45)],
        "miller_house": [Vector2(228,88),Vector2(0,-45)],
        "carpenter_house": [Vector2(222,86),Vector2(0,-44)],
        "common_house": [Vector2(226,108),Vector2(0,-55)],
        "herbalist_house": [Vector2(242,85),Vector2(0,-44)],
        "crooked_pine": [Vector2(76,48),Vector2(0,-15)],
        "mixed_tree": [Vector2(25,24),Vector2(0,-9)],
        "pine_0": [Vector2(20,22),Vector2(0,-9)],
        "pine_1": [Vector2(20,22),Vector2(0,-9)],
        "pine_2": [Vector2(20,22),Vector2(0,-9)],
        "pine_3": [Vector2(20,22),Vector2(0,-9)],
        "fence_h": [Vector2(96,10),Vector2(0,-5)],
        "fence_broken": [Vector2(91,9),Vector2(0,-5)],
        "fence_v": [Vector2(12,80),Vector2(0,-40)],
        "gate_leaf": [Vector2(85,11),Vector2(0,-5)],
        "gate_post": [Vector2(20,15),Vector2(0,-5)],
        "well": [Vector2(57,40),Vector2(0,-23)],
        "barrel": [Vector2(28,17),Vector2(0,-9)],
        "crate": [Vector2(27,19),Vector2(0,-10)],
        "vegetable_box": [Vector2(27,18),Vector2(0,-9)],
        "cart": [Vector2(65,38),Vector2(0,-20)],
        "rock": [Vector2(32,20),Vector2(0,-10)],
        "stump": [Vector2(25,20),Vector2(0,-10)],
        "logs": [Vector2(44,23),Vector2(0,-12)],
        "wood_store": [Vector2(85,26),Vector2(0,-13)],
        "lantern": [Vector2(9,9),Vector2(0,-4)],
        "hanging_lantern": [Vector2(11,10),Vector2(-14,-5)],
        "bench": [Vector2(63,15),Vector2(0,-7)],
        "sign": [Vector2(36,14),Vector2(0,-6)],
        "scarecrow": [Vector2(11,10),Vector2(0,-5)]
    }
    for info in assets.objects:
        var key: String=info.name
        var base := Node2D.new()
        base.name=key.to_pascal_case()
        var sprite := Sprite2D.new()
        sprite.name="Art"
        sprite.texture=load(BASE+"objects/"+key+".png")
        sprite.centered=false
        sprite.offset=-Vector2(info.pivot[0],info.pivot[1])
        sprite.scale=Vector2.ONE*float(info.scale)
        sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
        base.add_child(sprite)
        sprite.owner=base
        if key.begins_with("pine_") or key in ["grass","flowers","shrub"]:
            var mat := ShaderMaterial.new()
            mat.shader=load("res://shaders/vegetation.gdshader")
            mat.set_shader_parameter("strength",0.6 if key.begins_with("pine_") else 1.0)
            mat.set_shader_parameter("speed",0.7)
            sprite.material=mat
            sprite.add_to_group("wind_plants",true)
        if shapes.has(key):
            var body := StaticBody2D.new()
            body.name="Solid"
            body.collision_layer=1
            body.collision_mask=2
            base.add_child(body)
            body.owner=base
            var collision := CollisionShape2D.new()
            collision.name="Footprint"
            var rectangle := RectangleShape2D.new()
            rectangle.size=shapes[key][0]
            collision.shape=rectangle
            collision.position=shapes[key][1]
            body.add_child(collision)
            collision.owner=base
        save_scene(base,SCENES+key+".tscn")
        base.free()

func group(name: String, parent: Node2D, sort: bool = false) -> Node2D:
    var item := Node2D.new()
    item.name=name
    item.y_sort_enabled=sort
    own(item,parent)
    return item

func world_pos(point: Vector2) -> Vector2:
    return (point*POSITION_FACTOR).round()

func object(key: String, pos: Vector2, parent: Node2D, tag: String = "", native_position: bool = false) -> Node2D:
    var item := load(SCENES+key+".tscn").instantiate() as Node2D
    item.name=tag if tag!="" else key.to_pascal_case()+str(count)
    item.position=world_pos(pos) if not native_position and parent in [structures,nature,props,foreground,ground_props] else pos
    own(item,parent)
    if key=="garden":
        item.get_node("Art").texture=load(BASE+"surfaces/garden_blended.png")
    if item.has_node("Solid/Footprint"):
        var collision: CollisionShape2D=item.get_node("Solid/Footprint")
        var shape: RectangleShape2D=collision.shape
        solid_rects.append(Rect2(item.position+collision.position-shape.size/2,shape.size))
    count+=1
    return item

func inspect(item: Node2D, title: String, description: String, point := Vector2(0,15)) -> void:
    var interaction := load("res://scenes/objects/interaction_point.tscn").instantiate() as Marker2D
    interaction.title=title
    interaction.description=description
    interaction.position=point
    own(interaction,item)

func light(parent: Node2D, pos: Vector2, radius: float, energy_value: float) -> void:
    var glow := PointLight2D.new()
    glow.name="WarmLight"+str(parent.get_child_count())
    glow.texture=load("res://assets/environment/light.png")
    glow.texture_scale=radius
    glow.position=pos
    glow.color=Color("ffc77d")
    glow.energy=energy_value
    glow.set_script(load("res://scripts/components/warm_light.gd"))
    glow.base_energy=energy_value
    glow.flicker=0.025
    own(glow,parent)

func smoke(parent: Node2D, pos: Vector2) -> void:
    var item := CPUParticles2D.new()
    item.name="ChimneySmoke"+str(parent.get_child_count())
    item.position=pos
    item.amount=11
    item.lifetime=5.0
    item.preprocess=3.0
    item.texture=load("res://assets/environment/smoke.png")
    item.direction=Vector2(0.3,-1)
    item.spread=17.0
    item.gravity=Vector2(1,-1)
    item.initial_velocity_min=7.0
    item.initial_velocity_max=11.0
    item.scale_amount_min=0.9
    item.scale_amount_max=1.6
    var curve := Curve.new()
    curve.add_point(Vector2(0,0.5))
    curve.add_point(Vector2(1,2.2))
    item.scale_amount_curve=curve
    var gradient := Gradient.new()
    gradient.set_color(0,Color(0.85,0.84,0.76,0.8))
    gradient.set_color(1,Color(0.85,0.84,0.76,0))
    item.color_ramp=gradient
    item.z_index=2
    item.add_to_group("ambient_particles",true)
    own(item,parent)

func path_distance(point: Vector2) -> float:
    var distance := INF
    for points in roads:
        for i in range(points.size()-1):
            distance=minf(distance,point.distance_to(Geometry2D.get_closest_point_to_segment(point,points[i],points[i+1])))
    return distance

func terrain() -> void:
    for road in layout.roads:
        var points:Array=[]
        for point in road.points:points.append(Vector2(point[0],point[1]))
        roads.append(points)
    var tiles:=TileSet.new()
    tiles.tile_size=Vector2i(32,32)
    for index in range(2):
        tiles.add_terrain_set()
        tiles.set_terrain_set_mode(index,TileSet.TERRAIN_MODE_MATCH_SIDES)
        tiles.add_terrain(index)
        tiles.set_terrain_name(index,0,"Тропы" if index==0 else "Влажная земля")
        tiles.set_terrain_color(index,0,Color("997445") if index==0 else Color("57412d"))
    var grass:=TileSetAtlasSource.new()
    grass.texture=load(BASE+"surfaces/grass.png")
    grass.texture_region_size=Vector2i(32,32)
    for y in range(16):
        for x in range(16):grass.create_tile(Vector2i(x,y))
    tiles.add_source(grass,0)
    var overlay:=TileSetAtlasSource.new()
    overlay.texture=load(BASE+"surfaces/world_overlay.png")
    overlay.texture_region_size=Vector2i(32,32)
    for point in surfaces.active_cells:
        var y:int=point[0]
        var x:int=point[1]
        var coord:=Vector2i(x,y)
        overlay.create_tile(coord)
        var kind:int=surfaces.cell_kinds[y][x]
        if kind<0:continue
        var data:=overlay.get_tile_data(coord,0)
        data.terrain_set=kind
        data.terrain=0
        # Authored cells keep their world phase; native painting chooses reusable brushes.
        data.probability=0.0
        var neighbors: Array = [[Vector2i.UP,TileSet.CELL_NEIGHBOR_TOP_SIDE],[Vector2i.RIGHT,TileSet.CELL_NEIGHBOR_RIGHT_SIDE],[Vector2i.DOWN,TileSet.CELL_NEIGHBOR_BOTTOM_SIDE],[Vector2i.LEFT,TileSet.CELL_NEIGHBOR_LEFT_SIDE]]
        for pair in neighbors:
            var sample:Vector2i=coord+pair[0]
            var same:=sample.x>=0 and sample.y>=0 and sample.x<SIZE.x/32 and sample.y<SIZE.y/32 and int(surfaces.cell_kinds[sample.y][sample.x])==kind
            data.set_terrain_peering_bit(pair[1],0 if same else -1)
    tiles.add_source(overlay,1)
    var brushes:=TileSetAtlasSource.new()
    brushes.texture=load(BASE+"surfaces/terrain_brushes.png")
    brushes.texture_region_size=Vector2i(32,32)
    for row in range(2):
        for mask in range(16):
            var coord:=Vector2i(mask,row)
            brushes.create_tile(coord)
            var data:=brushes.get_tile_data(coord,0)
            data.terrain_set=row
            data.terrain=0
            var bits:Array=[[1,TileSet.CELL_NEIGHBOR_TOP_SIDE],[2,TileSet.CELL_NEIGHBOR_RIGHT_SIDE],[4,TileSet.CELL_NEIGHBOR_BOTTOM_SIDE],[8,TileSet.CELL_NEIGHBOR_LEFT_SIDE]]
            for pair in bits:data.set_terrain_peering_bit(pair[1],0 if mask&pair[0] else -1)
    tiles.add_source(brushes,2)
    assert(ResourceSaver.save(tiles,BASE+"surfaces/expanded_surfaces.tres",ResourceSaver.FLAG_CHANGE_PATH)==OK)
    var ground:=TileMapLayer.new()
    ground.name="Ground"
    ground.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
    ground.tile_set=tiles
    own(ground,world)
    var detail:=TileMapLayer.new()
    detail.name="Ground Details"
    detail.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
    detail.tile_set=tiles
    own(detail,world)
    for y in range(SIZE.y/32):
        for x in range(SIZE.x/32):
            ground.set_cell(Vector2i(x,y),0,Vector2i(x%16,y%16))
    for point in surfaces.active_cells:
        var coord:=Vector2i(point[1],point[0])
        detail.set_cell(coord,1,coord)

func yard(x0: float, x1: float, y_back: float, y_front: float, entry: float) -> void:
    for x in range(int(x0)+48,int(x1),96):
        object("fence_h",Vector2(x,y_back),props,"",true)
        if absf(x-entry)>72:object("fence_h",Vector2(x,y_front),props,"",true)
    for y in range(int(y_back)+80,int(y_front)+1,80):
        object("fence_v",Vector2(x0,y),props,"",true)
        object("fence_v",Vector2(x1,y),props,"",true)
    if (int(y_front)-int(y_back))%80!=0:
        object("fence_v",Vector2(x0,y_front),props,"",true)
        object("fence_v",Vector2(x1,y_front),props,"",true)

func build() -> void:
    world=Node2D.new()
    world.name="KrivayaSosna"
    world.set_script(load("res://scripts/krivaya_sosna.gd"))
    terrain()
    ground_props=group("Ground Objects",world)
    actors=group("Actors",world,true)
    structures=group("Structures",actors,true)
    nature=group("Nature",actors,true)
    props=group("Props",actors,true)
    foreground=group("Foreground",world,true)
    lighting=group("Lighting",world)
    var elder:=object("elder_house",Vector2(645,500),structures,"ElderHouse")
    var miller:=object("miller_house",Vector2(1195,500),structures,"MillerHouse")
    var common:=object("common_house",Vector2(910,820),structures,"CommonHouse")
    var carpenter:=object("carpenter_house",Vector2(590,1120),structures,"CarpenterHouse")
    var herbalist:=object("herbalist_house",Vector2(1230,1120),structures,"HerbalistHouse")
    inspect(elder,"Дом старшего","Самый крепкий сруб в хуторе. На косяке — старый обережный знак. За окнами теплится огонь.",Vector2(24,15))
    inspect(miller,"Дом мельника","У стены стоят мешки и бочки. Пахнет зерном и сырым деревом.",Vector2(24,15))
    inspect(common,"Общий дом","Кухня и склад для всего хутора. У порога сложены припасы; из трубы тянется спокойный дым.",Vector2(0,15))
    inspect(carpenter,"Дом плотника","В стружке лежат обрезки брёвен. На лавке оставлен инструмент; работа затихла к вечеру.",Vector2(24,15))
    inspect(herbalist,"Дом знахарки","Под навесом сохнут травы. Из огорода тянет горьким запахом полыни.",Vector2(-22,15))
    # Lit glazing is another original cropped element, attached to the house scene instance.
    var window_points:Dictionary={"ElderHouse":Vector2(-43,-74),"MillerHouse":Vector2(-54,-71),"CarpenterHouse":Vector2(-51,-68)}
    for house in [elder,miller,carpenter]:
        object("warm_window",window_points[String(house.name)],house)
    object("warm_window",Vector2(-81,-85),common)
    object("warm_window",Vector2(44,-85),common)
    object("warm_window",Vector2(26,-57),herbalist)
    for house in [elder,miller,carpenter]:
        light(house,window_points[String(house.name)],1.3,0.62)
        light(house,Vector2(28,-22),1.3,0.45)
        var chimney_offsets:Dictionary={"ElderHouse":Vector2(-12,-226),"MillerHouse":Vector2(39,-226),"CarpenterHouse":Vector2(40,-225)}
        smoke(house,chimney_offsets[String(house.name)])
    light(common,Vector2(-81,-85),1.55,0.65)
    light(common,Vector2(44,-85),1.35,0.48)
    light(common,Vector2(1,-22),1.6,0.45)
    smoke(common,Vector2(-30,-288))
    light(herbalist,Vector2(26,-57),1.3,0.58)
    smoke(herbalist,Vector2(-15,-212))
    var pine:=object("crooked_pine",Vector2(343,625),nature,"CrookedPine")
    inspect(pine,"Кривая Сосна","Старая сосна склонилась над хутором. Говорят, она помнит всё, что здесь происходило.",Vector2(75,22))
    var well:=object("well",Vector2(910,1100),props,"VillageWell")
    inspect(well,"Старый колодец","Сырой камень холодит ладонь. Из глубины доносится тихий плеск. Здесь сходятся тропинки пяти дворов.")
    for field in layout.yards:yard(field[0],field[1],field[2],field[3],field[4])
    for point in layout.gardens:
        var center:=Vector2(point[0],point[1])
        object("garden",center,ground_props,"",true)
        object("fence_h",center+Vector2(0,-112),props,"",true)
        object("fence_h",center+Vector2(0,8),props,"",true)
        object("fence_v",center+Vector2(-65,-24),props,"",true)
    object("scarecrow",Vector2(1310,992),props)
    object("shrub",Vector2(1320,1085),nature)
    # Rebuild longer fences with unchanged segment sizes and native-width openings.
    var gate_pos:=world_pos(Vector2(910,1280))
    var north_x:=1387.0
    for x in range(int(world_pos(Vector2(284,0)).x),int(world_pos(Vector2(1510,0)).x),96):
        if absf(x-gate_pos.x)>110:object("fence_h",Vector2(x,gate_pos.y),props,"",true)
        if absf(x-north_x)>85:object("fence_broken",Vector2(x,world_pos(Vector2(0,320)).y),props,"",true)
    for y in range(int(world_pos(Vector2(0,320)).y)+80,int(gate_pos.y)+1,80):
        if absf((y-40)-1417)>90:object("fence_v",Vector2(336,y),props,"",true)
        if absf((y-40)-1225)>90:object("fence_v",Vector2(2191,y),props,"",true)
    var gate:=group("MainGate",structures)
    gate.position=gate_pos
    var post_left:=object("gate_post",gate_pos+Vector2(-72,0),props,"GatePostLeft",true)
    var post_right:=object("gate_post",gate_pos+Vector2(72,0),props,"GatePostRight",true)
    object("gate_leaf",gate_pos+Vector2(-125,-2),props,"",true)
    var right_leaf:=object("gate_leaf",gate_pos+Vector2(124,-2),props,"",true)
    right_leaf.get_node("Art").flip_h=true
    var beam:=object("gate_beam",gate_pos+Vector2(0,-84),foreground,"GateLintel",true)
    beam.z_index=3
    var sign:=Label.new()
    sign.name="VillageName"
    sign.text="КРИВАЯ СОСНА"
    sign.position=gate_pos+Vector2(-61,-93)
    sign.add_theme_font_override("font",load("res://assets/fonts/DejaVuSerif.ttf"))
    sign.add_theme_font_size_override("font_size",11)
    sign.add_theme_color_override("font_color",Color("debf83"))
    sign.z_index=4
    own(sign,foreground)
    inspect(gate,"Ворота хутора","Кривая Сосна. Пять домов, общий колодец и лес за оградой. Ворота открыты.",Vector2(0,18))
    light(post_left,Vector2(0,-48),1.6,0.6)
    light(post_right,Vector2(0,-48),1.6,0.6)
    for pos in [Vector2(501,562),Vector2(1325,558),Vector2(815,890),Vector2(690,1163),Vector2(1364,1158)]:
        var lamp:=object("hanging_lantern",pos,props)
        light(lamp,Vector2(1,-40),1.9,0.72)
    var decor := [
        ["wood_store",Vector2(443,1093)],["logs",Vector2(496,1147)],
        ["cart",Vector2(407,1171)],["stump",Vector2(752,1129)],
        ["barrel",Vector2(786,516)],["crate",Vector2(785,550)],
        ["barrel",Vector2(1046,519)],["barrel",Vector2(1073,523)],
        ["cart",Vector2(1366,527)],["crate",Vector2(1053,827)],
        ["vegetable_box",Vector2(1046,866)],["barrel",Vector2(775,855)],
        ["bench",Vector2(965,909)],["bench",Vector2(760,577)],
        ["sign",Vector2(444,711)],["rock",Vector2(359,808)],
        ["rock",Vector2(1429,826)],["logs",Vector2(1483,1028)],
        ["pumpkins",Vector2(1341,1156)],["vegetable_box",Vector2(1314,1161)]
    ]
    for info in decor:
        if info[0]=="cart" and info[1]==Vector2(407,1171):object("cart",Vector2(660,1650),props,"",true)
        elif info[0]=="cart" and info[1]==Vector2(1366,527):object("cart",Vector2(2055,780),props,"",true)
        elif info[0]=="barrel" and info[1]==Vector2(786,516):object("barrel",Vector2(760,810),props,"",true)
        elif info[0]=="crate" and info[1]==Vector2(785,550):object("crate",Vector2(800,850),props,"",true)
        elif info[0]=="barrel" and info[1]==Vector2(1046,519):object("barrel",Vector2(1530,800),props,"",true)
        elif info[0]=="barrel" and info[1]==Vector2(1073,523):object("barrel",Vector2(1570,800),props,"",true)
        elif info[0]=="stump":object("stump",Vector2(1000,1700),props,"",true)
        else:object(info[0],info[1],props)
    # Forest assets are source fir crops; extra crooked-tree angles form mixed growth.
    for y in range(130,SIZE.y-56,75):
        for x in range(80,SIZE.x-56,70):
            var pos:=Vector2(x+rng.randi_range(-22,22),y+rng.randi_range(-20,20))
            if Rect2(world_pos(Vector2(230,320)),Vector2(1340,1020)*POSITION_FACTOR).has_point(pos) or path_distance(pos)<112:continue
            var clearing:=false
            for point in layout.exploration_points:
                if pos.distance_to(Vector2(point.position[0],point.position[1]))<140:clearing=true
            if clearing:continue
            if rng.randf()<0.18:continue
            object("mixed_tree" if rng.randf()<0.18 else "pine_"+str(rng.randi_range(0,3)),pos,nature,"",true)
    for pos in [Vector2(280,835),Vector2(1466,722),Vector2(1459,1031),Vector2(420,962),Vector2(1378,1280)]:
        if path_distance(world_pos(pos))>92:
            object("mixed_tree" if rng.randf()<0.18 else "pine_"+str(rng.randi_range(0,3)),pos,nature)
    for i in range(470):
        var pos:=Vector2(rng.randf_range(100,SIZE.x-100),rng.randf_range(320,SIZE.y-66))
        if path_distance(pos)<55 or ((pos-Vector2(1320,1435))/Vector2(220,105)).length()<1.1:continue
        var occupied:=false
        for box in solid_rects:
            if box.grow(20).has_point(pos):occupied=true;break
        if occupied:continue
        object("grass" if i%4 else "flowers",pos,nature,"",true)
    for pos in [Vector2(320,716),Vector2(388,837),Vector2(795,671),Vector2(1384,690),Vector2(1424,944),Vector2(380,1241)]:
        object("shrub",pos,nature)
    var exploration:=group("Exploration",world)
    for point in layout.exploration_points:
        var marker:=Marker2D.new()
        marker.name=point.name
        marker.position=Vector2(point.position[0],point.position[1])
        own(marker,exploration)
    var hans:=load("res://scenes/player/hans.tscn").instantiate() as CharacterBody2D
    hans.name="Hans"
    hans.position=world_pos(Vector2(975,1018))
    own(hans,actors)
    var bounds:=StaticBody2D.new()
    bounds.name="MapBounds"
    bounds.collision_mask=2
    own(bounds,world)
    for box in [Rect2(-32,-32,SIZE.x+64,32),Rect2(-32,SIZE.y,SIZE.x+64,32),Rect2(-32,0,32,SIZE.y),Rect2(SIZE.x,0,32,SIZE.y)]:
        var collision:=CollisionShape2D.new()
        var shape:=RectangleShape2D.new()
        shape.size=box.size
        collision.shape=shape
        collision.position=box.get_center()
        own(collision,bounds)
    var evening:=CanvasModulate.new()
    evening.name="Evening"
    evening.color=Color(0.87,0.89,0.92,1)
    own(evening,lighting)
    var atmosphere:=Node2D.new()
    atmosphere.name="Atmosphere"
    atmosphere.set_script(load("res://scripts/atmosphere.gd"))
    own(atmosphere,world)
    var screen:=CanvasLayer.new()
    screen.name="Screen"
    screen.layer=4
    own(screen,atmosphere)
    var fog:=ColorRect.new()
    fog.name="Fog"
    fog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    fog.mouse_filter=Control.MOUSE_FILTER_IGNORE
    var material:=ShaderMaterial.new()
    material.shader=load("res://shaders/atmosphere.gdshader")
    material.set_shader_parameter("fog_strength",0.045)
    fog.material=material
    own(fog,screen)
    var hud:=CanvasLayer.new()
    hud.name="HUD"
    hud.layer=10
    hud.set_script(load("res://scripts/ui/hud.gd"))
    hud.location_title="Кривая Сосна"
    hud.location_subtitle="Пять домов. Общий колодец. Лес за оградой."
    hud.chapter_label="II  ·  КРИВАЯ СОСНА"
    hud.pause_caption="Кривая Сосна · стартовая локация"
    own(hud,world)
    save_scene(world,"res://scenes/world/krivaya_sosna/krivaya_sosna.tscn")
    world.free()
