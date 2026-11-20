# Reviewed Hans frame repairs

`recipe.json` freezes interior garment polygons, original hashes, integer donor offsets and measured registration context. It is a **partial restoration**, not an approval of every source pose.

Original archive PNGs under `forest_v2/assets/` remain unchanged. `recovered_source/` holds partially corrected copies of those source frames; the matching `forest_v2/prepared/Hans/...` PNGs are the actual runtime resources. Existing SpriteFrames, sizes, origins, playback order and timings stay unchanged.

A new opaque pixel must have retained nonzero target RGB or a literal colour from a reviewed adjacent source frame. Donor colour replaces only original zero-RGB pixels whose baseline runtime alpha was below 128. Existing opaque black shadows are preserved. No black fill, colour interpolation, model generation, cross-character copying or frame resizing is used. Multiple donors may supply disjoint missing pixels; previously repaired pixels are never overwritten.

`provenance.json` records actual changed pixels and every donor. A failed source hash, registration context or unexpected local edit aborts regeneration. The recipe is not a heuristic to apply to new assets without review.

Rebuild through the existing pipeline:

```sh
python HutorReborn/tools/repair_combat_opacity.py
```

Read-only validation:

```sh
python HutorReborn/tools/restore_hans_combat_frames.py
python HutorReborn/tests/verify_hans_frame_restoration.py
```

For visual review, use the existing `scenes/combat/CombatGraphicsLab.tscn`, select Hans, white/magenta/black and the relevant clip. Left is the immutable source; right is the prepared runtime derivative. Some original body/sleeve/leg artwork is still absent and requires an artist; see the per-frame inventory and restoration report at repository root/deliverables.
