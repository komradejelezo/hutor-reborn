extends SceneTree
var elapsed:=0.0
var actors:Array[Dictionary]=[]
var caption:Label
func _initialize() -> void:call_deferred("run")
func run() -> void:
    root.title="Hutor Reborn — NPC 5.4 RESOURCE PREVIEW"
    var bg:=ColorRect.new();bg.color=Color(.15,.17,.15);bg.size=Vector2(960,540);root.add_child(bg)
    caption=Label.new();caption.position=Vector2(10,6);caption.add_theme_font_size_override("font_size",16);root.add_child(caption)
    var ids:Array=["hans","elder","innkeeper","innkeeper_wife","woodcutter","woodcutter_wife","woodcutter_son","herbalist","herbalist_brother","old_man"]
    for n in ids.size():
        var id:String=ids[n]
        var base:=Vector2(96+(n%5)*190,244+(n/5)*244)
        var spr:=AnimatedSprite2D.new();spr.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;spr.centered=false
        spr.position=base;spr.offset=Vector2(-480,-1280) if id=="hans" else Vector2(-48,-82)
        spr.sprite_frames=load("res://assets/characters/hans_frames.tres" if id=="hans" else "res://assets/npc/stage54/game/"+id+"/frames.tres")
        spr.scale=Vector2.ONE*(2.0/24.0 if id=="hans" else 2.0)
        root.add_child(spr)
        var label:=Label.new();label.text=id;label.position=base+Vector2(-82,9);label.add_theme_font_size_override("font_size",14);root.add_child(label)
        var line:=Line2D.new();line.points=PackedVector2Array([base+Vector2(-65,0),base+Vector2(65,0)]);line.default_color=Color(.7,.35,.2,.6);line.width=1;root.add_child(line)
        actors.append({"id":id,"sprite":spr,"label":label})
    print("NPC54_PREVIEW_READY")

func _process(delta:float) -> bool:
    if actors.is_empty():return false
    elapsed+=delta
    var directions:Array=["down","right","up","left"]
    var facing:String=directions[mini(3,int(elapsed/4.5))]
    var idle:bool=fmod(elapsed,4.5)>3.0
    caption.text="AUDIT: RESOURCE PLAYBACK 2x NEAREST — not live gameplay | "+facing+" "+("idle" if idle else "walk")
    for item in actors:
        var spr:AnimatedSprite2D=item.sprite
        var clip:String=("idle_" if idle else "walk_")+facing
        if item.id=="woodcutter_son" and not idle:clip="run_"+facing
        spr.speed_scale=1.0
        spr.flip_h=facing=="left" and (item.id=="hans" or (item.id=="woodcutter_son" and not idle))
        if item.id=="hans":spr.scale=Vector2.ONE*(2.0/21.0 if idle and facing in ["left","right"] else 2.0/24.0)
        if elapsed>18:
            var choices:Array=[]
            for name in spr.sprite_frames.get_animation_names():
                if String(name).begins_with("work_"):choices.append(name)
            clip=String(choices[mini(choices.size()-1,int((elapsed-18)/3.0))]) if not choices.is_empty() else "idle_down"
            spr.flip_h=false;spr.speed_scale=1.0
            if item.id=="hans":spr.scale=Vector2.ONE*(2.0/24.0)
            caption.text="AUDIT: RESOURCE PLAYBACK 2x NEAREST — activity resources, not live gameplay"
        item.label.text=item.id+"\n"+clip
        if spr.animation!=clip:spr.play(clip)
    if elapsed>42:quit()
    return false
