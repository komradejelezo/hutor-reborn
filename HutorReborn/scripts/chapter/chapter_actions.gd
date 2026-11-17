extends RefCounted
## Atomic consequences; guarded here as well as in the dialogue option builder.
static func apply(s:RefCounted,a:String) -> Dictionary:
    var result:Dictionary={"ok":true,"event":""}
    if a.begins_with("w_"):
        if not s.has("night"):return {"ok":false}
        if s.mark(a):s.clue(a,preload("res://scripts/chapter/chapter_content.gd").WITNESSES[a.trim_prefix("w_")])
    elif a in ["axe_keep","axe_elder","axe_brother"]:
        if not s.has("axe_found") or not s.choose("axe",a.trim_prefix("axe_")):return {"ok":false}
        if a=="axe_elder":s.take("axe");s.relate("elder",1);s.relate("herbalist_brother",-1)
        elif a=="axe_brother":s.relate("herbalist_brother",1);s.clue("brother_resin","Брат узнал свои три зарубки. Смола ему незнакома.")
        else:s.relate("elder",-1)
        s.mark("axe_decided")
    elif a.begins_with("approach_"):
        if not s.has("camp_done") or not s.choose("approach",a.trim_prefix("approach_")):return {"ok":false}
        if a=="approach_elder":s.relate("elder",1)
        s.mark("house_plan","Решено, как попасть в пустой дом. Засов поддастся через ставню с тремя зарубками.")
    else:
        match a:
            "pay":
                if s.has("lodging") or s.money<3:return {"ok":false}
                s.money-=3;s.choose("lodging","pay");s.mark("lodging");s.relate("innkeeper",1)
            "work_paid":
                if not s.has("dishes_delivered") or s.has("lodging"):return {"ok":false}
                s.choose("lodging","work");s.mark("lodging");s.relate("innkeeper",1)
            "take_dishes":
                if not s.has("inn_work"):return {"ok":false}
                if s.reward("dishes_taken","dishes"):s.journal.append("Грязная посуда собрана. Отнести её к кухонной стойке, затем поговорить с трактирщиком.")
            "deliver_dishes":
                if not s.has("dishes_taken") or not s.take("dishes"):return {"ok":false}
                s.mark("dishes_delivered","Посуда отнесена к стойке. Трактирщик обещал ночлег за работу.")
            "axe_found":
                if s.reward(a,"axe"):s.clue("resin","Чёрная смола на топоре Мирона. На обухе три зарубки.")
            "herbs_started":
                if not s.has("investigation"):return {"ok":false}
                s.mark(a)
            "valerian","thyme","poison":
                if not s.has("herbs_started") or s.has("herbs_done") or s.count(a)>0:return {"ok":false}
                s.give(a)
            "discard_poison":s.take("poison",s.count("poison"))
            "herbs_done":
                if s.has(a) or s.count("valerian")==0 or s.count("thyme")==0:return {"ok":false}
                s.take("valerian");s.take("thyme");s.reward(a,"tincture",2,"herbalist");s.give("root")
                s.clue("root_story","После контакта с корнями человек не узнавал семью. Смола встречалась под старой сосной.")
            "old_kindness":
                if s.mark(a):s.relate("old_man",1)
            "warning":
                if not s.has("herbs_done"):return {"ok":false}
                s.mark("old_met");s.mark(a);s.clue("ban","За северным оврагом запрещали рубить. Три зарубки обозначают границу.")
            "archive":
                s.mark("warning");s.mark(a);s.clue("archive","В описи: семья Саввы исчезла после зимней рубки. Ключ спрятан под половицами, шкаф заперт. Три зарубки — граница запретной вырубки.")
            "official_copy":
                if s.decisions.get("approach")!="elder":return {"ok":false}
                s.reward(a,"copy");s.clue(a,"В выданной старостой выписке зачёркнута строка о ночном свете. Семья запирала границу изнутри; ключ спрятан под половицами.")
            "pine_symbol":s.mark(a);s.clue(a,"Три старые зарубки на сосне повторяют знак с топора и пустого дома.")
            "tools","tracks","struggle","handle","cloth","vanishing":
                if s.mark(a):
                    var texts:Dictionary={"tools":"Уложенные инструменты: Мирон рассчитывал вернуться.","tracks":"Северный след уходит к деревьям с вывернутыми корнями.","struggle":"Под навесом следы борьбы. Крови нет, земля словно вздыбилась.","handle":"Рукоять инструмента сломана сильным скручивающим движением.","cloth":"Синий лён врос в корни. Ткань ещё влажная.","vanishing":"Человеческие следы обрываются у целого ствола. Обратной дорожки нет."}
                    s.clue(a,texts[a])
                    if a in ["cloth","handle"]:s.give(a)
            "toy_started":
                if s.reward(a,"toy"):s.relate("woodcutter_son",1)
            "wheel":
                if s.has("toy_started") and s.reward("wheel_found","wheel"):s.journal.append("Колесо найдено у колодца. На складе можно починить лошадку: иных материалов не нужно.")
            "repair":
                if s.count("toy")>0 and s.count("wheel")>0:
                    s.take("toy");s.take("wheel");s.give("fixed_toy")
                    s.journal.append("Лошадка починена. Осталось вернуть её сыну дровосека.")
                else:return {"ok":false}
            "toy_done":
                if s.count("fixed_toy")==0 or s.has(a):return {"ok":false}
                s.take("fixed_toy");s.reward(a,"",1,"woodcutter_son");s.relate("old_man",1)
                s.clue("boy_night","Мальчик видел Мирона лицом к стене пустого дома.")
            "collect_logs":
                if not s.has("wood_started"):return {"ok":false}
                if s.reward("logs_taken","logs",2):s.journal.append("Из дворовой поленницы взяты две связки дров. Отнести их к печи в доме дровосека.")
            "deliver_logs":
                if s.count("logs")<2:return {"ok":false}
                s.take("logs",2);s.mark("wood_delivered","Обе связки сложены у печи. Нужно сообщить жене дровосека.")
            "wood_done":
                if not s.has("wood_delivered") or not s.reward(a,"",1,"woodcutter_wife"):return {"ok":false}
                s.money+=2;s.clue("husband","Дровосек по ночам ждёт кого-то у северной тропы.")
            "take_mug":
                if s.has("mug_started") and s.reward("mug_taken","mug"):s.journal.append("На забытой кружке вырезана буква М. Показать её брату травницы.")
            "mug_owner":
                if s.count("mug")==0:return {"ok":false}
                s.mark(a);s.clue(a,"Кружка принадлежала Мирону: он не собирался уезжать.")
            "mug_done":
                if not s.has("mug_owner") or not s.reward(a,"bait",1,"innkeeper"):return {"ok":false}
                s.take("mug");s.money+=2
            "dry_take":
                if s.has("dry_started"):s.reward("dry_taken","dry")
            "dry_sort":
                if s.count("dry")==0:return {"ok":false}
                s.take("dry");s.mark("dry_sorted")
            "dry_done":
                if not s.has("dry_sorted"):return {"ok":false}
                s.reward(a,"tincture",1,"herbalist");s.clue("dry_resin","Чёрная смола появлялась в запасах ещё прошлой зимой.")
            "bait_received":s.reward(a,"bait")
            "bait":
                if not s.take("bait"):return {"ok":false}
                s.mark("wolves_clear","Волки ушли к приманке. Тропа свободна.");s.choose("wolves","bait")
            "bypass":s.mark("wolves_clear","Волчий дозор обойдён по западной кромке оврага.");s.choose("wolves","bypass")
            "floor_cache":
                if s.reward(a,"key"):s.clue(a,"Под половицами — ключ, свежая грязь и ещё тёплая смола.")
            "cabinet":
                if s.count("key")==0:return {"ok":false}
                if s.reward("diary_found","diary"):s.clue("diary","«Мы думали, что оно живёт в лесу. Но лес лишь держит его снаружи».")
            "tincture":
                if s.health>=108 or not s.take("tincture"):return {"ok":false}
                s.health=mini(108,s.health+30)
            _:s.mark(a)
    s._reconcile();s.changed.emit();return result
