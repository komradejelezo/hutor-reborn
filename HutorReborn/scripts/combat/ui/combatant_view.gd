extends Button
## Experimental presentation only: no world scripts, physics or NPC definitions.
signal chosen(id:String)
const STYLE=preload("res://scripts/combat/ui/style.gd")
const ANIMATION=preload("res://scripts/combat/animation/combat_animation.gd")
const MATERIAL=preload("res://scripts/combat/animation/combat_material.gd")
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
    size=Vector2(118,155);flat=true;mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
    _frame=STYLE.box(Color(0,0,0,0))
    name_label=STYLE.label(self,"",Vector2(4,107),Vector2(110,14),11);name_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    body=Node2D.new();body.name="Body";body.position=Vector2(59,103);add_child(body)
    sprite=AnimatedSprite2D.new();sprite.centered=false;sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;body.add_child(sprite)
    bar=ProgressBar.new();bar.show_percentage=false;bar.position=Vector2(8,123)
    bar.mouse_filter=Control.MOUSE_FILTER_IGNORE;var bg:=StyleBoxFlat.new();bg.bg_color=Color("0c120f");bg.border_color=Color("3a4034");bg.set_border_width_all(1)
    bar.add_theme_stylebox_override("background",bg)
    var fill:=StyleBoxFlat.new();fill.bg_color=Color("7f9c66");bar.add_theme_stylebox_override("fill",fill);bar.size=Vector2(102,4);add_child(bar)
    hp_label=STYLE.label(self,"",Vector2(4,128),Vector2(110,12),10);hp_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    status_label=STYLE.label(self,"",Vector2(2,141),Vector2(114,14),9);status_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    for label in [name_label,hp_label,status_label]:
        label.add_theme_color_override("font_shadow_color",Color(0,0,0,.95));label.add_theme_constant_override("shadow_offset_x",1);label.add_theme_constant_override("shadow_offset_y",1)
    pressed.connect(func():chosen.emit(unit.id))
    mouse_entered.connect(func():hovered=true);mouse_exited.connect(func():hovered=false)
func setup(value:RefCounted) -> void:
    unit=value
    presented_hp=unit.hp
    if unit.data.has("frames"):
        var path:String="res://assets/combat/readability/"+unit.kind+"_frames.tres" if unit.kind in ["herbalist","woodcutter"] else String(unit.data.frames)
        sprite.sprite_frames=load(path);sprite.offset=Vector2(-480,-1280) if unit.kind=="hans" else Vector2(-48,-82)
        sprite.scale=Vector2.ONE*(1.55/21.0 if unit.kind=="hans" else 1.55*(1.08 if unit.kind=="woodcutter" else 1.0))
    else:
        var f:=SpriteFrames.new();f.add_frame("default",load(unit.data.image));sprite.sprite_frames=f
        sprite.offset=Vector2(-48,-82);sprite.scale=Vector2.ONE*1.5
    var driver:=ANIMATION.new();add_child(driver)
    if driver.configure(sprite,unit.kind,unit.team):animation=driver
    else:
        driver.queue_free()
        var clip:=native_idle()
        if not sprite.sprite_frames.has_animation(clip):clip="default"
        var tex:=sprite.sprite_frames.get_frame_texture(clip,0)
        var bounds:=tex.get_image().get_used_rect()
        var height:float=bounds.size.y
        sprite.offset.x=-tex.get_size().x*.5
        sprite.offset.y=-bounds.end.y
        if height>0:sprite.scale=Vector2.ONE*MATERIAL.height(unit.kind)/height
        sprite.material=MATERIAL.make(unit.kind)
    sprite.modulate=Color.WHITE;sprite.self_modulate=Color.WHITE
    body.modulate=Color.WHITE;body.self_modulate=Color.WHITE
    name_label.z_index=2
    refresh(false,false,"")
func reveal_health() -> void:
    presented_hp=unit.hp;health_staged=false
func native_idle() -> String:
    # Existing approved front/three-quarter pose reads better than the very thin
    # side profile at combat distance. The world NPC keeps its own directions.
    if unit.kind=="herbalist":return "idle_down"
    return "idle_right" if unit.team==0 else "idle_left"
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
        var clip:=native_idle()
        if unit.alive():sprite.play(clip)
        else:sprite.pause()
        var native:PackedStringArray=sprite.sprite_frames.get_meta("native_left_clips",PackedStringArray())
        sprite.flip_h=unit.team==1 and not clip in native
    else:sprite.flip_h=(unit.team==1) if unit.kind=="mercenary" else unit.team==0
    # Selection is indicated by ground markers, never by fading the character.
    modulate=Color.WHITE;self_modulate=Color.WHITE
    sprite.modulate.a=1.0;sprite.self_modulate.a=1.0
    queue_redraw()
func _process(delta:float) -> void:
    pulse+=delta
    if active or (selectable and hovered):queue_redraw()
func _draw() -> void:
    if not _frame:return
    var radius:float=40 if unit and unit.kind=="beast" else 36 if unit and unit.kind=="wolf" else 26
    if animation and animation.dead:radius*=1.6
    for ring in 3:
        var points:=PackedVector2Array();var k:=1.0-float(ring)*.2
        for i in 24:
            var a:=TAU*float(i)/24;points.append(Vector2(59+cos(a)*radius*k,104+sin(a)*4*k))
        draw_colored_polygon(points,Color(.055,.035,.025,.08))
    if active:
        var c:=Color("dfc285");c.a=.55+.3*sin(pulse*3)
        draw_line(Vector2(21,105),Vector2(97,105),c,1)
    if selectable:
        var c:=Color("c6d5a1");c.a=.8 if hovered else .4
        draw_line(Vector2(12,102),Vector2(12,93),c,1);draw_line(Vector2(106,102),Vector2(106,93),c,1)
