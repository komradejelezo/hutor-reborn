#!/usr/bin/env python3
"""Audit original ZIP bytes, curated phases, alpha processing and unchanged battle math."""
from pathlib import Path
from zipfile import ZipFile
import argparse,hashlib,json,subprocess,re
from PIL import Image

P=Path(__file__).resolve().parents[1];R=P.parent;A=P/'assets/combat/animations_v1';BASE='539346d'
def git(*args):return subprocess.check_output(['git','-C',str(R),*args])
def main():
 parser=argparse.ArgumentParser();parser.add_argument('--archive',type=Path);args=parser.parse_args()
 expected={'HutorReborn/data/combat/prototype.json','HutorReborn/scripts/combat/combat_arena.gd','HutorReborn/scripts/combat/ui/combatant_view.gd'}
 changed=set(git('diff','--name-only','--diff-filter=M',BASE).decode().splitlines());assert changed==expected,changed
 assert not git('diff','--name-only','--diff-filter=D',BASE).strip()
 old=json.loads(git('show',BASE+':HutorReborn/data/combat/prototype.json'));new=json.loads((P/'data/combat/prototype.json').read_text())
 old['units']['beast']['name']='Леший';assert old==new
 for s in ['scripts/combat/combat_battle.gd','scripts/combat/combat_ai.gd','scripts/combat/combat_unit.gd','scripts/chapter','scripts/player.gd','assets/characters/hans','assets/npc','scenes/world','scenes/interiors','data/life','dialogues','project.godot']:
  assert not git('diff',BASE,'--','HutorReborn/'+s),s
 print('PASS: only presentation and canonical beast label change; battle math, IDs/stats, world, saves, quests and NPCs preserved')
 hashes=json.loads((A/'source_checksums.json').read_text())
 for path,sha in hashes.items():assert hashlib.sha256((A/path).read_bytes()).hexdigest()==sha,path
 if args.archive:
  with ZipFile(args.archive) as z:assert hashes=={i.filename:hashlib.sha256(z.read(i)).hexdigest() for i in z.infolist() if not i.is_dir()}
 print('PASS:',len(hashes),'source files match ZIP byte-for-byte')
 lib=json.loads((A/'library.json').read_text())
 assert lib['hans']['dodge']['source_count']==12
 assert lib['hans']['victory']['used_indices']==list(range(1,9))+[11,12]
 assert lib['wolf']['attack']['used_indices']==list(range(1,11))+list(range(22,25))
 assert lib['leshy']['idle']['derived_from']=='Leshy/Attack quiet lead-in 1..6'
 assert lib['hans']['idle']['derived_from']=='Hans/Attack quiet recovery 11,12,1'
 for actor,clips in lib.items():
  for clip,c in clips.items():
   assert c['loop']==(clip=='idle') and (not c['pingpong'] or clip=='idle')
   assert c['hold']==(clip=='death')
   for f in c['frames']:
    image=Image.open(A/f['path']);assert image.mode=='RGBA' and list(image.size)==f['size']
    # Preparation changes alpha only. It never paints or rescales RGB.
    original=Image.open(A/f['source']).convert('RGBA');assert original.convert('RGB').tobytes()==image.convert('RGB').tobytes()
    b=f['bbox'];o=f['origin'];assert 600-o[0]>=0 and 650-o[1]>=0
 print('PASS: strip excluded, unsafe phases curated, only idle may loop/ping-pong; full-resolution source RGB retained')
 for p in (P/'scripts/combat/animation').glob('*.gd'):
  s=p.read_text();names=re.findall(r'^func (\w+)\(',s,re.M);assert len(names)==len(set(names))
  assert not re.search(r'^(<<<<<<< |=======|>>>>>>> )',s,re.M)
 assert not (P/'override.cfg').exists()
 print('PASS: no duplicate functions, conflict markers or observer overrides')
 print('RESULT: 4 source/integrity groups passed')
if __name__=='__main__':main()
