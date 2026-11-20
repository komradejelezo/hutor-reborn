extends "res://tests/verify_combat_ui_61.gd"
## Diagnostic driver only. Not a game scene, autoload, import or resource edit.
var lab:Control
var timeline:Array=[]
var seen:Dictionary={}
var segment:=0
var output:=OS.get_environment("DODGE_REVIEW_OUT")
var baseline:=OS.get_environment("DODGE_REVIEW_BASELINE")
var elapsed:=0.0
func observe() -> void:
    if not is_instance_valid(lab):return
    var s:AnimatedSprite2D=lab.actors[1].sprite
    if s.animation=="dodge":seen[s.frame]=true
    lab.counter.text="%s · кадр %d · ×%.1f"%["Уклонение" if s.animation=="dodge" else "Покой",s.frame+1,s.speed_scale]
func run() -> void:
    check(not output.is_empty() and not baseline.is_empty(),"diagnostic paths supplied")
    if failed:quit(1);return
    DirAccess.make_dir_recursive_absolute(output)
    root.size=Vector2i(960,540);root.position=Vector2i(20,20)
    change_scene_to_file("res://scenes/combat/CombatGraphicsLab.tscn");await scene_changed;await frames()
    lab=current_scene;lab.set_process(false)
    var lib:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/combat/forest_v2/library.json"))
    check(lib.hans.dodge.frames.size()==12,"all twelve actual gameplay Dodge frames")
    var old:SpriteFrames=lab.actors[1].sprite.sprite_frames.duplicate(true)
    var textures:Array=[]
    for i in 12:
        var f:Dictionary=lib.hans.dodge.frames[i]
        var image:=Image.load_from_file(baseline+"/"+f.path)
        check(image!=null and image.get_size()==Vector2i(357,358),"baseline image size "+str(i+1))
        var texture:=ImageTexture.create_from_image(image);textures.append(texture)
        var atlas:AtlasTexture=old.get_frame_texture("dodge",i).duplicate();atlas.atlas=texture;old.set_frame("dodge",i,atlas)
    lab.actors[0].sprite.sprite_frames=old
    for label in lab.find_children("*","Label",true,false):
        if label.text.begins_with("Слева:"):label.text="Слева — до PR №42 / справа — текущая версия main после PR №42"
    for i in lab.clips.item_count:
        if lab.clips.get_item_text(i)=="dodge":lab.clips.select(i)
    # Fresh static contrast evidence through real production material/controller.
    for bg in [2,3,1]:
        lab.background.select(bg);lab.background.item_selected.emit(bg)
        var sheet:=Image.create(1120,1040,false,Image.FORMAT_RGBA8)
        lab.stop()
        for i in 12:
            lab.set_frame(i);await process_frame;await RenderingServer.frame_post_draw
            var image:=root.get_texture().get_image()
            var pos:=Vector2i((i%2)*560,(i/2)*170)
            # 2 columns x 6 rows of real, paired stage crops; no resampling.
            sheet.blit_rect(image,Rect2i(80,265,280,170),pos)
            sheet.blit_rect(image,Rect2i(540,265,280,170),pos+Vector2i(280,0))
            check(lab.actors[0].sprite.frame==i and lab.actors[1].sprite.frame==i,"paused pair matches exact frame "+str(i+1)+" bg "+str(bg))
            check(lab.actors[1].sprite.modulate.a==1 and lab.actors[1].sprite.self_modulate.a==1,"opaque modulation")
        check(sheet.save_png(output+"/godot-bg"+str(bg)+".png")==OK,"contrast capture saved")
    for view in lab.actors:view.animation.diagnostic_hold=false
    lab.actors[1].sprite.frame_changed.connect(observe)
    process_frame.connect(observe)
    lab.status.text="Диагностический просмотр: игровые кадры, масштаб, материал и точки опоры сохранены.\nПрозрачные повреждения остаются видимыми; никакая дорисовка не выполняется."
    lab.background.select(2);lab.background.item_selected.emit(2);lab.stop();observe()
    var ready:=FileAccess.open(output+"/ready",FileAccess.WRITE);ready.store_string("ready");ready.close()
    await create_timer(1).timeout
    var started:=Time.get_ticks_msec()
    for bg in [2,3]:
        lab.background.select(bg);lab.background.item_selected.emit(bg)
        for rate in [.5,1.0]:
            segment+=1;lab.rate=rate
            for control in lab.get_children():
                if control is SpinBox and control.position.x==540:control.value=rate
            for repeat in 2:
                seen.clear();var begin:=Time.get_ticks_msec()
                lab.play(true);observe()
                await create_timer(lab.actors[1].animation.duration("dodge",rate)+.12).timeout
                check(lab.actors[1].animation.motion=="idle" and lab.actors[0].animation.motion=="idle","Dodge returns to Idle on both sides")
                check(seen.size()==12,"all twelve frames observed at rate "+str(rate))
                timeline.append({"background":"белый" if bg==2 else "ярко-розовый","speed":rate,"repeat":repeat+1,"start_ms":begin-started,"idle_ms":Time.get_ticks_msec()-started,"frames_observed":seen.keys()})
                await create_timer(1.1).timeout
    await create_timer(.5).timeout
    var file:=FileAccess.open(output+"/timeline.json",FileAccess.WRITE);file.store_string(JSON.stringify(timeline,"  "));file.close()
    file=FileAccess.open(output+"/done",FileAccess.WRITE);file.store_string("done");file.close()
    await create_timer(.5).timeout
    change_scene_to_file(MENU);await scene_changed;await frames()
    lab=null;textures.clear();old=null
    print("RESULT: ",passed," diagnostic checks passed; ",failed," failed")
    call_deferred("quit",0 if failed==0 else 1)
