class_name HutorDailyResidentState
extends RefCounted
## One logical identity owns one existing body, including when parked off-tree.
var id: StringName
var actor: HutorResident
var original: HutorNpcDefinition
var schedule: Dictionary
var block: Dictionary
var block_stamp := -INF
var scene: StringName
var desired_scene: StringName
var position := Vector2.ZERO
var mode: StringName = &"local"
var activity: StringName = &"rest"
var index := 0
var until := 0.0
var updated := 0.0
var travel_end := 0.0
var hop: StringName
var goal := Vector2.ZERO
var snapshot: Dictionary = {}
var snapshot_stamp := -INF
var parked_at := 0.0
var route: Array = []
var portal_direction := Vector2.ZERO
var portal_target := Vector2.ZERO
var portal_blocked := 0.0
var event_counts: Dictionary = {}
func count_event(event: String) -> void: event_counts[event]=event_counts.get(event,0)+1
