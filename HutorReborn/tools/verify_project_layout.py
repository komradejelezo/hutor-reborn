#!/usr/bin/env python3
"""Detect active nested Godot projects, duplicate UIDs/classes and broken resource links.
Read-only: never delete copies or replace portraits/resources.
"""
import argparse
import json
from pathlib import Path
import re

def ignored(path, root):
    return any(part.name in {'.godot', '.git', '__pycache__'} or (part / '.gdignore').exists()
               for part in path.parents if part != root and root in part.parents)

def inspect(root):
    root = root.resolve()
    active = [p for p in root.rglob('*') if p.is_file() and not ignored(p, root)]
    nested = [str(p.relative_to(root)) for p in active if p.name == 'project.godot' and p.parent != root]
    uid_paths, classes = {}, {}
    for path in active:
        relative = str(path.relative_to(root))
        if path.suffix == '.uid':uid_paths.setdefault(path.read_text().strip(), []).append(relative)
        elif path.suffix == '.gd':
            match = re.search(r'^class_name\s+(\w+)', path.read_text(), re.M)
            if match:classes.setdefault(match[1], []).append(relative)
    missing = []
    references = 0
    for path in active:
        if path.relative_to(root).parts[0] not in {'scripts','scenes','assets','data','dialogues'}:continue
        if path.suffix not in {'.gd','.tscn','.tres','.json','.import'}:continue
        for value in re.findall(r'[\"\'](res://[^\"\'\n]+)[\"\']', path.read_text()):
            # Directory prefixes in dynamically constructed paths are not files.
            if value.endswith('/'):continue
            references += 1
            if not (root/value.removeprefix('res://')).exists():missing.append({'file':str(path.relative_to(root)),'resource':value})
    duplicate_uids = {uid:paths for uid,paths in uid_paths.items() if len(paths)>1}
    duplicate_classes = {name:paths for name,paths in classes.items() if len(paths)>1}
    return {'project':str(root/'project.godot'),'nested_projects':nested,'duplicate_uids':duplicate_uids,
            'duplicate_classes':duplicate_classes,'missing_resources':missing,'references_checked':references,
            'valid':not (nested or duplicate_uids or duplicate_classes or missing)}

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--project',type=Path,default=Path(__file__).resolve().parents[1])
    p.add_argument('--output',type=Path)
    a=p.parse_args();result=inspect(a.project)
    if a.output:a.output.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps(result,ensure_ascii=False,indent=2))
    raise SystemExit(0 if result['valid'] else 1)

if __name__=='__main__':main()
