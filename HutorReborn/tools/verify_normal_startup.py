#!/usr/bin/env python3
"""Launch the configured main scene normally; --script would conceal startup order."""
import argparse
from contextlib import contextmanager
import json
import os
from pathlib import Path
import subprocess
import tempfile

@contextmanager
def observer_override(project):
    override = project / 'override.cfg'
    if override.exists():
        raise RuntimeError(f'Refusing to overwrite existing {override}')
    content='[autoload]\nStage493Observer="*res://tools/runtime_observer.gd"\n'
    with override.open('x') as file:file.write(content)
    try:
        yield
    finally:
        if override.exists() and override.read_text()==content:
            override.unlink()  # Only our own unchanged temporary file.
        elif override.exists():
            raise RuntimeError(f'Observer override was changed externally; left untouched: {override}')

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project', type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument('--output', type=Path)
    parser.add_argument('--godot', default='godot')
    args = parser.parse_args()
    with tempfile.TemporaryDirectory(prefix='hutor-startup-') as temporary:
        output = (args.output or Path(temporary) / 'startup.json').resolve()
        output.parent.mkdir(parents=True, exist_ok=True)
        with observer_override(args.project):
            result = subprocess.run([args.godot, '--headless', '--path', str(args.project),
                                     '--quit-after', '180', '--', f'--runtime-output={output}',
                                     '--runtime-once'], timeout=30)
        if not output.exists():
            raise SystemExit('FAIL: normal startup did not produce a runtime report')
        status = json.loads(output.read_text())
        valid = all(status['checks'].values())
        raise SystemExit(0 if result.returncode == 0 and valid else 1)

if __name__ == '__main__':
    main()
