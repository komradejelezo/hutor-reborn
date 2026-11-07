extends "res://scripts/world.gd"
@export var building_id: StringName
@export var map_size := Vector2i(960, 640)
@export var room_bounds := Rect2(96, 96, 768, 448)
@export var resident_definitions: Array[HutorNpcDefinition] = []

func _ready() -> void:
    # The saved Hans supports F6; travel replaces it with the existing object.
    super._ready()
    var camera: Camera2D = player.get_node("Camera2D")
    camera.zoom = Vector2.ONE * 1.3
    camera.position = Vector2.ZERO
    camera.limit_left = 0; camera.limit_top = 0
    camera.limit_right = map_size.x; camera.limit_bottom = map_size.y
    camera.reset_smoothing()

func local_definition(id: StringName) -> HutorNpcDefinition:
    for data in resident_definitions:
        if data.id == id: return data
    return null
