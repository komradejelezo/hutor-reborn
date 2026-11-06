extends HutorDialogueInteractable
## Reuse the existing world -> DialogueManager bridge without changing it.
var _pending := false
var _owns_session := false
@onready var npc: CharacterBody2D = get_parent()
@onready var manager: Node = get_node("/root/DialogueManager")

func _ready() -> void:
    super._ready()
    title = "Поговорить · "+npc.definition.display_name
    reach = 52.0
    dialogue_path = npc.definition.dialogue_path
    manager.dialogue_started.connect(_started)
    manager.dialogue_finished.connect(_finished)

func interact() -> Dictionary:
    _pending = true
    call_deferred("_clear_pending")
    return super.interact()

func _clear_pending() -> void: _pending = false
func _started(id: String) -> void:
    if not _pending or id != npc.definition.dialogue_id: return
    _pending = false
    _owns_session = true
    npc.begin_conversation()

func _finished(_id: String, _reason: String) -> void:
    if not _owns_session: return
    _owns_session = false
    npc.end_conversation()

func _exit_tree() -> void:
    if _owns_session and is_instance_valid(manager): manager.close_dialogue("npc_removed")
