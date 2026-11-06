class_name HutorDialogueInteractable
extends HutorInteractable
## Drop this reachable marker into a future NPC scene; no NPC logic required.
@export_file("*.json") var dialogue_path := ""

func interact() -> Dictionary:
    return {"dialogue_path": dialogue_path, "title": title, "text": description}
