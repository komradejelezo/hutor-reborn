"""Author nine role-based cyclic routines and first-meeting conversation graphs."""
from pathlib import Path
import json

P=Path(__file__).resolve().parents[1]
OUT=P/'assets/npc/stage43'
def step(label,point,action='REST',duration=3,facing='down',animation='',partner=''):
 return {'label':label,'position':point,'action':action,'duration':duration,'facing':facing,'animation':animation,'look_at_npc':partner}
roster=[
 {'id':'elder','name':'Староста','behavior':'PATROL','speed':30,'spawn':[936,805],'routine':[
  step('У своего дома',[936,805],'HOME',7),step('Осмотреть двор',[936,920],'WALK',3,'right'),step('Верхняя дорога',[1390,920],'MOVE',.5),step('Центральная дорога',[1440,1370],'MOVE',.5),step('Осмотреть площадь',[1378,1442],'REST',7,'left'),step('Возвращение во двор',[936,920],'MOVE',.5)]},
 {'id':'innkeeper','name':'Трактирщик','behavior':'WORKER','speed':28,'spawn':[1688,2325],'routine':[
  step('Вход в трактир',[1688,2248],'HOME',5),step('Проверить бочки',[1860,2320],'WORK',7,'down','work_wipe'),step('Коновязь',[1490,2360],'WALK',5,'left'),step('Перед трактиром',[1688,2325],'REST',4)]},
 {'id':'innkeeper_wife','name':'Жена трактирщика','behavior':'WORKER','speed':34,'spawn':[1830,2410],'routine':[
  step('У входа',[1748,2250],'HOME',4),step('Хозяйственный двор',[1990,2355],'WORK',8,'left','work_sweep'),step('Припасы',[1900,2405],'REST',4,'up'),step('Перед трактиром',[1780,2375],'WALK',2,'left')]},
 {'id':'woodcutter','name':'Дровосек','behavior':'WORKER','speed':36,'spawn':[1713,810],'routine':[
  step('У своего дома',[1713,810],'HOME',5),step('Дорога к лесу',[1905,925],'MOVE',.5),step('Разрешённое место рубки',[2080,980],'WORK',12,'right','work_chop'),step('Привал у опушки',[1960,955],'REST',4,'left')]},
 {'id':'woodcutter_wife','name':'Жена дровосека','behavior':'WORKER','speed':32,'spawn':[1770,870],'routine':[
  step('Домашние дела',[1770,870],'HOME',4),step('Подмести у поленницы',[1800,850],'WORK',7,'right','work_sweep'),step('Поговорить с сыном',[1745,895],'TALK',4,'left',partner='woodcutter_son'),step('Отдохнуть во дворе',[1640,875],'REST',4)]},
 {'id':'woodcutter_son','name':'Сын дровосека','behavior':'CHILD','speed':62,'spawn':[1680,840],'radius':4,'bounds':[1540,740,380,210],'notices_player':True,'routine':[
  step('У дома',[1713,825],'HOME',1),step('Игра во дворе',[1685,895],'REST',4,'down','work_play'),step('Пробежка',[1770,910],'WALK',.7,'left'),step('Рядом с матерью',[1745,865],'TALK',2,'down',partner='woodcutter_wife'),step('Обратно во двор',[1640,840],'WALK',1)]},
 {'id':'herbalist','name':'Травница','behavior':'WORKER','speed':29,'spawn':[1717,1660],'routine':[
  step('У ветхого дома',[1717,1660],'HOME',6),step('Лекарственные грядки',[1910,1660],'WORK',7,'right','work_gather'),step('Тропа к опушке',[2010,1730],'MOVE',1),step('Собрать травы у леса',[2150,1720],'WORK',10,'right','work_gather')]},
 {'id':'herbalist_brother','name':'Брат травницы','behavior':'WORKER','speed':37,'spawn':[1760,1670],'routine':[
  step('Общий с сестрой дом',[1760,1670],'HOME',5),step('Дорога к лесной работе',[1800,1300],'MOVE',1),step('Работа у восточной опушки',[2145,1285],'WORK',12,'right','work_chop'),step('Возвращение по тропе',[1800,1300],'MOVE',1)]},
 {'id':'old_man','name':'Старик с трубкой','behavior':'ELDER','speed':18,'spawn':[555,945],'bounds':[410,890,310,170],'pipe_smoke':True,'routine':[
  step('У Кривой сосны',[560,917],'REST',9,'right','work_smoke'),step('Медленная прогулка',[650,952],'WALK',3,'left'),step('Покурить у тропы',[630,1010],'REST',10,'left','work_smoke'),step('Рядом с корнями',[560,980],'WALK',2),step('Короткий отдых',[550,945],'REST',5,'right','work_smoke')]},
]
conversations={
 'elder':('Я за хутор отвечаю. Ты к кому, путник?',
  [('Нужен ночлег.','За воротами, у дороги, наш трактир. С хозяином и потолкуй.','neutral'),('Хочу осмотреться.','По тропам ходи, дворы людям оставь. Мы к чужим сперва присматриваемся.','displeased')],
  'Пока ты у нас — живи с людьми в ладу.'),
 'innkeeper':('Дорога пылью кормит, а добрый очаг — теплом. Чего ищешь, гость?',
  [('Здесь часто бывают путники?','Бывают. Один больше молчит, другой всё о себе расскажет. Я обоим рад.','joy'),('Что слышно в хуторе?','Живём понемногу. Кто дрова считает, кто припасы. Молва обычно быстрее дела.','neutral')],
  'Будешь проходить — заглядывай. Разговор дорогу короче делает.'),
 'innkeeper_wife':('Чужака по сапогам видно. Долго тебя дорога водила?',
  [('Всякое бывало в пути.','И у нас всякое бывает, только мы сперва друг друга слушаем.','neutral'),('У вас тихое место.','Тихое — не значит пустое. На девять человек забот хватает.','joy')],
  'Проходи осторожно, во дворе утварь стоит.'),
 'woodcutter':('Шаг в сторону, путник. Щепа летит.',
  [('Давно работаешь в этих местах?','Достаточно, чтобы знать: дерево сперва слушают, потом берутся за топор.','neutral'),('Не мешаю?','Сейчас нет. Закончу дело — вернусь к своим.','neutral')],
  'Держись тропы. Так всем спокойнее.'),
 'woodcutter_wife':('Столько дел, что день короток. А ты с дороги?',
  [('Да, только пришёл.','Тогда сперва отдышись. На усталую голову всё труднее.','anxious'),('Сын у тебя бойкий.','Любопытный. Пока возле дома бегает — мне спокойнее.','joy')],
  'Ладно, заговорилась я. Хозяйство не ждёт.'),
 'woodcutter_son':('Ты дальше нашего леса бывал? Я пока только возле дома хожу.',
  [('Бывал, дорога длинная.','Вот вырасту — тоже погляжу. Мама говорит, сперва свои тропки запомни.','joy'),('А что тебе здесь нравится?','Смотреть, кто по дороге идёт. И палкой по земле рисовать.','joy')],
  'Я тут ещё побегаю. Далеко мне не велят.'),
 'herbalist':('На посадки не наступай. Молодой росток не сразу заметишь.',
  [('Ты знаешь местные растения?','Те, что рядом растут. С незнакомой травой я и сама осторожна.','neutral'),('Можно посмотреть на грядки?','С тропинки смотри. Пусть растения спокойно принимаются.','anxious')],
  'Не всякую траву в руки брать стоит. Помни это.'),
 'herbalist_brother':('Если к сестре — она неподалёку. Я к работе иду.',
  [('Вы вместе здесь живёте?','Вместе. Дом старый, работы с ним хватает.','neutral'),('В лесу сейчас спокойно?','На рабочей опушке привычно. Глубже мне без дела ходить незачем.','anxious')],
  'Мне пора. Ступай по дороге.'),
 'old_man':('Сосна скрипит, а люди всё спешат. Присядешь словом, путник?',
  [('Что о ней рассказывают?','Всякий своё. Я пока слушаю и дерево, и людей. Не всему сразу верить надо.','neutral'),('Ты давно здесь живёшь?','Давно. Только по одному разговору всей жизни не узнаешь.','joy')],
  'Будет случай — ещё потолкуем. Сейчас дай старику трубку докурить.'),
}
for resident in roster:
 role=resident['id'];greeting,branches,closing=conversations[role]
 resident['dialogue_path']='res://dialogues/residents/'+role+'.json'
 resident['dialogue_id']='resident_'+role
 portraits={emotion:'res://assets/npc/stage43/'+role+'/portraits/'+emotion+'.png' for emotion in ['neutral','joy','displeased','anxious']}
 def line(id,text,emotion='neutral',**fields):
  return {'id':id,'speaker':resident['name'],'portrait':'','emotion':emotion,'portraits':portraits,'text':text,**fields}
 nodes=[line('greeting',greeting,choices=[{'id':'answer_'+str(i+1),'text':option,'next':'reply_'+str(i+1)} for i,(option,reply,emotion) in enumerate(branches)])]
 nodes += [line('reply_'+str(i+1),reply,emotion,next='closing') for i,(option,reply,emotion) in enumerate(branches)]
 nodes.append(line('closing',closing,end=True))
 (P/'dialogues/residents'/(role+'.json')).write_text(json.dumps({'id':resident['dialogue_id'],'start':'greeting','nodes':nodes},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
(OUT/'roster.json').write_text(json.dumps(roster,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('Prepared nine cyclic routines and nine independent first conversations; no quests or final biographies')
