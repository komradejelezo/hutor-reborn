extends "res://tests/verify_interiors.gd"
## Door staging and a workday while Hans stays inside the inn.
var life:Node
func unique_people(expected:Dictionary)->bool:
    var found:Dictionary={}
    var worlds:Array=[travel.exterior,life._parking];worlds.append_array(travel.rooms.values())
    for world in worlds:
        if not is_instance_valid(world):continue
        for body in world.find_children("*","CharacterBody2D",true,false):
            if not body is HutorResident:continue
            if found.has(body.definition.id):return false
            found[body.definition.id]=body.get_instance_id()
    return found==expected
func single_schedule_subscriptions()->bool:
    for r:HutorDailyResidentState in life.states.values():
        for pair in [["routine_step_requested","_prepare_partner_visit"],["routine_step_changed","_arrived"]]:
            var matches:=0
            for link in r.actor.get_signal_connection_list(pair[0]):
                if link.callable==Callable(life,pair[1]):matches+=1
            if matches!=1:return false
    return true
func run()->void:
    travel=root.get_node("InteriorTravel");life=root.get_node("VillageLife")
    change_scene_to_file(travel.VILLAGE);await frames(12);life.clock.running=false
    var ids:Dictionary={}
    for id in life.states:ids[id]=life.states[id].actor.get_instance_id()
    life.clock.seek(1078)
    check(travel.request_transition(&"woodcutter"),"Hans enters family home before evening")
    await wait_transition()
    var room:Node2D=travel.active_world;var hero:CharacterBody2D=room.player
    hero.position=room.get_node("Entry").position
    life.clock.set_speed(30);life.clock.running=true
    await create_timer(4).timeout
    life.clock.running=false
    for id in [&"woodcutter_wife",&"woodcutter_son"]:
        var r:HutorDailyResidentState=life.states[id]
        check(r.scene==&"woodcutter" and r.pending_entry and not r.actor.is_inside_tree(),String(id)+" waits at blocked indoor entrance without overlapping Hans")
        check(r.position.distance_to(room.get_node("Entry").position)<.1,String(id)+" does not virtually walk through an occupied visible entrance")
    check(unique_people(ids),"door queue retains exactly nine bodies")
    hero.position+=Vector2(40,-24)
    life.clock.running=true
    var deadline:=Time.get_ticks_msec()+5000
    var saw_entry:Dictionary={};var before:Dictionary={};var invalid:=""
    while Time.get_ticks_msec()<deadline and saw_entry.size()<2:
        await physics_frame
        for id in [&"woodcutter_wife",&"woodcutter_son"]:
            var r:HutorDailyResidentState=life.states[id]
            if not r.actor.is_inside_tree():continue
            if not saw_entry.has(id):
                saw_entry[id]=true
                if r.actor.position.distance_to(room.get_node("Entry").position)>40:invalid="appeared away from door"
            before[id]=r.actor.position
        var present:Array=room.get_node("Actors/Residents").residents.values()
        for i in present.size():
            for j in range(i+1,present.size()):
                if present[i].position.distance_to(present[j].position)<present[i].definition.foot_radius+present[j].definition.foot_radius-.5:invalid="simultaneous door overlap"
    life.clock.running=false
    check(saw_entry.size()==2 and invalid.is_empty(),"both family members enter sequentially after Hans clears doorway: "+invalid)
    check(unique_people(ids),"no duplicates after queued entry")
    check(travel.request_transition(&"woodcutter",true),"family-home exit remains unchanged")
    await wait_transition()
    life.clock.seek(450)
    check(travel.request_transition(&"inn"),"Hans enters existing inn for the workday")
    await wait_transition()
    room=travel.active_world;hero=room.player
    var solves:Dictionary={}
    for cached in travel.rooms.values():
        if cached!=room:solves[cached.building_id]=cached.get_node("Actors/Residents/Navigation").solve_count
    var village_solves:int=travel.exterior.get_node("Actors/Residents/Navigation").solve_count
    var seen:Dictionary={&"innkeeper":{},&"innkeeper_wife":{}}
    life.clock.set_speed(60);life.clock.running=true
    deadline=Time.get_ticks_msec()+45000
    while life.clock.absolute_minutes<1215 and Time.get_ticks_msec()<deadline:
        await physics_frame
        for id in seen:
            var r:HutorDailyResidentState=life.states[id]
            if r.scene!=&"inn" or not r.actor.is_inside_tree():invalid="inn worker left inn"
            if r.actor.state==HutorResident.State.WAITING:seen[id][r.activity]=true
    life.clock.running=false
    check(life.clock.absolute_minutes>=1215,"workday advances naturally while Hans remains inside")
    check(invalid.is_empty(),"inn workers remain physically present at work: "+invalid)
    for id in seen:check(seen[id].size()>=3,String(id)+" actually completes several indoor chores: "+str(seen[id].keys()))
    for id in [&"woodcutter",&"herbalist_brother"]:
        var r:HutorDailyResidentState=life.states[id]
        check(r.event_counts.get("left_for_work",0)>=1 and r.event_counts.get("return_from_work",0)>=1,String(id)+" works and returns while off-scene")
        check(r.scene==r.schedule.home,String(id)+" is at own home in evening")
    check(travel.exterior.get_node("Actors/Residents/Navigation").solve_count==village_solves,"unloaded village does no physics path solves")
    for id in solves:check(travel.rooms[id].get_node("Actors/Residents/Navigation").solve_count==solves[id],"inactive room does no physics search: "+String(id))
    var time_before:float=life.clock.absolute_minutes
    check(travel.request_transition(&"inn",true),"Hans leaves inn after workday")
    await wait_transition()
    check(life.clock.absolute_minutes==time_before and unique_people(ids),"time and all nine identities persist after return")
    life.clock.seek(1438);life.clock.running=true;life.clock.set_speed(30)
    await create_timer(.25).timeout;life.clock.running=false
    check(life.clock.absolute_minutes>1440 and life.clock.phase_name()==&"night","night continues across midnight")
    life.clock.seek(1805)
    check(life.states[&"elder"].desired_scene==&"elder" and unique_people(ids),"next-morning time skip restores current schedule without duplicates")
    check(single_schedule_subscriptions(),"all nine residents retain exactly one schedule subscription after scene visits")
    print("RESULT: ",passed," scene-state checks passed, ",failed," failed")
    quit(0 if failed==0 else 1)
