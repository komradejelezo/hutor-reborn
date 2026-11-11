extends "res://tools/review_npc_rework.gd"
## Resource-only temporal QC, same scale for comparison; no gameplay claim.
func run() -> void:
    super.run()
    root.title="Hutor Reborn — 5.4.1 technical resource review"
    for item in actors:
        if item.id!="hans":item.sprite.sprite_frames=load("res://assets/npc/stage541/"+item.id+"/frames.tres")
    print("NPC541_RESOURCES_READY")
