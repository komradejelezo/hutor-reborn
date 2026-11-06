extends SceneTree
## Offline authoring utility. Produces editable native scenes, never runs in the game.
const OUT = "res://scenes/world/outskirts.tscn"
var rng := RandomNumberGenerator.new()
var world_root: Node2D
var actors: Node2D
var atmosphere: Node2D
var wind: ShaderMaterial
var reserved: Array[Rect2] = []
var object_count := 0

func _initialize() -> void:
    rng.seed = 4126
    build_frames()
    build_object_scenes()
    build_world()
    print("BUILT: ", OUT, " — ", object_count, " object instances")
    quit()

func own(node: Node, parent: Node) -> void:
    parent.add_child(node)
    node.owner = world_root

func save_scene(node: Node, path: String) -> void:
    var packed := PackedScene.new()
    var error := packed.pack(node)
    assert(error == OK)
    assert(ResourceSaver.save(packed, path) == OK)

func build_frames() -> void:
    # Authored Hans frames are generated only by tools/slice_hans.py.
    # Rebuilding the map must preserve the supplied character artwork.
    assert(ResourceLoader.exists("res://assets/characters/hans_frames.tres"))
    var fire_frames := SpriteFrames.new()
    fire_frames.set_animation_speed("default", 10.0)
    for index in range(8):
        var frame := AtlasTexture.new()
        frame.atlas = load("res://assets/environment/fire.png")
        frame.region = Rect2(index*64, 0, 64, 64)
        fire_frames.add_frame("default", frame)
    ResourceSaver.save(fire_frames, "res://assets/environment/fire_frames.tres")

func build_object_scenes() -> void:
    var definitions := {
        "izba": [Vector2(200, 69), Vector2(0,-37), "Старая изба", "Из трубы тянется дым, за стеклом дрожит огонь. Дверь заперта изнутри.\nГанс: «Значит, хутор ещё не совсем опустел»."],
        "shed": [Vector2(129, 56), Vector2(0,-30), "Хозяйственный сарай", "Сквозь щели пахнет сеном и сырой древесиной. На тяжёлой двери — ржавый засов.\nВнутри что-то едва слышно поскрипывает."],
        "well": [Vector2(53, 27), Vector2(0,-14), "Старый колодец", "Верёвка влажная и холодная. Из глубины доносится тихий плеск.\nНа каменном ободе вырезан старый обережный знак."],
        "fence_h": [Vector2(66, 9), Vector2(0,-5), "", ""],
        "fence_v": [Vector2(12, 61), Vector2(0,-31), "", ""],
        "rock": [Vector2(32, 15), Vector2(0,-8), "", ""],
        "stump": [Vector2(25, 15), Vector2(0,-8), "", ""],
        "barrel": [Vector2(20, 15), Vector2(0,-8), "", ""],
        "logs": [Vector2(47, 17), Vector2(0,-8), "", ""],
        "sign": [Vector2(13, 10), Vector2(0,-5), "Дорога к хутору", "На потемневшей доске: «Хутор — по дороге. После заката в лес не сходить».\nДальше путь теряется в тумане. Здесь заканчивается первая локация."],
        "lantern": [Vector2(10, 9), Vector2(-3,-5), "", ""]
    }
    for key in definitions:
        var data: Array = definitions[key]
        var base := Node2D.new()
        base.name = key.capitalize()
        var sprite := Sprite2D.new()
        sprite.name = "Sprite2D"
        sprite.texture = load("res://assets/environment/" + key + ".png")
        sprite.position.y = -sprite.texture.get_height()*0.5
        base.add_child(sprite)
        sprite.owner = base
        var solid := StaticBody2D.new()
        solid.name = "Solid"
        solid.collision_layer = 1
        solid.collision_mask = 2
        base.add_child(solid)
        solid.owner = base
        var collision := CollisionShape2D.new()
        collision.name = "Footprint"
        var shape := RectangleShape2D.new()
        shape.size = data[0]
        collision.shape = shape
        collision.position = data[1]
        solid.add_child(collision)
        collision.owner = base
        if data[2] != "":
            var interaction := load("res://scenes/objects/interaction_point.tscn").instantiate() as Marker2D
            interaction.name = "InteractionPoint"
            interaction.title = data[2]
            interaction.description = data[3]
            interaction.position = Vector2(-14, 6) if key == "izba" else Vector2(0, 9)
            base.add_child(interaction)
            interaction.owner = base
        save_scene(base, "res://scenes/objects/"+key+".tscn")
        base.free()
    for tree in ["pine_0", "pine_1", "pine_2", "birch_0", "birch_1"]:
        var base := Node2D.new()
        base.name = "Tree"
        var sprite := Sprite2D.new()
        sprite.name = "Crown"
        sprite.texture = load("res://assets/environment/"+tree+".png")
        sprite.position.y = -sprite.texture.get_height()*0.5
        var material := ShaderMaterial.new()
        material.shader = load("res://shaders/vegetation.gdshader")
        material.set_shader_parameter("strength", 1.0)
        material.set_shader_parameter("speed", 0.9)
        sprite.material = material
        sprite.add_to_group("wind_plants", true)
        base.add_child(sprite)
        sprite.owner = base
        var solid := StaticBody2D.new()
        solid.name = "Trunk"
        solid.collision_mask = 2
        base.add_child(solid)
        solid.owner = base
        var collision := CollisionShape2D.new()
        collision.name = "Footprint"
        var shape := CircleShape2D.new()
        shape.radius = 8.0
        collision.shape = shape
        collision.position.y = -9
        solid.add_child(collision)
        collision.owner = base
        save_scene(base, "res://scenes/objects/"+tree+".tscn")
        base.free()

func instance(key: String, pos: Vector2) -> Node2D:
    var node := load("res://scenes/objects/"+key+".tscn").instantiate() as Node2D
    node.name = key.capitalize()+str(object_count)
    node.position = pos
    own(node, actors)
    object_count += 1
    return node

func decoration(key: String, pos: Vector2, parent: Node2D, moving: bool = false) -> Sprite2D:
    var sprite := Sprite2D.new()
    sprite.name = key.capitalize()+str(object_count)
    sprite.texture = load("res://assets/environment/"+key+".png")
    sprite.position = pos
    sprite.offset.y = -sprite.texture.get_height()*0.5
    if moving:
        sprite.material = wind
        sprite.add_to_group("wind_plants", true)
    own(sprite, parent)
    object_count += 1
    return sprite

func light(pos: Vector2, parent: Node2D, size: float, energy_value: float, amount: float = 0.02) -> void:
    var glow := PointLight2D.new()
    glow.name = "WarmLight"+str(parent.get_child_count())
    glow.texture = load("res://assets/environment/light.png")
    glow.texture_scale = size
    glow.position = pos
    glow.color = Color("ffd18c")
    glow.energy = energy_value
    glow.set_script(load("res://scripts/components/warm_light.gd"))
    glow.base_energy = energy_value
    glow.flicker = amount
    own(glow, parent)

func particles(pos: Vector2, parent: Node, smoke: bool) -> void:
    var item := CPUParticles2D.new()
    item.name = "ChimneySmoke" if smoke else "Embers"
    item.position = pos
    item.amount = 18 if smoke else 10
    item.lifetime = 5.5 if smoke else 2.2
    item.preprocess = 3.0
    item.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
    item.emission_sphere_radius = 2.0 if smoke else 9.0
    item.direction = Vector2(0.3,-1)
    item.spread = 17.0
    item.gravity = Vector2(2,-1)
    item.initial_velocity_min = 8.0 if smoke else 12.0
    item.initial_velocity_max = 12.0 if smoke else 22.0
    item.scale_amount_min = 0.8 if smoke else 1.0
    item.scale_amount_max = 1.8 if smoke else 1.5
    var gradient := Gradient.new()
    gradient.set_color(0, Color(0.8,0.83,0.76,0.65) if smoke else Color("ffd68c"))
    gradient.set_color(1, Color(0.7,0.76,0.7,0) if smoke else Color(0.8,0.3,0.1,0))
    item.color_ramp = gradient
    if smoke:
        item.texture = load("res://assets/environment/smoke.png")
        item.z_index = 3
        var curve := Curve.new()
        curve.add_point(Vector2(0,0.4))
        curve.add_point(Vector2(1,2.3))
        item.scale_amount_curve = curve
    else:
        item.z_index = 2
    item.add_to_group("ambient_particles", true)
    own(item, parent)

func distance_path(p: Vector2, points: Array[Vector2]) -> float:
    var best := INF
    for i in range(points.size()-1):
        best = minf(best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, points[i], points[i+1])))
    return best

func build_world() -> void:
    world_root = Node2D.new()
    world_root.name = "Outskirts"
    world_root.set_script(load("res://scripts/world.gd"))
    wind = ShaderMaterial.new()
    wind.shader = load("res://shaders/vegetation.gdshader")
    wind.set_shader_parameter("strength", 1.0)
    ResourceSaver.save(wind,"res://shaders/grass_wind.tres")
    var tiles := TileSet.new()
    tiles.tile_size = Vector2i(32,32)
    var terrain := TileSetAtlasSource.new()
    terrain.texture = load("res://assets/tilesets/terrain.png")
    terrain.texture_region_size = Vector2i(32,32)
    for y in range(7):
        for x in range(8):
            terrain.create_tile(Vector2i(x,y))
    tiles.add_source(terrain,0)
    var scatter := TileSetAtlasSource.new()
    scatter.texture = load("res://assets/tilesets/scatter.png")
    scatter.texture_region_size = Vector2i(32,32)
    for x in range(8):
        scatter.create_tile(Vector2i(x,0))
    tiles.add_source(scatter,1)
    ResourceSaver.save(tiles,"res://assets/tilesets/outskirts.tres")
    var ground := TileMapLayer.new()
    ground.name = "01_Ground"
    ground.tile_set = tiles
    own(ground,world_root)
    var paths := TileMapLayer.new()
    paths.name = "02_MudAndPaths"
    paths.tile_set = tiles
    own(paths,world_root)
    var details := TileMapLayer.new()
    details.name = "03_GroundDetails"
    details.tile_set = tiles
    own(details,world_root)
    var road: Array[Vector2] = [Vector2(610,1210),Vector2(635,1000),Vector2(710,810),Vector2(700,650),Vector2(795,560),Vector2(1020,710),Vector2(1260,765),Vector2(1570,710)]
    var house_path: Array[Vector2] = [Vector2(525,490),Vector2(555,570),Vector2(700,650)]
    var shed_path: Array[Vector2] = [Vector2(940,460),Vector2(875,545),Vector2(795,560)]
    var dirt: Dictionary = {}
    for y in range(36):
        for x in range(48):
            var cell := Vector2i(x,y)
            var p := Vector2(x*32+16,y*32+16)
            ground.set_cell(cell,0,Vector2i(rng.randi_range(0,7),0))
            if distance_path(p,road)<37 or distance_path(p,house_path)<25 or distance_path(p,shed_path)<21:
                dirt[cell] = true
            elif Rect2(845,500,183,150).has_point(p):
                paths.set_cell(cell,0,Vector2i(rng.randi_range(0,7),3))
            elif p.distance_to(Vector2(290,780)) < 120:
                paths.set_cell(cell,0,Vector2i(rng.randi_range(0,7),2))
            if rng.randf()<0.52:
                details.set_cell(cell,1,Vector2i(rng.randi_range(0,7),0))
    for cell in dirt:
        var mask := 0
        for pair in [[Vector2i.UP,1],[Vector2i.RIGHT,2],[Vector2i.DOWN,4],[Vector2i.LEFT,8]]:
            if dirt.has(cell+pair[0]): mask |= pair[1]
        paths.set_cell(cell,0,Vector2i(mask%8,5+mask/8))
        details.erase_cell(cell)
    var ground_props := Node2D.new()
    ground_props.name = "04_GroundProps"
    own(ground_props,world_root)
    actors = Node2D.new()
    actors.name = "Actors"
    actors.y_sort_enabled = true
    own(actors,world_root)
    var house := instance("izba",Vector2(540,490))
    var shed := instance("shed",Vector2(943,457))
    instance("well",Vector2(740,578))
    instance("sign",Vector2(1200,740))
    light(Vector2(-64,-73),house,1.1,0.8)
    light(Vector2(65,-61),house,1.0,0.6)
    light(Vector2(-13,5),house,1.4,0.48)
    for x in range(862,1024,64):
        instance("fence_h",Vector2(x,494))
        instance("fence_h",Vector2(x,661))
    for y in [539,600,651]:
        instance("fence_v",Vector2(833,y))
        if y!=600:instance("fence_v",Vector2(1040,y))
    for y in range(518,643,24):
        for x in range(859,1020,27):
            decoration("crop",Vector2(x+rng.randi_range(-2,2),y),actors,true)
    for pos in [Vector2(399,484),Vector2(433,503),Vector2(1007,461)]:
        instance("barrel",pos)
    instance("logs",Vector2(689,486))
    instance("stump",Vector2(390,703))
    instance("rock",Vector2(801,738))
    instance("rock",Vector2(1107,607))
    instance("rock",Vector2(465,826))
    for pos in [Vector2(497,553),Vector2(1003,698),Vector2(696,908)]:
        var lamp := instance("lantern",pos)
        light(Vector2(10,-57),lamp,2.6,0.84,0.05)
    var fire := Node2D.new()
    fire.name = "Campfire"
    fire.position = Vector2(558,670)
    own(fire,actors)
    var animation := AnimatedSprite2D.new()
    animation.name = "Flames"
    animation.sprite_frames = load("res://assets/environment/fire_frames.tres")
    animation.position.y = -32
    animation.autoplay = "default"
    own(animation,fire)
    var solid := StaticBody2D.new()
    solid.name = "StoneRing"
    solid.collision_mask = 2
    own(solid,fire)
    var collision := CollisionShape2D.new()
    collision.name = "Footprint"
    var shape := RectangleShape2D.new()
    shape.size = Vector2(44,18)
    collision.shape = shape
    collision.position.y = -10
    own(collision,solid)
    var interaction := load("res://scenes/objects/interaction_point.tscn").instantiate() as Marker2D
    interaction.title = "Тлеющий костёр"
    interaction.description = "Огонь прогоняет сырость. В золе ещё различимы следы недавней трапезы.\nГанс: «Кто-то ушёл совсем недавно. Или услышал мои шаги»."
    interaction.position.y = 12
    own(interaction,fire)
    light(Vector2(0,-18),fire,3.6,1.15,0.11)
    particles(Vector2(0,-30),fire,false)
    instance("logs",Vector2(498,681))
    # Puddles are deliberately walkable shallow water.
    for pos in [Vector2(668,748),Vector2(804,620),Vector2(1090,750),Vector2(622,932),Vector2(302,792),Vector2(248,755),Vector2(345,826)]:
        decoration("puddle",pos,ground_props)
    # Dense forest surrounds a broad, readable clearing and the departing road.
    for y in range(115,1120,60):
        for x in range(70,1480,57):
            var pos := Vector2(x+rng.randi_range(-19,19),y+rng.randi_range(-18,18))
            var clearing := Rect2(360,330,760,515).has_point(pos)
            var path_dist := distance_path(pos,road)
            if clearing or path_dist < 85 or pos.distance_to(Vector2(285,780))<92:
                continue
            if rng.randf()<0.16:continue
            var key := "birch_"+str(rng.randi_range(0,1)) if rng.randf()<0.28 else "pine_"+str(rng.randi_range(0,2))
            instance(key,pos)
    for pos in [Vector2(364,547),Vector2(1117,490),Vector2(1134,582),Vector2(342,690),Vector2(1083,865)]:
        instance("birch_0",pos)
    for i in range(300):
        var pos := Vector2(rng.randf_range(100,1430),rng.randf_range(240,1100))
        if Rect2(415,300,255,190).has_point(pos) or Rect2(830,360,215,307).has_point(pos) or distance_path(pos,road)<45 or distance_path(pos,house_path)<26:
            continue
        decoration("grass" if rng.randf()<0.85 else "mushrooms",pos,actors,true)
    for i in range(42):
        var angle := rng.randf()*TAU
        var pos := Vector2(290,790)+Vector2(cos(angle)*rng.randf_range(65,130),sin(angle)*rng.randf_range(40,90))
        decoration("reeds",pos,actors,true)
    var player := load("res://scenes/player/hans.tscn").instantiate() as CharacterBody2D
    player.name = "Hans"
    player.position = Vector2(700,648)
    own(player,actors)
    var boundaries := StaticBody2D.new()
    boundaries.name = "MapBounds"
    boundaries.collision_mask = 2
    own(boundaries,world_root)
    for box in [Rect2(-32,-32,1600,32),Rect2(-32,1152,1600,32),Rect2(-32,0,32,1152),Rect2(1536,0,32,1152)]:
        var wall := CollisionShape2D.new()
        var rectangle := RectangleShape2D.new()
        rectangle.size = box.size
        wall.shape = rectangle
        wall.position = box.get_center()
        own(wall,boundaries)
    var evening := CanvasModulate.new()
    evening.name = "EveningLight"
    evening.color = Color(0.69,0.76,0.79,1)
    own(evening,world_root)
    atmosphere = Node2D.new()
    atmosphere.name = "Atmosphere"
    atmosphere.set_script(load("res://scripts/atmosphere.gd"))
    own(atmosphere,world_root)
    particles(Vector2(575,291),atmosphere,true)
    var motes := CPUParticles2D.new()
    motes.name = "DriftingMotes"
    motes.amount = 38
    motes.lifetime = 12
    motes.preprocess = 6
    motes.position = Vector2(760,590)
    motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
    motes.emission_rect_extents = Vector2(580,300)
    motes.direction = Vector2(-1,-0.1)
    motes.spread = 30
    motes.gravity = Vector2.ZERO
    motes.initial_velocity_min = 2
    motes.initial_velocity_max = 5
    motes.color = Color(0.7,0.78,0.6,0.28)
    motes.z_index = 3
    motes.add_to_group("ambient_particles",true)
    own(motes,atmosphere)
    var screen := CanvasLayer.new()
    screen.name = "Screen"
    screen.layer = 4
    own(screen,atmosphere)
    var fog := ColorRect.new()
    fog.name = "Fog"
    fog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var material := ShaderMaterial.new()
    material.shader = load("res://shaders/atmosphere.gdshader")
    fog.material = material
    own(fog,screen)
    var hud := CanvasLayer.new()
    hud.name = "HUD"
    hud.layer = 10
    hud.set_script(load("res://scripts/ui/hud.gd"))
    own(hud,world_root)
    save_scene(world_root,OUT)
    world_root.free()
