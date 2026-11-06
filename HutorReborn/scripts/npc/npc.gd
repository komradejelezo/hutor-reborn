class_name HutorResident
extends CharacterBody2D
## Shared cyclic state machine; the nine residents differ only through resources.
signal routine_step_changed(npc_id: StringName, index: int)
enum State { WAIT_PATH, MOVING, WAITING, YIELDING, RECOVERING, TALKING }
@export var definition: HutorNpcDefinition
var state: State = State.WAIT_PATH
var step_index := 0
var facing: StringName = &"down"
var wait_left := 0.0
var recovery_count := 0
var steps_completed := 0
var distance_walked := 0.0
var director: Node2D
var _path := PackedVector2Array()
var _path_index := 0
var _token := 0
var _blocked_time := 0.0
var _retry_count := 0
var _avoid_cell := Vector2i(-1,-1)
var _resume_state: State = State.WAITING
var _talk_resume_state: State = State.WAITING
var _rng := RandomNumberGenerator.new()
var _notice_cooldown := 0.0
var _social_timer := 0.0
var _ready_to_walk := false
var motion_paused := false
@onready var animator: Node = $Animator

func _ready() -> void:
    add_to_group("residents")
    motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
    $AnimatedSprite2D.sprite_frames = definition.frames
    var feet: CapsuleShape2D = $Feet.shape
    feet.radius = definition.foot_radius
    feet.height = definition.foot_radius*2
    _rng.seed = hash(String(definition.id))
    call_deferred("_begin")

func _begin() -> void:
    director = get_parent()
    _ready_to_walk = true
    if definition.routine.is_empty():
        state = State.WAITING; wait_left = INF
    else: _request_path()
    _present()

func current_step() -> HutorNpcRoutineStep:
    return definition.routine[step_index] if not definition.routine.is_empty() else null

func _request_path() -> void:
    if not is_instance_valid(director): return
    _token += 1
    state = State.WAIT_PATH
    director.navigation.request(self,_token,global_position,current_step().position,definition.route_bounds,_avoid_cell)

func _path_received(token: int, path: PackedVector2Array) -> void:
    if token != _token: return
    _path = path
    _path_index = 1 if path.size()>1 else 0
    if state == State.TALKING: return
    if path.is_empty():
        _recover()
    else:
        state = State.MOVING
        _blocked_time = 0

func _physics_process(delta: float) -> void:
    if not _ready_to_walk: return
    if motion_paused:
        velocity = Vector2.ZERO
        _present()
        return
    _notice_cooldown = maxf(0,_notice_cooldown-delta)
    _social_timer = maxf(0,_social_timer-delta)
    velocity = Vector2.ZERO
    if state == State.TALKING:
        _present(); return
    if state == State.RECOVERING:
        wait_left -= delta
        if wait_left <= 0: _request_path()
    elif state == State.WAITING:
        wait_left -= delta
        var step := current_step()
        if step and step.look_at_npc != &"" and _social_timer<=0:
            var partner: CharacterBody2D = director.resident(step.look_at_npc)
            if is_instance_valid(partner): face_point(partner.global_position)
            _social_timer = .5
        if wait_left <= 0: _next_step()
    elif state == State.YIELDING:
        wait_left -= delta
        if wait_left <= 0 and _player_distance()>42:
            state = _resume_state
    elif state == State.MOVING:
        if _player_distance()<28:
            _yield(.45)
        elif definition.notices_player and _notice_cooldown<=0 and _player_distance()<62:
            face_point(director.player.global_position)
            _notice_cooldown = 8
            _yield(1.4)
        elif _neighbor_has_priority():
            _yield(.3)
        else:
            while _path_index < _path.size() and global_position.distance_to(_path[_path_index]) < 2:
                _path_index += 1
            if _path_index >= _path.size():
                _arrive()
            else:
                var delta_position := _path[_path_index]-global_position
                var speed := minf(definition.speed,delta_position.length()/maxf(delta,.001))
                velocity = delta_position.normalized()*speed
                face_point(global_position+velocity)
                var before := global_position
                move_and_slide()
                var traveled := before.distance_to(global_position)
                distance_walked += traveled
                if traveled < speed*delta*.18: _blocked_time += delta
                else: _blocked_time = 0
                if _blocked_time>1.2:
                    _avoid_cell = director.navigation.cell(_path[_path_index])
                    _recover()
    _present()

func _player_distance() -> float:
    return global_position.distance_to(director.player.global_position) if is_instance_valid(director.player) else INF

func _neighbor_has_priority() -> bool:
    for other in director.residents.values():
        if not is_instance_valid(other) or other == self: continue
        if global_position.distance_squared_to(other.global_position)>22*22: continue
        if other.state == State.MOVING and String(definition.id)>String(other.definition.id): return true
    return false

func _yield(duration: float) -> void:
    _resume_state = state
    state = State.YIELDING
    wait_left = duration
    velocity = Vector2.ZERO

func _arrive() -> void:
    var step := current_step()
    state = State.WAITING
    facing = step.facing
    wait_left = step.duration*_rng.randf_range(1-step.duration_variation,1+step.duration_variation)
    _retry_count = 0; _avoid_cell = Vector2i(-1,-1)
    steps_completed += 1
    routine_step_changed.emit(definition.id,step_index)

func _next_step() -> void:
    step_index = (step_index+1)%definition.routine.size()
    _request_path()

func _recover() -> void:
    recovery_count += 1
    _retry_count += 1
    _token += 1
    state = State.RECOVERING
    velocity = Vector2.ZERO
    wait_left = .6+_rng.randf_range(0,.5)
    _blocked_time = 0
    if _retry_count>=3:
        step_index = (step_index+1)%definition.routine.size()
        _retry_count = 0; _avoid_cell = Vector2i(-1,-1)

func face_point(point: Vector2) -> void:
    var axis := point-global_position
    if axis.length_squared()<.01: return
    facing = (&"right" if axis.x>0 else &"left") if absf(axis.x)>absf(axis.y) else (&"down" if axis.y>0 else &"up")

func begin_conversation() -> void:
    if state == State.TALKING: return
    _talk_resume_state = state
    state = State.TALKING
    velocity = Vector2.ZERO
    if is_instance_valid(director.player): face_point(director.player.global_position)
    _present()

func end_conversation() -> void:
    if state != State.TALKING: return
    state = _talk_resume_state
    if state == State.WAIT_PATH:
        if not _path.is_empty(): state = State.MOVING
        else: _request_path()
    _present()

func _present() -> void:
    var mode := "walk" if state == State.MOVING and not velocity.is_zero_approx() else "idle"
    var step := current_step()
    if not motion_paused and state == State.WAITING and step and step.animation != &"": mode = "work"
    var allow_smoke: bool = definition.pipe_smoke and (not is_instance_valid(director) or not is_instance_valid(director.atmosphere) or director.atmosphere.effects_enabled)
    animator.apply(mode,facing,step.animation if step else &"",allow_smoke)

func set_motion_paused(value: bool) -> void:
    motion_paused = value
    if value: velocity = Vector2.ZERO
    if is_node_ready(): _present()
