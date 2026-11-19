extends RefCounted
## Short bound tweens. Arena owns the cancel-safe timer and epoch validation.
static func popup(view:Control,text:String,color:Color,duration:float) -> void:
    var l:=Label.new();l.text=text;l.add_theme_font_size_override("font_size",18);l.add_theme_color_override("font_color",color)
    l.position=Vector2(-12,36);l.size=Vector2(142,40);l.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;l.mouse_filter=Control.MOUSE_FILTER_IGNORE
    view.add_child(l);var t:=view.create_tween();t.tween_property(l,"position:y",16,duration);t.parallel().tween_property(l,"modulate:a",0.0,duration)
    t.tween_callback(l.queue_free)
static func strike(view:Control,direction:float,duration:float) -> void:
    # A unit without authored attack poses must not slide its idle feet.
    var t:=view.create_tween()
    t.tween_property(view.sprite,"self_modulate",Color.WHITE,duration).from(Color(1.12,1.07,1.0,1))
static func hit(view:Control,dead:bool,duration:float) -> void:
    var t:=view.create_tween()
    t.tween_property(view.sprite,"self_modulate",Color(.7,.67,.62,1) if dead else Color.WHITE,duration).from(Color(1.16,.72,.65,1))
static func roots(view:Control,duration:float) -> void:
    var vines:=Node2D.new();view.add_child(vines)
    for i in 4:
        var line:=Line2D.new();line.width=2;line.default_color=Color("839564")
        line.points=PackedVector2Array([Vector2(35+i*12,104),Vector2(32+i*12,91),Vector2(39+i*10,80),Vector2(37+i*11,72)])
        vines.add_child(line)
    var t:=view.create_tween();t.tween_property(vines,"modulate:a",0.0,duration);t.tween_callback(vines.queue_free)
