extends SceneTree
## Read-only audit and rendered comparisons; never saves or edits the game scene.
var destination:String
func _initialize() -> void:
    destination=OS.get_cmdline_user_args()[0]
    call_deferred("run")
func encode(value:Variant) -> Variant:
    if value is Resource:
        if value.resource_path!="":return value.resource_path
        var properties:Dictionary={"class":value.get_class()}
        for info in value.get_property_list():
            if info.usage&PROPERTY_USAGE_STORAGE and info.name not in ["resource_name","resource_local_to_scene","script"]:
                properties[info.name]=encode(value.get(info.name))
        return properties
    if value is Object:return value.get_class()
    if value is Array:
        var array:Array=[]
        for item in value:array.append(encode(item))
        return array
    return str(value) if typeof(value) not in [TYPE_NIL,TYPE_BOOL,TYPE_INT,TYPE_FLOAT,TYPE_STRING] else value
func snapshot(world:Node) -> Dictionary:
    var result:Dictionary={}
    var nodes:Array[Node]=[world]
    nodes.append_array(world.find_children("*","",true,false))
    for node in nodes:
        if node is TileMapLayer:continue
        var data:Dictionary={"class":node.get_class(),"scene":node.scene_file_path}
        for info in node.get_property_list():
            if info.usage&PROPERTY_USAGE_STORAGE and info.name not in ["owner","unique_name_in_owner"]:
                data[info.name]=encode(node.get(info.name))
        result[str(world.get_path_to(node))]=data
    return result
func frames(count:int=4) -> void:
    for i in range(count):await process_frame
    await RenderingServer.frame_post_draw
func save_image(name:String) -> void:
    var image:=root.get_texture().get_image()
    assert(image.save_png(destination+"-"+name+".png")==OK)
func run() -> void:
    var world:Node2D=load("res://scenes/world/krivaya_sosna/krivaya_sosna.tscn").instantiate()
    root.add_child(world)
    current_scene=world
    var state:=snapshot(world)
    await frames(8)
    var audit:Dictionary={"scene_state":state,"layers":[],"display":{}}
    for key in ["rendering/textures/canvas_textures/default_texture_filter","rendering/2d/snap/snap_2d_transforms_to_pixel","rendering/2d/snap/snap_2d_vertices_to_pixel","display/window/stretch/mode","display/window/stretch/scale_mode"]:
        audit.display[key]=ProjectSettings.get_setting(key)
    for node in world.find_children("*","TileMapLayer",true,false):
        var info:Dictionary={"path":str(world.get_path_to(node)),"transform":str(node.transform),"filter":node.texture_filter,"z":node.z_index,"cells":node.get_used_cells().size(),"cell_size":str(node.tile_set.tile_size),"sources":[]}
        for i in range(node.tile_set.get_source_count()):
            var source:TileSetAtlasSource=node.tile_set.get_source(node.tile_set.get_source_id(i))
            var image:=source.texture.get_image()
            info.sources.append({"id":node.tile_set.get_source_id(i),"path":source.texture.resource_path,"size":str(image.get_size()),"alpha":image.detect_alpha(),"region":str(source.texture_region_size),"margins":str(source.margins),"separation":str(source.separation),"padding":source.use_texture_padding,"tiles":source.get_tiles_count()})
        audit.layers.append(info)
    var file:=FileAccess.open(destination+"-audit.json",FileAccess.WRITE)
    file.store_string(JSON.stringify(audit,"  ",true))
    file.close()
    save_image("gameplay")
    var player:CharacterBody2D=world.get_node("Actors/Hans")
    player.set_physics_process(false)
    var camera:Camera2D=player.get_node("Camera2D")
    camera.position_smoothing_enabled=false
    camera.position=Vector2.ZERO
    world.get_node("HUD").hide()
    root.size=world.map_size
    root.content_scale_size=world.map_size
    camera.zoom=Vector2.ONE
    camera.force_update_scroll()
    await frames()
    save_image("overview")
    # Diagnostic views remove moving fog/particles only in this preview instance.
    world.atmosphere.set_effects_enabled(false)
    player.hide()
    root.size=Vector2i(960,540)
    root.content_scale_size=Vector2i(960,540)
    var views:Dictionary={"elder":Vector2(950,780),"miller":Vector2(1720,780),"common":Vector2(1287,1280),"carpenter":Vector2(880,1650),"herbalist":Vector2(1800,1650),"junction":Vector2(1580,1260),"forest":Vector2(640,1050)}
    for key in views:
        player.position=views[key]
        camera.force_update_scroll()
        await frames()
        save_image(key)
    world.queue_free()
    await process_frame
    quit()
