extends Control
## Developer-only F6 tool. Uses the production view/controller/material and
## SpriteFrames; no combat model, world NPC or persistent state is modified.
const VIEW=preload("res://scripts/combat/ui/combatant_view.gd")
const UNIT=preload("res://scripts/combat/combat_unit.gd")
const CATALOG=preload("res://scripts/combat/combat_catalog.gd")
const STYLE=preload("res://scripts/combat/ui/style.gd")
const MATERIAL=preload("res://scripts/combat/animation/combat_material.gd")
var forest:Control
var backdrop:ColorRect
var characters:OptionButton
var clips:OptionButton
var background:OptionButton
var quality:OptionButton
var counter:Label
var status:Label
var frame_input:SpinBox
var marker:Node2D
var actors:Array=[]
var rate:=1.0
var show_shadow:=true
var show_pivot:=true
var environment_only:=false
var compare:=true
var updating:=false
var definitions:Dictionary
func option(pos:Vector2,width:float,items:Array) -> OptionButton:
    var n:=OptionButton.new();n.position=pos;n.size=Vector2(width,30)
    for item in items:n.add_item(str(item))
    add_child(n);return n
func toggle(text:String,pos:Vector2,enabled:bool,callback:Callable) -> CheckButton:
    var n:=CheckButton.new();n.text=text;n.position=pos;n.button_pressed=enabled;n.toggled.connect(callback);add_child(n);return n
func _ready() -> void:
    theme=STYLE.theme();definitions=CATALOG.new().data.units
    backdrop=ColorRect.new();backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(backdrop)
    forest=preload("res://scenes/combat/CombatForestStage.tscn").instantiate();add_child(forest)
    STYLE.hud_backdrop(self,192,458)
    STYLE.label(self,"Лаборатория боевой графики · F6",Vector2(18,8),Vector2(700,30),21,true)
    characters=option(Vector2(18,46),175,definitions.keys())
    clips=option(Vector2(204,46),190,[])
    background=option(Vector2(405,46),195,["Лесная поляна","Чёрный","Белый","Маджента"])
    quality=option(Vector2(612,46),170,["Эффекты: выкл.","Эффекты: низкие","Эффекты: стандарт"]);quality.select(2)
    STYLE.button(self,"В арену",Vector2(795,46),Vector2(145,30),func():get_tree().change_scene_to_file("res://scenes/combat/CombatTestArena.tscn"))
    STYLE.button(self,"▶",Vector2(18,86),Vector2(60,30),play)
    STYLE.button(self,"Ⅱ",Vector2(84,86),Vector2(60,30),pause)
    STYLE.button(self,"■",Vector2(150,86),Vector2(60,30),stop)
    STYLE.button(self,"◀ кадр",Vector2(220,86),Vector2(100,30),func():step(-1))
    STYLE.button(self,"кадр ▶",Vector2(326,86),Vector2(100,30),func():step(1))
    frame_input=SpinBox.new();frame_input.position=Vector2(438,86);frame_input.size=Vector2(90,30);frame_input.min_value=1;frame_input.step=1;add_child(frame_input)
    frame_input.value_changed.connect(func(value:float):
        if not updating:set_frame(int(value)-1))
    var speed:=SpinBox.new();speed.position=Vector2(540,86);speed.size=Vector2(88,30);speed.min_value=.1;speed.max_value=3;speed.step=.1;speed.value=1;add_child(speed)
    speed.value_changed.connect(func(value:float):
        rate=value
        for view in actors:view.sprite.speed_scale=value)
    counter=STYLE.label(self,"",Vector2(640,91),Vector2(300,24),12)
    toggle("Сравнение",Vector2(18,122),true,func(value:bool):compare=value;_visibility())
    toggle("Тени",Vector2(184,122),true,func(value:bool):
        show_shadow=value
        for view in actors:view.shadow_enabled=value;view.queue_redraw())
    toggle("Опора",Vector2(303,122),true,func(value:bool):show_pivot=value;queue_redraw())
    toggle("Только окружение",Vector2(435,122),false,func(value:bool):environment_only=value;_visibility())
    for i in 5:
        var key:String=["wind","fog","leaves","lighting","smoke"][i]
        toggle(["Ветер","Туман","Листья","Свет","Дым"][i],Vector2(18+i*180,157),true,func(value:bool):forest.set_effect(key,value))
    STYLE.label(self,"Слева: исходный ресурс / справа: боевой производный",Vector2(18,462),Vector2(850,22),12)
    status=STYLE.label(self,"",Vector2(18,487),Vector2(925,46),11)
    characters.item_selected.connect(func(_index:int):_character())
    clips.item_selected.connect(func(_index:int):stop())
    quality.item_selected.connect(func(index:int):forest.quality=index)
    background.item_selected.connect(func(index:int):
        forest.visible=index==0;backdrop.color=[Color.BLACK,Color.BLACK,Color.WHITE,Color.MAGENTA][index])
    _character()
func _character() -> void:
    for view in actors:remove_child(view);view.queue_free()
    actors.clear();clips.clear()
    var kind:=characters.get_item_text(characters.selected)
    for i in 2:
        var view:=VIEW.new();view.position=Vector2(220+460*i-59,300);add_child(view)
        view.setup(UNIT.new(definitions[kind],{"id":"lab"+str(i),"kind":kind,"team":0,"row":"front","lane":0}))
        for item in [view.name_label,view.hp_label,view.status_label,view.bar]:item.hide()
        view.mouse_filter=Control.MOUSE_FILTER_IGNORE;view.shadow_enabled=show_shadow
        if view.animation:view.animation.diagnostic_hold=true
        actors.append(view)
    var fixed=actors[1]
    var names:PackedStringArray=fixed.sprite.sprite_frames.get_animation_names()
    for clip in names:
        if fixed.sprite.sprite_frames.get_frame_count(clip)>0:clips.add_item(clip)
    var idle:String="idle" if fixed.animation else fixed.native_idle() if fixed.unit.data.has("frames") else "default"
    for i in clips.item_count:
        if clips.get_item_text(i)==idle:clips.select(i)
    _original(actors[0]);stop();_visibility()
func _original(view:Button) -> void:
    if view.animation:
        var frames:SpriteFrames=view.sprite.sprite_frames.duplicate(true)
        for clip in view.animation.clips:
            var source:Array=view.animation.clips[clip].frames
            var count:=frames.get_frame_count(clip)
            for i in count:
                var index:=i if i<source.size() else source.size()*2-2-i
                var texture:AtlasTexture=frames.get_frame_texture(clip,i).duplicate()
                texture.atlas=load(view.animation.ROOT+source[index].source)
                frames.set_frame(clip,i,texture)
        view.sprite.sprite_frames=frames
    elif view.unit.data.has("frames"):
        view.sprite.sprite_frames=load(String(view.unit.data.frames))
        var tex:Texture2D=view.sprite.sprite_frames.get_frame_texture(view.native_idle(),0)
        var bounds:Rect2i=tex.get_image().get_used_rect()
        view.sprite.offset=Vector2(-tex.get_width()*.5,-bounds.end.y)
        view.sprite.scale=Vector2.ONE*MATERIAL.height(view.unit.kind)/maxf(1,bounds.size.y)
    else:
        var frames:=SpriteFrames.new();frames.add_frame("default",load(String(view.unit.data.image)))
        view.sprite.sprite_frames=frames
        var tex:=frames.get_frame_texture("default",0);var bounds:Rect2i=tex.get_image().get_used_rect()
        view.sprite.offset=Vector2(-tex.get_width()*.5,-bounds.end.y)
        view.sprite.scale=Vector2.ONE*MATERIAL.height(view.unit.kind)/maxf(1,bounds.size.y)
func _visibility() -> void:
    for i in actors.size():actors[i].visible=not environment_only and (i==1 or compare)
    queue_redraw()
func selected_clip() -> String:return clips.get_item_text(clips.selected)
func play(restart:bool=false) -> void:
    for view in actors:
        var sprite:AnimatedSprite2D=view.sprite
        var last:=sprite.sprite_frames.get_frame_count(selected_clip())-1
        var reset:=restart or sprite.animation!=selected_clip() or (not sprite.is_playing() and sprite.frame==last)
        if view.animation and reset:
            view.animation.dead=false;view.animation.play(selected_clip(),rate)
        else:
            sprite.speed_scale=rate
            if reset:sprite.stop()
            sprite.play(selected_clip())
func pause() -> void:
    for view in actors:view.sprite.pause()
func stop() -> void:
    play(true);set_frame(0)
func set_frame(index:int) -> void:
    pause()
    for view in actors:
        view.sprite.frame=clampi(index,0,view.sprite.sprite_frames.get_frame_count(selected_clip())-1)
    updating=true;frame_input.value=actors[1].sprite.frame+1;updating=false
func step(direction:int) -> void:set_frame(actors[1].sprite.frame+direction)
func _process(_delta:float) -> void:
    if actors.is_empty():return
    var sprite:AnimatedSprite2D=actors[1].sprite
    var count:=sprite.sprite_frames.get_frame_count(selected_clip())
    updating=true;frame_input.max_value=count;frame_input.value=sprite.frame+1;updating=false
    counter.text="Кадр %d / %d · %.2f FPS × %.1f"%[sprite.frame+1,count,sprite.sprite_frames.get_animation_speed(selected_clip()),rate]
    status.text="Исходник слева сохраняет дефекты alpha/старой подготовки. Справа — ресурс из игры.\n"+("У этого бойца нет отдельных боевых Attack/Hit/Death — показаны только реально доступные кадры." if not actors[1].animation else "Однократные действия останавливаются на последнем кадре для проверки; повтор — ▶. Idle зациклен.")
func _draw() -> void:
    if not show_pivot or environment_only:return
    for i in 2:
        if i==0 and not compare:continue
        var p:=Vector2(220+460*i,403)
        draw_line(p-Vector2(70,0),p+Vector2(70,0),Color(.55,.75,.85,.7),1)
        draw_line(p-Vector2(0,6),p+Vector2(0,6),Color(.55,.75,.85,.9),1)
