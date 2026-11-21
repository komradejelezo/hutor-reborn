extends "res://tests/verify_combat_ui_61.gd"
## External diagnostic only; replaces textures on duplicated memory resources.
var lab:Control
var pilot:SpriteFrames
var current:SpriteFrames
var textures:Array=[]
var seen:Dictionary={}
var timeline:Array=[]
var output:=OS.get_environment("PILOT_CAPTURE_OUT")
var directory:=OS.get_environment("PILOT_DIRECTORY")
func observe() -> void:
    if not is_instance_valid(lab):return
    var s:AnimatedSprite2D=lab.actors[1].sprite
    if s.animation=="dodge":seen[s.frame]=true
    lab.counter.text="%s · кадр %02d · ×%.1f"%["Уклонение" if s.animation=="dodge" else "Покой",s.frame+1,s.speed_scale]
func run() -> void:
    check(not output.is_empty() and not directory.is_empty(),"diagnostic paths supplied")
    if failed:quit(1);return
    DirAccess.make_dir_recursive_absolute(output)
    root.size=Vector2i(960,540);root.position=Vector2i(20,20)
    change_scene_to_file("res://scenes/combat/CombatGraphicsLab.tscn");await scene_changed;await frames()
    lab=current_scene;lab.set_process(false)
    current=lab.actors[1].sprite.sprite_frames.duplicate(true)
    pilot=current.duplicate(true)
    for number in [6,7,8]:
        var image:=Image.load_from_file(directory+"/restored/dodge_%02d.png"%number)
        print("PILOT_INPUT_",number,": ",FileAccess.get_sha256(directory+"/restored/dodge_%02d.png"%number))
        check(image!=null and image.get_size()==Vector2i(357,358),"pilot canvas unchanged "+str(number))
        var texture:=ImageTexture.create_from_image(image);textures.append(texture)
        var atlas:AtlasTexture=pilot.get_frame_texture("dodge",number-1).duplicate()
        var old_margin:=atlas.margin
        atlas.atlas=texture;pilot.set_frame("dodge",number-1,atlas)
        check(atlas.margin==old_margin and atlas.region.size==Vector2(357,358),"registration preserved "+str(number))
    check(pilot.get_animation_speed("dodge")==current.get_animation_speed("dodge") and pilot.get_frame_count("dodge")==12,"FPS/order untouched")
    lab.actors[0].sprite.sprite_frames=current;lab.actors[1].sprite.sprite_frames=pilot
    for label in lab.find_children("*","Label",true,false):
        if label.text.begins_with("Слева:"):label.text="Слева — текущая игра / справа — частичная пробная реставрация (06–08)"
    for i in lab.clips.item_count:
        if lab.clips.get_item_text(i)=="dodge":lab.clips.select(i)
    for bg in [2,3,0]:
        lab.background.select(bg);lab.background.item_selected.emit(bg);lab.stop()
        var sheet:=Image.create(560,850,false,Image.FORMAT_RGBA8)
        for number in [5,6,7,8,9]:
            lab.set_frame(number-1);await process_frame;await RenderingServer.frame_post_draw
            var image:=root.get_texture().get_image();var pos:=Vector2i(0,(number-5)*170)
            sheet.blit_rect(image,Rect2i(80,265,280,170),pos)
            sheet.blit_rect(image,Rect2i(540,265,280,170),pos+Vector2i(280,0))
            check(lab.actors[1].sprite.frame==number-1,"exact frame "+str(number)+" bg "+str(bg))
            check(lab.actors[0].sprite.scale==lab.actors[1].sprite.scale,"same scale")
            check(lab.actors[0].body.position==lab.actors[1].body.position,"same local foot anchor")
        check(sheet.save_png(output+"/lab-bg"+str(bg)+".png")==OK,"save actual contrast/forest pair")
    for view in lab.actors:view.animation.diagnostic_hold=false
    lab.actors[1].sprite.frame_changed.connect(observe)
    process_frame.connect(observe)
    lab.background.select(2);lab.background.item_selected.emit(2);lab.stop();observe()
    lab.status.text="Фрагмент 05 → 06 → 07 → 08 → 09 — в полном исходном цикле; опора и скорость прежние.\nПилот частичный: большие неподтверждённые разрывы плаща оставлены для художника."
    var file:=FileAccess.open(output+"/ready",FileAccess.WRITE);file.store_string("ready");file.close()
    await create_timer(1).timeout
    var began:=Time.get_ticks_msec()
    for bg in [2,3]:
        lab.background.select(bg);lab.background.item_selected.emit(bg)
        for rate in [.5,1.0]:
            lab.rate=rate
            for control in lab.get_children():
                if control is SpinBox and control.position.x==540:control.value=rate
            for repeat in 2:
                seen.clear();var start:=Time.get_ticks_msec()
                lab.play(true);observe()
                await create_timer(lab.actors[1].animation.duration("dodge",rate)+.12).timeout
                check(seen.size()==12,"all frames observed, including 05-09")
                check(lab.actors[0].animation.motion=="idle" and lab.actors[1].animation.motion=="idle","both normal Idle returns")
                timeline.append({"background":bg,"speed":rate,"repeat":repeat+1,"start_ms":start-began,"idle_ms":Time.get_ticks_msec()-began,"frames_observed":seen.keys()})
                await create_timer(.8).timeout
    file=FileAccess.open(output+"/timeline.json",FileAccess.WRITE);file.store_string(JSON.stringify(timeline,"  "));file.close()
    file=FileAccess.open(output+"/done",FileAccess.WRITE);file.store_string("done");file.close()
    await create_timer(.6).timeout
    # Same existing battle arena, paused only at a diagnostic actor pose.
    lab=null;change_scene_to_file(ARENA);await scene_changed;await frames()
    var arena:Control=current_scene;arena.fast.button_pressed=true
    arena._start_scenario("forest");await ready_turn(arena)
    var hero:Control=arena.views.hans
    for number in [6,7,8]:
        for after in ([false,true] if number==7 else [true]):
            hero.sprite.sprite_frames=pilot if after else current
            hero.animation.diagnostic_hold=true;hero.animation.play("dodge",1);hero.sprite.pause();hero.sprite.frame=number-1
            await frames(2);await RenderingServer.frame_post_draw
            var name:="arena-%02d-%s.png"%[number,"after" if after else "before"]
            check(root.get_texture().get_image().save_png(output+"/"+name)==OK,"actual forest battle capture "+name)
    arena._cancel();change_scene_to_file(MENU);await scene_changed;await frames()
    textures.clear();current=null;pilot=null
    print("RESULT: ",passed," pilot display checks passed; ",failed," failed")
    call_deferred("quit",0 if failed==0 else 1)
