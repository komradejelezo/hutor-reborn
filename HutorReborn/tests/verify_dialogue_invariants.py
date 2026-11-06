"""Stage 4.1 must not alter the approved map, art, camera or mechanics."""
from pathlib import Path
import hashlib
import json
import re

root = Path(__file__).resolve().parents[1]
baseline = json.loads((root / 'docs/stage41-preserved-files.json').read_text())
for name, expected in baseline['files'].items():
    assert hashlib.sha256((root / name).read_bytes()).hexdigest() == expected, name
print(f"PASS: {len(baseline['files'])} approved files unchanged from {baseline['commit'][:7]}")
config = (root / 'project.godot').read_text()
assert config.count('[autoload]') == 1
assert 'DialogueManager="*res://scripts/dialogue/dialogue_controller.gd"' in config
without_autoload = re.sub(r'\[autoload\]\nDialogueManager=[^\n]+\n', '', config)
# Freeze all original project settings while allowing this one registration.
assert hashlib.sha256(without_autoload.encode()).hexdigest() == baseline['project_without_autoload_sha256']
print('PASS: main scene, input/display/render/physics settings unchanged; one lazy autoload registered')
demo = (root / 'scenes/demo/dialogue_demo.tscn').read_text()
assert 'CharacterBody2D' not in demo and 'NPC' not in demo
assert 'controls_locked' in (root / 'scripts/player.gd').read_text()
print('PASS: existing player lock reused; no saved map or player scene edits')
