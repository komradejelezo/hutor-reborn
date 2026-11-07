class_name HutorGameClock
extends Node
signal minute_changed(absolute_minute: float)
signal phase_changed(phase: StringName)
signal speed_changed(value: float)
signal sought
@export_range(60.0,7200.0) var real_day_seconds := 1800.0
var absolute_minutes := 420.0
var running := false
var speed := 1.0
var _last_minute := -1
var _last_phase: StringName = &""
func _ready() -> void: process_mode = Node.PROCESS_MODE_ALWAYS
func _process(delta: float) -> void:
    if running and not get_tree().paused:
        absolute_minutes += delta*1440.0/real_day_seconds*speed
        _notify()
func _notify() -> void:
    var phase := phase_name()
    if phase != _last_phase:
        _last_phase = phase; phase_changed.emit(phase)
    if int(absolute_minutes) != _last_minute:
        _last_minute = int(absolute_minutes); minute_changed.emit(absolute_minutes)
func minute_of_day() -> float: return fposmod(absolute_minutes,1440)
func phase_name() -> StringName:
    var minute := minute_of_day()
    if minute>=360 and minute<600:return &"morning"
    if minute>=600 and minute<1080:return &"day"
    if minute>=1080 and minute<1320:return &"evening"
    return &"night"
func display_time() -> String:
    var minute := int(minute_of_day())
    return "%02d:%02d" % [minute/60,minute%60]
func set_speed(value: float) -> void:
    speed = clampf(value,.1,120)
    speed_changed.emit(speed)
func seek(value: float) -> void:
    absolute_minutes = maxf(0,value);_last_minute=-1
    sought.emit();_notify()
