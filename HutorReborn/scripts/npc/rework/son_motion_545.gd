extends RefCounted
## Son-only policy. Source definitions and the other eight residents are immutable.
static func runs(record:HutorDailyResidentState, label:String="") -> bool:
    if record.mode!=&"local" or record.scene!=&"village":return false
    if label.is_empty():label=String(record.block.activities[record.index].id)
    return label.begins_with("run_") or label in ["play_stick","visit_mother","return_yard"]

static func speed(record:HutorDailyResidentState, label:String="") -> float:
    return record.original.speed*(float(record.schedule.get("run_multiplier",1.25)) if runs(record,label) else .55)
