extends SceneTree
## Authoring only. Original scene/layers are not loaded or repacked here.
const BASE = "res://assets/environment/krivaya_sosna/stage42/"
const OUT = "res://scenes/world/krivaya_sosna/stage42/"
func _initialize() -> void: call_deferred("run")
func run() -> void:
    var plan: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BASE + "layout.json"))
    DirAccess.make_dir_recursive_absolute(OUT)
    for item in [["Extension Ground", "extension_ground", "ground_cells", 0], ["New Paths", "new_paths", "path_cells", 0]]:
        var texture: Texture2D = load(BASE + item[1] + ".png")
        var tiles := TileSet.new()
        tiles.tile_size = Vector2i(32,32)
        var atlas := TileSetAtlasSource.new()
        atlas.texture = texture
        atlas.texture_region_size = Vector2i(32,32)
        atlas.use_texture_padding = true
        tiles.add_source(atlas, 0)
        var layer := TileMapLayer.new()
        layer.name = item[0]
        layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
        layer.z_index = item[3]
        layer.tile_set = tiles
        for cell in plan[item[2]]:
            var uv := Vector2i(cell[2],cell[3])
            atlas.create_tile(uv)
            layer.set_cell(Vector2i(cell[0],cell[1]),0,uv)
        var resource_path: String = BASE + item[1] + ".tres"
        assert(ResourceSaver.save(tiles, resource_path) == OK)
        tiles.take_over_path(resource_path)
        var packed := PackedScene.new()
        assert(packed.pack(layer) == OK)
        assert(ResourceSaver.save(packed, OUT + item[1] + ".tscn") == OK)
        print("SAVED ", item[0], ": ", layer.get_used_cells().size(), " native cells")
        layer.free()
    quit()
