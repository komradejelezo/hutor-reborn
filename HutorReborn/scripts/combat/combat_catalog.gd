extends RefCounted
const PATH="res://data/combat/prototype.json"
var data:Dictionary={}
var error:=""
func _init() -> void:
    var parsed:Variant=JSON.parse_string(FileAccess.get_file_as_string(PATH))
    if not parsed is Dictionary:error="Не удалось прочитать параметры испытаний";return
    data=parsed
    error=validate()
func scenario(id:String) -> Dictionary:
    for item in data.get("scenarios",[]):
        if item.id==id:return item.duplicate(true)
    return {}
func validate() -> String:
    if not data.has_all(["units","scenarios","potion_heal","guard_multiplier"]):return "Неполная конфигурация"
    var ids:Dictionary={}
    for s in data.scenarios:
        if ids.has(s.id):return "Повтор сценария"
        ids[s.id]=true
        var names:Dictionary={};var slots:Dictionary={};var allies:=0;var enemies:=0
        for u in s.units:
            if not data.units.has(u.kind) or names.has(u.id):return "Неизвестный или повторный боец"
            names[u.id]=true
            var slot:String=str(u.team)+u.row+str(u.lane)
            if slots.has(slot) or u.row not in ["front","back"] or int(u.lane) not in [0,1] or int(u.team) not in [0,1]:return "Неверное место бойца"
            slots[slot]=true
            if int(u.team)==0:allies+=1
            else:enemies+=1
            var d:Dictionary=data.units[u.kind]
            if not d.has_all(["name","health","damage","armor","initiative","accuracy","reach","visual"]):return "Неполное описание бойца"
            if d.reach not in ["melee","ranged"]:return "Неизвестный тип атаки"
            var image_path:String=d.get("frames",d.get("image",""))
            if not ResourceLoader.exists(image_path):return "Не найден образ: "+str(d.name)
            if int(d.health)<=0 or int(d.damage)<0 or int(d.armor)<0 or int(d.initiative)<0 or int(d.accuracy)<1 or int(d.accuracy)>100:return "Неверные характеристики"
        if allies<1 or allies>3 or enemies<1 or enemies>3:return "Неверный размер отряда"
    return ""
