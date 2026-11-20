# Ганс: Dodge — материалы перед художественной реставрацией

Основа: `main` **6ef9994**, после объединённого PR №42. Сравнение с подготовленными PNG **ce7e706**, до PR №42. Все 12 кадров анимации присутствуют, исходные и игровые номера совпадают.

**Этот PR содержит только диагностику. Игровые PNG, исходники, SpriteFrames, FPS, размеры, origin, эффекты и механики не изменены. Маски не являются утверждением новой геометрии или разрешением на заливку.**

## Просмотр

Открывать PNG в масштабе 100% или увеличивать целочисленно с Nearest. Уменьшенное превью GitHub не показывает все исходные пиксели; скачайте изображение для художественной работы.

| Материал | Что показано |
|---|---|
| [АТЛАС №1 — все кадры](ATLAS_ALL_FRAMES.png) | Все 12 поз по порядку; целые холсты 357×358 на белом, ярко-розовом и чёрном, 1:1. Метка исходной опоры поверх изображения. |
| [АТЛАС №2 — повреждения](ATLAS_DAMAGE.png) | Оригинал и текущий игровой PNG; корпус, колено и дальнее бедро при 4× Nearest. Продолжение: [страница 2](pages/ATLAS_DAMAGE_02.png), [страница 3](pages/ATLAS_DAMAGE_03.png). |
| [АТЛАС №3 — до/после](ATLAS_BEFORE_AFTER.png) | Старый prepared против текущего prepared; точная разница PR №42 и отдельные остаточные/подозрительные маски. Продолжение: [2](pages/ATLAS_BEFORE_AFTER_02.png), [3](pages/ATLAS_BEFORE_AFTER_03.png), [4](pages/ATLAS_BEFORE_AFTER_04.png). |
| [АТЛАС №4 — маски](ATLAS_MASKS.png) | Красный: остаток в ранее проверенном ядре; оранжевый: подозрение; голубой: естественный воздух; зелёный: рваный край. Исходный размер — `masks/dodge_01.png` … `dodge_12.png`. |
| [Эталон Hans Idle v2 Stabilized](HANS_IDLE_REFERENCE.png) | Три утверждённых позы покоя при 2× Nearest. Лицо, одежда, цвета, снаряжение; не подмена движения Dodge. |
| [Покадровый отчёт](FRAME_REPORT.md), [JSON](FRAME_REPORT.json) | Пути/SHA, номера, origin, точные полигоны/окна, прежние правки и доноры, остаток alpha/RGB, уверенность, следующий шаг. |
| [Видео MP4](DODGE_COMPARISON.mp4) | Реальное окно существующей CombatGraphicsLab. Слева до PR №42, справа текущие PNG; белый/розовый, ×0,5 и ×1, два полных Dodge и возврата в Idle на каждое условие. |
| Снимки Godot: [белый](godot/ФОН_БЕЛЫЙ.png), [розовый](godot/ФОН_РОЗОВЫЙ.png), [чёрный](godot/ФОН_ЧЁРНЫЙ.png) | Свежая фиксация всех 12 пар, настоящий игровой материал, масштаб и опора; без изменения сцены лаборатории. |

## Координаты и диагноз

Начало `(0,0)` — верхний левый угол исходного PNG, x вправо, y вниз. Все диагностические маски имеют ровно **357×358** и накладываются без сдвига. Окна `[x0,y0,x1,y1)` исключают правую/нижнюю границу. Полигон ядра сужается крестом на 3 пикселя. Отмечаются только пиксели `alpha <128` внутри выбранных областей. Прозрачность вне масок означает **«диагноз не задан»**, а не «исправно».

В прежних проверенных ядрах остаётся **782** прозрачных пикселя; у них нулевой исходный RGB. Это не площадь всех повреждений модели. Более широкие спорные окна Б/Л показаны отдельно: подмышка, разрывы около бедра, край полы. Не весь этот воздух — потерянная ткань. В кадрах 02, 03, 09 ноль подтверждённых остаточных пикселей **в выбранных ядрах** не означает художественного одобрения всего кадра.

PR №42 ранее изменил **1 614** пикселей именно Dodge. Новых пиксельных правок в этом этапе нет. Все перенесённые ранее участки видны в бирюзовой разнице, а происхождение указано по кадрам. Для остатка не подтверждён надёжный полный донор. Художник должен сначала утвердить границу ткани; автоматическое заполнение нулевого RGB чёрным не выполняется.

Сырой исходник местами выглядит как контурный рисунок из-за уже повреждённой alpha. В первых позах также видна чёрная строка подложки. Это реальное содержимое исходника, а не эффект атласа. В отчёте отдельно учтены контакты с краями холста: они требуют осмотра, но не доказывают обрезание конечностей.

## Исходные PNG без ненужных копий

Оригиналы и текущие PNG уже хранятся в проекте, поэтому здесь не дублируются. До-версии доступны из Git по зафиксированному коммиту; ссылки ниже открывают сами PNG.

| Кадр | Оригинал | До PR №42 | Текущий |
|---|---|---|---|
| 01 | [PNG](../../HutorReborn/assets/combat/forest_v2/assets/Hans/Dodge/dodge_01.png) | [PNG до](https://raw.githubusercontent.com/komradejelezo/hutor-reborn/ce7e70600d10f2d534ea539090da2c8bf68d46b6/HutorReborn/assets/combat/forest_v2/prepared/Hans/Dodge/dodge_01.png) | [PNG сейчас](../../HutorReborn/assets/combat/forest_v2/prepared/Hans/Dodge/dodge_01.png) |
| 02 | [PNG](../../HutorReborn/assets/combat/forest_v2/assets/Hans/Dodge/dodge_02.png) | [PNG до](https://raw.githubusercontent.com/komradejelezo/hutor-reborn/ce7e70600d10f2d534ea539090da2c8bf68d46b6/HutorReborn/assets/combat/forest_v2/prepared/Hans/Dodge/dodge_02.png) | [PNG сейчас](../../HutorReborn/assets/combat/forest_v2/prepared/Hans/Dodge/dodge_02.png) |
| 03 | [PNG](../../HutorReborn/assets/combat/forest_v2/assets/Hans/Dodge/dodge_03.png) | [PNG до](https://raw.githubusercontent.com/komradejelezo/hutor-reborn/ce7e70600d10f2d534ea539090da2c8bf68d46b6/HutorReborn/assets/combat/forest_v2/prepared/Hans/Dodge/dodge_03.png) | [PNG сейчас](../../HutorReborn/assets/combat/forest_v2/prepared/Hans/Dodge/dodge_03.png) |
| 04 | [PNG](../../HutorReborn/assets/combat/forest_v2/assets/Hans/Dodge/dodge_04.png) | [PNG до](https://raw.githubusercontent.com/komradejelezo/hutor-reborn/ce7e70600d10f2d534ea539090da2c8bf68d46b6/HutorReborn/assets/combat/forest_v2/prepared/Hans/Dodge/dodge_04.png) | [PNG сейчас](../../HutorReborn/assets/combat/forest_v2/prepared/Hans/Dodge/dodge_04.png) |
| 05 | [PNG](../../HutorReborn/assets/combat/forest_v2/assets/Hans/Dodge/dodge_05.png) | [PNG до](https://raw.githubusercontent.com/komradejelezo/hutor-reborn/ce7e70600d10f2d534ea539090da2c8bf68d46b6/HutorReborn/assets/combat/forest_v2/prepared/Hans/Dodge/dodge_05.png) | [PNG сейчас](../../HutorReborn/assets/combat/forest_v2/prepared/Hans/Dodge/dodge_05.png) |
| 06 | [PNG](../../HutorReborn/assets/combat/forest_v2/assets/Hans/Dodge/dodge_06.png) | [PNG до](https://raw.githubusercontent.com/komradejelezo/hutor-reborn/ce7e70600d10f2d534ea539090da2c8bf68d46b6/HutorReborn/assets/combat/forest_v2/prepared/Hans/Dodge/dodge_06.png) | [PNG сейчас](../../HutorReborn/assets/combat/forest_v2/prepared/Hans/Dodge/dodge_06.png) |
| 07 | [PNG](../../HutorReborn/assets/combat/forest_v2/assets/Hans/Dodge/dodge_07.png) | [PNG до](https://raw.githubusercontent.com/komradejelezo/hutor-reborn/ce7e70600d10f2d534ea539090da2c8bf68d46b6/HutorReborn/assets/combat/forest_v2/prepared/Hans/Dodge/dodge_07.png) | [PNG сейчас](../../HutorReborn/assets/combat/forest_v2/prepared/Hans/Dodge/dodge_07.png) |
| 08 | [PNG](../../HutorReborn/assets/combat/forest_v2/assets/Hans/Dodge/dodge_08.png) | [PNG до](https://raw.githubusercontent.com/komradejelezo/hutor-reborn/ce7e70600d10f2d534ea539090da2c8bf68d46b6/HutorReborn/assets/combat/forest_v2/prepared/Hans/Dodge/dodge_08.png) | [PNG сейчас](../../HutorReborn/assets/combat/forest_v2/prepared/Hans/Dodge/dodge_08.png) |
| 09 | [PNG](../../HutorReborn/assets/combat/forest_v2/assets/Hans/Dodge/dodge_09.png) | [PNG до](https://raw.githubusercontent.com/komradejelezo/hutor-reborn/ce7e70600d10f2d534ea539090da2c8bf68d46b6/HutorReborn/assets/combat/forest_v2/prepared/Hans/Dodge/dodge_09.png) | [PNG сейчас](../../HutorReborn/assets/combat/forest_v2/prepared/Hans/Dodge/dodge_09.png) |
| 10 | [PNG](../../HutorReborn/assets/combat/forest_v2/assets/Hans/Dodge/dodge_10.png) | [PNG до](https://raw.githubusercontent.com/komradejelezo/hutor-reborn/ce7e70600d10f2d534ea539090da2c8bf68d46b6/HutorReborn/assets/combat/forest_v2/prepared/Hans/Dodge/dodge_10.png) | [PNG сейчас](../../HutorReborn/assets/combat/forest_v2/prepared/Hans/Dodge/dodge_10.png) |
| 11 | [PNG](../../HutorReborn/assets/combat/forest_v2/assets/Hans/Dodge/dodge_11.png) | [PNG до](https://raw.githubusercontent.com/komradejelezo/hutor-reborn/ce7e70600d10f2d534ea539090da2c8bf68d46b6/HutorReborn/assets/combat/forest_v2/prepared/Hans/Dodge/dodge_11.png) | [PNG сейчас](../../HutorReborn/assets/combat/forest_v2/prepared/Hans/Dodge/dodge_11.png) |
| 12 | [PNG](../../HutorReborn/assets/combat/forest_v2/assets/Hans/Dodge/dodge_12.png) | [PNG до](https://raw.githubusercontent.com/komradejelezo/hutor-reborn/ce7e70600d10f2d534ea539090da2c8bf68d46b6/HutorReborn/assets/combat/forest_v2/prepared/Hans/Dodge/dodge_12.png) | [PNG сейчас](../../HutorReborn/assets/combat/forest_v2/prepared/Hans/Dodge/dodge_12.png) |

## Что фактически проверено

- Официальный **Godot 4.6.2**, Linux/X11, Mesa llvmpipe. Существующая CombatGraphicsLab: **105 проверок, 0 ошибок**, [журнал](GODOT_CHECK.log). Обычное предупреждение о V-Sync относится к программному драйверу.
- Все 12 кадров на белом/розовом/чёрном; восемь проигрываний Dodge, посещение всех кадров и возврат обеих моделей в Idle: [таймлайн](MOTION_TIMELINE.json). Контроллер возвращает Idle к ×1; это существующее поведение.
- Независимая проверка фактических SpriteFrames, всех SHA/размеров/origin, координат 12 масок, точной разницы PNG, всех 36 увеличений без размытия, ссылок и неизменности **всего `HutorReborn/`**: [результат](VERIFICATION.json), [журнал](VERIFY.log).
- MP4 декодирован обратно и сопоставлен с реальными статическими кадрами Godot: [проверка содержимого видео](VIDEO_REVIEW.json). Все 12 поз доступны в записи на обоих фонах. Это проверка покрытия, а не доказательство анатомической правильности.

Видео H.264/yuv420p удобно скачивать и воспроизводить обычным плеером. Такое сжатие меняет цвет резких розовых краёв; **для точных RGB/alpha используйте PNG**, а не снимок MP4. Интерполяция движения не использовалась. [Метаданные записи](VIDEO_CAPTURE.json) включают счётчик отставаний от накопленного таймера захвата; он не равен числу потерянных игровых кадров. Наличие каждой позы дополнительно проверено в декодированном файле.

Windows и аппаратный GPU здесь не проверялись. Новый прогон квестов, боевой математики и всей деревни не выполнялся: игровые файлы не менялись. Перед реставрацией нужна художественная оценка спорных контуров, затем проверка будущих правок в полном цикле, включая 03→04, 05→06, 09→10 и возврат в Idle.

## Воспроизведение диагностики

Все вспомогательные файлы находятся в этой папке, вне игрового проекта. Они не являются новой сценой/системой игры и не подключены к меню или автозагрузке.

1. Из Git `ce7e706` выгрузить 12 старых `prepared/Hans/Dodge/dodge_NN.png` во временную папку с теми же относительными путями.
2. Для графического запуска задать `DODGE_REVIEW_BASELINE` (временная папка), `DODGE_REVIEW_OUT` (новая пустая папка захватов, без старых `ready`/`done`); запустить Godot с `--path HutorReborn --script /абсолютный/путь/capture_lab.gd`. Скрипт открывает прежнюю лабораторию, заменяет только временные текстуры левого просмотра и завершает работу. Для MP4 одновременно запустить `record_lab.py --capture-dir ... --output .../DODGE_COMPARISON.mp4 --display ...`.
3. `python deliverables/hans-dodge-restoration-review/build_review.py --captures /папка/захватов` создаёт атласы/отчёт, читая игровые ресурсы. При отличии игровых файлов от указанной main сборка останавливается.
4. Сохранить `godot.log` как `GODOT_CHECK.log`, `timeline.json` как `MOTION_TIMELINE.json`. Затем выполнить `verify_review.py` и `verify_video.py` из этой папки.

Генератор и проверки используют Python, Pillow, numpy и scipy; видео — FFmpeg. В репозитории нет временных профилей Godot, старых экспортированных PNG, маркеров готовности, промежуточных кадров записи или кешей. PR не объединяется автоматически.
