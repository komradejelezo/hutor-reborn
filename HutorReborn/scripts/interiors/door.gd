extends HutorInteractable
@export var building_id: StringName
@export var exit_to_village := false

func interaction_priority() -> int:
    return 10

func prompt_text() -> String:
    return "E — Выйти" if exit_to_village else "E — Войти"

func interact() -> Dictionary:
    return {"building_id": building_id, "exit_to_village": exit_to_village}
