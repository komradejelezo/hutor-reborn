extends Node2D
## Container/director; every resident is a normal instance of the same base scene.
var player: CharacterBody2D
var residents: Dictionary = {}
var atmosphere: Node2D
@onready var navigation: HutorNpcNavigation = $Navigation

func _ready() -> void:
    _refresh()

func _enter_tree() -> void:
    if is_node_ready(): _refresh.call_deferred()

func _refresh() -> void:
    player = get_node("../Hans")
    atmosphere = get_node_or_null("../../Atmosphere")
    add_to_group("npc_population")
    residents.clear()
    for child in get_children():
        if child is CharacterBody2D:
            adopt(child)

func resident(id: StringName) -> CharacterBody2D:
    var actor: Variant = residents.get(id)
    return actor if is_instance_valid(actor) else null

func _unregister(id: StringName) -> void: residents.erase(id)

func adopt(actor: CharacterBody2D) -> void:
    residents[actor.definition.id] = actor
    var callback := _unregister.bind(actor.definition.id)
    if not actor.tree_exiting.is_connected(callback): actor.tree_exiting.connect(callback)
