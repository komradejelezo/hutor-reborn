extends Node2D
## Sparse pixel leaves, window light and two additional foreground twigs.
## No sampled master pixels, duplicate cutouts, tree/ground displacement or camera motion.
var elapsed:=0.0
func _process(delta:float) -> void:
    elapsed+=minf(delta,.1);queue_redraw()
func _draw() -> void:
    # Coordinates refer to the fixed 960 x 540 combat canvas.
    for i in 7:
        var phase:=float(i)*1.73
        var cycle:=fmod(elapsed*.014+float(i)*.143,1.0)
        var alpha:=sin(cycle*PI)*.44
        var x:=fposmod(60+i*147+elapsed*(1.3+float(i%3)*.35)+sin(elapsed*.18+phase)*5,950)
        var y:=90+cycle*340
        var colors:=[Color("b26838"),Color("8f4d32"),Color("c27b40")]
        var color:Color=colors[i%3];color.a=alpha
        draw_rect(Rect2(Vector2(roundf(x),roundf(y)),Vector2(2,1)),color)
        draw_rect(Rect2(Vector2(roundf(x)+1,roundf(y)-1),Vector2(1,1)),color*.8)
    # Source window locations, measured in the supplied master (1672 x 941).
    for i in 7:
        var p:Vector2=[Vector2(557,136),Vector2(568,134),Vector2(588,135),Vector2(617,126),Vector2(635,135),Vector2(694,185),Vector2(743,185)][i]
        var color:=Color(.95,.47,.16,.06+.035*sin(elapsed*.65+i*1.37))
        draw_rect(Rect2(p,Vector2(2,4)),color)
    # Newly drawn small edge twigs: intentionally not fake extracted tree layers.
    for i in 2:
        var root:=Vector2(13,280) if i==0 else Vector2(947,251)
        var sign_x:=1.0 if i==0 else -1.0
        var breeze:=pow(maxf(0,sin(elapsed*.22+i*2.3)),3)*sin(elapsed*.43+i)*.7
        var tip:=root+Vector2(sign_x*28,-18+breeze)
        draw_line(root,tip,Color("332a23"),2,false)
        draw_line(root+Vector2(sign_x*15,-9),tip+Vector2(sign_x*3,-10),Color("403024"),1,false)
        for j in 4:
            var p:=tip+Vector2(sign_x*(j*3-5),j%2*3-4)
            draw_rect(Rect2(p,Vector2(3,2)),Color("975632") if j%2==0 else Color("713c2b"))
