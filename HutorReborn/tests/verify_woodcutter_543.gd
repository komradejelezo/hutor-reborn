extends "res://tests/verify_interiors.gd"
## Read-only visual comparison fixture; never saved into the playable world.
var output := "/tmp/wood543"
var actor:HutorResident
var sprite:AnimatedSprite2D
var caption:Label
var grade:Material
var life:Node
var samples:Array[Dictionary]=[]

func capture(name:String) -> void:
    if DisplayServer.get_name()=="headless":return
    await process_frame;await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(output+"-"+name+".png")

func pair(name:String) -> void:
    var shadow:CanvasItem=actor.get_node("Shadow")
    sprite.play("idle_down");sprite.pause();sprite.frame=0
    sprite.scale=Vector2.ONE;sprite.material=null;shadow.scale=Vector2.ONE
    caption.text="5.4.3 DIAGNOSTIC / "+name+" / BEFORE 1.00 / Hans unchanged"
    await frames(3);await capture(name+"-before")
    sprite.scale=Vector2.ONE*1.08;sprite.material=grade;shadow.scale=Vector2.ONE*1.08
    caption.text="5.4.3 DIAGNOSTIC / "+name+" / AFTER 1.08 / Hans unchanged"
    await frames(3);await capture(name+"-after")

func bounds(image:Image) -> Rect2i:
    return image.get_used_rect()

func raster_contract() -> void:
    if DisplayServer.get_name()=="headless":return
    var viewport:=SubViewport.new();viewport.size=Vector2i(128,128)
    viewport.transparent_bg=true;viewport.disable_3d=true;viewport.world_2d=World2D.new()
    viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
    var probe:=Sprite2D.new();probe.centered=false;probe.offset=Vector2(-48,-82)
    probe.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;probe.position=Vector2(64,96)
    probe.texture=sprite.sprite_frames.get_frame_texture("idle_down",0);viewport.add_child(probe)
    await process_frame;await RenderingServer.frame_post_draw
    var before:=viewport.get_texture().get_image()
    probe.material=grade
    await process_frame;await RenderingServer.frame_post_draw
    var after:=viewport.get_texture().get_image()
    var wrong_alpha:=0;var changed:=0;var l0:=0.0;var l1:=0.0
    var warm0:=0.0;var warm1:=0.0
    for y in 128:
        for x in 128:
            var a:=before.get_pixel(x,y);var b:=after.get_pixel(x,y)
            if absf(a.a-b.a)>.001:wrong_alpha+=1
            if a.a<.99:continue
            if not a.is_equal_approx(b):changed+=1
            l0+=a.get_luminance();l1+=b.get_luminance()
            warm0+=a.r-a.b;warm1+=b.r-b.b
    check(wrong_alpha==0,"palette preserves every alpha texel / no halo")
    check(changed>100 and l1/l0>.75 and l1/l0<1.0,"palette is visible but retains readable luminance")
    check(warm1<warm0,"warm red/blue separation is reduced")
    probe.scale=Vector2.ONE*1.08
    await process_frame;await RenderingServer.frame_post_draw
    var enlarged:=viewport.get_texture().get_image()
    var b0:=bounds(before);var b1:=bounds(enlarged)
    check(b1.size.y>b0.size.y and absf(float(b1.size.y)/b0.size.y-1.08)<.04,"visible height increases about eight percent")
    check(absi(b1.end.y-b0.end.y)<=1,"sole stays on the same ground baseline")
    var f:SpriteFrames=sprite.sprite_frames
    for clip in f.get_animation_names():
        for i in f.get_frame_count(clip):
            probe.texture=f.get_frame_texture(clip,i)
            await process_frame;await RenderingServer.frame_post_draw
            var box:=bounds(viewport.get_texture().get_image())
            check(box.position.x>0 and box.position.y>0 and box.end.x<128 and box.end.y<128,"scaled full-body bounds: "+String(clip)+"/"+str(i))
    samples.append({"raster_before":b0,"raster_after":b1,"luminance_ratio":l1/l0,"warm_before":warm0,"warm_after":warm1,"alpha_mismatches":wrong_alpha})
    viewport.queue_free();await process_frame

func run() -> void:
    if not OS.get_cmdline_user_args().is_empty():output=OS.get_cmdline_user_args()[0]
    travel=root.get_node("InteriorTravel");change_scene_to_file(travel.VILLAGE);await frames(12)
    life=root.get_node("VillageLife");life.clock.running=false;life.clock.seek(465);await frames(5)
    life.set_physics_process(false);life._widget.hide()
    var world:Node2D=travel.active_world
    actor=life.states[&"woodcutter"].actor;sprite=actor.get_node("AnimatedSprite2D");grade=sprite.material
    var identity:=actor.get_instance_id()
    for r in life.states.values():r.actor.set_physics_process(false)
    world.player.set_physics_process(false);world.hud.hide()
    check(sprite.scale==Vector2.ONE*1.08 and sprite.material!=null,"only pilot scene loads uniform finish and colour grade")
    for id in life.states:
        if id==&"woodcutter":continue
        var other:AnimatedSprite2D=life.states[id].actor.get_node("AnimatedSprite2D")
        check(other.scale==Vector2.ONE and other.material==null,"other resident presentation unchanged: "+String(id))
    var feet:CapsuleShape2D=actor.get_node("Feet").shape
    check(feet.radius==actor.definition.foot_radius and actor.scale==Vector2.ONE,"body/navigation radius remains original; only art grows")
    var found:=false
    for y in range(1400,1750,16):
        for x in range(1100,1550,16):
            if free_at(world,Vector2(x,y),7) and free_at(world,Vector2(x+60,y),7):
                actor.position=Vector2(x,y);world.player.position=Vector2(x+60,y);found=true;break
        if found:break
    check(found,"comparison positions have clear foot collisions")
    actor.state=actor.State.WAITING;actor.facing=&"down";world.player.sprite.play("idle_down")
    var cam:Camera2D=world.player.get_node("Camera2D");cam.set_as_top_level(true);cam.position_smoothing_enabled=false
    cam.position=actor.position+Vector2(30,-50);cam.force_update_scroll()
    var layer:=CanvasLayer.new();layer.layer=95;root.add_child(layer)
    caption=Label.new();caption.position=Vector2(8,4);caption.add_theme_font_size_override("font_size",14);layer.add_child(caption)
    var light:CanvasModulate=world.get_node("Lighting/Evening");var original_light:=light.color
    for entry in [[720,"day"],[1140,"evening"],[1380,"night"]]:
        # Clock phase observation only: no schedule seeking/actor reconstruction.
        life.clock.absolute_minutes=entry[0];root.get_node("AmbientDirector")._refresh_audio()
        await pair(entry[1])
        samples.append({"phase":entry[1],"minute":entry[0],"canvas_modulate":light.color})
    check(light.color==original_light,"clock phases do not replace the existing static world tint")
    light.color=Color(.38,.45,.56)
    await pair("night-stress-test-only")
    light.color=original_light
    await raster_contract()
    life.clock.seek(425)
    check(travel.request_transition(&"woodcutter"),"existing home transition works with scaled pilot")
    await wait_transition();world=travel.active_world
    for r in life.states.values():r.actor.set_physics_process(false)
    actor=life.states[&"woodcutter"].actor;sprite=actor.get_node("AnimatedSprite2D")
    world.player.set_physics_process(false);world.hud.hide();life._widget.hide()
    actor.position=world.get_node("NPCPoints/FatherRest").position;actor.state=actor.State.WAITING;actor.facing=&"down"
    world.player.position=actor.position+Vector2(60,0);world.player.sprite.play("idle_down")
    check(free_at(world,actor.position,actor.definition.foot_radius),"original FatherRest feet remain outside furniture")
    check(actor.get_instance_id()==identity,"same original actor crosses scenes")
    cam=world.player.get_node("Camera2D");cam.set_as_top_level(false);cam.position_smoothing_enabled=false;cam.reset_smoothing();cam.force_update_scroll()
    check(cam.zoom.is_equal_approx(Vector2(1.3,1.3)),"interior camera stays at approved scale")
    await pair("home-warm-light")
    actor.get_node("Interaction").position=Vector2.ZERO
    world.player.position=actor.position+Vector2(0,24);await frames(6)
    check(world.player.sensor.target==actor.get_node("Interaction"),"real E selects the original woodcutter")
    await tap_e();await create_timer(.4).timeout
    var dm:Node=root.get_node("DialogueManager")
    check(dm.is_active(),"existing dialogue opens")
    if dm.is_active():
        dm.window.reveal_all();var line:Dictionary=dm.data.nodes[dm.current_line]
        var p:TextureRect=dm.window.portrait
        for emotion in ["neutral","joy","displeased","anxious"]:
            var variant:=line.duplicate(true);variant.emotion=emotion;dm.window.show_line(variant);dm.window.reveal_all()
            check(p.size==Vector2(128,192),"native portrait size / "+emotion)
            check(p.position==p.position.floor() and p.get_rect().end.x<p.get_parent().size.x and p.get_rect().end.y<p.get_parent().size.y,"integer placement fits existing frame / "+emotion)
            if emotion=="neutral":
                var saved:=Rect2(p.position,p.size)
                p.position=dm.window._portrait_default_rect.position;p.size=dm.window._portrait_default_rect.size
                caption.text="5.4.3 DIAGNOSTIC / PORTRAIT BEFORE / original pixels, fractional downsample"
                await capture("portrait-before")
                p.position=saved.position;p.size=saved.size
            caption.text="5.4.3 DIAGNOSTIC / PORTRAIT AFTER 1:1 / "+emotion
            await capture("portrait-"+emotion+"-after")
        var old_line:=line.duplicate(true)
        old_line.portraits=HutorNpcVisualLibrary.profile(&"elder").portraits
        dm.window.show_line(old_line)
        check(Rect2(p.position,p.size)==dm.window._portrait_default_rect,"next resident restores original portrait layout")
        dm.close_dialogue()
    var file:=FileAccess.open(output+"-measurements.json",FileAccess.WRITE);file.store_string(JSON.stringify(samples,"  "));file.close()
    print("RESULT: ",passed," finish/raster/portrait checks passed, ",failed," failed")
    quit(0 if failed==0 else 1)
