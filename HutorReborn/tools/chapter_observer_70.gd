extends Node
## Read-only native playtest observer, enabled only by a temporary override.
var output:=""
var elapsed:=0.0
func _ready() -> void:
    process_mode=Node.PROCESS_MODE_ALWAYS # Journal pauses the world, not observation.
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--chapter-observe="):output=arg.trim_prefix("--chapter-observe=")
func _process(delta:float) -> void:
    elapsed+=delta
    if output=="" or elapsed<.08:return
    elapsed=0
    var scene:Node=get_tree().current_scene
    if not is_instance_valid(scene):return
    var c:Node=get_node("/root/ChapterI");var h:CharacterBody2D=c.travel.active_world.player if is_instance_valid(c.travel.active_world) else null
    var state:Dictionary={"tick":Engine.get_process_frames(),"scene":scene.scene_file_path,"active":c.active,"test":c.test_mode,"stage":c.state.stage(),"flags":c.state.flags.duplicate(),"position":[h.position.x,h.position.y] if h else [0,0],"world":String(c.travel.active_id),"locked":h.controls_locked if h else false,"busy":c.busy or c.travel.busy,"dialogue":c.dialogue.is_active(),"typing":c.dialogue.window.typing if is_instance_valid(c.dialogue.window) else false,"overlay":c.ui.is_open(),"target":h.sensor.target.title if h and is_instance_valid(h.sensor.target) else "","buttons":[]}
    for context in [scene,c.dialogue,c.ui]:
        for b in context.find_children("*","Button",true,false):
            if not b.is_visible_in_tree():continue
            var centre:Vector2=b.get_global_rect().get_center();state.buttons.append({"text":b.text,"disabled":b.disabled,"center":[centre.x,centre.y]})
    state.phase=int(c.dialogue.phase);state.line=c.dialogue.current_line;state.hero_id=h.get_instance_id() if h else 0
    var path:String=c.SAVE.path(false,"manual")
    state.normal_digest=c.SAVE.digest(FileAccess.get_file_as_bytes(path)).hex_encode() if FileAccess.file_exists(path) else ""
    var f:=FileAccess.open(output+".tmp",FileAccess.WRITE);f.store_string(JSON.stringify(state));f.close();DirAccess.rename_absolute(output+".tmp",output)
