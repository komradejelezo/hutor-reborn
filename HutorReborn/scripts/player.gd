extends CharacterBody2D
signal interaction_requested(payload: Dictionary)
@export var speed: float = 94.0
# Uniform nearest sampling; idle.png was drawn smaller than the walking sheets.
@export var walk_sprite_scale: float = 1.0 / 24.0
@export var side_idle_sprite_scale: float = 1.0 / 21.0
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
    var idle := axis.is_zero_approx()
    sprite.flip_h = facing == "left"
    var side_idle := idle and (facing == "left" or facing == "right")
    sprite.scale = Vector2.ONE * (side_idle_sprite_scale if side_idle else walk_sprite_scale)
    sprite.play(("idle_" if idle else "walk_") + facing)
    move_and_slide()
