extends PointLight2D
@export var base_energy: float = 0.8
@export var flicker: float = 0.05
var elapsed: float = 0.0

func _process(delta: float) -> void:
    elapsed += delta
    energy = base_energy + (sin(elapsed * 7.1 + position.x) + sin(elapsed * 11.3)) * flicker * 0.5
