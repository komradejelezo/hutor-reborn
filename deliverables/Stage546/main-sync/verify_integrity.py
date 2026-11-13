from pathlib import Path
import subprocess,json,re,hashlib
R=Path(__file__).resolve().parents[3];main='bc8bfaa';pr='d174085'
def tree(ref):
 rows=subprocess.check_output(['git','ls-tree','-rz',ref],cwd=R).split(b'\0');out={}
 for row in rows:
  if not row:continue
  meta,path=row.split(b'\t',1);out[path.decode()]=meta.split()[2].decode()
 return out
def blob(ref,path):return subprocess.check_output(['git','show',ref+':'+path],cwd=R)
mt,pt=tree(main),tree(pr);count=0
for path in sorted(set(mt)|set(pt)):
 if not path.startswith('HutorReborn/assets/'):continue
 ref=main if path in mt else pr
 data=(R/path).read_bytes()
 oid=hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()
 assert oid==(mt if ref==main else pt)[path],path
 count+=1
print('PASS:',count,'asset files exactly match main or original PR #28; no artwork changes')
for group in ['data/life/residents/','scenes/npc/residents/','dialogues/residents/']:
 for path in mt:
  if not path.startswith('HutorReborn/'+group):continue
  ref=pr if Path(path).stem=='innkeeper' else main
  assert (R/path).read_bytes()==blob(ref,path),path
for path in set(mt)|set(pt):
 if path.startswith('HutorReborn/scripts/npc/rework/'):
  ref=pr if 'innkeeper_' in path else main
  if path not in (pt if ref==pr else mt):continue
  assert (R/path).read_bytes()==blob(ref,path),path
assert (R/'HutorReborn/scripts/life/village_life.gd').read_bytes()==blob(main,'HutorReborn/scripts/life/village_life.gd')
assert (R/'HutorReborn/scenes/interiors/inn.tscn').read_bytes()==blob(pr,'HutorReborn/scenes/interiors/inn.tscn')
print('PASS: family/other resident data and behavior unchanged from main; innkeeper and inn unchanged from PR #28')
for path in ['HutorReborn/data/visuals/animation_catalog.json','HutorReborn/data/visuals/residents.json']:
 combined=json.loads((R/path).read_text());original=json.loads(blob(main,path));pilot=json.loads(blob(pr,path))
 assert set(combined)==set(original)
 for key in original:assert combined[key]==(pilot[key] if key=='innkeeper' else original[key]),(path,key)
print('PASS: all nine animation and portrait profiles retain the correct versions')
files=['scripts/dialogue/dialogue_window.gd','scripts/life/activity_presenter.gd','scripts/npc/npc_animator.gd','scripts/npc/visuals/visual_library.gd']
for name in files:
 path='HutorReborn/'+name;s=(R/path).read_text()
 assert not re.search(r'(?m)^\s*(?:<<<<<<< |=======\s*$|>>>>>>> )',s),name
 funcs=re.findall(r'(?m)^\s*(?:static )?func\s+(\w+)\s*\(',s)
 assert len(funcs)==len(set(funcs)),(name,funcs)
 assert funcs==re.findall(r'(?m)^\s*(?:static )?func\s+(\w+)\s*\(',blob(main,path).decode())
print('PASS: four resolved files have no markers, duplicate functions or added functions')
