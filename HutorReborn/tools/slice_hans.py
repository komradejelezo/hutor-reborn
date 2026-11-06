"""Lossless slicing of the four user-supplied PNGs; requires Pillow, not used at runtime.

No drawing, background removal, colour correction, or image resampling. Only the
side-walk sheet's non-character guides are excluded. Originals stay byte-identical.
Run from any directory: python3 HutorReborn/tools/slice_hans.py
"""
from pathlib import Path
from PIL import Image, ImageChops
import hashlib
import json

PROJECT = Path(__file__).resolve().parents[1]
ASSETS = PROJECT / 'assets/characters/hans'
CANVAS = (960, 1344)
PIVOT = (480, 1280)
CELL_WIDTH = 793
# A fixed foot contact point for an entire clip preserves its original bobbing.
SHEETS = (
    ('вниз.png', 'walk_down', 6, (416, 1252)),
    ('вверх.png', 'walk_up', 6, (420, 1252)),
    ('ходьба.png', 'walk_right', 8, (440, 1252)),
    ('idle.png', 'idle_right', 3, (397, 1270)),
)


def source_crop(image, clip, index):
    # Columns 772..778 in the first two cells are vertical grey separators.
    # The character ends at x=769 / 758 respectively, so no art is clipped.
    width = 772 if clip == 'walk_right' and index < 2 else CELL_WIDTH
    box = (index * CELL_WIDTH, 0, index * CELL_WIDTH + width, image.height)
    crop = image.crop(box)
    removed = 0
    if clip == 'walk_right':
        red, green, blue, alpha = crop.split()
        # The guides have small RGB variations in the supplied PNG (not just exact grey).
        high = ImageChops.lighter(ImageChops.lighter(red, green), blue)
        low = ImageChops.darker(ImageChops.darker(red, green), blue)
        neutral = ImageChops.subtract(high, low).point(lambda v: 255 if v <= 12 else 0)
        bright = low.point(lambda v: 255 if v >= 60 else 0)
        bottom = Image.new('L', crop.size)
        bottom.paste(255, (0, 1238, crop.width, crop.height))
        guides = ImageChops.multiply(neutral, bright)
        guides = ImageChops.multiply(ImageChops.multiply(guides, bottom), alpha)
        removed = guides.histogram()[255]
        # Only near-neutral grey baseline pixels are masked. Black/coloured boots stay intact.
        crop.paste((0, 0, 0, 0), (0, 0), guides)
    return crop, box, removed


def write_sprite_frames(files):
    resources = sorted({path for paths in files.values() for path in paths})
    ids = {path: f'{i+1}_frame' for i, path in enumerate(resources)}
    lines = [f'[gd_resource type="SpriteFrames" load_steps={len(resources)+1} format=3]', '']
    for path in resources:
        lines.append(f'[ext_resource type="Texture2D" path="res://{path}" id="{ids[path]}"]')
    lines += ['', '[resource]', 'animations = [']
    for clip in sorted(files):
        lines += ['{', '"frames": [']
        for i, path in enumerate(files[clip]):
            comma = ',' if i < len(files[clip])-1 else ''
            lines.append('{"duration": 1.0, "texture": ExtResource("'+ids[path]+'")}'+comma)
        speed = 2.5 if clip.startswith('idle_') else 8.0 if clip in ('walk_up', 'walk_down') else 10.0
        loop = len(files[clip]) > 1
        lines += ['],', f'"loop": {str(loop).lower()},', f'"name": &"{clip}",', f'"speed": {speed}', '},']
    lines[-1] = '}'
    lines += [']', '']
    (PROJECT / 'assets/characters/hans_frames.tres').write_text('\n'.join(lines))


def main():
    (ASSETS / 'frames').mkdir(parents=True, exist_ok=True)
    manifest = {'canvas': CANVAS, 'pivot': PIVOT, 'cell_width': CELL_WIDTH,
                'walk_scale': 1/24, 'side_idle_scale': 1/21, 'sources': [], 'frames': []}
    clips = {}
    for filename, clip, count, foot in SHEETS:
        path = ASSETS / 'source' / filename
        raw = path.read_bytes()
        image = Image.open(path)
        assert image.mode == 'RGBA' and image.width == count*CELL_WIDTH
        manifest['sources'].append({'file': filename, 'sha256': hashlib.sha256(raw).hexdigest(),
                                    'size': image.size, 'clip': clip, 'count': count, 'foot': foot})
        clips[clip] = []
        offset = (PIVOT[0]-foot[0], PIVOT[1]-foot[1])
        for index in range(count):
            crop, box, removed = source_crop(image, clip, index)
            assert offset[0]>=0 and offset[1]>=0
            assert offset[0]+crop.width<=CANVAS[0] and offset[1]+crop.height<=CANVAS[1]
            frame = Image.new('RGBA', CANVAS)
            # Direct paste, without an alpha mask, copies all RGBA bytes exactly.
            frame.paste(crop, offset)
            relative = Path('assets/characters/hans/frames') / f'{clip}_{index:02d}.png'
            frame.save(PROJECT / relative)
            clips[clip].append(relative.as_posix())
            manifest['frames'].append({'file': relative.as_posix(), 'source': filename,
                'index': index, 'source_box': box, 'paste_offset': offset,
                'guide_pixels_removed': removed, 'sha256': hashlib.sha256((PROJECT/relative).read_bytes()).hexdigest()})
    clips['walk_left'] = clips['walk_right']  # AnimatedSprite2D.flip_h, never duplicate art.
    clips['idle_left'] = clips['idle_right']
    clips['idle_down'] = [clips['walk_down'][2]]
    clips['idle_up'] = [clips['walk_up'][2]]
    write_sprite_frames(clips)
    (ASSETS / 'slicing.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2)+'\n')
    print('Sliced 23 original RGBA frames; wrote eight animations and slicing.json.')


if __name__ == '__main__':
    main()
