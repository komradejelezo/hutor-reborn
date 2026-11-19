extends RefCounted
const SANS=preload("res://assets/fonts/DejaVuSans.ttf")
const SERIF=preload("res://assets/fonts/DejaVuSerif.ttf")
static func box(color:Color=Color("141c19"),border:Color=Color("665d42")) -> StyleBoxFlat:
    var s:=StyleBoxFlat.new();s.bg_color=color;s.border_color=border;s.set_border_width_all(1);s.set_corner_radius_all(3)
    s.content_margin_left=12;s.content_margin_right=12;s.content_margin_top=8;s.content_margin_bottom=8
    return s
static func theme() -> Theme:
    var t:=Theme.new();t.default_font=SANS;t.default_font_size=13
    t.set_color("font_color","Label",Color("e1d7bd"));t.set_color("font_color","Button",Color("e1d7bd"))
    t.set_color("font_shadow_color","Label",Color(0,0,0,.95))
    t.set_constant("shadow_offset_x","Label",1);t.set_constant("shadow_offset_y","Label",1)
    t.set_stylebox("normal","Button",box());t.set_stylebox("hover","Button",box(Color("28332a"),Color("c2a96c")))
    t.set_stylebox("pressed","Button",box(Color("394133"),Color("d9bf7b")))
    t.set_stylebox("focus","Button",box(Color(0,0,0,0),Color("b7c7a1")))
    t.set_stylebox("disabled","Button",box(Color("111713"),Color("36392f")))
    t.set_color("font_disabled_color","Button",Color("72766b"))
    t.set_stylebox("panel","PanelContainer",box())
    return t
static func label(parent:Node,text:String,pos:Vector2,size:Vector2,font_size:int=13,serif:bool=false) -> Label:
    var n:=Label.new();n.add_theme_font_size_override("font_size",font_size)
    if serif:n.add_theme_font_override("font",SERIF)
    n.text=text;n.position=pos;n.size=size
    n.mouse_filter=Control.MOUSE_FILTER_IGNORE;parent.add_child(n)
    # Re-apply after inherited fonts resolve; a Label otherwise keeps the
    # larger pre-tree minimum even after its small font override takes effect.
    n.set_deferred("size",size)
    return n
static func button(parent:Node,text:String,pos:Vector2,size:Vector2,callback:Callable,tip:String="") -> Button:
    var n:=Button.new();n.text=text;n.position=pos;n.size=size;n.tooltip_text=tip;n.pressed.connect(callback);parent.add_child(n);return n
static func background(parent:Control) -> void:
    parent.add_child(preload("res://scenes/combat/CombatForestStage.tscn").instantiate())
static func hud_backdrop(parent:Control,top:float,bottom:float) -> void:
    for rect in [Rect2(0,0,960,top),Rect2(0,bottom,960,540-bottom)]:
        var shade:=ColorRect.new();shade.color=Color(.035,.025,.025,.72)
        shade.position=rect.position;shade.size=rect.size;shade.mouse_filter=Control.MOUSE_FILTER_IGNORE;parent.add_child(shade)
