extends HutorInteractable
@export var chapter_action:=""
func interaction_priority() -> int:return 11
func prompt_text() -> String:return "E — "+title
func interact() -> Dictionary:return {"chapter_action":chapter_action}
