class_name HutorBuildingDefinition
extends Resource
@export var id: StringName
@export var display_name := "Дом"
@export_file("*.tscn") var interior_scene := ""
@export var exterior_anchor: NodePath
@export var door_offset := Vector2(0, 26)
@export var inspection_offset := Vector2(-96, 50)
@export_range(12.0, 40.0) var inspection_reach := 24.0
@export_range(1.25, 1.35) var camera_zoom := 1.3
@export var residents: Array[StringName] = []
@export var always_inside: Array[StringName] = []
@export var return_delay := 60.0
