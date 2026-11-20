extends "res://tests/verify_combat_ui_61.gd"
## Existing Lab only; diagnostic fixtures never change scene/resource files.
const PACK="res://assets/combat/forest_v2/"
const LAB="res://scenes/combat/CombatGraphicsLab.tscn"
var output:=OS.get_environment("HANS_RESTORE_CAPTURE")
var baseline_dir:=OS.get_environment("HANS_RESTORE_BASELINE")
var records:Array=[]
func select_clip(lab:Control,clip:String) -> void:
    for i in lab.clips.item_count:
        if lab.clips.get_item_text(i)==clip:lab.clips.select(i)
    lab.stop()
func cropped_pair(image:Image,index:int,sheet:Image) -> void:
    var cell:=Vector2i((index%4)*560,(index/4)*260)
    sheet.blit_rect(image,Rect2i(80,180,280,260),cell)
    sheet.blit_rect(image,Rect2i(540,180,280,260),cell+Vector2i(280,0))
func compare_before(sheet:Image,clip:String,bg:int,count:int) -> void:
    if baseline_dir.is_empty():return
    var before:=Image.load_from_file(baseline_dir+"/"+clip+"-bg"+str(bg)+".png")
    check(before!=null and before.get_size()==sheet.get_size(),"baseline capture size "+clip+"/"+str(bg))
    if before==null:return
    for i in count:
        var cell:=Vector2i((i%4)*560,(i/4)*260)
        check(before.get_region(Rect2i(cell,Vector2i(280,260))).get_data()==sheet.get_region(Rect2i(cell,Vector2i(280,260))).get_data(),"immutable original PNG renders identically "+clip+"/"+str(i+1)+"/"+str(bg))
        check(before.get_region(Rect2i(cell+Vector2i(280,210),Vector2i(280,50))).get_data()==sheet.get_region(Rect2i(cell+Vector2i(280,210),Vector2i(280,50))).get_data(),"feet/ground render unchanged "+clip+"/"+str(i+1)+"/"+str(bg))
func texture_for(frame:Dictionary,raw:bool) -> AtlasTexture:
    var texture:=AtlasTexture.new();texture.atlas=load(PACK+(frame.source if raw else frame.path))
    texture.region=Rect2(0,0,frame.size[0],frame.size[1])
    texture.margin=Rect2(600-frame.origin[0],650-frame.origin[1],1200-frame.size[0],800-frame.size[1])
    return texture
func run() -> void:
    var graphical:=DisplayServer.get_name()!="headless" and not output.is_empty()
    if graphical:DirAccess.make_dir_recursive_absolute(output)
    change_scene_to_file(LAB);await scene_changed;await frames()
    var lab:Control=current_scene
    var lib:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(PACK+"library.json"))
    for bg in ([2,3,1] if graphical else [2]):
        lab.background.select(bg);lab.background.item_selected.emit(bg)
        for clip in lib.hans:
            select_clip(lab,clip)
            var count:int=lib.hans[clip].frames.size()
            var sheet:Image
            if graphical:sheet=Image.create(2240,260*int(ceil(count/4.0)),false,Image.FORMAT_RGBA8)
            for i in count:
                lab.set_frame(i);await process_frame
                var f:Dictionary=lib.hans[clip].frames[i]
                check(lab.actors[1].sprite.frame==i and not lab.actors[1].sprite.is_playing(),"exact paused runtime frame "+clip+"/"+str(i+1))
                check(lab.actors[1].sprite.scale.x==lab.actors[1].sprite.scale.y and lab.actors[1].sprite.modulate.a==1,"uniform scale/opaque modulation "+clip+"/"+str(i+1))
                if graphical:
                    await RenderingServer.frame_post_draw;cropped_pair(root.get_texture().get_image(),i,sheet)
                if bg==2:records.append({"clip":clip,"runtime_frame":i+1,"file":f.path,"source":f.source,"origin":f.origin,"in_runtime":true})
            if graphical:
                compare_before(sheet,clip,bg,count)
                check(sheet.save_png(output+"/"+clip+"-bg"+str(bg)+".png")==OK,"save contrast sheet "+clip+"/"+str(bg))
    # Six excluded Victory files are inspected in the same Lab as temporary
    # one-frame textures; they never become playable animations.
    var audit:Array=JSON.parse_string(FileAccess.get_file_as_string(PACK+"source_audit.json"))
    var victory_frames:Array=[]
    for spec in audit:
        if spec.animation=="Hans/Victory":victory_frames=spec.frames
    select_clip(lab,"victory")
    lab.background.select(2);lab.background.item_selected.emit(2)
    var extra:Image
    if graphical:extra=Image.create(2240,520,false,Image.FORMAT_RGBA8)
    var slot:=0
    for number in [9,10,13,14,15,16]:
        var f:Dictionary=victory_frames[number-1]
        for side in 2:
            var sf:=SpriteFrames.new();sf.add_animation("victory");sf.add_frame("victory",texture_for(f,side==0));sf.set_animation_loop("victory",false)
            var sprite:AnimatedSprite2D=lab.actors[side].sprite
            sprite.sprite_frames=sf;sprite.animation="victory";sprite.pause();sprite.frame=0
        await process_frame
        if graphical:
            await RenderingServer.frame_post_draw;cropped_pair(root.get_texture().get_image(),slot,extra)
        records.append({"clip":"victory","runtime_frame":null,"source_frame":number,"file":f.path,"source":f.source,"origin":f.origin,"in_runtime":false})
        slot+=1
    if graphical:
        check(extra.save_png(output+"/excluded-victory-bg2.png")==OK,"save excluded-source review, not new runtime clips")
        var file:=FileAccess.open(output+"/frame_index.json",FileAccess.WRITE);file.store_string(JSON.stringify(records,"  "))
    change_scene_to_file(LAB);await scene_changed;await frames();lab=current_scene
    var driver:Node=lab.actors[1].animation;driver.diagnostic_hold=false
    for clip in ["attack","hit","dodge","victory","use_invoke"]:
        var foot:Vector2=lab.actors[1].body.position
        var duration:float=driver.play(clip,1)
        await create_timer(duration+.1).timeout
        check(driver.motion=="idle" and not driver.dead,"normal transition "+clip+" to Idle")
        check(lab.actors[1].body.position==foot,"normal transition keeps ground anchor "+clip)
    var duration:float=driver.play("death",1);await create_timer(duration+.1).timeout
    check(driver.dead and lab.actors[1].sprite.frame==15 and not lab.actors[1].sprite.is_playing(),"Death keeps its final frame")
    change_scene_to_file(ARENA);await scene_changed;await frames()
    var arena:Control=current_scene;arena.fast.button_pressed=true
    for id in ["duel","forest","companions"]:
        arena._start_scenario(id);await ready_turn(arena)
        var actions:=0
        while arena.battle.result=="" and actions<60:
            var targets:Array=arena.battle.targets("attack")
            if targets.is_empty():arena._select_action("defend")
            else:arena._target(targets[0])
            await ready_turn(arena);actions+=1
        check(arena.battle.result!="" and actions<60,"actual action flow reaches result "+id)
        if graphical:
            await RenderingServer.frame_post_draw
            root.get_texture().get_image().save_png(output+"/battle-"+id+".png")
    # Release temporary diagnostic textures and cancel presentation coroutines
    # before SceneTree shutdown; gameplay scripts remain untouched.
    arena._cancel()
    change_scene_to_file(MENU);await scene_changed;await frames()
    lab=null;driver=null;arena=null;victory_frames.clear();audit.clear()
    print("RESULT: ",passed," focused Hans checks passed, ",failed," failed; ",records.size()," source/runtime records")
    call_deferred("quit",0 if failed==0 else 1)
