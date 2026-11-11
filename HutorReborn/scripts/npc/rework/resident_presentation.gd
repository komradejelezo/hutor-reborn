extends RefCounted
## Stage 54 presentation: real state/position remain owned by VillageLife.
const BIND=preload("res://scripts/npc/rework/work_bindings.gd")
var last_work:=""
var work_starts:=0
var rejected_work:=0
var work_clock:=0.0
var action_key:=""

func release(actor:HutorResident) -> void:
    action_key="";last_work="";work_clock=0
    var sprite:AnimatedSprite2D=actor.get_node("AnimatedSprite2D")
    sprite.position=Vector2.ZERO;sprite.z_index=0
    var smoke:CPUParticles2D=actor.get_node("PipeSmoke")
    smoke.emitting=false;smoke.visible=false
    actor.animator.reset_presentation()

func _prop(world:Node2D, kind:String, point:Vector2) -> Node2D:
    var root:Node2D=world.get_node_or_null("Actors/NpcWorkProps54")
    if root==null:
        root=Node2D.new();root.name="NpcWorkProps54";root.y_sort_enabled=true;world.get_node("Actors").add_child(root)
    var key:="P_"+kind+"_"+str(int(point.x/16))+"_"+str(int(point.y/16))
    var item:Node2D=root.get_node_or_null(key)
    if item:return item
    if root.get_child_count()>=24:return null
    item=Node2D.new();item.name=key;item.position=point
    var art:=Sprite2D.new();art.name="Art";art.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;art.centered=false
    var texture_path:="res://assets/interiors/stage44/herbs.png";var factor:=.45;var offset:=Vector2(16,0)
    if kind=="seat":texture_path="res://assets/interiors/stage44/bench.png";factor=.5;offset=Vector2(0,-14)
    elif kind=="tub":texture_path="res://assets/npc/stage54/game/props/wash_tub.png";factor=.36;offset=Vector2(16,0)
    elif kind=="workblock":texture_path="res://assets/environment/krivaya_sosna/objects/stump.png";factor=.3;offset=Vector2(0,-10)
    elif kind=="toy":texture_path="res://assets/npc/stage54/game/props/toy_ball.png";factor=.3;offset=Vector2(13,-1)
    art.texture=load(texture_path);art.scale=Vector2.ONE*factor
    art.position=Vector2(-art.texture.get_width()*factor*.5,-art.texture.get_height()*factor)+offset
    item.add_child(art);root.add_child(item)
    item.set_meta("npc_work_prop",kind)
    return item

func present(actor:HutorResident, record:HutorDailyResidentState, look:StringName, delta:float) -> bool:
    var sprite:AnimatedSprite2D=actor.get_node("AnimatedSprite2D")
    var step:HutorNpcRoutineStep=actor.current_step()
    var key:=String(record.scene)+"/"+str(record.block_stamp)+"/"+str(actor.step_index)+"/"+(step.label if step else "")
    if key!=action_key:action_key=key;work_clock=0
    actor.animator.set_work_context(key)
    actor.get_node("Interaction").position=step.talk_offset if step and actor.state in [actor.State.WAITING,actor.State.TALKING] else Vector2.ZERO
    var target_offset:=Vector2.ZERO
    sprite.z_index=0
    var working:=false
    var clip:=""
    var smoke:=false
    if actor.state==actor.State.TALKING:
        actor.animator.apply("talk",actor.facing,&"",false)
    elif actor.state==actor.State.MOVING and not actor.velocity.is_zero_approx():actor.animator.apply("walk",actor.facing,&"",false)
    elif look!=&"" and actor.state==actor.State.WAITING:actor.animator.apply("turn",look,&"",false)
    elif actor.state==actor.State.WAITING and record.mode==&"local" and step and actor.position.distance_to(step.position)<12:
        var world:Node2D=actor.director.get_parent().get_parent()
        var spec:Dictionary=BIND.specification(record.id,record.scene,step.label)
        if not spec.is_empty():
            var object:Node2D=world.get_node_or_null(spec.get("object","")) if spec.has("object") else null
            var valid:bool=not spec.has("object") or (object!=null and actor.position.distance_to(object.position)<=float(spec.get("reach",64)))
            if spec.has("prop"):
                object=_prop(world,spec.prop,step.position)
                valid=valid and object!=null and actor.position.distance_to(object.position)<16
            clip=String(spec.get("clip",""))
            valid=valid and sprite.sprite_frames.has_animation(clip)
            if valid:
                working=true
                work_clock+=delta
                if record.id==&"elder" and record.scene==&"elder" and step.label=="read_documents" and fmod(work_clock,16)>7 and fmod(work_clock,16)<12:
                    clip="work_write";spec["overlay"]=true;spec["offset"]=[0,0]
                var direction:StringName=&"right" if spec.get("overlay",false) else actor.facing
                actor.animator.apply("work",direction,StringName(clip),false)
                sprite.z_index=1 if spec.get("overlay",false) else 0
                var offset:Array=spec.get("offset",[0,0]);target_offset=Vector2(offset[0],offset[1])
                smoke=spec.get("smoke",false) and actor.director.atmosphere.effects_enabled
            else:rejected_work+=1
        if not working:actor.animator.apply("idle",actor.facing,&"",false)
    else:actor.animator.apply("idle",actor.facing,&"",false)
    if working and clip!=last_work:work_starts+=1
    last_work=clip if working else ""
    # A deliberate short lean into the work surface; no actor teleportation.
    # Full-body frames always retain their authored ground pivot. A work-only
    # lean must never drift standing feet after talking, stopping or relocating.
    sprite.position=sprite.position.move_toward(target_offset,delta*64) if working else Vector2.ZERO
    var particle:CPUParticles2D=actor.get_node("PipeSmoke")
    particle.emitting=smoke;particle.visible=smoke;particle.position=Vector2(-8 if sprite.flip_h else 8,-26 if clip=="work_sit" else -35)
    return true
