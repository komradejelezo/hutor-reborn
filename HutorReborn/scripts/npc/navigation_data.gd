class_name HutorNpcNavigationData
extends Resource
## Baked from static world collision shapes. No map geometry is rewritten.
@export var world_size := Vector2i(2976,2560)
@export var cell_size := 16
@export var blocked: PackedInt32Array
@export var costs: PackedByteArray
@export var source_scene_sha256 := ""
