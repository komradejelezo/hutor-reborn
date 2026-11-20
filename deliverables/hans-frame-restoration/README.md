# Evidence: focused Hans frame restoration

See [the Russian report](../../HANS_COMBAT_FRAME_RESTORATION.md).

- [Per-frame inventory](FRAME_INVENTORY.md), [CSV](FRAME_INVENTORY.csv), [JSON](frame_inventory.json): all 104 immutable source files, explicit mapping to 98 gameplay frames, statuses, paths, pixel counts and unresolved files. Source-file frame numbers start at 1. Victory gameplay frames 9/10 map to source 11/12.
- [Recipe](../../HutorReborn/assets/combat/restoration/hans/recipe.json), [per-patch provenance](../../HutorReborn/assets/combat/restoration/hans/provenance.json): exact target polygons, donor original files, hashes, integer offsets and actual counts. No resizing/interpolation or opaque black painting.
- `frames/*-source-prepared-godot.png`: all original poses. Columns 1–3 are **technical PNG projections** using production origin/scale, not Godot screenshots. Column 4 is **actual CombatGraphicsLab output**. The excluded six Victory poses were temporary diagnostic textures, never added to playable SpriteFrames.
- `examples/*-png-comparison.png`: raw source / prepared main / prepared current / diagnostic change mask, 4× Nearest. Cyan is an evidence annotation, not an in-game effect. `examples/*-godot-comparison.png` contains actual before/after prepared-frame captures with identical material, scale and lighting.
- [Playback comparison](motion-comparison.mp4): real X11 Godot window, **old prepared main on the left** and repaired on the right. It does not use the damaged raw input as the before model. Exact equivalence of a control capture is asserted in `motion.log`. Action playback is ×0.5 for inspection; resource FPS/order are unchanged. `motion-capture.json` records capture timing.
- `temporal.json`: frame-to-frame white-composited difference **only in edited regions**, registered by unchanged origin. The metric is a diagnostic, not an anatomy or full-animation approval.
- `audit-after/`: unmodified existing graphics auditor run again. Zero structural errors does not mean zero visual defects. `audit-comparison.json` lists the six additional enclosed-gap candidates, not six automatically proven new defects.
- `battles/battle-{duel,forest,companions}.png`: actual battle-result captures after ordinary action-handler playthroughs. These demonstrate execution/result rendering, not comprehensive frame-by-frame artistic approval.
- [Regeneration hash proof](rebuild-proof.json): all 248 prepared PNG files stayed byte-identical across a full existing preparation run.
- Final logs: `pixels-test.log`, `opacity-test.log`, `source-test.log`, `import.log`, `after-lab.log`, `animation-test.log`, `ui-test.log`, `motion.log`, `rebuild.log`.

Original archive files are immutable. Partially corrected source copies under `recovered_source/` preserve the original source format (RGB input may retain its black matte); actual transparent game images are under `forest_v2/prepared/`. Many missing body pixels remain unsupported and explicitly require an artist/new sources. Natural air gaps, torn cloak hems and the translucent Invoke effect were not treated as opaque fabric.

Rebuild inventory/contact sheets from actual focused-test captures:

```sh
python deliverables/hans-frame-restoration/build_review.py --captures /absolute/path/to/HANS_RESTORE_CAPTURE
```

The builder reads the old prepared PNGs from Git commit `ce7e706`; it never writes game resources. The existing Lab and focused GDScript/Python tests are the review entry points. All tests used isolated profiles. Platform: official Godot 4.6.2, Linux/X11/llvmpipe. Hardware/Windows and final artistic approval still require manual testing.
