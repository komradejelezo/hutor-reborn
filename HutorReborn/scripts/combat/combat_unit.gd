extends RefCounted
## A battle-local value object. Never references a world/NPC instance.
var serial:int
var id:String
var kind:String
var name:String
var team:int
var row:String
var lane:int
var hp:int
var max_hp:int
var damage:int
var armor:int
var initiative:int
var accuracy:int
var reach:String
var data:Dictionary
var guarding:=false
var skips:=0
var raven:=0
var weakened:=0
var cooldown:=0
var heals:=0
func _init(definition:Dictionary,slot:Dictionary) -> void:
    data=definition.duplicate(true)
    id=slot.id;kind=slot.kind;name=data.name;team=int(slot.team);row=slot.row;lane=int(slot.lane)
    max_hp=int(data.health);hp=max_hp;damage=int(data.damage);armor=int(data.armor)
    initiative=int(data.initiative);accuracy=int(data.accuracy);reach=data.reach
    heals=int(data.get("heal_charges",0))
func alive() -> bool:return hp>0
func status_text() -> String:
    if not alive():return "Погиб"
    var tags:PackedStringArray=[]
    if guarding:tags.append("Щит")
    if skips>0:tags.append("Корни")
    if raven>0:tags.append("Ворон ·"+str(raven))
    if weakened>0:tags.append("Слабость ·"+str(weakened))
    return " · ".join(tags)
