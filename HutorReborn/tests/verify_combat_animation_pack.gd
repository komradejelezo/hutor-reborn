extends "res://tests/verify_combat_ui_61.gd"
const DRIVER=preload("res://scripts/combat/animation/combat_animation.gd")
const ROOT=DRIVER.ROOT
func run() -> void:
    var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"library.json"))
    for kind in ["hans","wolf","beast"]:
        var holder:=Node2D.new();root.add_child(holder)
        var sprite:=AnimatedSprite2D.new();holder.add_child(sprite)
        var driver:=DRIVER.new();holder.add_child(driver)
        check(driver.configure(sprite,kind,0),"configure existing actor "+kind)
        check(sprite.texture_filter==CanvasItem.TEXTURE_FILTER_NEAREST,"nearest "+kind)
        var key:String="leshy" if kind=="beast" else kind
        var clips:Dictionary=data[key]
        for clip in clips:
            var spec:Dictionary=clips[clip]
            var expected:int=spec.frames.size()*2-2 if spec.pingpong else spec.frames.size()
            check(sprite.sprite_frames.get_frame_count(clip)==expected,"curated frame order "+key+"/"+clip)
            check(sprite.sprite_frames.get_animation_loop(clip)==(clip=="idle"),"one shot except idle "+key+"/"+clip)
            check(is_equal_approx(sprite.sprite_frames.get_animation_speed(clip),1000.0/spec.ms),"timing "+key+"/"+clip)
            for frame in spec.frames:
                var b:Array=frame.bbox;var o:Array=frame.origin
                var scale_value:float=driver.ground_scale*spec.scale
                var lo:Vector2=Vector2(b[0]-o[0],b[1]-o[1])*scale_value
                var hi:Vector2=Vector2(b[2]-o[0],b[3]-o[1])*scale_value
                # Actual alpha bounds, not the transparent atlas padding.
                var center:=Vector2(239,288) if kind=="hans" else Vector2(499,288)
                if kind!="hans":var swap:=lo.x;lo.x=-hi.x;hi.x=-swap
                check((center+lo).x>=0 and (center+hi).x<720 and (center+lo).y>100 and (center+hi).y<430,"visible source fits combat stage: "+frame.path.get_file())
        for clip in ["attack","hit","dodge","victory","use_invoke"]:
            var duration:float=driver.play(clip,3)
            if driver.has(clip):
                check(duration>0 and sprite.scale.x==sprite.scale.y,"uniform fixed calibration "+key+"/"+clip)
                await create_timer(duration+.07).timeout
                check(driver.motion=="idle","action returns to idle "+key+"/"+clip)
            else:check(duration==0,"missing optional clip safe fallback "+key+"/"+clip)
        var death_time:float=driver.play("death",3);await create_timer(death_time+.06).timeout
        check(driver.dead and sprite.frame==sprite.sprite_frames.get_frame_count("death")-1 and not sprite.is_playing(),"death holds final frame "+key)
        check(driver.play("idle")==0 and driver.play("death")==0,"refresh cannot resurrect or repeat death "+key)
        holder.queue_free();await frames()
    var sprite:=AnimatedSprite2D.new();root.add_child(sprite)
    var original:=SpriteFrames.new();sprite.sprite_frames=original
    var missing:=DRIVER.new();root.add_child(missing)
    check(not missing.configure(sprite,"hans",0,"res://missing-animation-pack/") and sprite.sprite_frames==original,"missing resource preserves original sprite fallback")
    sprite.queue_free();missing.queue_free();await frames()
    change_scene_to_file(ARENA);await scene_changed;await frames()
    var arena:Control=current_scene;arena.fast.button_pressed=true
    arena._start_scenario("duel");await ready_turn(arena)
    check(arena.views.hans.animation!=null and arena.views.wolf_a.animation!=null,"ordinary arena uses new actors")
    arena.battle.units.wolf_a.hp=1;arena.views.wolf_a.reveal_health();arena.battle.units.hans.accuracy=100
    var key_seen:=[]
    arena.animation_keyframe.connect(func(e:Dictionary):
        if e.type=="attack":key_seen.append({"target":e.target,"hp":arena.views[e.target].presented_hp,"frame":arena.views[e.actor].sprite.frame,"dead":arena.views[e.target].animation.dead}))
    arena._target("wolf_a")
    check(arena.battle.units.wolf_a.hp==0 and arena.views.wolf_a.presented_hp==1,"unchanged immediate math; HP display deferred to key frame")
    check(arena.busy and not is_instance_valid(arena.modal),"next phase locked before impact")
    for i in 300:
        if key_seen.size()>0:break
        await physics_frame
    check(key_seen.size()==1 and key_seen[0].hp==0 and key_seen[0].dead,"damage popup/HP/death start together")
    check(abs(key_seen[0].frame-6)<=1,"Hans impact aligns with sword key frame")
    check(arena.busy and not is_instance_valid(arena.modal),"wait for death/recovery before result")
    await ready_turn(arena)
    check(arena.views.wolf_a.animation.dead and arena.views.wolf_a.sprite.frame==23,"death final pose persists through result")
    check(arena.views.hans.animation.motion=="idle" and is_instance_valid(arena.modal),"Victory plays once before result")
    arena._start_scenario("forest");await ready_turn(arena)
    check(arena.views.beast.unit.name=="Леший" and arena.views.beast.animation.kind=="leshy","canonical leshy uses existing beast ID and stats")
    arena.battle.units.beast.hp=1;arena.views.beast.reveal_health();arena.battle.units.hans.accuracy=100
    arena._target("beast");arena._start_scenario("duel");await ready_turn(arena)
    check(arena.battle.units.wolf_a.hp==64 and arena.views.wolf_a.presented_hp==64,"restart cancels old key frame without mutating new fight")
    for fixture in [["duel","wolf_a",13],["forest","beast",12]]:
        arena._start_scenario(fixture[0]);await ready_turn(arena)
        var impacts:=[]
        var observer:=func(e:Dictionary):
            if e.type=="attack" and e.actor==fixture[1]:
                var bolts:=0
                for child in arena.get_children():
                    if child.has_meta("combat_transient"):bolts+=1
                impacts.append({"frame":arena.views[e.actor].sprite.frame,"hp":arena.views.hans.presented_hp,"resolved":arena.battle.units.hans.hp,"bolts":bolts})
        arena.animation_keyframe.connect(observer)
        arena._select_action("defend");await ready_turn(arena)
        check(impacts.size()==1,"actual enemy turn reaches one impact: "+fixture[1])
        if impacts.size()==1:
            check(abs(impacts[0].frame-fixture[2])<=1,"enemy impact aligns with bite/magic frame: "+fixture[1])
            check(impacts[0].hp==impacts[0].resolved,"enemy HP presentation synchronized: "+fixture[1])
            check(impacts[0].bolts==(1 if fixture[1]=="beast" else 0),"green VFX belongs only to leshy: "+fixture[1])
        arena.animation_keyframe.disconnect(observer)
    arena._start_scenario("duel");await ready_turn(arena)
    arena.battle.units.hans.hp-=20;arena.views.hans.reveal_health()
    var before_use:int=arena.views.hans.presented_hp
    var uses:=[]
    var use_observer:=func(e:Dictionary):
        if e.type=="heal":uses.append({"frame":arena.views.hans.sprite.frame,"hp":arena.views.hans.presented_hp,"resolved":arena.battle.units.hans.hp})
    arena.animation_keyframe.connect(use_observer)
    arena._select_action("item");arena._target("hans")
    check(arena.views.hans.animation.motion=="use_invoke" and arena.views.hans.presented_hp==before_use,"item uses generic Invoke and defers HP until key frame")
    await ready_turn(arena)
    check(uses.size()==1,"item emits one presentation key frame")
    if uses.size()==1:
        check(abs(uses[0].frame-7)<=1 and uses[0].hp==uses[0].resolved and uses[0].hp>before_use,"healing synchronized with Invoke key frame")
    arena.animation_keyframe.disconnect(use_observer)
    change_scene_to_file("res://scenes/combat/CombatAnimationReview.tscn");await scene_changed;await frames()
    check(current_scene.drivers.size()==3,"F6 review contains exactly three existing actor models")
    change_scene_to_file(MENU);await scene_changed;await frames()
    print("RESULT: ",passed," animation pack checks passed, ",failed," failed")
    quit(0 if failed==0 else 1)
