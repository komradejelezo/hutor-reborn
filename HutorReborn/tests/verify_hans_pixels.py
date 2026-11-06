"""Check original RGBA pixels, crop boundaries, guide exclusion and foot alignment.
Run: python3 HutorReborn/tests/verify_hans_pixels.py (requires Pillow).
"""
from pathlib import Path
from PIL import Image, ImageChops
import hashlib
import json

PROJECT = Path(__file__).resolve().parents[1]
ASSETS = PROJECT / 'assets/characters/hans'
manifest = json.loads((ASSETS / 'slicing.json').read_text())
count = 0
for info in manifest['sources']:
    path = ASSETS / 'source' / info['file']
    assert hashlib.sha256(path.read_bytes()).hexdigest() == info['sha256'], info['file']
    image = Image.open(path)
    assert image.mode == 'RGBA' and list(image.size) == info['size']
    count += 1
for info in manifest['frames']:
    source = Image.open(ASSETS / 'source' / info['source'])
    crop = source.crop(info['source_box'])
    frame = Image.open(PROJECT / info['file'])
    assert frame.mode == 'RGBA' and list(frame.size) == manifest['canvas']
    dx, dy = info['paste_offset']
    actual = frame.crop((dx, dy, dx+crop.width, dy+crop.height))
    # Every pixel must be the original RGBA value, or an explicitly removed grey guide.
    different = ImageChops.difference(actual, crop)
    allowed = 0
    for y in range(crop.height):
        for x in range(crop.width):
            if different.getpixel((x,y)) != (0,0,0,0):
                r,g,b,a = crop.getpixel((x,y))
                assert info['source']=='ходьба.png' and y>=1238 and max(r,g,b)-min(r,g,b)<=12 and min(r,g,b)>=60 and a==255
                assert actual.getpixel((x,y))==(0,0,0,0)
                allowed += 1
    assert allowed == info['guide_pixels_removed']
    # Outside the source rectangle there must only be transparent padding.
    padding = frame.copy()
    padding.paste((0,0,0,0), (dx,dy,dx+crop.width,dy+crop.height))
    assert padding.getchannel('A').getbbox() is None
    src = next(s for s in manifest['sources'] if s['file']==info['source'])
    assert [dx+src['foot'][0],dy+src['foot'][1]]==manifest['pivot']
    # Excluded columns must contain only the vertical guide, never neighbouring art.
    if crop.width<793:
        tail=source.crop((info['source_box'][2],0,(info['index']+1)*793,source.height))
        for r,g,b,a in zip(*(iter(tail.tobytes()),)*4):
            assert a==0 or (max(r,g,b)-min(r,g,b)<=12 and min(r,g,b)>=60)
    assert hashlib.sha256((PROJECT/info['file']).read_bytes()).hexdigest()==info['sha256']
    count += 1
print(f'PASS: {count} source/frame checks — source RGBA pixels preserved, no crop bleed, aligned feet.')
