# Evidence index

See [the Russian report](../../COMBAT_VISUAL_OVERHAUL_REPORT.md) for findings, limitations and Windows steps.

- `screenshots/companions-before.png` / `companions-after.png`: controlled resource A/B inside the same current arena. The before fixture swaps the old woodcutter atlas/side Idle and old spirit image; it is **not a complete old-branch execution**.
- `screenshots/lab-*.png`: actual Godot graphics laboratory, original resource left / repaired derivative right. `lab-dodge-final.png` includes the final retained-RGB alpha repair.
- `screenshots/native-*-result.png`: real OS mouse playthroughs of duel, forest and companions, all inspected victory screens. `native-input.json` records input provenance, including the corrected result-modal navigation in the first replay.
- `screenshots/native-window-1280x800.png`, `native-fullscreen.png`: actual X11 screen captures. Viewport screenshots alone do not prove native window dimensions. Integer-scale letterboxing is intentional and project settings were preserved.
- `environment-final.mp4`: 12-second native-window recording of the actual standalone forest stage, default Standard. No actors, artwork edits or acceleration. `environment-final.json` records capture timing.
- `combat-final.mp4`: 24-second native-window recording of final-code duel/forest/companions. The recording fixture calls normal action handlers without changing stats or HP; it is separate from OS-click evidence. Playback uses the existing ×3 option.
- `environment-pixel-comparison.json`: actual stage snapshots 5 seconds apart; branch/fog pixels change, a stated ground sample remains static. Leaves can legitimately pass over other ground samples.
- `screenshots/registered-sequences.png`: **technical composite, not Godot output**. Eight sampled source poses per actual runtime clip, uniformly scaled using its existing calibration/origin. Rebuild with `python deliverables/combat-overhaul/make_sequence_sheet.py`.
- `screenshots/dodge-before-rgb-recovery.png`: white-background inspection of the pre-existing prepared Dodge poses, before this task's final retained-RGB correction. It documents defects rather than an approved final asset.
- `graphics_audit.json` / `GRAPHICS_AUDIT.md`: read-only PNG/clip scanner; review candidates are not automatically defects. Regenerate with `python HutorReborn/tools/audit_combat_graphics.py`.
- `soak-final.json` / `.log`: real-time graphical 181-second final-timing run, 35 completed battles, bounded node/memory samples. Later alpha-only Dodge recovery was checked separately without changing timing or frame geometry.
- `checks.json` and individual logs: actual verification results. The first failed VFX-count assertion is retained in history; the final test filters magic by script type and all final tests pass. A timing mismatch under load was fixed by latching the actual contact pose.

Environment: official Godot 4.6.2, X11, Compatibility, Mesa llvmpipe. V-Sync switching is unsupported by this software driver. Performance and artistic approval still require Windows/hardware testing. A clean import and these tests do not certify missing authored NPC combat clips or repair artwork whose RGB has been discarded.
