extends SceneTree
## Standalone controlled 2D texture rig. Writes only this deliverable directory.
## Artwork comes from ONE new RGBA source. No RGB-background key exists here.
var directory:=OS.get_environment("HANS_REBORN_DIR")
var config:Dictionary
var master:Image
var torso:PackedFloat32Array=[]
var shoulder:PackedFloat32Array=[]
var cape:PackedFloat32Array=[]
func _initialize() -> void:call_deferred("run")
func bump(p:Vector2,box:Array) -> float:
    var u:=(p.x-float(box[0]))/(float(box[2])-float(box[0]))
    var v:=(p.y-float(box[1]))/(float(box[3])-float(box[1]))
    if u<=0 or u>=1 or v<=0 or v>=1:return 0
    return pow(sin(u*PI),2)*pow(sin(v*PI),2)
func weights() -> void:
    torso.resize(512*512);shoulder.resize(512*512);cape.resize(512*512)
    var sword:=PackedVector2Array()
    for p in config.lock_weapon_hand_sword:sword.append(Vector2(p[0],p[1]))
    var bag:=Rect2(config.lock_backpack[0],config.lock_backpack[1],config.lock_backpack[2]-config.lock_backpack[0],config.lock_backpack[3]-config.lock_backpack[1])
    for y in 512:
        for x in 512:
            var i:=y*512+x;var p:=Vector2(x,y)
            if y<=int(config.lock_head_above_y) or y>=int(config.lock_ground_below_y) or bag.has_point(p) or Geometry2D.is_point_in_polygon(p,sword):continue
            torso[i]=bump(p,config.torso.box)
            shoulder[i]=bump(p,config.shoulder.box)
            cape[i]=bump(p,config.cape.box)
    var image:=Image.create(512,512,false,Image.FORMAT_RGBA8)
    for y in 512:
        for x in 512:
            var i:=y*512+x;image.set_pixel(x,y,Color(torso[i],shoulder[i],cape[i],1))
    image.save_png(directory+"/working/rig_weights.png")
func weight_at(values:PackedFloat32Array,p:Vector2) -> float:
    return values[clampi(int(round(p.y)),0,511)*512+clampi(int(round(p.x)),0,511)]
func displacement(p:Vector2,phase:float) -> Vector2:
    var t:=weight_at(torso,p);var s:=weight_at(shoulder,p);var c:=weight_at(cape,p)
    return Vector2(c*float(config.cape.amplitude_x)*sin(phase+float(config.cape.phase)),
        -(t*float(config.torso.amplitude_y)+s*float(config.shoulder.amplitude_y))*sin(phase)+c*float(config.cape.amplitude_y)*sin(phase+.1))
func run() -> void:
    if directory.is_empty():push_error("HANS_REBORN_DIR required");quit(1);return
    config=JSON.parse_string(FileAccess.get_file_as_string(directory+"/working/rig.json"))
    var source:=Image.load_from_file(directory+"/working/"+String(config.source))
    if source==null:push_error("Missing new RGBA source");quit(1);return
    source.convert(Image.FORMAT_RGBA8)
    var coverage:=Image.create(source.get_width(),source.get_height(),false,Image.FORMAT_L8)
    var calibrated:=Image.create(source.get_width(),source.get_height(),false,Image.FORMAT_RGBA8)
    var source_black_kept:=0;var retained:=0
    for y in source.get_height():
        for x in source.get_width():
            var pixel:=source.get_pixel(x,y)
            # Separate matte uses only supplied alpha. RGB never decides coverage.
            if pixel.a*255>=float(config.matte.threshold):
                coverage.set_pixel(x,y,Color.WHITE);pixel.a=1;calibrated.set_pixel(x,y,pixel);retained+=1
                if pixel.r==0 and pixel.g==0 and pixel.b==0:source_black_kept+=1
    coverage.save_png(directory+"/working/source_coverage.png")
    # Keep every original covered texel. Downsampling the matte introduced
    # pinholes at fine cape cuts; native pixels plus padding avoid that loss.
    master=Image.create(1280,1280,false,Image.FORMAT_RGBA8)
    master.blit_rect(calibrated,Rect2i(0,0,source.get_width(),source.get_height()),Vector2i(13,13))
    master.save_png(directory+"/working/master.png")
    weights()
    var frames:Array=[]
    for index in int(config.frames):
        var phase:=TAU*index/float(config.frames)
        var image:Image=master.duplicate()
        var texel_scale:=float(source.get_width())/512.0
        for y in range(380,1078):
            for x in range(172,908):
                var p:=(Vector2(x,y)-Vector2(13,13))/texel_scale;var q:=p
                for iteration in 3:q=p-displacement(q,phase)
                var sample:=q*texel_scale+Vector2(13,13)
                image.set_pixel(x,y,master.get_pixel(clampi(int(round(sample.x)),0,1279),clampi(int(round(sample.y)),0,1279)))
        var name:="idle_%02d.png"%(index+1)
        var error:Error=image.save_png(directory+"/frames/"+name)
        if error!=OK:push_error("PNG write failed "+name);quit(1);return
        frames.append({"frame":index+1,"file":"frames/"+name,"phase_radians":phase,"anchor":config.anchor,"sha256":FileAccess.get_sha256(directory+"/frames/"+name)})
        print("FRAME: ",index+1," ",frames[-1].sha256)
    var record:={"source_sha256":FileAccess.get_sha256(directory+"/working/color_source.png"),"source_covered_pixels":retained,"source_black_rgb_pixels_preserved":source_black_kept,"matte_uses_rgb":false,"source_zero_alpha_filled":false,"canvas":config.canvas,"anchor":config.anchor,"frame_seconds":config.frame_seconds,"frames":frames}
    var f:=FileAccess.open(directory+"/MANIFEST.json",FileAccess.WRITE);f.store_string(JSON.stringify(record,"  "));f.close()
    print("RESULT: 12 new controlled-rig frames; original source dark RGB preserved: ",source_black_kept)
    call_deferred("quit",0)
