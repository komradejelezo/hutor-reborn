extends Node2D
## Container/director; every resident is a normal instance of the same base scene.
var player: CharacterBody2D
var residents: Dictionary = {}
var atmosphere: Node2D
@onready var navigation: HutorNpcNavigation = $Navigation

func _ready() -> void:
    player = get_node("../Hans")
    atmosphere = get_node_or_null("../../Atmosphere")
    add_to_group("npc_population")
    for child in get_children():
        if child is CharacterBody2D:
            residents[child.definition.id] = child
            child.tree_exiting.connect(_unregister.bind(child.definition.id))

func resident(id: StringName) -> CharacterBody2D:
    var actor: Variant = residents.get(id)
    return actor if is_instance_valid(actor) else null

func _unregister(id: StringName) -> void: residents.erase(id)
