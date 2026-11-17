extends Node2D
## Story-only additions to cached worlds; existing map/room resources are untouched.
const MARKER=preload("res://scripts/chapter/chapter_marker.gd")
var chapter:Node
var world:Node2D
var scene_id:=""
var markers:Dictionary={}
var light:PointLight2D
var exit_prompted:=false
func _ready() -> void:
    chapter=get_node("/root/ChapterI");world=get_parent();scene_id=String(chapter.travel.active_id)
    for label in world.hud.find_children("*","Label",true,false):
        if label.text==world.hud.chapter_label:label.text="I · ТЕНИ КРИВОЙ СОСНЫ"
    if scene_id=="":
        point("sign","Осмотреть указатель",Vector2(1330,2410),"res://assets/environment/krivaya_sosna/objects/sign.png")
        point("leave","Уйти по южной дороге",Vector2(1378,2504))
        point("axe_found","Осмотреть топор в смоле",Vector2(1425,370),"res://assets/interiors/stage45/axe.png")
        point("tools","Осмотреть оставленные инструменты",Vector2(1480,450))
        point("tracks","Изучить северные следы",Vector2(1384,190))
        point("north","Идти к старым лесозаготовкам",Vector2(1384,60))
        point("pine_symbol","Осмотреть зарубки на сосне",Vector2(560,917))
        point("finale","Прислушаться у Кривой Сосны",Vector2(560,952))
        point("valerian","Осмотреть белые цветы",Vector2(710,1140),"res://assets/interiors/stage44/herbs.png")
        point("thyme","Осмотреть мелколистный куст",Vector2(790,1250),"res://assets/interiors/stage44/herb_line.png")
        point("poison","Осмотреть пятнистый стебель",Vector2(660,1330),"res://assets/interiors/stage44/herbs.png")
        point("wheel","Поднять деревянное колесо",Vector2(1340,1520))
        var wheel:=AtlasTexture.new();wheel.atlas=load("res://assets/environment/krivaya_sosna/objects/cart.png");wheel.region=Rect2(51,43,27,37)
        object_art(markers.wheel,wheel,Vector2(0,-5),.35)
        anchored("collect_logs","Взять две связки дров","S42_Woodcutter_wood_store_0")
        point("abandoned","Осмотреть дверь пустого дома",Vector2(2710,1078))
        light=PointLight2D.new();light.position=Vector2(2670,940);light.texture=load("res://assets/environment/krivaya_sosna/stage33/soft_light.tres");light.color=Color("e8b87d");light.energy=.65;light.texture_scale=.25;add_child(light)
    elif scene_id=="inn":
        anchored("take_dishes","Собрать грязную посуду","TableA")
        anchored("deliver_dishes","Отнести посуду к стойке","Counter")
        anchored("take_mug","Осмотреть забытую кружку","TableB")
        furniture_art("take_dishes","TableA","res://assets/npc/innkeeper_wife547/game/tray.png",Vector2(-9,-40),1.25)
        furniture_art("take_dishes","TableA","res://assets/npc/innkeeper546/game/mug_empty.png",Vector2(12,-40),1.25)
        furniture_art("take_mug","TableB","res://assets/npc/innkeeper546/game/mug_empty.png",Vector2(4,-40),1.5)
        var mug:Node2D=markers.take_mug.get_meta("art")[0]
        # A small diegetic carving, using whole pixel strokes, not a map marker.
        var carving:=Line2D.new();carving.width=1;carving.default_color=Color("c8b58b")
        carving.points=PackedVector2Array([Vector2(3,-39),Vector2(3,-42),Vector2(5,-40),Vector2(7,-42),Vector2(7,-39)])
        mug.get_parent().add_child(carving);markers.take_mug.get_meta("art").append(carving)
        point("sleep","Отдохнуть на тюфяке",Vector2(750,418))
        point("wait","Подождать до вечера",Vector2(690,420))
    elif scene_id=="woodcutter":anchored("deliver_logs","Сложить дрова у печи","Stove")
    elif scene_id=="herbalist":anchored("dry_sort","Разобрать лекарственные запасы","Table")
    elif scene_id=="storehouse":
        anchored("repair","Починить игрушку на верстаке","WorkTable")
        anchored("dry_take","Снять сухие связки","Tools")
    elif scene_id=="elder":
        anchored("archive","Прочитать старую опись","Documents")
        anchored("official_copy","Забрать выписку старосты","Desk")
    elif scene_id=="logging_camp":
        point("camp_exit","Вернуться в Кривую Сосну",Vector2(590,1085))
        point("wolves","Оценить волчий дозор",Vector2(620,790))
        point("struggle","Осмотреть следы борьбы",Vector2(730,300))
        point("handle","Поднять сломанную рукоять",Vector2(560,430),"res://assets/interiors/stage45/axe.png")
        point("cloth","Осмотреть ткань в корнях",Vector2(880,420),"res://assets/interiors/stage45/linen_line.png")
        point("vanishing","Проследить шаги до дерева",Vector2(910,235))
    elif scene_id=="abandoned":
        point("house_exit","Выйти из пустого дома",Vector2(512,505))
        point("family","Осмотреть старые вещи семьи",Vector2(330,390))
        point("house_symbol","Осмотреть три зарубки",Vector2(650,400))
        point("floor_cache","Приподнять половицу",Vector2(450,365))
        point("cabinet","Открыть запертый шкаф",Vector2(730,290))
    chapter.state.changed.connect(refresh);refresh()
func anchored(action:String,title:String,prop:String,icon:String="") -> void:
    var target:Node2D=world.get_node_or_null("Actors/Props/"+prop)
    if not target:
        push_error("Chapter interaction has no furniture: "+scene_id+"/"+prop);return
    # Contact is just outside the actual feet, never inside the wall behind it.
    var feet:CollisionShape2D=target.get_node_or_null("Solid/Feet")
    if not feet:feet=target.get_node_or_null("Solid/Footprint")
    var bottom:=0.0
    if feet and not feet.disabled and feet.shape is RectangleShape2D:bottom=feet.global_position.y-target.global_position.y+feet.shape.size.y*.5
    point(action,title,target.position+Vector2(0,bottom+10),icon)
    markers[action].set_meta("furniture",target.get_path())
func object_art(parent:Node2D,texture:Texture2D,pos:Vector2,factor:float) -> Sprite2D:
    var art:=Sprite2D.new();art.texture=texture;art.position=pos;art.scale=Vector2.ONE*factor
    art.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;parent.add_child(art);return art
func furniture_art(action:String,prop:String,path:String,pos:Vector2,factor:float) -> void:
    var art:=object_art(world.get_node("Actors/Props/"+prop),load(path),pos,factor)
    art.modulate=Color(1.08,1.05,1.0)
    if not markers[action].has_meta("art"):markers[action].set_meta("art",[])
    markers[action].get_meta("art").append(art)
func point(action:String,title:String,pos:Vector2,icon:String="") -> void:
    var marker:=MARKER.new();marker.name="Story_"+action;marker.chapter_action=action;marker.title=title;marker.position=pos;marker.reach=52;add_child(marker);markers[action]=marker
    if icon!="":
        var art:=Sprite2D.new();art.texture=load(icon);art.scale=Vector2.ONE*minf(28.0/art.texture.get_height(),.6);art.position=Vector2(0,-12);art.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;marker.add_child(art)
    _settle.call_deferred(marker)
func _settle(marker:Node2D) -> void:
    if not is_instance_valid(marker) or not world.is_inside_tree():return
    var origin:=marker.position
    var shape:=CircleShape2D.new();shape.radius=9
    for radius in [0,8,16,24]:
        for direction in [Vector2.DOWN,Vector2.RIGHT,Vector2.LEFT,Vector2.UP]:
            var p:Vector2=origin+direction*radius
            if world.get("room_bounds") is Rect2 and not world.room_bounds.grow(-8).has_point(p):continue
            var q:=PhysicsShapeQueryParameters2D.new();q.shape=shape;q.transform=Transform2D(0,p);q.collision_mask=1
            if world.get_world_2d().direct_space_state.intersect_shape(q,1).is_empty():marker.position=p;return
func refresh() -> void:
    for a in markers:
        var enabled:bool=chapter.available(a)
        var m:Node2D=markers[a];m.visible=enabled
        for art in m.get_meta("art",[]):art.visible=enabled
        if enabled and not m.is_in_group("interactables"):m.add_to_group("interactables")
        elif not enabled and m.is_in_group("interactables"):m.remove_from_group("interactables")
func saved_floor_position(pos:Vector2) -> Vector2:
    # v1 saves predate the full-size mattress; preserve every unaffected position.
    if scene_id!="inn":return pos
    var bed:Node2D=world.get_node("Actors/Props/NapBed63")
    var feet:CollisionShape2D=bed.get_node("Solid/Feet")
    var footprint:=Rect2(bed.position+feet.position-feet.shape.size*.5,feet.shape.size)
    if footprint.grow(7).has_point(pos+Vector2(0,-3)):return Vector2(pos.x,footprint.position.y-10)
    return pos
func _process(_delta:float) -> void:
    if scene_id=="":
        var hero:CharacterBody2D=world.player
        if hero.position.y<2450:exit_prompted=false
        if hero.position.y>2480 and hero.position.x>1250 and hero.position.x<1470 and not exit_prompted and not chapter.dialogue.is_active() and not chapter.ui.is_open() and not chapter.busy:
            exit_prompted=true;chapter.interact("leave")
    if light:light.visible=chapter.state.has("night") and chapter.life.clock.phase_name()==&"night"
    if scene_id=="logging_camp" and not chapter.state.has("wolves_clear") and world.player.position.y<620:
        # Physical western path around the guard, never a dialogue-only bypass.
        if world.player.position.x<420:chapter.apply("bypass")
    if scene_id=="" and chapter.state.has("finale") and not has_node("FreshNotches"):
        var marks:=Node2D.new();marks.name="FreshNotches";marks.position=Vector2(485,805);add_child(marks)
        for i in 3:
            var line:=Line2D.new();line.width=3;line.default_color=Color("cdb68d");line.points=PackedVector2Array([Vector2(-12,i*7),Vector2(9,i*7+3)]);marks.add_child(line)
