# Elder authoring sources — stage 5.4.8

These twelve PNG sheets are new derivative drawings made with the image generation tool using the user's approved village-elder reference. They are not described as an originally supplied production atlas. The existing art remains elsewhere in the project.

`idle`, `right`, `down`, `up` provide whole-body directional poses; `read`, `write`, `inspect`, `point`, `think`, `social` provide whole-body actions without duplicate furniture. `portrait` contains four expressions; `props` contains parchment, journal, ink and quill variations. Left walking mirrors right once. Six genuine selected gait phases are used rather than padding counts to eight; one inconsistent side conversation candidate is excluded.

`tools/prepare_elder_548.py` performs technical alpha/halo cleanup, component slicing and uniform Nearest reduction. It does not paint or warp limbs to synthesize animation. The manifest stores the SHA-256 of every source PNG, extraction boxes, uniform scale, offsets, feet pivot and clip frame lists. Source sheets are excluded only from Godot importing with `.gdignore`, not from Git. The full report documents motion tests and artistic limits.
