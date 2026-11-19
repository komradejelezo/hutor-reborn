extends Node
## One presentation controller drives the existing combat AnimatedSprite2D.
## Resolved battle state is never changed here.
const ROOT="res://assets/combat/forest_v2/"
const MATERIAL=preload("res://scripts/combat/animation/combat_material.gd")
static var library:Dictionary={}
var sprite:AnimatedSprite2D
var kind:=""
var clips:Dictionary={}
var diagnostic_hold:=false
var key_pending:=false
var key_latched:=false
var dead:=false
var motion:="idle"
var speed:=1.0
var ground_scale:=1.0
var team:=0
func configure(target:AnimatedSprite2D,unit_kind:String,unit_team:int,asset_root:String=ROOT) -> bool:
    if not library:
        if not FileAccess.file_exists(ROOT+"library.json"):return false
        var value:Variant=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"library.json"))
        if value is Dictionary:library=value
    kind={"beast":"leshy"}.get(unit_kind,unit_kind);team=unit_team
    if not library.has(kind):return false
    var path:=asset_root+"prepared/"+kind.capitalize()+"/frames.tres"
    if not ResourceLoader.exists(path):return false
    clips=library[kind]
    for spec in clips.values():
        for frame in spec.frames:
            if not ResourceLoader.exists(asset_root+frame.path):return false
    var frames:SpriteFrames=load(path)
    if not frames or not frames.has_animation("idle"):return false
    sprite=target;sprite.sprite_frames=frames;sprite.offset=Vector2(-600,-650)
    sprite.centered=false;sprite.flip_h=team==1;sprite.material=null
    sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
    var bbox:Array=clips.idle.frames[0].bbox
    ground_scale=MATERIAL.height(kind)/float(bbox[3]-bbox[1])
    sprite.material=MATERIAL.make(kind)
    sprite.animation_finished.connect(_finished)
    sprite.frame_changed.connect(_frame_changed)
    play("idle")
    return true
func has(clip:String) -> bool:return clips.has(clip) and is_instance_valid(sprite) and sprite.sprite_frames.has_animation(clip)
func duration(clip:String,rate:float=1.0) -> float:
    if not has(clip):return 0.0
    return minf(4.0,float(sprite.sprite_frames.get_frame_count(clip))*float(clips[clip].ms)/1000.0/maxf(.1,rate))
func key_time(clip:String,rate:float=1.0) -> float:
    if not has(clip):return 0.0
    return clampf(float(clips[clip].impact)*float(clips[clip].ms)/1000.0/maxf(.1,rate),0,duration(clip,rate))
func play(clip:String,rate:float=1.0,hold_key:bool=false) -> float:
    if (dead and clip!="death") or not has(clip):return 0.0
    if clip=="death" and dead:return 0.0
    if clip=="death":dead=true
    motion=clip;speed=clampf(rate,.1,3)
    key_pending=hold_key and int(clips[clip].impact)>0;key_latched=false
    sprite.scale=Vector2.ONE*ground_scale*float(clips[clip].scale)
    sprite.speed_scale=speed;sprite.stop();sprite.play(clip);sprite.show()
    return duration(clip,speed)
func _frame_changed() -> void:
    if key_pending and sprite.frame>=int(clips[motion].impact):
        # Hold the exact authored contact pose until the arena consumes it.
        # This prevents a wall-clock timer from skipping the jaw/hand frame on
        # a slow renderer; no battle state or source frames are changed.
        key_pending=false;key_latched=true
        sprite.pause();sprite.frame=int(clips[motion].impact)
func release_key() -> void:
    if not key_latched:return
    key_latched=false
    if not dead:sprite.play()
func _finished() -> void:
    if dead:
        sprite.frame=sprite.sprite_frames.get_frame_count("death")-1;sprite.pause()
    elif diagnostic_hold:sprite.pause()
    else:play("idle",1.0)
func socket() -> Vector2:
    if not is_instance_valid(sprite):return Vector2.ZERO
    var p:=Vector2(245,86) if motion=="attack" else Vector2(247,128)
    var f:Dictionary=clips[motion].frames[mini(sprite.frame,clips[motion].frames.size()-1)]
    p=(p-Vector2(f.origin[0],f.origin[1]))*sprite.scale
    if sprite.flip_h:p.x=-p.x
    return sprite.global_position+p
