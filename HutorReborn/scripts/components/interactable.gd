class_name HutorInteractable
extends Marker2D
## Put this component at the reachable interaction point, outside the solid footprint.
@export var title: String = "Осмотреть"
@export_multiline var description: String = ""
@export var reach: float = 58.0
var focused := false

func _ready() -> void:
    add_to_group("interactables")

func interaction_priority() -> int:
    return 0 # Passive inspections; actionable doors/conversations take precedence.

func prompt_text() -> String:
    return "[ E ]   " + title

func set_focused(value: bool) -> void:
    if focused != value:
        focused = value
        queue_redraw()

func _draw() -> void:
    if focused:
        draw_arc(Vector2(0, -4), 4, 0.0, TAU, 12, Color("e8cb89"), 1.0)
        draw_circle(Vector2(0, -4), 1, Color("e8cb89"))

func interact() -> Dictionary:
    return {"title": title, "text": description}
