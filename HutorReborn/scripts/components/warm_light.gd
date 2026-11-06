extends PointLight2D
@export var base_energy: float = 0.8
@export var flicker: float = 0.05
@export_range(0.01, 0.25) var update_interval: float = 0.08
@export_range(0.1, 5.0) var flicker_speed: float = 1.3
var elapsed: float = 0.0
var _since_update: float = 0.0
var _phase: float = 0.0

func _ready() -> void:
    _phase = fposmod(global_position.x * 0.023 + global_position.y * 0.017, TAU)
    energy = base_energy
    _since_update = _phase / TAU * update_interval
    set_process(flicker > 0.0)

func _process(delta: float) -> void:
    if not enabled or flicker <= 0.0:
        return
    elapsed += delta
    _since_update += delta
    if _since_update < update_interval:
        return
    _since_update = fmod(_since_update, update_interval)
    var pulse := sin(elapsed * flicker_speed + _phase) + sin(elapsed * flicker_speed * 1.63 + _phase * 1.7)
    var target := maxf(0.0, base_energy + pulse * flicker * 0.5)
    if absf(energy - target) >= 0.00025:
        energy = target
