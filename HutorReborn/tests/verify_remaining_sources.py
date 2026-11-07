"""Audit all protected 4.4 files and native-pixel provenance of new 4.5 resources."""
from pathlib import Path
import hashlib
import json
import numpy as np
from PIL import Image

P=Path(__file__).resolve().parents[1]
baseline=json.loads((P/'docs/stage45-preserved-files.json').read_text(encoding='utf-8'))
count=0


def check(ok,message):
    global count
    assert ok,message
    count+=1


for name,sha in baseline['files'].items():
    check(hashlib.sha256((P/name).read_bytes()).hexdigest()==sha,'Protected file changed: '+name)
folder=P/'assets/interiors/stage45'
records=json.loads((folder/'manifest.json').read_text(encoding='utf-8'))
provenance=np.load(folder/'floor_provenance.npz')
pixels=0
for record in records:
    source_path=P/record['source']
    check(hashlib.sha256(source_path.read_bytes()).hexdigest()==record['sha256'],'Declared source SHA: '+record['name'])
    source=np.array(Image.open(source_path).convert('RGBA'))
    image=np.array(Image.open(folder/(record['name']+'.png')).convert('RGBA'))
    check(tuple(image.shape[1::-1])==tuple(record['size']),'Native canvas size: '+record['name'])
    check(set(np.unique(image[:,:,3])).issubset({0,255}),'Binary pixel alpha: '+record['name'])
    if record['name']=='parents_bed':
        expected=np.zeros_like(image)
        expected[:source.shape[0],:source.shape[1]]=source
        right=expected[:,40:40+source.shape[1]]
        mask=source[:,:,3]>0
        right[mask]=source[mask]
        visible=image[:,:,3]>0
        check(np.array_equal(image[visible],expected[visible]),'Parents bed uses only the two original bed copies')
        check(np.array_equal(image[:,:,3],expected[:,:,3]),'Parents bed silhouette is the exact original union')
    else:
        x0,y0,x1,y1=record['box']
        check(np.array_equal(image[:,:,:3],source[y0:y1,x0:x1,:3]),'Unpainted native source pixels: '+record['name'])
    if record['name'].startswith('floor_atlas_'):
        room=record['name'].removeprefix('floor_atlas_')
        original=np.array(Image.open(P/record['original_source']).convert('RGB'))
        coords=provenance[room]
        check(np.array_equal(image[:,:,:3],original[coords//original.shape[1],coords%original.shape[1]]),'Floor traces back to original user sheet: '+room)
    pixels+=image.shape[0]*image.shape[1]
registry=json.loads((P/'data/interiors/registry.json').read_text())
check(len(registry)==len(set(registry))==6,'Exactly six unique building entries')
check(registry[:3]==['res://data/interiors/inn.tres','res://data/interiors/elder.tres','res://data/interiors/herbalist.tres'],'Three original entries retained')
for room,size in [('woodcutter',(448,320)),('old_man',(352,288)),('storehouse',(416,320))]:
    scene=(P/'scenes/interiors'/(room+'.tscn')).read_text(encoding='utf-8')
    check('type="TileMapLayer"' in scene and 'name="Floor"' in scene and 'name="Walls"' in scene,'Editable saved tiles: '+room)
    check('res://scenes/npc/resident.tscn' not in scene,'No new actor instances in room: '+room)
    check('name="NPCPoints"' in scene,'Prepared action/access markers: '+room)
    for line in scene.splitlines():
        if line.startswith('[node name="Art"'):check('type=' not in line,'Inherited prop override retains correct ownership')
print(f'PASS: {count} preservation/source checks; {len(baseline["files"])} old files byte-identical; {len(records)} derivatives; {pixels} native source pixels')
