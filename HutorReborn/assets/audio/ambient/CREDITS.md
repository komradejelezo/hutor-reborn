# Ambient audio attribution

All eleven Ogg files are copied byte for byte from the pinned upstream revisions in `sources.json`. No synthesis, pitch alteration, re-encoding or denoising was applied. Godot loop flags and in-game gain are runtime settings. These licenses apply to the identified audio files, not to the game's unrelated graphics or source code.

## 0 A.D.

`forest_day`, `forest_bird`, `wind`, `leaves_1`, `leaves_2`, `axe_1`, `axe_2`, `wood_1`, `wood_2`:

Copyright © 2009 **Wildfire Games** — <http://www.wildfiregames.com/>. From the 0 A.D. media repository: <https://github.com/0ad/0ad>.

Licensed under **Creative Commons Attribution-ShareAlike 3.0 Unported**: <https://creativecommons.org/licenses/by-sa/3.0/>. Original notice: [licenses/0ad-audio.txt](licenses/0ad-audio.txt). Redistribute these recordings, and any adaptations of them, under that license with this attribution. The files are unchanged apart from their descriptive local filenames.

## Small fire

`fire.ogg` is the unchanged `fire_small.ogg` from Minetest Game / Luanti Game: <https://github.com/luanti-org/minetest_game>.

Recording by **dobroide**, **CC BY 3.0**: <https://creativecommons.org/licenses/by/3.0/>. Original recording: <http://www.freesound.org/people/dobroide/sounds/4211/>. Upstream attribution and license are retained in `licenses/minetest-fire-readme.md` and `licenses/minetest-fire-license.txt`.

## Wooden hinge / creak

`wood_creak.ogg` is the unchanged `default_chest_open.ogg` from Minetest Game, a mix credited to **sofar**, using recordings by:

Retain the upstream media notice **CC BY-SA 3.0** in `licenses/minetest-default-license.txt`, together with the individually credited CC BY 3.0 / CC0 components below. This package does not remove or weaken any upstream notice.

- **Sevin7** — <http://www.freesound.org/people/Sevin7/sounds/269722/> — CC0.
- **Percy Duke** — <http://www.freesound.org/people/Percy%20Duke/sounds/23448/> — CC BY 3.0.
- **kingsamas** — <http://www.freesound.org/people/kingsamas/sounds/135576/> — CC BY 3.0.
- **bulbastre** — <http://www.freesound.org/people/bulbastre/sounds/126887/> — CC BY 3.0.
- **Yoyodaman234** — <http://www.freesound.org/people/Yoyodaman234/sounds/183541/> — CC0.

CC BY 3.0: <https://creativecommons.org/licenses/by/3.0/>; CC0: <https://creativecommons.org/publicdomain/zero/1.0/>. Full upstream provenance is retained in `licenses/minetest-default-readme.md` and `licenses/minetest-default-license.txt`. This is a small wooden mechanism sound, not a newly recorded tree creak or footstep.

## Resources still needed

No suitable licensed recording was selected for crickets, nocturnal woodland animals, clay dishes, paper, a small boiling pot, handling dried herbs, actual floorboard creaks or old trees creaking in the wind. Their empty catalog slots in `data/atmosphere/sounds.json` are intentional. They are skipped silently; no unpleasant synthesized placeholders or unrelated breaking-glass sounds are used.
