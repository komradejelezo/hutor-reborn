extends Node
## Targeted display-only corrections from VISUAL_AUDIT_5_3 A-04..A-11.
## No transforms of buildings/actors, bodies, routes, time or scene travel change.
const BASE="res://assets/environment/visual_fixes_5_3/"
const FLAME=preload("res://shaders/hearth_flame.gdshader")
var world:Node2D
var flame_material:ShaderMaterial
var elapsed:=0.0
var last_phase:=-1

func apply(target:Node2D) -> void:
    world=target
    process_mode=Node.PROCESS_MODE_PAUSABLE
    if world.get("building_id")!=null:
        _walls()
        _tables()
        _room_readability()
        flame_material=ShaderMaterial.new();flame_material.shader=FLAME
        for sprite in world.find_children("Art","Sprite2D",true,false):
            if sprite.texture and sprite.texture.resource_path.ends_with("/fireplace.png"):sprite.material=flame_material
    elif world.scene_file_path=="res://scenes/world/krivaya_sosna/krivaya_sosna.tscn":
        world.get_node("Actors/Structures/CommonHouse/Art").texture=load(BASE+"common_house.png")
        for particle in world.find_children("ChimneySmoke*","CPUParticles2D",true,false):
            particle.texture=load(BASE+"chimney_smoke.png")
            particle.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
            particle.position.y-=8
        _forest_variants()
    else:set_process(false)

func _walls() -> void:
    var walls:TileMapLayer=world.get_node("Walls")
    var old:Texture2D=(walls.tile_set.get_source(0) as TileSetAtlasSource).texture
    var kind:="wall_old" if old.resource_path.ends_with("wall_old.png") else "wall"
    var source:=TileSetAtlasSource.new()
    source.texture=load(BASE+kind+"_atlas.png");source.texture_region_size=Vector2i(32,32)
    for y in 3:
        for x in 3:source.create_tile(Vector2i(x,y))
    walls.tile_set=walls.tile_set.duplicate(true)
    walls.tile_set.add_source(source,532)
    var rect:Rect2=world.room_bounds
    var left:=int(rect.position.x/32)-1;var right:=int(rect.end.x/32)
    var top:=int(rect.position.y/32)-1;var bottom:=int(rect.end.y/32)
    for cell in walls.get_used_cells():
        var edge_left:=cell.x==left;var edge_right:=cell.x==right
        var cap:=cell.y==top or cell.y==bottom
        var tile:=Vector2i.ZERO
        if (edge_left or edge_right) and cap:tile=Vector2i(0 if edge_left else 1,1 if cell.y==top else 2)
        elif edge_left or edge_right:tile=Vector2i(1 if edge_left else 2,0)
        walls.set_cell(cell,532,tile)

func _tables() -> void:
    var id:StringName=world.building_id
    if id!=&"herbalist" and id!=&"old_man":return
    var prop:Node2D=world.get_node("Actors/Props/"+("Table" if id==&"herbalist" else "SideTable"))
    var art:Sprite2D=prop.get_node("Art")
    art.texture=load("res://assets/interiors/stage44/table_round.png")
    var factor:=.72 if id==&"herbalist" else .64
    art.scale=Vector2.ONE*factor
    art.position=Vector2(-art.texture.get_width()*factor*.5,-art.texture.get_height()*factor-12)
    # These tiny non-solid props used to float above the wrongly chosen bed.
    if id==&"old_man":
        world.get_node("Actors/Props/Pipe").position.y+=18
        world.get_node("Actors/Props/SmokingPouch").position.y+=16

func _room_readability() -> void:
    if world.building_id not in [&"herbalist",&"storehouse"]:return
    var fill:=PointLight2D.new();fill.name="WindowFill532"
    fill.texture=load("res://assets/environment/krivaya_sosna/stage33/soft_light.tres")
    fill.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
    fill.position=world.room_bounds.get_center()+Vector2(0,-18)
    fill.color=Color(.95,.83,.65);fill.energy=.34 if world.building_id==&"herbalist" else .28
    fill.texture_scale=.72;fill.shadow_enabled=false
    world.get_node("Atmosphere").add_child(fill)

func _forest_variants() -> void:
    # Same anchors, footprints, scale, mirrors and hierarchy. Only swap compatible
    # 118x186 native crown variants to break repeated adjacent silhouettes.
    for item in world.get_node("Actors/Nature").get_children():
        var sprite:Sprite2D=item.get_node_or_null("Art")
        if not sprite or not sprite.texture:continue
        var source:String=sprite.texture.resource_path
        if not source.contains("/objects/pine_"):continue
        var key:=absi(hash(str(item.position)+String(item.name)))
        if key%3!=0:continue
        var index:=key%4
        sprite.texture=load("res://assets/environment/krivaya_sosna/objects/pine_"+str(index)+".png")
        # Independent native wind phase, no position/collision changes.
        if sprite.material is ShaderMaterial:
            sprite.material=sprite.material.duplicate()
            sprite.material.set_shader_parameter("speed",.62+float(key%7)*.035)

func _process(delta:float) -> void:
    if not flame_material:return
    var allowed:bool=world.atmosphere.effects_enabled
    if allowed:elapsed+=delta
    var phase:=int(elapsed*5)%3 if allowed else 0
    if phase!=last_phase:
        flame_material.set_shader_parameter("flame_phase",phase);last_phase=phase
