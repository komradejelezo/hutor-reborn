extends "res://tests/verify_combat_ui_61.gd"
const FX=preload("res://scripts/combat/ui/combat_effects.gd")
func shot(name:String) -> void:
    var out:=OS.get_environment("READABILITY_CAPTURE")
    if out.is_empty() or DisplayServer.get_name()=="headless":return
    DirAccess.make_dir_recursive_absolute(out);await RenderingServer.frame_post_draw
    check(root.get_texture().get_image().save_png(out+"/"+name+".png")==OK,"capture "+name)
func opaque(view:Control,label:String) -> void:
    for node in [view,view.body,view.sprite]:
        check(is_equal_approx(node.modulate.a,1) and is_equal_approx(node.self_modulate.a,1),"opaque modulation "+label+"/"+node.name)
    check(view.sprite.material is ShaderMaterial and view.sprite.material.shader.resource_path=="res://shaders/combat_readable.gdshader","single straight-alpha combat material "+label)
func run() -> void:
    change_scene_to_file(ARENA);await scene_changed;await frames()
    var arena:Control=current_scene;arena.fast.button_pressed=true
    check(not arena.journal.visible,"journal collapsed by default")
    arena._toggle_journal();await frames()
    check(arena.journal.visible and arena.journal.position.y+arena.journal.size.y<=114 and not arena.queue_label.visible,"journal opens in header, never over battlefield")
    arena._toggle_journal()
    check(arena.queue_label.visible and arena.turn_label.visible,"initiative and turn return after collapsing journal")
    for scenario in ["duel","tincture","forest","companions","betrayal"]:
        arena._start_scenario(scenario);await ready_turn(arena)
        for view in arena.views.values():
            opaque(view,scenario+"/"+view.unit.id)
            check(is_equal_approx((view.position+view.body.position).y,378),"one ground line "+view.unit.id)
            view.refresh(false,false,"");opaque(view,"inactive "+view.unit.id)
        arena._render();await shot(scenario+"-idle")
    for fixture in [["duel","hans"],["duel","wolf_a"],["tincture","herbalist"],["forest","beast"]]:
        arena._start_scenario(fixture[0]);await ready_turn(arena)
        var view:Control=arena.views[fixture[1]]
        var foot:Vector2=view.body.position
        for clip in ["idle","attack","hit","death"]:
            if clip=="death":view.unit.hp=0;view.reveal_health();view.refresh(false,false,"")
            var duration:float=0
            if view.animation:duration=view.animation.play(clip,3)
            if duration>0:
                if clip=="death":await create_timer(duration+.07).timeout
                else:await create_timer(maxf(.02,view.animation.key_time(clip,3))).timeout
            else:
                if clip=="attack":FX.strike(view,1,.15)
                if clip in ["hit","death"]:FX.hit(view,clip=="death",.15)
                await frames(2)
                check(view.body.position==foot,"fallback does not slide idle feet "+view.unit.id+"/"+clip)
            opaque(view,fixture[1]+"/"+clip)
            check(view.body.position==foot,"feet stay anchored "+fixture[1]+"/"+clip)
            await shot(fixture[1]+"-"+clip)
            if clip=="death" and view.animation:
                check(view.animation.dead and not view.sprite.is_playing(),"death remains terminal and visible "+fixture[1])
            elif duration>0:await create_timer(duration+.03).timeout
            else:await create_timer(.2).timeout
    # Preserve absent authored actions honestly: no invented herbalist combat clips.
    arena._start_scenario("tincture");await ready_turn(arena)
    check(arena.views.herbalist.animation==null and arena.views.herbalist.sprite.sprite_frames.has_animation("idle_right"),"herbalist retains approved frames and uses presentation fallback")
    var herb:AnimatedSprite2D=arena.views.herbalist.sprite
    var herb_bounds:=herb.sprite_frames.get_frame_texture(herb.animation,0).get_image().get_used_rect()
    check(herb.scale.x==herb.scale.y and herb_bounds.size.y*herb.scale.y>=117,"herbalist enlarged proportionally from approved high-resolution source")
    check(herb.animation=="idle_down","approved frontal herbalist Idle selected for combat readability")
    arena._toggle_journal();await shot("journal-open")
    print("RESULT: ",passed," combat readability checks passed, ",failed," failed")
    quit(0 if failed==0 else 1)
