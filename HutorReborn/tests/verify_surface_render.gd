extends SceneTree
## Real GPU raster checks of the two saved TileMapLayers at fractional positions.
var passed:=0
var failed:=0
func _initialize() -> void:call_deferred("run")
func check(ok:bool,message:String) -> void:
    if ok:
        passed+=1
        print("PASS: ",message)
    else:
        failed+=1
        push_error("FAIL: "+message)
func frame() -> void:
    for i in range(3):await process_frame
    await RenderingServer.frame_post_draw
func capture() -> Image:
    return root.get_texture().get_image()
func shifted_equal(a:Image,b:Image) -> bool:
    var bounds:=Rect2i(3,3,a.get_width()-6,a.get_height()-6)
    var reference:=a.get_region(bounds).get_data()
    for dx in range(-2,3):
        var moved:=bounds
        moved.position.x+=dx
        if b.get_region(moved).get_data()==reference:return true
    return false
func no_gaps(image:Image) -> bool:
    for y in range(image.get_height()):
        for x in range(image.get_width()):
            var pixel:=image.get_pixel(x,y)
            if pixel.r>.99 and pixel.b>.99 and pixel.g<.01:return false
    return true
func run() -> void:
    root.size=Vector2i(320,192)
    root.content_scale_size=root.size
    RenderingServer.set_default_clear_color(Color.MAGENTA)
    var world:Node2D=load("res://scenes/world/krivaya_sosna/krivaya_sosna.tscn").instantiate()
    var layers:=Node2D.new()
    root.add_child(layers)
    for name in ["Ground","Ground Details"]:
        var layer:=world.get_node(name)
        layer.owner=null
        world.remove_child(layer)
        layers.add_child(layer)
    world.free()
    var camera:=Camera2D.new()
    layers.add_child(camera)
    var center:=Vector2(1320,1435)
    camera.position=center
    camera.force_update_scroll()
    await frame()
    var unit:=capture()
    check(no_gaps(unit),"native tile raster has no exposed background")
    for zoom in [1,2]:
        camera.zoom=Vector2.ONE*zoom
        camera.position=center
        camera.force_update_scroll()
        await frame()
        var reference:=capture()
        if zoom==2:
            var scaled:=unit.get_region(Rect2i(80,48,160,96))
            scaled.resize(320,192,Image.INTERPOLATE_NEAREST)
            check(reference.get_data()==scaled.get_data(),"2x camera zoom matches exact nearest-neighbour pixels")
        for offset in [.25,.5,.75,1.0]:
            camera.position=center+Vector2(offset,0)
            camera.force_update_scroll()
            await frame()
            var sample:=capture()
            check(no_gaps(sample),"no tile gaps while camera moves at zoom "+str(zoom)+", offset "+str(offset))
            check(shifted_equal(reference,sample),"both layers move as one sharp pixel grid at zoom "+str(zoom)+", offset "+str(offset))
    print("RESULT: ",passed," rendered checks passed, ",failed," failed")
    layers.queue_free()
    await process_frame
    quit(0 if failed==0 else 1)
