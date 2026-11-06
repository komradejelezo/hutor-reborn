from PIL import Image, ImageDraw
import random, math, os, pathlib, shutil
ROOT=pathlib.Path(__file__).resolve().parents[1]
for p in ['scenes/world','scenes/player','scenes/objects','scenes/npc','scripts/components','scripts/ui','assets/characters','assets/environment','assets/tilesets','assets/fonts','shaders','tools','tests','docs']:
 (ROOT/p).mkdir(parents=True,exist_ok=True)
r=random.Random(4126)
def save(im,name): im.save(ROOT/name)
def canvas(w,h):
 im=Image.new('RGBA',(w,h)); return im,ImageDraw.Draw(im)
def shadow(d,box): d.ellipse(box,fill=(10,19,19,90))
def rect(d,b,c):d.rectangle(tuple(map(int,b)),fill=c)
def line(d,p,c,w=1):d.line(p,fill=c,width=w)
def noise_poly(im,poly,base,colors,count):
 d=ImageDraw.Draw(im);d.polygon(poly,fill=base)
 mask=Image.new('1',im.size);ImageDraw.Draw(mask).polygon(poly,fill=1)
 xs=[p[0] for p in poly];ys=[p[1] for p in poly]
 for _ in range(count):
  x=r.randint(min(xs),max(xs));y=r.randint(min(ys),max(ys))
  if 0<=x<im.width and 0<=y<im.height and mask.getpixel((x,y)):d.rectangle((x,y,x+r.randint(1,3),y+1),fill=r.choice(colors))
# A texture atlas: eight variations for each terrain, without painted grid edges.
im,d=canvas(256,160)
pals=[['#354739','#3b4c3b','#304236','#43513d'],['#625a46','#6c604b','#574f40','#71634d'],['#343d38','#3b4540','#444a40','#2f3834'],['#272e2c','#35382e','#444131','#34382f'],['#35494a','#3f5553','#304445','#465b58']]
for row,pal in enumerate(pals):
 for col in range(8):
  x0=col*32;y0=row*32;d.rectangle((x0,y0,x0+31,y0+31),fill=pal[0])
  for k in range(150):
   x=x0+r.randrange(32);y=y0+r.randrange(32);d.line((x,y,min(x+ r.choice([0,1,2,3]),x0+31),y),fill=r.choice(pal))
  if row==0:
   for k in range(9):
    x=x0+r.randrange(30);y=y0+r.randrange(30);d.line((x,y,x+1,y-2),fill='#4d5c42')
  if row==1:
   for k in range(5):
    x=x0+r.randrange(28);y=y0+r.randrange(30);d.line((x,y,x+3,y),fill='#807056')
save(im,'assets/tilesets/terrain.png')
# Ground overlay atlas: tufts, mud flecks, pebbles, leaves.
im,d=canvas(256,32)
for col in range(8):
 x=col*32
 for k in range(10):
  px=x+r.randrange(4,28);py=r.randrange(9,29)
  if col<4:
   line(d,[(px,py),(px-2,py-5)],r.choice(['#65714d','#536749','#76805a']))
   line(d,[(px,py),(px+1,py-7)],'#526443')
  else:d.rectangle((px,py,px+2,py+1),fill=r.choice(['#857357','#53604b','#9a8054']))
save(im,'assets/tilesets/scatter.png')
# Mature conifer silhouettes. Their lower trunk, not the crown, is the obstacle.
for variant in range(3):
 im,d=canvas(104,156);shadow(d,(20,137,91,152));
 rect(d,(48,95,56,145),'#3f392e');rect(d,(49,97,51,144),'#706048')
 for yy in range(102,140,8):line(d,[(52,yy),(55,yy+4)],'#272d28')
 for tier in range(6):
  yy=9+tier*18; half=12+tier*7
  poly=[(51,yy),(51-half+5,yy+26),(51-half,yy+34),(48,yy+29),(51+half,yy+35),(51+half-6,yy+22)]
  noise_poly(im,poly,['#243e35','#294539','#304a3b'][variant],['#365440','#416047','#1c352f','#4a6447'],110+tier*40)
  for k in range(15+tier*4):
   xx=r.randint(53-half,49+half);y=yy+ r.randint(20,29)
   line(d,[(xx,y),(xx-4,y+4)],'#456044' if k%3 else '#54704c')
 save(im,f'assets/environment/pine_{variant}.png')
# Birch with small, mottled leaves and crooked branches.
for variant in range(2):
 im,d=canvas(102,148);shadow(d,(25,130,83,144))
 d.polygon([(45,139),(52,139),(54,52),(49,32),(47,61)],fill='#b9b9a0');rect(d,(49,73,51,138),'#d0c8ad')
 for yy in range(63,137,9):
  xx=r.randrange(46,51);line(d,[(xx,yy),(xx+4,yy+1)],'#3e4940');line(d,[(50,yy+4),(53,yy+4)],'#657166')
 for pts in [[(50,85),(27,59),(21,36)],[(51,72),(75,52),(79,28)],[(50,55),(40,21)]]:
  line(d,pts,'#a2aa91',3)
 for cx,cy,rx,ry in [(29,39,24,25),(62,28,24,24),(74,55,23,29),(44,61,31,26),(45,18,17,16)]:
  d.ellipse((cx-rx,cy-ry,cx+rx,cy+ry),fill='#344c3b')
  for k in range(340):
   xx=r.randrange(cx-rx,cx+rx);yy=r.randrange(cy-ry,cy+ry)
   if ((xx-cx)/rx)**2+((yy-cy)/ry)**2<1:
    d.rectangle((xx,yy,xx+r.randrange(1,4),yy+1),fill=r.choice(['#455e43','#63714d','#73805a','#536c49','#2e4939','#879066']))
 save(im,f'assets/environment/birch_{variant}.png')
# Old log house, three-quarter projection; stone plinth, shingles, carved frames.
im,d=canvas(248,216);shadow(d,(8,185,246,214))
d.polygon([(22,123),(165,117),(232,144),(232,199),(165,213),(22,192)],fill='#383c34')
for yy in range(178,208,9):
 for xx in range(22,230,15):
  if yy < 192 or xx>165:d.rectangle((xx,yy,xx+12,yy+6),fill=r.choice(['#626354','#50594e','#747162']))
# wall front and side
noise_poly(im,[(24,105),(166,105),(166,191),(24,176)],'#64513b',['#705d41','#594832','#807052'],170)
noise_poly(im,[(166,105),(229,128),(229,191),(166,206)],'#423d2e',['#4d4935','#62553b'],100)
for yy in range(113,178,8):
 line(d,[(24,yy),(166,yy+4)],'#322e24',2);line(d,[(27,yy+2),(162,yy+6)],'#8a7550')
for yy in range(125,192,8):line(d,[(168,yy-12),(228,yy+9)],'#272c25',2)
for xx in [26,160]:
 rect(d,(xx,106,xx+7,187),'#4f4130')
 for yy in range(112,185,9):d.ellipse((xx,yy,xx+8,yy+5),fill='#99815a');line(d,[(xx+2,yy+2),(xx+6,yy+2)],'#5c4d37')
# Tall doorway
rect(d,(94,130,124,191),'#312c23');rect(d,(99,132,121,189),'#51432e')
for xx in [102,109,117]:line(d,[(xx,134),(xx,187)],'#796143')
rect(d,(93,126,126,132),'#9a8258');rect(d,(92,132,97,189),'#8a704b');rect(d,(122,132,127,192),'#6c593c');rect(d,(117,158,119,162),'#c69b55')
d.polygon([(89,191),(128,195),(130,202),(88,198)],fill='#87816a')
d.polygon([(84,199),(135,203),(137,209),(83,205)],fill='#555b50')
def window(x,y,w=26,h=28):
 rect(d,(x-4,y-5,x+w+4,y+h+5),'#302c23');rect(d,(x-2,y-3,x+w+2,y+h+3),'#a58a5d')
 rect(d,(x,y,x+w,y+h),'#bb7740');rect(d,(x+2,y+2,x+w-2,y+h-2),'#e4b367')
 line(d,[(x+w//2,y),(x+w//2,y+h)],'#5b4530',2);line(d,[(x,y+13),(x+w,y+13)],'#5b4530',2)
 rect(d,(x-6,y+h+3,x+w+6,y+h+6),'#8a704a')
 for xx in [x-9,x+w+6]:rect(d,(xx,y-1,xx+3,y+h),'#524631');line(d,[(xx,y+3),(xx+3,y+3)],'#978058')
window(46,126);window(176,140,23,25)
# roof polygons
roof=[(7,109),(70,19),(188,36),(174,126)]
noise_poly(im,roof,'#4c4d43',['#5b5b4d','#6b6856','#3c423b','#77705a'],700)
for yy in range(35,124,7):
 t=(yy-19)/107; left=70-63*t; right=188-14*t
 line(d,[(left,yy),(right,yy+8)],'#303a33',2)
 for xx in range(int(left)+r.randrange(6),int(right),10):line(d,[(xx,yy),(xx-3,yy+6)],'#7c7760' if r.random()<.35 else '#41483d')
noise_poly(im,[(188,36),(244,121),(174,126)],'#3b4239',['#4c5144','#61624e','#303c34'],220)
line(d,[(7,109),(174,126),(244,121)],'#928366',4);line(d,[(70,18),(188,36),(244,121)],'#7c7359',3)
# moss, breaks
for k in range(150):
 xx=r.randint(20,175);yy=r.randint(86,115)
 if (xx>40 or yy>96):rect(d,(xx,yy,xx+3,yy+1),r.choice(['#566646','#67704c','#7b7d53']))
# chimney
rect(d,(151,14,168,49),'#5a5748');rect(d,(148,10,171,16),'#837b62');rect(d,(151,8,168,11),'#313a32')
for yy in range(20,48,7):line(d,[(152,yy),(168,yy)],'#373e34');line(d,[(158,yy),(158,yy+5)],'#a08b6b')
# hanging charms, doorstep tools
line(d,[(84,126),(84,148)],'#b29b6b');d.polygon([(84,135),(80,140),(84,145),(88,140)],fill='#a59368')
line(d,[(211,157),(220,196)],'#9c865b',2)
for off in [-4,0,4]:line(d,[(220,184),(221+off,197)],'#796848')
save(im,'assets/environment/izba.png')
# utility shed
im,d=canvas(160,150);shadow(d,(5,123,158,149))
noise_poly(im,[(14,62),(111,57),(149,83),(149,137),(109,147),(14,133)],'#534835',['#6d5d40','#62553a','#3e3b2d'],200)
for xx in range(17,111,9):line(d,[(xx,64),(xx,133)],'#2b3027',2);line(d,[(xx+3,66),(xx+3,131)],'#86724f')
for yy in range(88,139,9):line(d,[(112,yy-7),(148,yy)],'#2e3329',2)
rect(d,(47,77,91,137),'#322f25')
for xx in range(50,91,8):rect(d,(xx,79,xx+5,135),'#67543a')
line(d,[(49,81),(89,133)],'#947a51',4);line(d,[(50,130),(89,83)],'#796445',3)
roof=[(2,67),(39,8),(122,20),(114,80)]
noise_poly(im,roof,'#4e5143',['#77735b','#625f4c','#3e463a'],400)
for yy in range(22,76,7):line(d,[(37-(yy-22)*.5,yy),(120-(yy-22)*.12,yy+3)],'#303a30',2)
d.polygon([(122,20),(158,74),(114,80)],fill='#343e33');line(d,[(2,67),(114,80),(158,74)],'#8b7c5d',3)
rect(d,(16,83,33,104),'#242f28');line(d,[(24,83),(24,104)],'#806b49',2)
save(im,'assets/environment/shed.png')
# well roof and stone masonry
im,d=canvas(78,96);shadow(d,(3,76,76,95))
d.ellipse((11,58,69,90),fill='#414c44');rect(d,(11,65,69,78),'#626957')
for yy in [65,74,83]:
 for xx in range(12,66,13):rect(d,(xx+(5 if yy==74 else 0),yy,xx+10,yy+6),r.choice(['#8c8b70','#6c7764','#a09a7a']))
d.ellipse((12,54,68,72),fill='#99977a');d.ellipse((20,57,60,68),fill='#1d302d')
rect(d,(12,24,17,72),'#776242');rect(d,(61,23,66,73),'#68573d')
line(d,[(17,39),(63,39)],'#ac9160',3);rect(d,(36,34,44,44),'#504536');line(d,[(40,43),(40,62)],'#a69369')
d.polygon([(2,28),(29,3),(71,13),(76,36),(37,40)],fill='#494e3e')
for yy in [14,21,28]:line(d,[(25-(yy-14),yy),(71,yy+9)],'#75735a',2)
line(d,[(2,28),(37,40),(76,36)],'#9c885f',3)
rect(d,(59,73,69,86),'#594c34');rect(d,(60,75,68,77),'#a59670')
save(im,'assets/environment/well.png')
# Fences: pivot at centre of footprint.
for kind in ['h','v']:
 im,d=canvas(68 if kind=='h' else 18,40 if kind=='h' else 64)
 if kind=='h':
  shadow(d,(0,32,68,39))
  for yy in [15,26]:rect(d,(1,yy,66,yy+4),'#756543');line(d,[(1,yy),(65,yy)],'#a28b5c')
  for xx in [4,32,61]:
   d.polygon([(xx-2,37),(xx-2,8),(xx,4),(xx+3,8),(xx+3,37)],fill='#6e5e3f');line(d,[(xx,9),(xx,35)],'#a38a5c')
 else:
  line(d,[(7,3),(7,63)],'#776646',4);line(d,[(12,3),(12,63)],'#8b7650',3)
  for yy in [5,32,59]:rect(d,(4,yy-8,14,yy+3),'#5d533b');rect(d,(7,yy-10,10,yy+2),'#a18c60')
 save(im,f'assets/environment/fence_{kind}.png')
# props
for name,w,h in [('rock',42,30),('stump',38,32),('barrel',26,36),('sign',58,66),('lantern',32,88),('grass',28,25),('reeds',36,52),('mushrooms',24,20),('logs',56,32),('crop',32,24),('puddle',88,39)]:
 im,d=canvas(w,h);shadow(d,(1,h-10,w-1,h-1))
 if name=='rock':
  noise_poly(im,[(3,23),(7,10),(20,3),(34,7),(40,23),(28,28),(12,26)],'#676e60',['#8d9078','#7b826e','#505e54'],70);line(d,[(9,11),(20,5),(31,9)],'#a1a18a',2)
 elif name=='stump':
  d.polygon([(7,10),(30,10),(32,25),(37,29),(3,29),(9,23)],fill='#594b33');d.ellipse((6,3,31,15),fill='#9f885c');d.ellipse((11,5,26,12),outline='#675a3e');line(d,[(19,5),(17,12)],'#584c34');line(d,[(11,15),(10,24)],'#8d734c',2)
 elif name=='barrel':
  d.rounded_rectangle((3,4,23,33),radius=5,fill='#77603c');d.ellipse((3,1,23,9),fill='#a58a59');d.ellipse((6,3,20,7),outline='#625135')
  for xx in [7,12,18]:line(d,[(xx,10),(xx,31)],'#4d432f')
  for yy in [12,26]:rect(d,(3,yy,23,yy+2),'#444c42')
 elif name=='sign':
  rect(d,(27,13,32,62),'#7b6544');rect(d,(29,14,30,60),'#ac8c5c');d.polygon([(4,9),(43,9),(55,17),(43,25),(4,25)],fill='#8b734c');line(d,[(7,11),(43,11)],'#b09968');
  for xx in range(10,40,5):line(d,[(xx,15),(xx+2,20)],'#51452f')
  d.polygon([(9,30),(45,30),(45,43),(9,43),(2,37)],fill='#66563c')
 elif name=='lantern':
  rect(d,(10,10,15,84),'#62543a');rect(d,(10,10,29,14),'#83704d');line(d,[(27,14),(27,22)],'#383e32',2)
  d.polygon([(19,24),(31,24),(29,38),(21,38)],fill='#d29b4e');rect(d,(23,26,27,35),'#ffe4a1');line(d,[(18,23),(31,23)],'#474d3a',2);line(d,[(21,39),(30,39)],'#383e30',2)
 elif name in ['grass','reeds','crop']:
  for k in range(16 if name!='crop' else 10):
   x=r.randrange(3,w-3);y=h-r.randrange(3,10);high=r.randrange(6,h-5)
   col=r.choice(['#65754d','#7d8454','#4d6746','#8a8855'])
   line(d,[(x,y),(x-2,y-high//2),(x+r.choice([-4,3,1]),y-high)],col)
   if name=='reeds':rect(d,(x-1,y-high-4,x+1,y-high+1),'#9d8453')
   if name=='crop':d.ellipse((x-3,y-7,x+3,y-3),fill='#727e4b')
 elif name=='mushrooms':
  for x,y in [(5,11),(14,13),(19,7)]:
   rect(d,(x,y,x+1,y+5),'#b9ad83');d.ellipse((x-3,y-3,x+3,y),fill='#a17548');rect(d,(x-1,y-3,x,y-2),'#c6a36b')
 elif name=='logs':
  for x,y in [(3,19),(20,20),(10,11)]:
   d.polygon([(x,y),(x+26,y-8),(x+34,y-3),(x+8,y+7)],fill='#514730');d.ellipse((x,y-2,x+12,y+8),fill='#a38b5d');d.ellipse((x+3,y,x+9,y+5),outline='#6c5b3d')
 elif name=='puddle':
  d.polygon([(2,19),(12,9),(30,8),(40,2),(64,6),(75,16),(85,19),(76,30),(43,35),(29,30),(9,31)],fill='#555744')
  d.polygon([(7,20),(16,13),(33,12),(43,6),(62,10),(71,19),(79,21),(70,27),(42,31),(29,26),(12,27)],fill='#354e50')
  for k in range(14):
   x=r.randrange(16,67);y=r.randrange(16,26);line(d,[(x,y),(x+r.randrange(3,13),y)],r.choice(['#61766c','#4c6963','#78867a']))
 save(im,f'assets/environment/{name}.png')
# Animated campfire sheet, 8 independent frames.
im,d=canvas(64*8,64)
for f in range(8):
 x=f*64
 shadow(d,(x+3,44,x+61,62))
 for a in range(0,360,40):
  xx=x+32+int(23*math.cos(math.radians(a)));yy=48+int(10*math.sin(math.radians(a)))
  d.ellipse((xx-5,yy-3,xx+5,yy+3),fill=r.choice(['#747568','#8d8870','#59665a']))
 line(d,[(x+18,46),(x+47,53)],'#725132',5);line(d,[(x+20,53),(x+45,44)],'#8b6238',4)
 for j in range(5):
  xx=x+21+j*5;top=r.randrange(12,31)
  d.polygon([(xx-4,47),(xx-5,33),(xx+1,top),(xx+5,35),(xx+7,48)],fill=['#c46b30','#dd8538','#edaa46','#c87632','#ad542b'][j])
  d.polygon([(xx-2,47),(xx,30),(xx+4,45)],fill='#ffd17a')
 save(im,'assets/environment/fire.png')
# Hans: 4 directions × 8 frames. Adult proportion, 6 pixel head / 40 pixel height.
im,d=canvas(32*8,48*4)
for dr in range(4):
 for frame in range(8):
  x=frame*32;y=dr*48;walk=frame>=2;phase=(frame-2)*math.tau/6 if walk else 0
  step=round(math.sin(phase)*3) if walk else 0;bob=round(abs(math.sin(phase))) if walk else frame
  # boots and separated legs
  by=y+44
  rect(d,(x+11+step,by-10,x+14+step,by-2),'#3c3a31');rect(d,(x+18-step,by-10,x+21-step,by-2),'#454031')
  rect(d,(x+10+step,by-3,x+15+step,by),'#302e28');rect(d,(x+17-step,by-3,x+22-step,by),'#302e28')
  line(d,[(x+11+step,by-3),(x+14+step,by-3)],'#7b6546');line(d,[(x+18-step,by-3),(x+21-step,by-3)],'#776347')
  b=y+bob
  # cloak jagged hem, shoulders, fold highlights
  d.polygon([(x+10,b+14),(x+21,b+14),(x+24,b+23),(x+25+(step//2),b+36),(x+20,b+38),(x+16,b+35),(x+10,b+37),(x+7,b+34),(x+8,b+23)],fill='#42483e')
  d.polygon([(x+11,b+17),(x+14,b+19),(x+12,b+33),(x+9,b+35)],fill='#61634d');line(d,[(x+19,b+19),(x+21,b+33)],'#292f2b',2)
  line(d,[(x+9,b+35),(x+11,b+36),(x+14,b+34)],'#8a8060')
  # Head shape, hair. Front/down, left, right, back.
  hx=x+12;hy=b+6
  rect(d,(hx,hy,hx+8,hy+10),'#967658');rect(d,(hx,hy,hx+8,hy+3),'#302f2a');rect(d,(hx-1,hy+2,hx+1,hy+7),'#35332b')
  line(d,[(hx+1,hy),(hx+7,hy)],'#56503e')
  if dr==3:
   rect(d,(hx,hy+2,hx+8,hy+8),'#35362d');rect(d,(hx+2,hy+9,hx+7,hy+11),'#4a4434')
   line(d,[(x+16,b+18),(x+16,b+34)],'#71715a')
  else:
   if dr==1:
    rect(d,(hx-2,hy+5,hx+3,hy+8),'#b08e65');rect(d,(hx-2,hy+8,hx+5,hy+12),'#423b2e');rect(d,(hx,hy+5,hx+1,hy+5),'#242c28')
   elif dr==2:
    rect(d,(hx+5,hy+5,hx+10,hy+8),'#b08e65');rect(d,(hx+3,hy+8,hx+10,hy+12),'#423b2e');rect(d,(hx+7,hy+5,hx+8,hy+5),'#242c28')
   else:
    rect(d,(hx+1,hy+4,hx+7,hy+7),'#b7966b');rect(d,(hx+1,hy+8,hx+7,hy+12),'#423d30');rect(d,(hx+3,hy+8,hx+5,hy+9),'#8f7050')
    for ex in [hx+2,hx+6]:rect(d,(ex,hy+5,ex,hy+5),'#242b26')
   line(d,[(x+13,b+20),(x+20,b+22)],'#a08a5d');rect(d,(x+16,b+21,x+17,b+22),'#b5aa78')
  # bag strap and bag on hip
  line(d,[(x+11,b+17),(x+22,b+29)],'#88734e',2);rect(d,(x+21,b+27,x+26,b+34),'#7e5d3a');rect(d,(x+20,b+27,x+26,b+29),'#a08050');rect(d,(x+23,b+30,x+24,b+31),'#c4ac71')
save(im,'assets/characters/hans.png')
# Light cookie, smoke and tiny particle.
im=Image.new('RGBA',(128,128));pix=im.load()
for y in range(128):
 for x in range(128):
  dist=math.hypot((x-63.5)/64,(y-63.5)/64);v=max(0,1-dist);v=v*v*(3-2*v)
  pix[x,y]=(255,255,255,int(v*255))
save(im,'assets/environment/light.png')
im,d=canvas(16,16)
for rad,alpha in [(7,10),(6,18),(5,30),(4,45),(3,60)]:d.ellipse((8-rad,8-rad,8+rad,8+rad),fill=(179,188,172,alpha))
save(im,'assets/environment/smoke.png')
# Icon
im,d=canvas(128,128);d.rectangle((0,0,127,127),fill='#1c2d29');d.polygon([(19,68),(64,20),(109,68)],fill='#9d8657');rect(d,(30,64,98,108),'#5d5c42');rect(d,(52,78,75,108),'#e3b86b');line(d,[(64,79),(64,106)],'#68563b',3);save(im,'icon.png')
print('Original pixel assets regenerated in',ROOT)

from PIL import Image,ImageDraw
import random
p=ROOT/'assets/tilesets/terrain.png'
a=Image.open(p);b=Image.new('RGBA',(256,224));b.paste(a,(0,0));r=random.Random(22)
for m in range(16):
 ox=(m%8)*32;oy=(5+m//8)*32
 for y in range(32):
  for x in range(32):
   near=[]
   if not m&1: near.append(y)
   if not m&2: near.append(31-x)
   if not m&4: near.append(31-y)
   if not m&8: near.append(x)
   dist=min(near) if near else 99
   c=a.getpixel((x+r.randrange(8)*32,y+(32 if dist>r.randrange(2,9) else 0)))
   b.putpixel((ox+x,oy+y),c)
b.save(p)
