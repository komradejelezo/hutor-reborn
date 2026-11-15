# Old man with pipe — authoring sources, stage 5.4.9

These eleven sheets are newly drawn derivatives made with the image generation tool from the user's approved frail old-man reference, not a blindly imported collage or a claim that repeated reference poses form a finished atlas. Previous assets remain in the repository.

`idle` contains four independent directions; `right`, `left`, `down`, `up` contain separately drawn walks. Staff stays in anatomical right hand and pipe in left; left locomotion is not a flipped right sheet. `smoke`, `sit_down`, `sit_smoke`, `rest`, `social` contain whole-body actions without painted smoke or baked furniture. `portrait` contains four expressions.

The manifest records each source hash, crop, uniform scale and support pivot. `tools/prepare_old_man_549.py` cleans alpha/halos, slices and downsamples with Nearest, without painting/warping limbs. Standing target is 46 pixels; seating height is derived from the last authored sit-down pose, not enlarged to standing height. Stand-up uses the same authored poses in reverse. Six distinct gait phases are selected per direction without padding repetitions. Source PNGs are ignored only by Godot importer, not Git. See the report for artistic limits and test methodology.
