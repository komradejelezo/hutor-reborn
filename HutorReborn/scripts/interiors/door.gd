extends HutorInteractable
@export var building_id: StringName
@export var exit_to_village := false
func interact() -> Dictionary:
    return {"building_id": building_id, "exit_to_village": exit_to_village}
