extends Node2D
## Bounded pixel-art overlays. Only branch tips/grass move; the supplied master,
## trunks, roots, fence and fighting ground remain completely stationary.
var elapsed:=0.0
var quality:=2
var effects:Dictionary={"wind":true,"fog":true,"leaves":true,"lighting":true,"smoke":true}
const ROOTS=[Vector2(0,248),Vector2(960,238),Vector2(235,153),Vector2(837,118)]
const TIPS=[Vector2(85,-28),Vector2(-101,-27),Vector2(77,29),Vector2(-64,24)]
const GRASS=[Vector2(18,333),Vector2(913,328),Vector2(26,407),Vector2(714,456),Vector2(200,454),Vector2(436,455)]
const WINDOWS=[Vector2(557,136),Vector2(568,134),Vector2(588,135),Vector2(617,126),Vector2(635,135),Vector2(694,185),Vector2(743,185)]
func _process(delta:float) -> void:
    elapsed+=minf(delta,.1);queue_redraw()
func gust(index:int) -> float:
    # Independent quiet intervals, gust envelopes and higher-frequency flutter.
    var phase:=index*1.83
    return pow(maxf(0,sin(elapsed*.31+phase)),2)*sin(elapsed*1.17+phase)*2.7
func pixel(p:Vector2) -> Vector2:return p.round()
func _draw() -> void:
    if quality==0:return
    if effects.wind:
        for i in (4 if quality==2 else 2):
            var root:Vector2=ROOTS[i];var tip:Vector2=root+TIPS[i]+Vector2(0,gust(i))
            var mid:Vector2=root.lerp(tip,.5)+Vector2(0,-4)
            draw_line(pixel(root),pixel(mid),Color("352a22"),3,false)
            draw_line(pixel(mid),pixel(tip),Color("483324"),2,false)
            for j in 9:
                var t:=.35+j*.073
                var p:=root.lerp(tip,t)+Vector2(0,-sin(t*PI)*5)
                var twig:=p+Vector2((1 if i%2==0 else -1)*9,(-1 if j%2==0 else 1)*(8+j%3))
                twig.y+=sin(elapsed*1.5+i+j)*maxf(.2,absf(gust(i))*.3)
                draw_line(pixel(p),pixel(twig),Color("4b3627"),1,false)
                for k in 3:
                    var leaf:=pixel(twig+Vector2(k*3-3,(k%2)*2-1))
                    draw_rect(Rect2(leaf,Vector2(3,2)),Color("815330") if (j+k)%3 else Color("a36b36"))
        for i in GRASS.size():
            var root:Vector2=GRASS[i]
            for j in 5:
                var base:=root+Vector2(j*3,0)
                var tip:=base+Vector2((j-2)*1.5+gust(i+4)*.65,-4-j%3*2)
                draw_line(pixel(base),pixel(tip),Color("635b35") if j%2 else Color("7d7042"),1,false)
    if effects.leaves:
        for i in (10 if quality==2 else 3):
            var phase:=i*1.73;var duration:=22.0+(i%4)*5.0
            var cycle:=fposmod(elapsed/duration+i*.137,1.0)
            if cycle>.65:continue # Quiet interval between individual falling leaves.
            cycle/=.65
            var alpha:=minf(1,cycle*8)*minf(1,(1-cycle)*7)*.65
            var x:=fposmod(45+i*139+cycle*(36+i%3*22)+sin(elapsed*.42+phase)*10,950)
            var p:=pixel(Vector2(x,80+cycle*360))
            var angle:=elapsed*(.6+i%3*.17)+phase
            var points:=PackedVector2Array()
            for v in [Vector2(-2,0),Vector2(0,-1),Vector2(2,0),Vector2(0,1)]:points.append(pixel(p+v.rotated(angle)))
            var c:Color=[Color("b26838"),Color("8f4d32"),Color("c27b40")][i%3];c.a=alpha
            draw_colored_polygon(points,c)
    if effects.lighting:
        for i in WINDOWS.size():
            var c:=Color(.95,.47,.16,.07+.025*sin(elapsed*.65+i*1.37)+.01*sin(elapsed*1.7+i))
            draw_rect(Rect2(WINDOWS[i],Vector2(2,4)),c)
    if effects.smoke:
        # Two existing roof chimneys, distant and deliberately low contrast.
        for i in (6 if quality==2 else 2):
            var root:=Vector2(718,134) if i%2==0 else Vector2(764,137)
            var age:=fposmod(elapsed*.055+i*.167,1.0)
            var p:=pixel(root+Vector2(sin(age*4+i)*3+age*6,-age*29))
            var c:=Color(.56,.55,.51,sin(age*PI)*.10)
            draw_rect(Rect2(p,Vector2(2+int(age*3),2+int(age*3))),c)
