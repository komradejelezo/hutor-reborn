"""Two-parent merge proof. Historical stage-specific guards remain unchanged."""
from pathlib import Path
import subprocess,hashlib,json,re
R=Path(__file__).resolve().parents[3]
OURS='fb8384750c1c8f3ac908bbbb822e571e2d89f86e';MAIN='7b41017';BASE='3de107b'
def tree(ref):
 raw=subprocess.check_output(['git','ls-tree','-rz','--full-tree',ref],cwd=R)
 return {row.split(b'\t',1)[1].decode():row.split(b'\t',1)[0].split()[2].decode() for row in raw.split(b'\0') if row}
def body(ref,path):return subprocess.check_output(['git','show',ref+':'+path],cwd=R)
def digest(path):
 p=R/path;h=hashlib.sha1(('blob '+str(p.stat().st_size)+'\0').encode())
 with p.open('rb') as f:
  for chunk in iter(lambda:f.read(1024*1024),b''):h.update(chunk)
 return h.hexdigest()
a,b,base=tree(OURS),tree(MAIN),tree(BASE)
common={
 'HutorReborn/scripts/npc/visuals/visual_library.gd',
 'HutorReborn/scripts/life/activity_presenter.gd',
 'HutorReborn/scripts/npc/npc_animator.gd',
 'HutorReborn/scripts/dialogue/dialogue_window.gd',
 'HutorReborn/scripts/npc/rework/work_bindings.gd'}
json_paths={'HutorReborn/data/visuals/animation_catalog.json','HutorReborn/data/visuals/residents.json'}
tests={'HutorReborn/tests/verify_residents_547.gd','HutorReborn/tests/verify_residents_548.gd'}
count=0
for p in sorted(a.keys()|b.keys()):
 if p in common|json_paths|tests:continue
 if p not in a:expected=b[p]
 elif p not in b:expected=a[p]
 elif a[p]==b[p] or b[p]==base.get(p):expected=a[p]
 elif a[p]==base.get(p):expected=b[p]
 else:raise AssertionError('unreviewed two-sided change: '+p)
 assert (R/p).is_file() and digest(p)==expected,'parent file changed or lost: '+p
 count+=1
for p in common:
 expected=body(MAIN,p).decode()
 if p.endswith('visual_library.gd'):
  line='        if id==&"innkeeper_wife":path="res://assets/npc/innkeeper_wife547/game/frames.tres"\n'
  expected=expected.replace(line,line+'        if id==&"elder":path="res://assets/npc/elder548/game/frames.tres"\n')
 elif p.endswith('activity_presenter.gd'):
  line='    if resident.id==&"innkeeper_wife":visual54=preload("res://scripts/npc/rework/innkeeper_wife_presentation_547.gd").new()\n'
  expected=expected.replace(line,line+'    if resident.id==&"elder":visual54=preload("res://scripts/npc/rework/elder_presentation_548.gd").new()\n')
 elif p.endswith('npc_animator.gd'):
  expected=expected.replace('==547\n','==547 or int(sprite.sprite_frames.get_meta("elder_version",0))==548\n')
 elif p.endswith('dialogue_window.gd'):
  needle='path.begins_with("res://assets/npc/innkeeper_wife547/game/portraits/")):'
  expected=expected.replace(needle,needle.replace(')):',') or path.begins_with("res://assets/npc/elder548/game/portraits/")):'))
 else:
  needle='    elif world.get("building_id")==&"herbalist"'
  elder='    elif world.get("building_id")==&"elder" and id==&"elder" and action in ["read_documents","write_journal"]:\n        path="Actors/Props/Desk";offset=Vector2(-40,-16)\n'
  expected=expected.replace(needle,elder+needle)
 assert (R/p).read_text()==expected,'shared script differs from reviewed combination: '+p
for p in json_paths:
 expected=json.loads(body(MAIN,p));expected['elder']=json.loads(body(OURS,p))['elder']
 assert json.loads((R/p).read_text())==expected,'lost profile/catalogue data: '+p
for p in tests:
 ref=MAIN if p.endswith('547.gd') else OURS
 before='"innkeeper","innkeeper_wife"]' if ref==MAIN else '"innkeeper","elder"]'
 extra='elder' if ref==MAIN else 'innkeeper_wife'
 expected=body(ref,p).decode().replace(before,before[:-1]+',"'+extra+'"]')
 assert (R/p).read_text()==expected,'test changed beyond combined frame expectations: '+p
for p in common|tests:
 s=(R/p).read_text();assert not re.search(r'^(<<<<<<<|=======|>>>>>>>)',s,re.M),p
 names=re.findall(r'^(?:static )?func (\w+)\(',s,re.M);assert len(names)==len(set(names)),p
print(f'PASS: {count} files byte-identical to the appropriate parent; both sets of art, NPC logic, schedules, dialogue, scenes, and transitions retained')
print('PASS: five shared scripts equal the explicit combined changes; both profiles/catalogues retained; two tests only gain the other six-phase model; no markers or duplicate functions')
