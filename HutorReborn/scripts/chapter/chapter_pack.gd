extends Node2D
var done:=false
func _ready() -> void:
    var c:Node=get_node_or_null("/root/ChapterI")
    if c and c.active and c.state.has("wolves_clear"):
        done=true
        for shape in find_children("*","CollisionShape2D",true,false):shape.set_deferred("disabled",true)
        if c.state.decisions.get("wolves")=="bait":hide()
        elif c.state.decisions.get("wolves")=="fight":modulate.a=.18
func _process(_delta:float) -> void:
    var c:Node=get_node_or_null("/root/ChapterI")
    if not c or not c.active or done or not c.state.has("wolves_clear"):return
    done=true
    for body in find_children("*","CollisionShape2D",true,false):body.set_deferred("disabled",true)
    if c.state.decisions.get("wolves")=="bait":
        var tween:=create_tween();tween.tween_property(self,"position",position+Vector2(340,-200),1.6);tween.tween_property(self,"modulate:a",0.0,.4)
    elif c.state.decisions.get("wolves")=="fight":modulate.a=.18
