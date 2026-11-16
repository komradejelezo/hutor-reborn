#!/usr/bin/env python3
"""Ordinary game launch, real X11 mouse/WASD/E/J/I/F5/F9; no state fixtures."""
import argparse
import ctypes as C
import json
import time
from pathlib import Path
from native_window_playtest import NativeWindow


class ChapterWindow(NativeWindow):
    def pulse(self, keys, seconds=.08):
        super().pulse(keys, seconds)
        released = self.state()['tick']
        # The software renderer can publish a snapshot before X11 key-up is
        # dispatched. Wait across several observed frames before another key.
        return self.wait(lambda s: s['tick'] > released+3, 8)
    def click(self, text):
        def find(s):
            return next((b for b in s['buttons'] if text in b['text'] and not b['disabled']), None)
        state = self.wait(lambda s: find(s) is not None, 10)
        b = find(state); x, y = b['center']
        self.xt.XTestFakeMotionEvent.argtypes = [C.c_void_p, C.c_int, C.c_int, C.c_int, C.c_ulong]
        self.xt.XTestFakeButtonEvent.argtypes = [C.c_void_p, C.c_uint, C.c_int, C.c_ulong]
        self.xt.XTestFakeMotionEvent(self.display, -1, 20+int(x), 20+int(y), 0)
        self.x.XFlush(self.display); time.sleep(.05)
        self.xt.XTestFakeButtonEvent(self.display, 1, 1, 0); self.x.XFlush(self.display); time.sleep(.06)
        self.xt.XTestFakeButtonEvent(self.display, 1, 0, 0); self.x.XFlush(self.display)
        tick = self.state()['tick']; self.wait(lambda s: s['tick'] > tick+2, 6)
        self.log({'action': 'click', 'text': text})


def main():
    p = argparse.ArgumentParser(); p.add_argument('--output', type=Path, required=True)
    out = p.parse_args().output.resolve(); w = ChapterWindow(out)
    w.capture('menu'); w.click('Начать путь')
    s = w.wait(lambda s: s['active'] and not s['busy'], 20)
    assert s['stage'] == 0 and not s['test'] and abs(s['position'][1]-2460) < 1
    w.capture('arrival'); start = s['position']
    w.pulse(['w'], .24); w.pulse(['a'], .20)
    assert w.state()['position'] != start
    w.wait(lambda s: 'указатель' in s['target'], 5); w.pulse(['e'])
    w.wait(lambda s: s['dialogue'], 5); time.sleep(.3); w.pulse(['e'])
    w.wait(lambda s: not s['typing'], 5); w.capture('sign-dialogue')
    w.click('Запомнить предупреждение')
    w.wait(lambda s: s['line'].startswith('reply') and s['phase'] == 2, 5)
    if w.state()['typing']:
        w.pulse(['e'], .18); w.wait(lambda s: not s['typing'], 5)
    w.pulse(['Return'])
    s = w.wait(lambda s: not s['dialogue'] and s['flags'].get('sign'), 6)
    assert not s['locked']; w.pulse(['j'], .22); w.wait(lambda s: s['overlay'], 5)
    w.capture('journal'); w.click('Закрыть'); w.wait(lambda s: not s['overlay'], 5)
    w.pulse(['i'], .22); w.wait(lambda s: s['overlay'], 5); w.capture('inventory'); w.click('Закрыть')
    w.pulse(['F5'], .22); s = w.wait(lambda s: s['normal_digest'] != '', 5); digest = s['normal_digest']
    old_hero = s['hero_id']; w.pulse(['F9'], .22)
    s = w.wait(lambda s: not s['busy'] and s['flags'].get('sign') and s['hero_id'] != old_hero, 20)
    assert s['normal_digest'] == digest and not s['test']
    w.pulse(['j'], .22); w.wait(lambda s: s['overlay'], 5); w.click('Главное меню')
    w.wait(lambda s: not s['active'] and s['scene'].endswith('MainMenu.tscn'), 10)
    w.click('Тест главы I'); w.click('5. По ту сторону')
    w.wait(lambda s: s['active'] and s['test'] and not s['busy'] and s['stage'] == 4, 20)
    w.pulse(['F5'], .22); time.sleep(.3)
    assert w.state()['normal_digest'] == digest, 'Test save touched normal progress'
    w.capture('test-chapter'); w.pulse(['j'], .22); w.wait(lambda s: s['overlay'], 5); w.click('Главное меню')
    final = w.wait(lambda s: not s['active'], 10)
    assert final['normal_digest'] == digest
    (out/'result.json').write_text(json.dumps({'success': True, 'checks': ['ordinary-new-game', 'real-WASD', 'real-E-sign-dialogue', 'journal-and-inventory', 'manual-save-and-load', 'quest-five-test-jump', 'normal-save-isolated'], 'final': final}, ensure_ascii=False, indent=2))
    w.log({'action': 'chapter-native-success', 'success': True})


if __name__ == '__main__':
    main()
