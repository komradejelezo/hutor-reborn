extends SceneTree
## Additive SpriteFrames resources. Original walking images are retained verbatim.
func _initialize() -> void:call_deferred("run")
func run() -> void:
    var profiles:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/visuals/residents.json"))
    var catalog:Dictionary={}
    for id in profiles:
        var source:String="res://assets/npc/stage46/"+id+".tres"
        if not ResourceLoader.exists(source):source="res://assets/npc/stage43/"+id+"/frames.tres"
        var frames:SpriteFrames=load(source).duplicate(true)
        for clip in frames.get_animation_names():
            if String(clip).begins_with("work_"):frames.set_animation_speed(clip,profiles[id].work_fps)
        for direction in ["down","up","left","right"]:
            var turn:StringName=StringName("turn_"+direction)
            frames.add_animation(turn);frames.set_animation_loop(turn,false)
            frames.add_frame(turn,frames.get_frame_texture("idle_"+direction,0))
            if id=="woodcutter_son":
                var run_clip:StringName=StringName("run_"+direction)
                var walk:StringName=StringName("walk_"+direction)
                frames.add_animation(run_clip);frames.set_animation_loop(run_clip,true);frames.set_animation_speed(run_clip,6)
                for index in frames.get_frame_count(walk):frames.add_frame(run_clip,frames.get_frame_texture(walk,index))
        if id=="woodcutter":
            var atlas:Texture2D=load("res://assets/npc/stage47/woodcutter_saw.png")
            frames.add_animation(&"work_saw");frames.set_animation_loop(&"work_saw",true);frames.set_animation_speed(&"work_saw",6)
            for index in 6:
                var texture:=AtlasTexture.new();texture.atlas=atlas;texture.region=Rect2(index*96,0,96,96);texture.filter_clip=true
                frames.add_frame(&"work_saw",texture)
        if id in ["woodcutter","innkeeper_wife"]:
            var clean_atlas:Texture2D=load("res://assets/npc/stage532/"+id+"_atlas.png")
            for clip in frames.get_animation_names():
                for index in frames.get_frame_count(clip):
                    var frame:=frames.get_frame_texture(clip,index) as AtlasTexture
                    if frame and frame.atlas.resource_path=="res://assets/npc/stage43/"+id+"/atlas.png":frame.atlas=clean_atlas
        assert(ResourceSaver.save(frames,"res://assets/npc/stage47/"+id+".tres")==OK)
        catalog[id]={}
        for clip in frames.get_animation_names():
            var kind:="original_activity"
            if String(clip).begins_with("idle_"):kind="static_idle_fallback"
            elif String(clip).begins_with("turn_"):kind="static_directional_pose"
            elif String(clip).begins_with("run_"):kind="original_walk_frames_run_fallback"
            elif String(clip).begins_with("walk_"):kind="original_walk"
            elif clip==&"work_sit":kind="single_archived_seated_pose"
            elif clip==&"work_saw":kind="new_original_saw_cycle_prepared_only"
            catalog[id][String(clip)]={"frames":frames.get_frame_count(clip),"loop":frames.get_animation_loop(clip),"fps":frames.get_animation_speed(clip),"kind":kind}
    var file:=FileAccess.open("res://data/visuals/animation_catalog.json",FileAccess.WRITE)
    file.store_string(JSON.stringify(catalog,"  ")+"\n")
    print("SAVED: nine presentation resources; 36 directional turn poses, four child run clips, six native saw frames")
    quit()
