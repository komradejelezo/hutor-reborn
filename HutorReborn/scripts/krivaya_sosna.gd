extends "res://scripts/world.gd"
## Location configuration only; input, descriptions, pause and movement are inherited.
@export var map_size := Vector2i(2624, 2176)
@export var camera_lead := Vector2(0, -80)

func _ready() -> void:
    var camera: Camera2D = $Actors/Hans/Camera2D
    camera.limit_left = 0
    camera.limit_top = 0
    camera.limit_right = map_size.x
    camera.limit_bottom = map_size.y
    camera.position = camera_lead
    super._ready()
