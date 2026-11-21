extends "res://tests/verify_combat_ui_61.gd"
## External experimental viewer. Game scenes/resources are never written.
const STYLE=preload("res://scripts/combat/ui/style.gd")
var directory:=OS.get_environment("HANS_REBORN_DIR")
var output:=OS.get_environment("HANS_REBORN_CAPTURE")
var canvas:Control
var forest:Control
var backdrop:ColorRect
var old:AnimatedSprite2D
var fresh:AnimatedSprite2D
var new_frames:SpriteFrames
var counter:Label
var control:OptionButton
var seen:Dictionary={}
var manifest:Dictionary
var seen_all:Dictionary={}
func observe() -> void:
    if not is_instance_valid(fresh):return
    seen[fresh.frame]=true
    if is_instance_valid(counter):counter.text="Новый кадр %02d / 12 · цикл 3 с"%(fresh.frame+1)
func background(index:int) -> void:
    forest.visible=index==0
    backdrop.color=[Color.BLACK,Color.WHITE,Color.MAGENTA,Color.BLACK][index]
func run() -> void:
    check(not directory.is_empty(),"experimental path supplied")
    if failed:quit(1);return
    root.size=Vector2i(960,540);root.position=Vector2i(20,20)
    manifest=JSON.parse_string(FileAccess.get_file_as_string(directory+"/MANIFEST.json"))
    new_frames=SpriteFrames.new();new_frames.remove_animation("default");new_frames.add_animation("idle")
    new_frames.set_animation_loop("idle",true);new_frames.set_animation_speed("idle",1.0/float(manifest.frame_seconds))
    for f in manifest.frames:
        var path:String=directory+"/"+f.file
        check(FileAccess.get_sha256(path)==f.sha256,"frozen frame SHA "+str(f.frame))
        var image:=Image.load_from_file(path)
        check(image.get_size()==Vector2i(1280,1280),"native canvas "+str(f.frame))
        new_frames.add_frame("idle",ImageTexture.create_from_image(image))
    canvas=Control.new();root.add_child(canvas);current_scene=canvas;canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);canvas.theme=STYLE.theme()
    backdrop=ColorRect.new();backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);canvas.add_child(backdrop)
    forest=load("res://scenes/combat/CombatForestStage.tscn").instantiate();canvas.add_child(forest)
    STYLE.hud_backdrop(canvas,145,460)
    STYLE.label(canvas,"ГАНС REBORN · экспериментальный Idle v1",Vector2(18,8),Vector2(920,32),23,true)
    control=OptionButton.new();control.position=Vector2(18,53);control.size=Vector2(240,30)
    for name in ["Лесная арена","Белый","Ярко-розовый","Чёрный"]:control.add_item(name)
    canvas.add_child(control);control.item_selected.connect(background)
    STYLE.button(canvas,"Воспроизвести",Vector2(278,53),Vector2(190,30),func():old.play("idle");fresh.play("idle"))
    STYLE.button(canvas,"Пауза",Vector2(480,53),Vector2(100,30),func():old.pause();fresh.pause())
    STYLE.button(canvas,"Кадр →",Vector2(592,53),Vector2(120,30),func():fresh.pause();fresh.frame=(fresh.frame+1)%12;observe())
    STYLE.button(canvas,"Закрыть",Vector2(726,53),Vector2(210,30),func():quit())
    STYLE.label(canvas,"Утверждённый Hans Idle v2",Vector2(85,102),Vector2(370,28),19,true)
    STYLE.label(canvas,"Новая общая модель · 12 фаз",Vector2(520,102),Vector2(410,28),19,true)
    counter=STYLE.label(canvas,"",Vector2(560,470),Vector2(380,26),16)
    STYLE.label(canvas,"Голова, снаряжение и стопы фиксированы. Без цветового ключа. Новая версия не подключена к игре.",Vector2(18,505),Vector2(925,24),13)
    old=AnimatedSprite2D.new();old.centered=false;old.sprite_frames=load("res://assets/combat/forest_v2/prepared/Hans/frames.tres")
    old.offset=Vector2(-600,-650);old.position=Vector2(270,420);old.scale=Vector2.ONE*(248.0/177.0);old.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;canvas.add_child(old);old.play("idle")
    fresh=AnimatedSprite2D.new();fresh.centered=false;fresh.sprite_frames=new_frames;fresh.offset=Vector2(-706,-1185)
    fresh.position=Vector2(700,420);fresh.scale=Vector2.ONE*(248.0/1077.0);fresh.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;canvas.add_child(fresh);fresh.play("idle")
    fresh.frame_changed.connect(observe);process_frame.connect(observe);background(0);observe()
    if output.is_empty():return
    DirAccess.make_dir_recursive_absolute(output)
    old.pause();old.frame=0
    for bg in range(4):
        control.select(bg);background(bg)
        var sheet:=Image.create(1200,840,false,Image.FORMAT_RGBA8)
        for i in 12:
            fresh.pause();fresh.frame=i;await process_frame;await RenderingServer.frame_post_draw
            var image:=root.get_texture().get_image();var pos:=Vector2i((i%4)*300,(i/4)*280)
            sheet.blit_rect(image,Rect2i(550,165,300,280),pos)
            check(fresh.frame==i and fresh.scale.x==fresh.scale.y and fresh.modulate.a==1,"exact frame/uniform scale/opacity "+str(i+1)+" bg "+str(bg))
        check(sheet.save_png(output+"/new-bg"+str(bg)+".png")==OK,"save contrast atlas "+str(bg))
        fresh.frame=0;await process_frame;await RenderingServer.frame_post_draw
        root.get_texture().get_image().save_png(output+"/comparison-bg"+str(bg)+".png")
    control.select(1);background(1);old.play("idle");fresh.play("idle")
    var file:=FileAccess.open(output+"/ready",FileAccess.WRITE);file.store_string("ready");file.close()
    await create_timer(1).timeout
    for bg in [1,2,3,0]:
        control.select(bg);background(bg);seen.clear();fresh.stop();fresh.play("idle");observe()
        await create_timer(6.1).timeout
        check(seen.size()==12,"all twelve phases visible in two loops bg "+str(bg));seen_all[str(bg)]=seen.keys()
    # Show the new animation in the existing forest battle, in memory only.
    canvas=null;old=null;fresh=null;counter=null
    change_scene_to_file(ARENA);await scene_changed;await frames()
    var arena:Control=current_scene;arena._start_scenario("forest");await ready_turn(arena)
    var hero:Control=arena.views.hans
    var foot:Vector2=hero.body.global_position
    hero.sprite.sprite_frames=new_frames;hero.sprite.centered=false;hero.sprite.offset=Vector2(-706,-1185)
    hero.sprite.scale=Vector2.ONE*(124.0/1077.0);hero.sprite.play("idle")
    await create_timer(3.1).timeout
    check(hero.body.global_position==foot and hero.sprite.modulate.a==1 and hero.sprite.self_modulate.a==1,"existing forest arena anchor and opacity")
    await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(output+"/arena.png")
    await create_timer(3.1).timeout
    file=FileAccess.open(output+"/motion_checks.json",FileAccess.WRITE);file.store_string(JSON.stringify(seen_all,"  "));file.close()
    file=FileAccess.open(output+"/done",FileAccess.WRITE);file.store_string("done");file.close()
    await create_timer(.6).timeout
    arena._cancel();change_scene_to_file(MENU);await scene_changed;await frames()
    new_frames=null;hero=null;arena=null
    print("RESULT: ",passed," experimental Idle display checks passed; ",failed," failed")
    call_deferred("quit",0 if failed==0 else 1)
