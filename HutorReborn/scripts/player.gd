extends CharacterBody2D
signal interaction_requested(payload: Dictionary)
@export var speed: float = 94.0
var facing := "down"
var controls_locked := false
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var sensor: Node = $InteractionSensor

func _physics_process(_delta: float) -> void:
    var axis := Vector2.ZERO if controls_locked else Input.get_vector("move_left", "move_right", "move_up", "move_down")
    velocity = axis * speed
    if not axis.is_zero_approx():
        # Four-way animation, normalized diagonal travel at the same speed.
        if absf(axis.x) > absf(axis.y):
            facing = "right" if axis.x > 0 else "left"
        else:
            facing = "down" if axis.y > 0 else "up"
    sprite.play(("idle_" if axis.is_zero_approx() else "walk_") + facing)
    move_and_slide()
