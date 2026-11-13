# Authoring sources — innkeeper wife, stage 5.4.7

These PNGs are newly generated derivative pose drawings based on the user's approved innkeeper-wife reference (brown dress, cream apron/blouse, low chestnut bun). They are not claimed to be an originally supplied production atlas. Previous art is retained elsewhere in the project.

`idle`, `right`, `down`, `up`: full-body directional poses. `carry` / `carry_vertical`: independent tray-carry poses. `cook`, `cut`, `wipe`, `dishes`, `sweep`: full-body chore drawings without duplicate furniture. `serve`: pickup (row 1), set-down (row 2). `social`: talk (row 1), rest (row 2). `portrait`: four expressions. `props`: board, tray, mug/cloth, broom.

The manifest records SHA-256 and the technical slicing recipe for every PNG. `tools/prepare_innkeeper_wife_547.py` performs alpha cleanup and uniform Nearest slicing; it does not draw or warp limbs. Six selected gait phases are used rather than padding counts to eight. The source sheets are intentionally excluded from Godot's importer by `.gdignore`; the resulting native atlas and props are imported normally. See the stage report for visual-test limits.
