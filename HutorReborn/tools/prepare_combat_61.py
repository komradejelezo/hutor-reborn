"""Technical Nearest slicing of temporary combat poses, no animation claims."""
from pathlib import Path
import json,hashlib
import numpy as np
from scipy import ndimage as nd
from PIL import Image
P=Path(__file__).resolve().parents[1];B=P/'assets/combat/stage61';S=B/'source';S.mkdir(exist_ok=True)
paths={'background':'exec-af601abe-73a4-49ac-8fe0-5aa808c79dbc.png','fighters':'exec-160567ff-dd92-4761-96dc-05927bd61235.png'}
import shutil
for key,path in paths.items():
 if not (S/(key+'.png')).exists():shutil.copyfile('/workspace/generated_images/'+path,S/(key+'.png'))
(S/'.gdignore').touch();manifest={'sources':{},'poses':[]}
for key in paths:
 p=S/(key+'.png');manifest['sources'][key]={'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'file':p.name}
im=Image.open(S/'background.png').convert('RGB');factor=960/im.width;im=im.resize((960,round(im.height*factor)),Image.Resampling.NEAREST);y=(im.height-540)//2;im.crop((0,y,960,y+540)).save(B/'clearing.png')
a=np.array(Image.open(S/'fighters.png').convert('RGBA'));r,g,b=[a[:,:,i].astype(float) for i in range(3)]
neon=((r>165)&(g<75)&(b<75))|((g>135)&(g>r*1.3)&(g>b*1.3))
keep=nd.binary_opening((a[:,:,3]>=200)&~neon,structure=np.ones((2,2)));a[~keep]=0;a[:,:,3]=keep*255;im=Image.fromarray(a)
# The source has four separated equal panels, not four animation frames.
for i,(name,height) in enumerate([('wolf',30),('beast',56),('spirit',58),('mercenary',49)]):
 x0,x1=round(i*im.width/4),round((i+1)*im.width/4);panel=im.crop((x0,0,x1,im.height));box=panel.getbbox();assert box
 panel=panel.crop(box);factor=height/panel.height;native=panel.resize((round(panel.width*factor),height),Image.Resampling.NEAREST)
 out=Image.new('RGBA',(96,96));out.paste(native,(48-native.width//2,82-height));assert min(out.getbbox())>0 and max(out.getbbox())<96;out.save(B/(name+'.png'))
 manifest['poses'].append({'kind':name,'source_box':[x0+box[0],box[1],x0+box[2],box[3]],'height':height,'uniform_scale':factor,'pivot':[48,82]})
(B/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print('Prepared forest background and four individual temporary poses; no Hans/NPC assets modified')
