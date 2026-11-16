extends SceneTree
## Generates editable scenes exclusively from existing approved project resources.
const BASE="res://scenes/objects/krivaya_sosna/"
var world:Node2D
var actors:Node2D
func _initialize() -> void:call_deferred("run")
func node(type:Variant,name:String,parent:Node) -> Node:
    var n:Node=type.new();n.name=name;parent.add_child(n);return n
func solid(parent:Node,pos:Vector2,size:Vector2) -> void:
    var b:=StaticBody2D.new();b.position=pos;parent.add_child(b)
    var shape:=CollisionShape2D.new();var rect:=RectangleShape2D.new();rect.size=size;shape.shape=rect;b.add_child(shape)
func art(parent:Node,path:String,pos:Vector2,factor:float=1.0,foot:bool=true) -> Sprite2D:
    var s:=Sprite2D.new();s.texture=load(path);s.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;s.position=pos;s.scale=Vector2.ONE*factor
    if foot:s.offset=Vector2(0,-s.texture.get_height()*.5)
    parent.add_child(s);return s
func prop(kind:String,pos:Vector2) -> void:
    var scene:PackedScene=load(BASE+kind+".tscn");var n:Node2D=scene.instantiate();n.name=kind.replace("/","_")+str(actors.get_child_count());n.position=pos;actors.add_child(n)
func tile_layer(name:String,texture_path:String) -> TileMapLayer:
    var layer:=TileMapLayer.new();layer.name=name;layer.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;world.add_child(layer)
    var tiles:=TileSet.new();tiles.tile_size=Vector2i(32,32);var source:=TileSetAtlasSource.new();source.texture=load(texture_path);source.texture_region_size=Vector2i(32,32)
    for y in int(source.texture.get_height()/32):
        for x in int(source.texture.get_width()/32):source.create_tile(Vector2i(x,y))
    tiles.add_source(source,0);layer.tile_set=tiles;return layer
func run() -> void:
    for id in ["logging_camp","abandoned"]:
        world=Node2D.new();world.name="OldLoggingCamp" if id=="logging_camp" else "AbandonedHouseInterior"
        world.set_script(load("res://scripts/chapter/chapter_location.gd"));world.building_id=StringName(id)
        world.map_size=Vector2i(1216,1152) if id=="logging_camp" else Vector2i(1024,768)
        actors=node(Node2D,"Actors",world);actors.y_sort_enabled=true
        var residents:Node2D=node(Node2D,"Residents",actors);residents.y_sort_enabled=true;residents.set_script(load("res://scripts/npc/npc_population.gd"))
        var nav:Node=node(Node,"Navigation",residents);nav.set_script(load("res://scripts/npc/navigation_service.gd"))
        var data:=HutorNpcNavigationData.new();data.world_size=world.map_size;data.costs.resize(int(world.map_size.x/16)*int(world.map_size.y/16));data.costs.fill(1);nav.data=data
        var hero:Node2D=load("res://scenes/player/hans.tscn").instantiate();hero.name="Hans";hero.position=Vector2(590,1040) if id=="logging_camp" else Vector2(512,480);actors.add_child(hero)
        var entry:Marker2D=node(Marker2D,"Entry",world);entry.position=hero.position
        var exit:Marker2D=node(Marker2D,"Exit",world);exit.position=entry.position+Vector2(0,25)
        var atmo:Node2D=node(Node2D,"Atmosphere",world);atmo.set_script(load("res://scripts/chapter/chapter_atmosphere.gd"))
        var hud:CanvasLayer=node(CanvasLayer,"HUD",world);hud.set_script(load("res://scripts/ui/hud.gd"));hud.location_title="Старые лесозаготовки" if id=="logging_camp" else "Дом без хозяина";hud.location_subtitle="За северным оврагом" if id=="logging_camp" else "Кто-то зажигал здесь свечу";hud.chapter_label="I · ТЕНИ КРИВОЙ СОСНЫ"
        if id=="logging_camp":forest()
        else:house()
        var modulate:CanvasModulate=node(CanvasModulate,"Evening",world);modulate.color=Color(.62,.66,.68) if id=="logging_camp" else Color(.51,.48,.43)
        var audio:AudioStreamPlayer=node(AudioStreamPlayer,"RoomTone",world);audio.stream=load("res://assets/audio/ambient/wind.ogg");audio.volume_db=-29
        own(world,world);var packed:=PackedScene.new();assert(packed.pack(world)==OK);assert(ResourceSaver.save(packed,"res://scenes/chapter/"+id+".tscn")==OK);world.free()
    print("CHAPTER: two editable locations built from existing art");quit()
func own(n:Node,root_node:Node) -> void:
    for child in n.get_children():
        child.owner=root_node
        # Packed instances retain ownership of their inherited children. Re-owning
        # them writes duplicate inherited nodes and leaks their replaced bodies.
        if child.scene_file_path.is_empty():own(child,root_node)
func forest() -> void:
    var ground:=tile_layer("Ground","res://assets/environment/krivaya_sosna/surface_polish/world_ground.png");ground.z_index=-10
    for y in 36:
        for x in 38:ground.set_cell(Vector2i(x,y),0,Vector2i(x+25,y))
    var rng:=RandomNumberGenerator.new();rng.seed=701
    for i in 110:
        var p:=Vector2(rng.randf_range(40,1170),rng.randf_range(30,1100))
        if p.x>260 and p.x<1000 and p.y>150 and p.y<1080:continue
        prop(["pine_0","pine_1","mixed_tree","pine_2"][i%4],p)
    for i in 32:
        var p:=Vector2(rng.randf_range(450,980),rng.randf_range(200,1000))
        if p.distance_to(Vector2(590,1040))<90 or absf(p.x-590)<60:continue
        prop(["stump","stage32/branches","stage32/old_stump","stage32/fallen_a","rock"][i%5],p)
    prop("cart",Vector2(780,340));prop("stage32/dry_snag",Vector2(935,220));prop("stage32/roots",Vector2(885,405))
    prop("wood_store",Vector2(650,300));prop("stage32/fire_ring",Vector2(705,440)) if ResourceLoader.exists(BASE+"stage32/fire_ring.tscn") else prop("rock",Vector2(705,440))
    var ravine:Polygon2D=node(Polygon2D,"Ravine",world);ravine.z_index=-2;ravine.color=Color("17201d");ravine.polygon=PackedVector2Array([Vector2(125,350),Vector2(230,285),Vector2(310,440),Vector2(245,640),Vector2(175,700),Vector2(110,560)])
    solid(world,Vector2(180,490),Vector2(110,280))
    for x in [480,565,650,735]:prop("stage32/fallen_a",Vector2(x,120))
    var pack:Node2D=node(Node2D,"WolfGuard",actors);pack.set_script(load("res://scripts/chapter/chapter_pack.gd"))
    for pos in [Vector2(590,670),Vector2(685,645)]:
        var wolf:=art(pack,"res://assets/combat/stage61/wolf.png",pos,1,false);wolf.offset=Vector2(-48,-82);wolf.centered=false;solid(pack,pos+Vector2(0,-5),Vector2(48,20))
    for r in [[Vector2(608,0),Vector2(1216,12)],[Vector2(608,1152),Vector2(1216,12)],[Vector2(0,576),Vector2(12,1152)],[Vector2(1216,576),Vector2(12,1152)]]:solid(world,r[0],r[1])
    var screen:CanvasLayer=node(CanvasLayer,"Mist",world);screen.layer=-1
    var fog:ColorRect=node(ColorRect,"Fog",screen);fog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);fog.mouse_filter=Control.MOUSE_FILTER_IGNORE
    var material:=ShaderMaterial.new();material.shader=load("res://shaders/evening_mist.gdshader");fog.material=material
func house() -> void:
    var void_space:Polygon2D=node(Polygon2D,"OutsideWalls",world);void_space.z_index=-20;void_space.color=Color("090c0c");void_space.polygon=PackedVector2Array([Vector2.ZERO,Vector2(1024,0),Vector2(1024,768),Vector2(0,768)])
    var floor_layer:=tile_layer("Floor","res://assets/interiors/stage45/floor_atlas_old_man.png");floor_layer.z_index=-10
    var src:TileSetAtlasSource=floor_layer.tile_set.get_source(0)
    for y in range(6,16):
        for x in range(8,24):floor_layer.set_cell(Vector2i(x,y),0,Vector2i((x-8)%int(src.texture.get_width()/32),(y-6)%int(src.texture.get_height()/32)))
    var walls:=tile_layer("Walls","res://assets/environment/visual_fixes_5_3/wall_old_atlas.png");walls.z_index=-5
    for y in range(5,17):
        for x in range(7,25):
            if y in [5,16] or x in [7,24]:
                if y==16 and x in [15,16]:continue
                walls.set_cell(Vector2i(x,y),0,Vector2i(0,0))
    for r in [[Vector2(512,180),Vector2(576,20)],[Vector2(240,352),Vector2(20,352)],[Vector2(784,352),Vector2(20,352)],[Vector2(364,528),Vector2(216,20)],[Vector2(660,528),Vector2(216,20)]]:solid(world,r[0],r[1])
    solid(world,Vector2(512,535),Vector2(64,14)) # Door interaction is inside; no walking into the void.
    var props:Node2D=node(Node2D,"Props",actors);props.y_sort_enabled=true
    for d in [["bed_old",Vector2(310,280)],["table_small",Vector2(435,300)],["shelf_books",Vector2(710,255)],["chest",Vector2(705,310)],["broken_boards",Vector2(450,340)],["candle",Vector2(435,300)],["wall_hanging",Vector2(570,215)],["basket",Vector2(300,430)],["shelf_cups",Vector2(590,225)],["stool",Vector2(400,350)],["pot",Vector2(470,300)],["documents",Vector2(440,285)]]:
        var n:Node2D=node(Node2D,String(d[0]),props);n.position=d[1];art(n,"res://assets/interiors/stage44/"+d[0]+".png",Vector2.ZERO,.95)
        if d[0] in ["bed_old","table_small","shelf_books","chest"]:solid(n,Vector2(0,-10),Vector2(65,28))
    art(props,"res://assets/interiors/stage45/work_boots.png",Vector2(340,390),.8)
    art(props,"res://assets/interiors/stage45/linen_line.png",Vector2(360,255),.8)
    for x in [360,640,740]:art(props,"res://assets/interiors/stage44/broken_boards.png",Vector2(x,210),.9)
    var lamp:PointLight2D=node(PointLight2D,"CandleLight",world.get_node("Atmosphere"));lamp.position=Vector2(435,275);lamp.texture=load("res://assets/environment/krivaya_sosna/stage33/soft_light.tres");lamp.texture_scale=.75;lamp.energy=.85;lamp.color=Color("e4b77d")
    node(Node2D,"NPCPoints",world);var spot:Marker2D=node(Marker2D,"Herbalist",world.get_node("NPCPoints"));spot.position=Vector2(550,430)
