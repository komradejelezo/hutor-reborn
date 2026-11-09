extends "res://tests/verify_interiors.gd"
var ambient: Node
var result: Dictionary={}
var output_folder: String=""

func capture_audio(capture: AudioEffectCapture, seconds: float) -> Dictionary:
    capture.clear_buffer();await create_timer(seconds).timeout
    var frames: PackedVector2Array=capture.get_buffer(capture.get_frames_available())
    var sum:=0.0;var peak:=0.0
    for sample in frames:
        sum+=sample.length_squared();peak=maxf(peak,maxf(absf(sample.x),absf(sample.y)))
    return {"frames":frames,"rms":sqrt(sum/maxi(1,frames.size()*2)),"peak":peak}

func save_wave(frames: PackedVector2Array, filename: String) -> void:
    var wave:=AudioStreamWAV.new();wave.format=AudioStreamWAV.FORMAT_16_BITS
    wave.stereo=true;wave.mix_rate=int(AudioServer.get_mix_rate())
    var bytes:=PackedByteArray();bytes.resize(frames.size()*4)
    for i in frames.size():
        bytes.encode_s16(i*4,int(clampf(frames[i].x,-1,1)*32767))
        bytes.encode_s16(i*4+2,int(clampf(frames[i].y,-1,1)*32767))
    wave.data=bytes;wave.save_to_wav(filename)

func run() -> void:
    travel=root.get_node("InteriorTravel");ambient=root.get_node("AmbientDirector")
    change_scene_to_file(travel.VILLAGE);await frames(25)
    var life:Node=root.get_node("VillageLife");life.clock.running=false
    if not OS.get_cmdline_user_args().is_empty():
        output_folder=OS.get_cmdline_user_args()[0];DirAccess.make_dir_recursive_absolute(output_folder)
    var village:Node2D=current_scene
    check(ambient.world==village and ambient.scene_id=="village","normal village binds ambient service")
    check(ambient.mixer.get_child_count()==6,"fixed six-player pool")
    var original_count:int=ambient.mixer.get_child_count()
    var identities:Dictionary={}
    for id in life.states:identities[id]=life.states[id].actor.get_instance_id()
    ambient.configure({"crossfade_seconds":.3,"outdoor_event_seconds":[999,999],"indoor_event_seconds":[999,999],"visual_event_seconds":[999,999]})
    var phase_capture:=AudioEffectCapture.new();phase_capture.buffer_length=2
    var ambient_bus:=AudioServer.get_bus_index("HutorAmbient");AudioServer.add_bus_effect(ambient_bus,phase_capture)
    for pair in [[600,"day","forest_day"],[1080,"evening","wind_bed"],[1320,"night","wind_bed"],[420,"morning","forest_day"]]:
        life.clock.seek(pair[0]);await create_timer(.7).timeout
        check(ambient.phase==pair[1],"existing clock phase: "+pair[1])
        check(ambient.mixer._bed_key==pair[2],"correct phase sound: "+pair[1])
        check(ambient.mixer.beds.filter(func(p):return p.playing).size()==1,"one settled bed: "+pair[1])
        check(ambient.mixer.playing_count()<=6,"voice cap during phase change")
        var sample:Dictionary=await capture_audio(phase_capture,.6)
        check(sample.rms>.0005 and sample.peak<.98,"actual phase PCM audible-level floor without clipping: "+pair[1])
        result[pair[1]+"_audio"]={"rms":sample.rms,"peak":sample.peak}
        if not output_folder.is_empty():save_wave(sample.frames,output_folder+"/"+pair[1]+".wav")
    AudioServer.remove_bus_effect(ambient_bus,AudioServer.get_bus_effect_count(ambient_bus)-1)
    ambient.mixer.play_detail("bird",village.player.position,"outdoor")
    life.clock.seek(1320);await create_timer(.3).timeout
    check(not ambient.mixer.details.any(func(p):return p.playing and p.get_meta("ambient_key","")=="bird"),"day bird detail fades out when night begins")
    var timer_before:float=ambient._audio_left
    paused=true;await create_timer(.3).timeout
    check(is_equal_approx(ambient._audio_left,timer_before),"pause freezes ambient scheduling")
    paused=false
    ambient.set_volume_db(-18,"master",false)
    check(is_equal_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("HutorAmbient")),-18),"master volume API reaches actual audio bus")
    ambient.set_volume_db(-3,"master",false)
    check(not ambient.mixer.available("crickets") and not ambient.mixer.available("dishes"),"missing natural recordings remain honest empty slots")
    check(ambient.sounds.keys().size()==16,"extensible catalog includes missing categories")
    ambient.configure({"audio_enabled":false});await create_timer(.4).timeout
    check(ambient.mixer.playing_count()==0,"audio disable fades all voices")
    ambient.configure({"audio_enabled":true,"visuals_enabled":false});await frames(15)
    check(not ambient.effects.dust.emitting and not ambient.effects.motes.emitting,"visuals independently disabled")
    ambient.configure({"visuals_enabled":true})
    village.atmosphere.set_effects_enabled(false);await create_timer(.4).timeout
    check(ambient.mixer.playing_count()==0,"F3 atmosphere toggle also silences new ambience")
    check(not ambient.effects.puff.emitting,"F3 stops decorative particles")
    village.atmosphere.set_effects_enabled(true);await create_timer(.4).timeout
    check(ambient.mixer.playing_count()>0,"F3 restore resumes phase ambience")
    for _i in 18:ambient.trigger_audio_event()
    check(ambient.mixer.playing_count()<=6,"detail burst never exceeds fixed voice budget")
    ambient.configure({"max_voices":3})
    check(ambient.mixer.playing_count()<=3,"lowering budget retires excess voices")
    ambient.mixer.set_hearth(village.player.position,true,"outdoor")
    check(ambient.mixer.playing_count()<=3,"hearth respects reduced voice budget")
    life.clock.seek(600);await frames(3)
    check(ambient.mixer.playing_count()<=3,"crossfade also respects reduced voice budget")
    ambient.configure({"max_voices":6})
    for id in [&"inn",&"elder",&"herbalist",&"woodcutter",&"old_man",&"storehouse"]:
        life.clock.seek(1215)
        var previous:Node=ambient.effects
        check(travel.request_transition(id),"enter existing interior "+String(id));await wait_transition();await create_timer(.3).timeout
        check(ambient.scene_id==String(id) and ambient.world==current_scene,"interior profile connected: "+String(id))
        check(ambient.mixer._bed_key=="" and not ambient.mixer.beds.any(func(p):return p.playing),"street bed absent indoors: "+String(id))
        check(ambient.mixer.hearth.playing==(id!=&"storehouse"),"correct spatial fire presence: "+String(id))
        if id==&"storehouse":
            ambient._last_event="wood_creak"
            check(not ambient.trigger_audio_event() and ambient._last_event=="","single-recording room inserts a silent interval")
            check(ambient.trigger_audio_event(),"single-recording room can play again after silence")
        if id==&"woodcutter":
            var worker:HutorResident=life.states[&"woodcutter_wife"].actor
            var old_state:int=worker.state
            worker.set_physics_process(false);worker.state=HutorResident.State.WAITING
            var old_position:=worker.position
            var played_before:int=ambient.mixer.events_played
            ambient._audio_left=0;ambient._occupation(&"woodcutter_wife",&"household")
            check(ambient.mixer.events_played==played_before+1,"occupation signal routes a real spatial household recording")
            check(worker.position==old_position and worker.state==HutorResident.State.WAITING,"household audio changes no actor motion or state")
            worker.state=old_state;worker.set_physics_process(true)
        check(ambient.effects.dust.emitting,"sparse room dust active: "+String(id))
        var amount:int=ambient.effects.dust.amount+ambient.effects.motes.amount+ambient.effects.puff.amount
        check(amount<=ambient.settings.max_new_particles,"particle capacity bounded: "+String(id))
        check(not previous.is_inside_tree() and not previous.motes.emitting and not previous.puff.emitting,"detached scene decorations inactive")
        for npc_id in identities:check(life.states[npc_id].actor.get_instance_id()==identities[npc_id],"same resident "+String(npc_id)+" in "+String(id))
        var fx:Node=ambient.effects
        var event_count:int=fx.decorative_events
        for i in 4:fx.trigger()
        check(fx.decorative_events>event_count,"rare flame decoration can run: "+String(id))
        result[String(id)]={"dust":fx.dust.amount,"motes":fx.motes.amount,"puff":fx.puff.amount,"spatial_fire":ambient.mixer.hearth.playing}
        check(travel.request_transition(id,true),"exit existing interior "+String(id));await wait_transition();await create_timer(.3).timeout
        check(not fx.is_inside_tree() and not fx.dust.emitting,"cached room stops dust: "+String(id))
        check(ambient.scene_id=="village" and not current_scene.player.controls_locked,"outside control and ambience restore")
    check(ambient.mixer.get_child_count()==original_count,"transitions never recreate audio players")
    check(ambient.events.size()<=64,"event history bounded")
    # Only presentation may vary; even a forced due visual glance cannot mutate state.
    life.clock.seek(730);check(travel.request_transition(&"inn"),"enter inn for visual cue");await wait_transition();await frames(20)
    var record:HutorDailyResidentState=life.states[&"innkeeper"]
    record.actor.set_physics_process(false);record.actor.state=HutorResident.State.WAITING
    var before:=[record.actor.position,record.actor.state,record.actor.wait_left,record.actor.step_index,record.actor.scale,record.actor.rotation]
    ambient._glances[record.id]={"next":0.0,"until":0.0}
    var direction:StringName=ambient.glance_direction(record.actor,record)
    check(direction!=&"","existing-frame shelf glance available")
    check(before==[record.actor.position,record.actor.state,record.actor.wait_left,record.actor.step_index,record.actor.scale,record.actor.rotation],"glance changes no transform, routine or wait")
    record.actor.set_physics_process(true)
    check(travel.request_transition(&"inn",true),"leave visual-cue test");await wait_transition()
    # Actual audio-server output, using licensed fire, not a generated test signal.
    ambient.set_process(false);ambient.configure({"master_volume_db":0,"outdoor_volume_db":0});ambient.mixer.silence()
    var capture:=AudioEffectCapture.new();capture.buffer_length=3
    var bus:=AudioServer.get_bus_index("HutorAmbient");AudioServer.add_bus_effect(bus,capture)
    var hero:Node2D=current_scene.player
    var listener:AudioListener2D=hero.get_node("AmbientListener")
    ambient.mixer.set_hearth(hero.global_position,true,"outdoor")
    await create_timer(.4).timeout
    var near:Dictionary=await capture_audio(capture,1)
    check(near.frames.size()>1000 and near.rms>.0001,"licensed recording produces real mixed PCM")
    listener.position=Vector2(1500,0);await create_timer(.3).timeout
    var far:Dictionary=await capture_audio(capture,1)
    check(far.rms<near.rms*.08,"actual 2D output attenuates beyond source range")
    check(near.peak<.98,"recorded near-field mix has no clipping")
    listener.position=Vector2(0,-3)
    result["audio_capture"]={"near_rms":near.rms,"far_rms":far.rms,"near_peak":near.peak,"frames":near.frames.size()}
    if not OS.get_cmdline_user_args().is_empty():
        var folder:String=OS.get_cmdline_user_args()[0]
        DirAccess.make_dir_recursive_absolute(folder)
        save_wave(near.frames,folder+"/fire-near.wav");save_wave(far.frames,folder+"/fire-far.wav")
        var file:=FileAccess.open(folder+"/results.json",FileAccess.WRITE);file.store_string(JSON.stringify(result,"  "))
    AudioServer.remove_bus_effect(bus,AudioServer.get_bus_effect_count(bus)-1)
    ambient.mixer.silence()
    print("RESULT: ",passed," ambient checks passed, ",failed," failed")
    quit(0 if failed==0 else 1)
