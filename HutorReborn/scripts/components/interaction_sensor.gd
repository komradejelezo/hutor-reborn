extends Node
## A short ray prevents interaction through walls and fences.
signal focus_changed(target: HutorInteractable)
var target: HutorInteractable
var target_id: int = 0
@onready var actor: CharacterBody2D = get_parent()

func _physics_process(_delta: float) -> void:
    if target_id != 0 and not is_instance_valid(target):
        target = null
        target_id = 0
        focus_changed.emit(null)
    var best: HutorInteractable = null
    var best_distance := INF
    var best_priority := -2147483648
    for node in get_tree().get_nodes_in_group("interactables"):
        var candidate := node as HutorInteractable
        var distance := actor.global_position.distance_to(candidate.global_position)
        var priority := candidate.interaction_priority()
        if distance > candidate.reach or priority < best_priority:
            continue
        if priority == best_priority and distance >= best_distance:
            continue
        var ray := PhysicsRayQueryParameters2D.create(actor.global_position + Vector2(0, -5), candidate.global_position + Vector2(0, -5), 1)
        ray.exclude = [actor.get_rid()]
        if not actor.get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
            continue
        best = candidate
        best_distance = distance
        best_priority = priority
    if best != target:
        if is_instance_valid(target):
            target.set_focused(false)
        target = best
        target_id = target.get_instance_id() if target else 0
        if target:
            target.set_focused(true)
        focus_changed.emit(target)
