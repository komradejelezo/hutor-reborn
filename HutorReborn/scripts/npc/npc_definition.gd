class_name HutorNpcDefinition
extends Resource
enum Behavior { PATROL, WORKER, CHILD, ELDER }
@export var id: StringName
@export var display_name := "Житель"
@export var behavior: Behavior = Behavior.PATROL
@export_range(5.0, 90.0) var speed := 32.0
@export var frames: SpriteFrames
@export var routine: Array[HutorNpcRoutineStep] = []
@export var route_bounds := Rect2()
@export_range(3.0, 7.0) var foot_radius := 5.0
@export_file("*.json") var dialogue_path := ""
@export var dialogue_id := ""
@export var pipe_smoke := false
@export var notices_player := false
@export_multiline var art_notes := ""
