extends Node2D
## One reusable, bounded decoration component on the currently loaded world.
const PIXEL=preload("res://assets/effects/ambient_pixel.tres")
var world: Node2D
var settings: Dictionary
var dust: CPUParticles2D
var motes: CPUParticles2D
var puff: CPUParticles2D
var wind_materials: Array[ShaderMaterial]=[]
var wind_strengths: Array[float]=[]
var vegetation_points: Array[Vector2]=[]
var lamps: Array[PointLight2D]=[]
var energies: Array[float]=[]
var chimneys: Array[CPUParticles2D]=[]
var _gust_left:=0.0
var _pulse_left:=0.0
var _pulse_index:=-1
var _rng:=RandomNumberGenerator.new()
var decorative_events:=0

func _ready() -> void:
    _rng.randomize()
    for item in get_tree().get_nodes_in_group("wind_plants"):
        if not world.is_ancestor_of(item):continue
        vegetation_points.append(item.global_position)
        var material:=item.material as ShaderMaterial
        if material and not wind_materials.has(material):
            wind_materials.append(material)
            var value: Variant=material.get_shader_parameter("strength")
            wind_strengths.append(float(value) if value!=null else 1.0)
    for lamp in world.find_children("*","PointLight2D",true,false):
        if lamp.get_script()==load("res://scripts/components/warm_light.gd"):
            lamps.append(lamp);energies.append(lamp.base_energy)
    for particle in world.find_children("*","CPUParticles2D",true,false):
        if String(particle.name).begins_with("ChimneySmoke"):chimneys.append(particle)
    dust=_particle("RoomDust",10,8,Color(.7,.61,.45,.16))
    dust.emission_shape=CPUParticles2D.EMISSION_SHAPE_RECTANGLE
    dust.gravity=Vector2(.03,-.15);dust.initial_velocity_min=.25;dust.initial_velocity_max=1.1
    motes=_particle("LightMotes",5,5,Color(.85,.62,.31,.22))
    motes.emission_shape=CPUParticles2D.EMISSION_SHAPE_RECTANGLE
    motes.emission_rect_extents=Vector2(18,12);motes.gravity=Vector2(0,-.5)
    motes.initial_velocity_min=.3;motes.initial_velocity_max=1
    puff=_particle("ChimneyPuff",4,2.6,Color(.54,.53,.5,.2))
    puff.one_shot=true;puff.explosiveness=.55;puff.direction=Vector2(.2,-1)
    puff.texture=load("res://assets/environment/smoke.png")
    puff.gravity=Vector2(.5,-.4);puff.initial_velocity_min=5;puff.initial_velocity_max=9
    if world.get("room_bounds") is Rect2:
        var rect: Rect2=world.room_bounds
        dust.position=rect.get_center();dust.emission_rect_extents=rect.size*.4

func _particle(label: String, count: int, life: float, tint: Color) -> CPUParticles2D:
    var item:=CPUParticles2D.new();item.name=label;item.emitting=false
    item.amount=count;item.lifetime=life;item.color=tint;item.z_index=20
    item.texture=PIXEL
    item.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
    item.scale_amount_min=1;item.scale_amount_max=1;item.spread=25
    add_child(item);return item

func enabled_here() -> bool:
    return is_inside_tree() and settings.get("visuals_enabled",true) and (not settings.get("follow_f3",true) or world.atmosphere.effects_enabled)

func step(delta: float) -> void:
    if not is_instance_valid(dust):return
    var allowed:=enabled_here()
    _gust_left=maxf(0,_gust_left-delta);_pulse_left=maxf(0,_pulse_left-delta)
    var multiplier:=1.0+.65*sin((_gust_left/3.2)*PI) if _gust_left>0 else 1.0
    for i in wind_materials.size():
        wind_materials[i].set_shader_parameter("strength",wind_strengths[i]*multiplier if allowed and settings.wind_enabled else 0.0)
    var indoor:bool=world.get("building_id")!=null
    dust.emitting=allowed and indoor and settings.dust_enabled
    dust.visible=dust.emitting
    var hero: Node2D=world.get_node_or_null("Actors/Hans")
    var nearest:=-1;var distance:=INF
    for i in lamps.size():
        var lamp:=lamps[i]
        var gap:float=lamp.global_position.distance_squared_to(hero.global_position) if hero else INF
        if gap<distance:nearest=i;distance=gap
        if lamp.is_inside_tree():
            lamp.base_energy=energies[i]*(1.0+.06*sin(_pulse_left/2.4*PI) if i==_pulse_index and _pulse_left>0 and allowed and settings.light_pulses_enabled else 1.0)
    motes.emitting=allowed and settings.light_motes_enabled and nearest>=0 and distance<240*240
    motes.visible=motes.emitting
    if motes.emitting:motes.global_position=lamps[nearest].global_position
    if not allowed or not settings.smoke_enabled:puff.emitting=false;puff.visible=false
    var budget:int=settings.get("max_new_particles",24)
    dust.amount=mini(10,maxi(1,budget-9));motes.amount=mini(5,maxi(1,budget-4-dust.amount))

func trigger() -> String:
    if not enabled_here():return ""
    var choices: Array[String]=[]
    if not wind_materials.is_empty() and settings.wind_enabled:choices.append("gust")
    if not lamps.is_empty() and settings.light_pulses_enabled:choices.append("flame")
    if not chimneys.is_empty() and settings.smoke_enabled:choices.append("smoke")
    if choices.is_empty():return ""
    var kind:=choices[_rng.randi_range(0,choices.size()-1)]
    if kind=="gust":_gust_left=3.2
    elif kind=="flame":_pulse_index=_rng.randi_range(0,lamps.size()-1);_pulse_left=2.4
    else:
        var camera: Camera2D=world.player.get_node("Camera2D")
        var size: Vector2=world.get_viewport_rect().size/camera.zoom
        var visible:=Rect2(camera.get_screen_center_position()-size*.5,size).grow(32)
        var candidates: Array[CPUParticles2D]=[]
        for chimney in chimneys:
            if visible.has_point(chimney.global_position):candidates.append(chimney)
        if candidates.is_empty():return ""
        puff.global_position=candidates[_rng.randi_range(0,candidates.size()-1)].global_position
        puff.visible=true;puff.restart();puff.emitting=true
    decorative_events+=1
    return kind

func _exit_tree() -> void:
    for particle in [dust,motes,puff]:
        if is_instance_valid(particle):particle.emitting=false;particle.visible=false
    _gust_left=0;_pulse_left=0
    for i in wind_materials.size():wind_materials[i].set_shader_parameter("strength",wind_strengths[i])
    for i in lamps.size():
        if is_instance_valid(lamps[i]):lamps[i].base_energy=energies[i]
