extends RefCounted
## Enemies use the same legal-action API as the player.
static func choose(battle:RefCounted) -> Dictionary:
    var u:RefCounted=battle.actor()
    if not u:return {"action":"defend","target":""}
    var valid:Array=battle.targets("attack")
    if u.kind=="spirit" and battle.special_available("whisper") and battle.rng.randf()<.65:
        var cursed:Array=battle.targets("whisper")
        if not cursed.is_empty():return {"action":"whisper","target":cursed[0]}
    var defense_chance:=.25 if u.kind=="beast" else .1
    if u.hp<u.max_hp*.5 and battle.rng.randf()<defense_chance:return {"action":"defend","target":""}
    if valid.is_empty():return {"action":"defend","target":""}
    if u.kind=="mercenary" and "hans" in valid:return {"action":"attack","target":"hans"}
    valid.sort_custom(func(a:String,b:String):return float(battle.units[a].hp)/battle.units[a].max_hp<float(battle.units[b].hp)/battle.units[b].max_hp)
    var target:String=valid[0] if battle.rng.randf()<.75 else valid[battle.rng.randi_range(0,valid.size()-1)]
    return {"action":"attack","target":target}
