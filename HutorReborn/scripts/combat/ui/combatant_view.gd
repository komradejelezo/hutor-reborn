extends Button
## Experimental presentation only: no world scripts, physics or NPC definitions.
signal chosen(id:String)
const STYLE=preload("res://scripts/combat/ui/style.gd")
const ANIMATION=preload("res://scripts/combat/animation/combat_animation.gd")
var unit:RefCounted
var body:Node2D
var sprite:AnimatedSprite2D
var name_label:Label
var hp_label:Label
var status_label:Label
var bar:ProgressBar
var active:=false
var selectable:=false
var hovered:=false
var pulse:=0.0
var _frame:StyleBoxFlat
var animation:Node
var presented_hp:=0
var health_staged:=false
func _ready() -> void:
    size=Vector2(118,142);flat=true;mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
    _frame=STYLE.box(Color(.045,.065,.052,.9))
    name_label=STYLE.label(self,"",Vector2(4,2),Vector2(110,20),12);name_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    body=Node2D.new();body.name="Body";body.position=Vector2(59,103);add_child(body)
    sprite=AnimatedSprite2D.new();sprite.centered=false;sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;body.add_child(sprite)
    bar=ProgressBar.new();bar.show_percentage=false;bar.position=Vector2(8,106)
    bar.mouse_filter=Control.MOUSE_FILTER_IGNORE;var bg:=StyleBoxFlat.new();bg.bg_color=Color("0c120f");bg.border_color=Color("3a4034");bg.set_border_width_all(1)
    bar.add_theme_stylebox_override("background",bg)
    var fill:=StyleBoxFlat.new();fill.bg_color=Color("7f9c66");bar.add_theme_stylebox_override("fill",fill);bar.size=Vector2(102,8);add_child(bar)
    hp_label=STYLE.label(self,"",Vector2(4,114),Vector2(110,14),10);hp_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    status_label=STYLE.label(self,"",Vector2(2,128),Vector2(114,14),9);status_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    pressed.connect(func():chosen.emit(unit.id))
    mouse_entered.connect(func():hovered=true);mouse_exited.connect(func():hovered=false)
func setup(value:RefCounted) -> void:
    unit=value
    presented_hp=unit.hp
    if unit.data.has("frames"):
        sprite.sprite_frames=load(unit.data.frames);sprite.offset=Vector2(-480,-1280) if unit.kind=="hans" else Vector2(-48,-82)
        sprite.scale=Vector2.ONE*(1.55/21.0 if unit.kind=="hans" else 1.55*(1.08 if unit.kind=="woodcutter" else 1.0))
        var path:="res://assets/npc/woodcutter542/game/palette_543.tres" if unit.kind=="woodcutter" else "res://assets/npc/herbalist5410/game/palette.tres" if unit.kind=="herbalist" else ""
        if path!="":sprite.material=load(path)
    else:
        var f:=SpriteFrames.new();f.add_frame("default",load(unit.data.image));sprite.sprite_frames=f
        sprite.offset=Vector2(-48,-82);sprite.scale=Vector2.ONE*1.5
    var driver:=ANIMATION.new();add_child(driver)
    if driver.configure(sprite,unit.kind,unit.team):animation=driver
    else:driver.queue_free()
    name_label.z_index=2
    refresh(false,false,"")
func reveal_health() -> void:
    presented_hp=unit.hp;health_staged=false
func refresh(is_active:bool,can_target:bool,reason:String) -> void:
    if not health_staged:presented_hp=unit.hp
    active=is_active;selectable=can_target;disabled=not can_target
    name_label.text=("› " if active else "")+unit.name
    bar.max_value=unit.max_hp;bar.value=presented_hp;hp_label.text=str(presented_hp)+" / "+str(unit.max_hp)+" HP"
    status_label.text=unit.status_text()
    tooltip_text=unit.name+"\nУрон "+str(unit.damage)+" · Защита "+str(unit.armor)+"\nИнициатива "+str(unit.initiative)+" · Точность "+str(unit.accuracy)+"%\n"+("Дальний удар" if unit.reach=="ranged" else "Ближний бой")+"\n"+reason
    if animation:
        # Refresh never restarts actions or resurrects the final death pose.
        pass
    elif unit.data.has("frames"):
        var clip:="idle_right" if unit.team==0 else "idle_left"
        sprite.play(clip)
        var native:PackedStringArray=sprite.sprite_frames.get_meta("native_left_clips",PackedStringArray())
        sprite.flip_h=unit.team==1 and not clip in native
    else:sprite.flip_h=(unit.team==1) if unit.kind=="mercenary" else unit.team==0
    sprite.modulate=Color.WHITE if animation or presented_hp>0 else Color(.45,.48,.45,.25)
    modulate.a=1.0 if active or can_target else .78 if presented_hp>0 else .65
    queue_redraw()
func _process(delta:float) -> void:
    pulse+=delta
    if active or (selectable and hovered):queue_redraw()
func _draw() -> void:
    if not _frame:return
    _frame.border_color=Color("b4c784") if selectable else Color("756340") if active else Color("465043")
    _frame.set_border_width_all(2 if selectable or active else 1)
    draw_style_box(_frame,Rect2(Vector2.ZERO,Vector2(118,142)))
    if active:
        var c:=Color("dfc285");c.a=.55+.3*sin(pulse*3)
        draw_line(Vector2(7,23),Vector2(111,23),c,2)
    if selectable and hovered:draw_rect(Rect2(3,3,112,136),Color(.75,.85,.6,.08+.04*sin(pulse*6)),true)
