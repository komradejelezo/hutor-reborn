extends "res://tools/review_woodcutter_542.gd"
## The approved choreography and clips stay identical; align diagnostic props only.
func prop(item_name:String,texture:String,point:Vector2,factor:float,solid:bool) -> Node2D:
    if texture.ends_with("placed_logs.png"):
        point.x+=18*.08
        factor*=1.08
    var item:Node2D=super.prop(item_name,texture,point,factor,solid)
    if texture.ends_with("placed_logs.png"):
        item.get_node("Art").material=load("res://assets/npc/woodcutter542/game/palette_543.tres")
    return item

func snapshot(item_name:String) -> void:
    caption.text=caption.text.replace("5.4.2","5.4.3")
    await super.snapshot(item_name)
