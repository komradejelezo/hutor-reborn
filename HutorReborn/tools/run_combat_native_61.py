#!/usr/bin/env python3
"""Launch the ordinary game and exercise combat with real Linux X11 mouse input.

Requires a running X11 display, libXtst and ffmpeg. The temporary observer only
reads state; no fixture modifies combat outcomes. Run with a fresh output folder.
"""
import argparse
import os
from pathlib import Path
import subprocess
import sys
import time


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--godot', default='godot')
    parser.add_argument('--record', action='store_true')
    args = parser.parse_args()
    project = Path(__file__).resolve().parents[1]
    output = args.output.resolve()
    if output.exists() and any(output.iterdir()):
        parser.error('Use a fresh, empty output directory')
    output.mkdir(parents=True, exist_ok=True)
    override = project / 'override.cfg'
    if override.exists():
        parser.error('Existing override.cfg must not be overwritten')
    content = '[autoload]\nCombatObserver61="*res://tools/combat_observer_61.gd"\n'
    game = recorder = None
    override.write_text(content)
    try:
        with (output / 'game.log').open('w') as game_log, \
             (output / 'controller.log').open('w') as controller_log, \
             (output / 'recording.log').open('w') as recording_log:
            game = subprocess.Popen([
                args.godot, '--path', str(project), '--audio-driver', 'Dummy',
                '--position', '20,20', '--', f'--combat-output={output / "state.json"}'
            ], stdout=game_log, stderr=game_log)
            deadline = time.monotonic() + 40
            while not (output / 'state.json').exists() and time.monotonic() < deadline:
                if game.poll() is not None:
                    raise RuntimeError('Game exited during startup; see game.log')
                time.sleep(.1)
            if not (output / 'state.json').exists():
                raise RuntimeError('Read-only observer startup timed out')
            if args.record:
                recorder = subprocess.Popen([
                    'ffmpeg', '-y', '-loglevel', 'error', '-f', 'x11grab',
                    '-draw_mouse', '1', '-video_size', '960x540', '-framerate', '20',
                    '-i', os.environ['DISPLAY'] + '+20,20', '-c:v', 'libx264',
                    '-preset', 'ultrafast', '-crf', '26', '-pix_fmt', 'yuv420p',
                    '-movflags', '+faststart', str(output / 'combat-playtest.mp4')
                ], stdin=subprocess.PIPE, stdout=recording_log, stderr=recording_log)
            result = subprocess.run([
                sys.executable, '-B', str(project / 'tools/native_combat_61.py'),
                '--output', str(output)
            ], stdout=controller_log, stderr=controller_log, timeout=360)
            if result.returncode:
                raise RuntimeError('Native playtest failed; see controller.log')
            print('PASS: six native mouse-driven scenarios; see result.json')
    finally:
        try:
            if recorder:
                try:
                    recorder.communicate(b'q', timeout=20)
                except subprocess.TimeoutExpired:
                    recorder.kill(); recorder.wait()
                if recorder.returncode:
                    print('Recording failed; see recording.log', file=sys.stderr)
        finally:
            try:
                if game:
                    game.terminate()
                    try:
                        game.wait(timeout=10)
                    except subprocess.TimeoutExpired:
                        game.kill(); game.wait()
            finally:
                if override.exists() and override.read_text() == content:
                    override.unlink()


if __name__ == '__main__':
    main()
