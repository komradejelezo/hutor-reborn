extends SceneTree
## Authoring utility. Packs a fully editable native map, not a runtime generator.
const BASE := "res://assets/environment/krivaya_sosna/"
const SCENES := "res://scenes/objects/krivaya_sosna/"
const SIZE := Vector2i(1856, 1536)
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

func _initialize() -> void:
    rng.seed = 20261106
    assets = JSON.parse_string(FileAccess.get_file_as_string(BASE+"extraction.json"))
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

func object(key: String, pos: Vector2, parent: Node2D, tag: String = "") -> Node2D:
    var item := load(SCENES+key+".tscn").instantiate() as Node2D
    item.name=tag if tag!="" else key.to_pascal_case()+str(count)
    item.position=pos
    own(item,parent)
    if item.has_node("Solid/Footprint"):
        var collision: CollisionShape2D=item.get_node("Solid/Footprint")
        var shape: RectangleShape2D=collision.shape
        solid_rects.append(Rect2(pos+collision.position-shape.size/2,shape.size))
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
    roads=[
        [Vector2(910,1580),Vector2(910,1250),Vector2(990,1110),Vector2(1000,950),Vector2(1080,815),Vector2(990,640),Vector2(980,500),Vector2(980,250)],
        [Vector2(645,500),Vector2(675,579),Vector2(820,615),Vector2(990,640),Vector2(1195,581),Vector2(1195,500)],
        [Vector2(910,820),Vector2(925,880),Vector2(1000,950),Vector2(1260,922),Vector2(1550,865)],
        [Vector2(590,1120),Vector2(660,1190),Vector2(910,1200),Vector2(1230,1190),Vector2(1230,1120)],
        [Vector2(910,1100),Vector2(1000,1080)],
        [Vector2(350,625),Vector2(460,670),Vector2(610,640),Vector2(820,615)],
        [Vector2(620,660),Vector2(580,815),Vector2(650,965),Vector2(660,1190)]
    ]
    var tiles := TileSet.new()
    tiles.tile_size=Vector2i(32,32)
    var source := TileSetAtlasSource.new()
    source.texture=load(BASE+"terrain.png")
    source.texture_region_size=Vector2i(32,32)
    for y in range(6):
        for x in range(16):source.create_tile(Vector2i(x,y))
    tiles.add_source(source,0)
    var edge := TileSetAtlasSource.new()
    edge.texture=load(BASE+"path_edges.png")
    edge.texture_region_size=Vector2i(32,32)
    for y in range(8):
        for x in range(16):edge.create_tile(Vector2i(x,y))
    tiles.add_source(edge,1)
    ResourceSaver.save(tiles,BASE+"krivaya_sosna.tres")
    var ground := TileMapLayer.new()
    ground.name="Ground"
    ground.tile_set=tiles
    own(ground,world)
    var detail := TileMapLayer.new()
    detail.name="Ground Details"
    detail.tile_set=tiles
    own(detail,world)
    var paths: Dictionary={}
    for y in range(48):
        for x in range(58):
            var cell:=Vector2i(x,y)
            var point:=Vector2(x*32+16,y*32+16)
            var variant:=(x%4)+(y%4)*4
            ground.set_cell(cell,0,Vector2i(variant,0))
            if path_distance(point)<45:paths[cell]=true
            elif rng.randf()<0.09:
                detail.set_cell(cell,0,Vector2i(rng.randi_range(0,15),4))
    for cell in paths:
        var mask:=0
        for pair in [[Vector2i.UP,1],[Vector2i.RIGHT,2],[Vector2i.DOWN,4],[Vector2i.LEFT,8]]:
            if paths.has(cell+pair[0]):mask |= pair[1]
        var index:int=mask*8+(cell.x%4)+(cell.y%2)*4
        detail.set_cell(cell,1,Vector2i(index%16,index/16))
    for cell in [Vector2i(28,38),Vector2i(31,30),Vector2i(25,19),Vector2i(38,36),Vector2i(20,24),Vector2i(17,35)]:
        detail.set_cell(cell,0,Vector2i(2,5))
        detail.set_cell(cell+Vector2i.RIGHT,0,Vector2i(3,5))

func yard(x0: float, x1: float, y_back: float, y_front: float, entry: float) -> void:
    for x in range(int(x0)+48,int(x1),96):
        object("fence_h",Vector2(x,y_back),props)
        if absf(x-entry)>72:object("fence_h",Vector2(x,y_front),props)
    for y in range(int(y_back)+80,int(y_front)+1,80):
        object("fence_v",Vector2(x0,y),props)
        object("fence_v",Vector2(x1,y),props)

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
    yard(480,810,414,583,669)
    yard(1025,1360,414,583,1219)
    yard(755,1065,727,901,910)
    yard(425,755,1035,1196,614)
    yard(1065,1410,1035,1196,1208)
    # Fenced vegetable beds have an actual passable opening on the east side.
    for center in [Vector2(1140,1000),Vector2(690,1010)]:
        object("garden",center,ground_props)
        object("fence_h",center+Vector2(0,-112),props)
        object("fence_h",center+Vector2(0,8),props)
        object("fence_v",center+Vector2(-65,-24),props)
    object("scarecrow",Vector2(1310,992),props)
    object("shrub",Vector2(1320,1085),nature)
    # Settlement perimeter, with a 144 px wide entrance. No closed door blocks entry.
    for x in range(284,1510,96):
        object("fence_h",Vector2(x,1280),props) if absf(x-910)>110 else null
        object("fence_broken",Vector2(x,320),props) if absf(x-980)>85 else null
    for y in range(400,1281,80):
        object("fence_v",Vector2(238,y),props)
        object("fence_v",Vector2(1550,y),props)
    var gate:=group("MainGate",structures)
    gate.position=Vector2(910,1280)
    var post_left:=object("gate_post",Vector2(838,1280),props,"GatePostLeft")
    var post_right:=object("gate_post",Vector2(982,1280),props,"GatePostRight")
    object("gate_leaf",Vector2(785,1278),props)
    var right_leaf:=object("gate_leaf",Vector2(1034,1278),props)
    right_leaf.get_node("Art").flip_h=true
    var beam:=object("gate_beam",Vector2(910,1196),foreground,"GateLintel")
    beam.z_index=3
    var sign:=Label.new()
    sign.name="VillageName"
    sign.text="КРИВАЯ СОСНА"
    sign.position=Vector2(849,1187)
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
    for info in decor:object(info[0],info[1],props)
    # Forest assets are source fir crops; extra crooked-tree angles form mixed growth.
    for y in range(130,1480,75):
        for x in range(80,1800,70):
            var pos:=Vector2(x+rng.randi_range(-22,22),y+rng.randi_range(-20,20))
            if Rect2(230,320,1340,1020).has_point(pos) or path_distance(pos)<92:continue
            if rng.randf()<0.18:continue
            object("mixed_tree" if rng.randf()<0.18 else "pine_"+str(rng.randi_range(0,3)),pos,nature)
    for pos in [Vector2(280,835),Vector2(1466,722),Vector2(1459,1031),Vector2(420,962),Vector2(1378,1280)]:
        object("mixed_tree" if rng.randf()<0.18 else "pine_"+str(rng.randi_range(0,3)),pos,nature)
    for i in range(235):
        var pos:=Vector2(rng.randf_range(100,1750),rng.randf_range(320,1470))
        if path_distance(pos)<51:continue
        var occupied:=false
        for box in solid_rects:
            if box.grow(20).has_point(pos):occupied=true;break
        if occupied:continue
        object("grass" if i%4 else "flowers",pos,nature)
    for pos in [Vector2(320,716),Vector2(388,837),Vector2(795,671),Vector2(1384,690),Vector2(1424,944),Vector2(380,1241)]:
        object("shrub",pos,nature)
    var hans:=load("res://scenes/player/hans.tscn").instantiate() as CharacterBody2D
    hans.name="Hans"
    hans.position=Vector2(975,1018)
    own(hans,actors)
    var bounds:=StaticBody2D.new()
    bounds.name="MapBounds"
    bounds.collision_mask=2
    own(bounds,world)
    for box in [Rect2(-32,-32,1920,32),Rect2(-32,1536,1920,32),Rect2(-32,0,32,1536),Rect2(1856,0,32,1536)]:
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
