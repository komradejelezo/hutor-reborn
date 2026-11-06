class_name HutorDialogueData
extends RefCounted
## Validated, UI-independent conversation graph. JSON is copied before use.
var id := ""
var start := ""
var nodes: Dictionary = {}
var errors: Array[String] = []

static func from_file(path: String) -> HutorDialogueData:
    var result := HutorDialogueData.new()
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        result.errors.append("Не удалось открыть диалог: " + path)
        return result
    var parser := JSON.new()
    if parser.parse(file.get_as_text()) != OK:
        result.errors.append("JSON, строка %d: %s" % [parser.get_error_line(), parser.get_error_message()])
        return result
    return from_dictionary(parser.data)

static func from_dictionary(source: Variant) -> HutorDialogueData:
    var result := HutorDialogueData.new()
    if not source is Dictionary:
        result.errors.append("Корень диалога должен быть объектом")
        return result
    if not _string_field(source, "id") or not _string_field(source, "start") or not source.get("nodes") is Array:
        result.errors.append("Нужны непустые id, start и массив nodes")
        return result
    result.id = source.id
    result.start = source.start
    for raw in source.nodes:
        if not raw is Dictionary or not _string_field(raw, "id"):
            result.errors.append("У каждой реплики должен быть непустой id")
            continue
        if result.nodes.has(raw.id):
            result.errors.append("Повтор id реплики: " + raw.id)
            continue
        var line: Dictionary = raw.duplicate(true)
        result.nodes[line.id] = line
        var errors_before := result.errors.size()
        for field in ["speaker", "text"]:
            if not _string_field(line, field):
                result.errors.append("%s: нужно поле %s" % [line.id, field])
        for field in ["portrait", "emotion", "next"]:
            if line.has(field) and not line[field] is String:
                result.errors.append("%s: %s должно быть строкой" % [line.id, field])
        if not line.get("end", false) is bool:
            result.errors.append(line.id + ": end должен быть bool")
        var portraits: Variant = line.get("portraits", {})
        if not portraits is Dictionary:
            result.errors.append(line.id + ": portraits должен быть словарём эмоция → PNG")
        else:
            for emotion in portraits:
                if not emotion is String or not portraits[emotion] is String:
                    result.errors.append(line.id + ": неверный путь портрета")
        if result.errors.size() != errors_before:
            continue
        var choices: Variant = line.get("choices", [])
        if not choices is Array:
            result.errors.append(line.id + ": choices должен быть массивом")
            continue
        if line.get("end", false) == true and (not choices.is_empty() or line.get("next", "") != ""):
            result.errors.append(line.id + ": завершающая реплика не должна иметь переходы")
        if not choices.is_empty() and line.get("next", "") != "":
            result.errors.append(line.id + ": выберите choices или next")
        if choices.is_empty() and line.get("next", "") == "" and line.get("end", false) != true:
            result.errors.append(line.id + ": нужен next, choices или end")
        var choice_ids: Dictionary = {}
        for choice in choices:
            if not choice is Dictionary or not _string_field(choice, "id") or not _string_field(choice, "text"):
                result.errors.append(line.id + ": у ответа нужны id и text")
                continue
            if choice_ids.has(choice.id):
                result.errors.append(line.id + ": повтор id ответа " + choice.id)
            choice_ids[choice.id] = true
            if not choice.get("end", false) is bool or not choice.get("next", "") is String:
                result.errors.append(line.id + ": неверные end/next ответа")
                continue
            if (choice.get("end", false) == true) == (choice.get("next", "") != ""):
                result.errors.append(line.id + ": ответ должен иметь либо next, либо end")
    if not result.nodes.has(result.start):
        result.errors.append("Не найдена начальная реплика: " + result.start)
    for line in result.nodes.values():
        var destinations: Array = [line.get("next", "")]
        if line.get("choices", []) is Array:
            for choice in line.get("choices", []):
                if choice is Dictionary: destinations.append(choice.get("next", ""))
        for destination in destinations:
            if destination is String and destination != "" and not result.nodes.has(destination):
                result.errors.append("%s: не найден переход %s" % [line.id, destination])
    return result

static func _string_field(object: Dictionary, key: String) -> bool:
    return object.get(key) is String and not object[key].strip_edges().is_empty()

func is_valid() -> bool:
    return errors.is_empty() and not nodes.is_empty()
