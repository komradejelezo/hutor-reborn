extends SceneTree
var passed:=0
var failed:=0
func _initialize() -> void:call_deferred("run")
func check(ok:bool,message:String) -> void:
    if ok:
        passed+=1
        print("PASS: ",message)
    else:
        failed+=1
        push_error("FAIL: "+message)
func ticks(count:int) -> void:
    for i in range(count):await physics_frame
func run() -> void:
    var world:Node2D=load("res://scenes/world/krivaya_sosna/krivaya_sosna.tscn").instantiate()
    root.add_child(world)
    current_scene=world
    await ticks(4)
    var lights:=world.find_children("*","PointLight2D",true,false)
    var occluders:=world.find_children("*","LightOccluder2D",true,false)
    check(lights.size()==17,"17 existing local lights; no second lighting system")
    check(occluders.size()==1,"one focused common-house light occluder")
    var shadow_count:=0
    var light_settings:=true
    var origins_clear:=true
    var phases:Array=[]
    for light in lights:
        light_settings=light_settings and light.texture_filter==CanvasItem.TEXTURE_FILTER_NEAREST and light.base_energy<=.56 and light.flicker<=.012
        if light.shadow_enabled:
            shadow_count+=1
            light_settings=light_settings and light.shadow_filter==Light2D.SHADOW_FILTER_PCF5
            for caster in occluders:
                if Geometry2D.is_point_in_polygon(caster.to_local(light.global_position),caster.occluder.polygon):origins_clear=false
        if light.get_parent().name.begins_with("HangingLantern"):phases.append(light._phase)
    check(light_settings and shadow_count==1,"high-resolution falloff, Nearest and one bounded PCF5 shadow source")
    check(origins_clear,"shadow lantern origins stay outside house solids")
    phases.sort()
    var independent:=true
    for i in range(1,phases.size()):independent=independent and absf(phases[i]-phases[i-1])>.01
    check(independent,"five lanterns no longer share a synchronous local-position phase")
    var geometry_correct:=true
    for caster in occluders:
        var foot:CollisionShape2D=caster.get_parent().get_node("Solid/Footprint")
        var shape:RectangleShape2D=foot.shape
        var expected:=Rect2(foot.position-shape.size/2,shape.size)
        var points:PackedVector2Array=caster.occluder.polygon
        var actual:=Rect2(points[0],Vector2.ZERO)
        for p in points:actual=actual.expand(p)
        geometry_correct=geometry_correct and expected.is_equal_approx(actual) and not caster.sdf_collision
    check(geometry_correct,"visual occluders follow existing footprints without adding physics/SDF")
    var cookie:GradientTexture2D=lights[0].texture
    var falloff_ok:=cookie.width==512 and cookie.height==512
    var previous:=cookie.gradient.sample(0).a
    for x in range(1,129):
        var alpha:=cookie.gradient.sample(float(x)/128).a
        falloff_ok=falloff_ok and alpha<=previous+.005 and absf(alpha-previous)<.035
        previous=alpha
    check(falloff_ok and cookie.gradient.sample(1).a==0,"radial gradient has a continuous falloff and transparent boundary")
    var light:PointLight2D=world.get_node("Actors/Props/HangingLantern187/WarmLight2")
    light.set_process(false)
    light.elapsed=0.0
    light._since_update=0.0
    light.energy=light.base_energy
    var updates:=0
    var smooth_pulse:=true
    for i in range(600):
        var before:=light.energy
        light._process(1.0/60.0)
        if light.energy!=before:updates+=1
        smooth_pulse=smooth_pulse and absf(light.energy-light.base_energy)<=light.flicker+.0001 and absf(before-light.energy)<.004
    check(smooth_pulse and updates>10 and updates<=84,"flicker stays subtle; energy writes bounded to at most 8.34 Hz")
    light.set_process(true)
    var strengths:Array=[]
    var materials:Array=[]
    for plant in get_nodes_in_group("wind_plants"):
        if plant.material and not materials.has(plant.material):
            materials.append(plant.material)
            strengths.append(plant.material.get_shader_parameter("strength"))
    var atmosphere:Node2D=world.get_node("Atmosphere")
    atmosphere.set_effects_enabled(false)
    check(not atmosphere.is_processing() and not atmosphere.fog.visible,"F3 suspends hidden fog uniform work")
    var disabled:=true
    for material in materials:disabled=disabled and material.get_shader_parameter("strength")==0.0
    for particle in get_nodes_in_group("ambient_particles"):disabled=disabled and not particle.visible and not particle.emitting
    check(disabled,"F3 disables existing wind and smoke")
    atmosphere.set_effects_enabled(true)
    var restored:=true
    for i in range(materials.size()):restored=restored and materials[i].get_shader_parameter("strength")==strengths[i]
    check(restored and strengths.has(.6),"F3 restores authored 0.6/1.0 strengths, including shared mirrored trees")
    check(atmosphere.world_space_fog and atmosphere.fog.material.get_shader_parameter("fog_strength")<=.035,"one low-density world-space mist pass")
    var player:CharacterBody2D=world.get_node("Actors/Hans")
    player.set_physics_process(false)
    # A real swept circuit around the well, not a disconnected reachability query.
    var well:Vector2=world.get_node("Actors/Props/VillageWell").global_position
    player.position=well+Vector2(0,76)
    var circuit_ok:=true
    for i in range(1,33):
        var angle:=PI/2+TAU*float(i)/32
        var destination:=well+Vector2(cos(angle),sin(angle))*76
        var contact:=player.move_and_collide(destination-player.position)
        circuit_ok=circuit_ok and contact==null
        await physics_frame
    check(circuit_ok,"Hans completes a collision-free circuit around the well")
    var camera:Camera2D=player.get_node("Camera2D")
    player.position=Vector2(1320,1435)
    camera.reset_smoothing()
    camera.force_update_scroll()
    await ticks(3)
    var start:=camera.get_screen_center_position()
    player.position.x+=96
    var previous_x:=start.x
    var monotonic:=true
    var intermediate:=false
    for i in range(75):
        await physics_frame
        var x:=camera.get_screen_center_position().x
        monotonic=monotonic and x>=previous_x-.02 and x<=start.x+96.1
        intermediate=intermediate or (x>start.x+.1 and x<start.x+95.9)
        previous_x=x
    check(monotonic and intermediate and previous_x>start.x+91,"original camera follows smoothly and monotonically at the approved zoom")
    check(camera.zoom==Vector2.ONE and camera.limit_right==2624 and camera.limit_bottom==2176,"camera zoom and world limits unchanged")
    print("RESULT: ",passed," lighting/technical checks passed, ",failed," failed")
    world.queue_free()
    await process_frame
    quit(0 if failed==0 else 1)
