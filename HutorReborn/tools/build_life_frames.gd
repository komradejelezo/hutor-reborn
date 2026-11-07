extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
    var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/npc/stage46/manifest.json"))
    for id in data:
        var frames:SpriteFrames=load("res://assets/npc/stage43/"+id+"/frames.tres").duplicate(true)
        var atlas:Texture2D=load("res://assets/npc/stage46/"+id+".png")
        for clip in data[id].clips:
            if frames.has_animation(clip):frames.remove_animation(clip)
            frames.add_animation(clip);frames.set_animation_loop(clip,data[id].clips[clip].size()>1)
            frames.set_animation_speed(clip,6 if id=="old_man" else 8)
            for index in data[id].clips[clip]:
                var texture:=AtlasTexture.new();texture.atlas=atlas
                texture.region=Rect2((int(index)%8)*96,(int(index)/8)*96,96,96);texture.filter_clip=true
                frames.add_frame(clip,texture)
        assert(ResourceSaver.save(frames,"res://assets/npc/stage46/"+id+".tres")==OK)
    print("SAVED: six additive activity SpriteFrames resources; original frames untouched")
    quit()
