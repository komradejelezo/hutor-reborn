extends Node2D
## Separate, bounded green light/bolt. No body tween or combat side effects.
var source:Vector2
var destination:Vector2
var remaining:=0.22
var lifetime:=0.22
func _ready() -> void:z_index=12
func _process(delta:float) -> void:
    remaining-=delta
    if remaining<=0:queue_free()
    else:queue_redraw()
func _draw() -> void:
    var alpha:=clampf(remaining/lifetime,0,1)
    var color:=Color(.2,.95,.35,alpha*.6)
    draw_line(source,destination,Color(.15,.8,.28,alpha*.15),8)
    draw_line(source,destination,color,2)
    draw_circle(source,5,Color(.35,1,.45,alpha*.3))
    draw_circle(destination,9,Color(.2,.9,.35,alpha*.18))
