extends Node2D
## Keyframe-only pixel flash/dust; no damage, screen shake or body displacement.
var lifetime:=.24
var remaining:=.24
var green:=false
func _ready() -> void:z_index=13
func _process(delta:float) -> void:
    remaining-=delta
    if remaining<=0:queue_free()
    else:queue_redraw()
func _draw() -> void:
    var t:=1-remaining/lifetime
    var c:=Color(.55,.84,.32,1-t) if green else Color(.84,.69,.43,(1-t)*.75)
    for i in 5:
        var direction:=Vector2.from_angle(i*TAU/5+.3)
        var p:Vector2=(direction*(2+t*10)).round()
        draw_line(p,(p+direction*(2-t)).round(),c,1,false)
    if t<.22:draw_rect(Rect2(-1,-1,2,2),c)
