class_name HutorNpcWorkBindings54
extends RefCounted
## Only work-place alignment, never schedule times, scene IDs or travel edges.
static func aligned_point(world:Node2D, id:StringName, action:String, original:Vector2) -> Vector2:
    if world==null:return original
    var path:="";var offset:=Vector2.ZERO
    if world.get("building_id")==&"inn" and id==&"innkeeper_wife":
        if action=="clean_tables":path="Actors/Props/TableA";offset=Vector2(0,-42)
        elif action=="kitchen":path="Actors/Props/TableC";offset=Vector2(0,-40)
    elif world.get("building_id")==&"herbalist" and id==&"herbalist" and action in ["sort_herbs","brew"]:
        path="Actors/Props/Table";offset=Vector2(0,30)
    elif world.get("building_id")==&"woodcutter" and id==&"woodcutter_wife" and action=="cook":
        path="Actors/Props/KitchenPot";offset=Vector2(-26,2)
    var object:Node2D=world.get_node_or_null(path) if not path.is_empty() else null
    return object.position+offset if object else original

static func specification(id:StringName, scene:StringName, action:String) -> Dictionary:
    if id==&"woodcutter" and scene==&"woodcutter" and action in ["prepare_work","rest_after_work"]:
        return {"clip":"work_rest"}
    if id==&"innkeeper" and scene==&"inn":
        if action in ["prepare_inn","wipe_mug"]:return {"clip":"work_wipe","object":"Actors/Props/Counter","reach":74,"overlay":true,"offset":[0,18]}
        if action=="arrange_dishes":return {"clip":"work_serve","object":"Actors/Props/Counter","reach":92,"overlay":true,"offset":[0,18]}
    if id==&"innkeeper_wife" and scene==&"inn":
        if action=="clean_tables":return {"clip":"work_wipe","object":"Actors/Props/TableA","reach":64,"overlay":true,"offset":[0,0]}
        if action=="kitchen":return {"clip":"work_cook","object":"Actors/Props/TableC","reach":64,"overlay":true,"offset":[0,16]}
        if action=="sweep_floor":return {"clip":"work_sweep"}
    if id==&"woodcutter_wife":
        if action=="cook" and scene==&"woodcutter":return {"clip":"work_cook","object":"Actors/Props/KitchenPot","reach":74}
        if action in ["sweep_yard","clean"]:return {"clip":"work_sweep"}
        if action=="household":return {"clip":"work_laundry","prop":"tub"}
        if action=="serve":return {"clip":"work_sort"}
        if action=="garden_work":return {"clip":"work_rake"}
        if action=="rest_night":return {"clip":"work_rest"}
    if id==&"elder":
        if action=="read_documents" and scene==&"elder":return {"clip":"work_read_full","object":"Actors/Props/Desk","reach":76}
        if action=="common_store" and scene==&"village":return {"clip":"work_read_full","object":"Actors/Structures/CommonHouse","reach":100}
        if action in ["ponder","inspect_square"]:return {"clip":"talk_down"}
    if id==&"old_man":
        if action=="sit_and_smoke":return {"clip":"work_sit","prop":"seat","smoke":true}
        if action in ["slow_walk","watch_hans","rest_by_hearth"]:return {"clip":"work_smoke","smoke":true}
        if action=="ponder":return {"clip":"work_story"}
    if id==&"herbalist":
        if action in ["gather","inspect_plants"] and scene==&"village":return {"clip":"work_gather","prop":"herbs"}
        if action in ["sort_herbs","brew"] and scene==&"herbalist":return {"clip":"work_grind","object":"Actors/Props/Table","reach":64}
    if id==&"herbalist_brother" and scene==&"herbalist" and action=="household":return {"clip":"work_mend","prop":"workblock"}
    if id==&"woodcutter_son":
        if action in ["home_play","play_stick","return_yard"]:return {"clip":"work_play"}
        if action in ["kneel_toy","inspect_well"]:return {"clip":"work_kneel","prop":"toy"}
    return {}
