extends "res://tests/verify_surface_render.gd"
## Raster checks crossing both extension boundaries and the new road junctions.
func run() -> void:
    root.size = Vector2i(320,192); root.content_scale_size = root.size
    RenderingServer.set_default_clear_color(Color.MAGENTA)
    var world: Node2D = load("res://scenes/world/krivaya_sosna/krivaya_sosna.tscn").instantiate()
    var layers := Node2D.new(); root.add_child(layers)
    for name in ["Ground","Ground Details","Extension Ground","New Paths"]:
        var layer := world.get_node(name); layer.owner = null
        world.remove_child(layer); layers.add_child(layer)
    world.free()
    var camera := Camera2D.new(); layers.add_child(camera)
    for center in [Vector2(2624,1030),Vector2(1688,2176),Vector2(1287,2176),Vector2(2480,1110)]:
        for zoom in [1,2]:
            camera.zoom = Vector2.ONE*zoom
            camera.position = center; camera.force_update_scroll(); await frame()
            var reference := capture()
            check(no_gaps(reference),"complete native ground at "+str(center)+", zoom "+str(zoom))
            for offset in [.25,.5,.75,1.0]:
                camera.position = center+Vector2(offset,0); camera.force_update_scroll(); await frame()
                var sample := capture()
                check(no_gaps(sample) and shifted_equal(reference,sample),"sharp shared pixel grid across extension/junction at "+str(center)+", zoom "+str(zoom)+", pan "+str(offset))
    print("RESULT: ",passed," extension raster checks passed, ",failed," failed")
    layers.queue_free(); await process_frame
    quit(0 if failed == 0 else 1)
