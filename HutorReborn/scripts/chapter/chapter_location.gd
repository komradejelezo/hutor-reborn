extends "res://scripts/world.gd"
@export var building_id:StringName
@export var map_size:=Vector2i(1216,1152)
@export var room_bounds:=Rect2(192,128,640,416)
func _ready() -> void:
    # Same world interaction contract, without applying village-specific polish.
    preload("res://scripts/input_setup.gd").ensure_actions()
    player.interaction_requested.connect(_show_description)
    player.sensor.focus_changed.connect(hud.set_focus)
    hud.resume_requested.connect(func():_set_paused(false))
    hud.quit_requested.connect(func():get_tree().quit())
    var camera:Camera2D=player.get_node("Camera2D")
    camera.position=Vector2.ZERO;camera.zoom=Vector2.ONE*(1.3 if building_id==&"abandoned" else 1)
    camera.limit_left=0;camera.limit_top=0;camera.limit_right=map_size.x;camera.limit_bottom=map_size.y
    camera.reset_smoothing()
    var audio:AudioStreamPlayer=get_node_or_null("RoomTone")
    if audio:
        var stream:AudioStreamOggVorbis=audio.stream.duplicate();stream.loop=true;audio.stream=stream;audio.play()
func local_definition(_id:StringName) -> HutorNpcDefinition:return null
func _process(_delta:float) -> void:
    if building_id==&"logging_camp":
        var phase:StringName=get_node("/root/VillageLife").clock.phase_name()
        $Evening.color={&"night":Color(.48,.55,.63),&"evening":Color(.62,.66,.68)}.get(phase,Color(.84,.85,.8))
