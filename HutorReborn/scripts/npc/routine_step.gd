class_name HutorNpcRoutineStep
extends Resource
@export var talk_offset := Vector2.ZERO
## A cyclic schedule entry, deliberately independent of clock time and quests.
enum Action { HOME, WORK, WALK, REST, TALK, MOVE }
@export var label := ""
@export var action: Action = Action.REST
@export var position := Vector2.ZERO
@export_range(0.0, 120.0) var duration := 3.0
@export_range(0.0, 1.0) var duration_variation := 0.15
@export var facing: StringName = &"down"
@export var animation: StringName = &""
@export var look_at_npc: StringName = &""
