#!/usr/bin/env python3
"""Native App Store copy for all 50 ASC locales (Sober). Source of truth for true multi-language."""
from __future__ import annotations

# name ≤30, subtitle ≤30, keywords ≤100 (comma, no spaces)

EN_DESCRIPTION = """Sober Tracker helps you stay alcohol free with a clear day counter, daily check-in, and a virtual garden that grows with every sober day.

FREE TO START
• Alcohol-free day counter — see days, hours, and your longest streak
• Daily check-in — one tap to log how today feels
• Sobriety calendar — sober days at a glance
• Virtual garden — watch your progress bloom
• Private on your device — no account required

BLOOM+ (OPTIONAL)
• Full health benefits timeline with sources
• Journal with prompts
• Achievements and milestones
• Money and calories saved
• More garden species
• Apple Watch companion and home-screen widgets

Whether you are quitting drinking, cutting back, or building dry days, Sober Tracker keeps recovery simple: count sober time, check in, and grow your garden.

Download free. Upgrade to Bloom+ anytime."""

LOCALES: dict[str, dict[str, str]] = {
    "en-US": {
        "name": "Sober Tracker - Alcohol Free",
        "subtitle": "Dry Days: Sobriety Counter",
        "keywords": "drink,less,quit,stop,recovery,sobriety,addiction,relapse,cravings,mood,streak,abstinence,daily,clean",
        "description": EN_DESCRIPTION,
    },
    "en-GB": {
        "name": "Sober Tracker - Alcohol Free",
        "subtitle": "Dry Days: Sobriety Counter",
        "keywords": "drink,less,quit,stop,recovery,sobriety,addiction,relapse,cravings,mood,streak,abstinence,daily,clean",
        "description": EN_DESCRIPTION.replace("cutting back", "cutting down"),
    },
    "en-AU": {
        "name": "Sober Tracker - Alcohol Free",
        "subtitle": "Dry Days: Sobriety Counter",
        "keywords": "drink,less,quit,stop,recovery,sobriety,addiction,relapse,cravings,mood,streak,abstinence,daily,clean",
        "description": EN_DESCRIPTION,
    },
    "en-CA": {
        "name": "Sober Tracker - Alcohol Free",
        "subtitle": "Dry Days: Sobriety Counter",
        "keywords": "drink,less,quit,stop,recovery,sobriety,addiction,relapse,cravings,mood,streak,abstinence,daily,clean",
        "description": EN_DESCRIPTION,
    },
    "de-DE": {
        "name": "Sober: Alkoholfrei Tracker",
        "subtitle": "Trockene Tage & Garten",
        "keywords": "trinken,weniger,aufhören,entzug,nüchtern,sucht,erholung,serie,abstinenz,rückfall,stimmung,streak",
        "description": """Sober Tracker hilft dir, alkoholfrei zu bleiben – mit Tageszähler, täglichem Check-in und einem virtuellen Garten, der mit jedem nüchternen Tag wächst.

KOSTENLOS STARTEN
• Alkoholfreier Tageszähler – Tage, Stunden und längste Serie
• Täglicher Check-in – ein Tippen für deinen Tag
• Nüchternheitskalender – nüchterne Tage auf einen Blick
• Virtueller Garten – sieh deinen Fortschritt wachsen
• Privat auf dem Gerät – kein Konto nötig

BLOOM+ (OPTIONAL)
• Gesundheits-Timeline mit Quellen
• Tagebuch mit Impulsen
• Erfolge und Meilensteine
• Geld und Kalorien gespart
• Mehr Gartenarten
• Apple Watch & Widgets

Ob du aufhörst zu trinken, weniger trinkst oder trockene Tage sammelst: Sober Tracker macht es einfach.

Kostenlos laden. Bloom+ jederzeit upgraden.""",
    },
    "fr-FR": {
        "name": "Sober – Sans alcool",
        "subtitle": "Jours secs & jardin",
        "keywords": "boire,moins,arrêter,sevrage,abstinence,sevrer,sevrage,envie,rétablissement,dépendance,humeur",
        "description": """Sober Tracker vous aide à rester sobre avec un compteur de jours, un check-in quotidien et un jardin virtuel qui grandit à chaque jour sans alcool.

GRATUIT POUR COMMENCER
• Compteur de jours sans alcool – jours, heures et plus longue série
• Check-in quotidien – une touche pour noter votre journée
• Calendrier de sobriété – vos jours sobres en un coup d'œil
• Jardin virtuel – voyez vos progrès fleurir
• Privé sur l'appareil – aucun compte requis

BLOOM+ (OPTIONNEL)
• Timeline santé complète avec sources
• Journal avec suggestions
• Succès et jalons
• Argent et calories économisés
• Plus d'espèces au jardin
• Apple Watch et widgets

Que vous arrêtiez de boire, réduisiez ou accumuliez des jours secs, Sober Tracker simplifie la reprise.

Téléchargement gratuit. Passez à Bloom+ quand vous voulez.""",
    },
    "fr-CA": {
        "name": "Sober – Sans alcool",
        "subtitle": "Jours secs et jardin",
        "keywords": "boire,moins,arrêter,sevrage,abstinence,rétablissement,envie,sevrer,dépendance,humeur,rechute",
        "description": """Sober Tracker vous aide à rester sobre avec un compteur de jours, un check-in quotidien et un jardin virtuel qui grandit à chaque jour sans alcool.

GRATUIT
• Compteur de jours sans alcool
• Check-in quotidien
• Calendrier de sobriété
• Jardin virtuel
• Privé sur l'appareil – aucun compte

BLOOM+ (OPTIONNEL)
• Timeline santé, journal, succès
• Économies et plus d'espèces au jardin
• Apple Watch et widgets

Téléchargement gratuit. Bloom+ en tout temps.""",
    },
    "es-ES": {
        "name": "Sober – Sin alcohol",
        "subtitle": "Días secos y jardín",
        "keywords": "beber,menos,dejar,adicción,antojo,abstinencia,recuperación,sobriedad,recaída,humor,raya",
        "description": """Sober Tracker te ayuda a mantenerte sobrio con contador de días, check-in diario y un jardín virtual que crece con cada día sin alcohol.

GRATIS PARA EMPEZAR
• Contador de días sin alcohol – días, horas y racha más larga
• Check-in diario – un toque para registrar el día
• Calendario de sobriedad – días sobrios de un vistazo
• Jardín virtual – mira crecer tu progreso
• Privado en el dispositivo – sin cuenta

BLOOM+ (OPCIONAL)
• Línea de salud completa con fuentes
• Diario con sugerencias
• Logros e hitos
• Dinero y calorías ahorrados
• Más especies en el jardín
• Apple Watch y widgets

Deja de beber, reduce o suma días secos: Sober Tracker lo hace simple.

Descarga gratis. Mejora a Bloom+ cuando quieras.""",
    },
    "es-MX": {
        "name": "Sober – Sin alcohol",
        "subtitle": "Días secos y jardín",
        "keywords": "beber,menos,dejar,adicción,antojo,abstinencia,recuperación,sobriedad,recaída,humor,raya",
        "description": """Sober Tracker te ayuda a mantenerte sobrio con contador de días, check-in diario y un jardín virtual que crece cada día sin alcohol.

GRATIS
• Contador de días sin alcohol
• Check-in diario
• Calendario de sobriedad
• Jardín virtual
• Privado – sin cuenta

BLOOM+ (OPCIONAL)
• Salud, diario, logros, ahorros
• Más jardín, Apple Watch y widgets

Descarga gratis. Bloom+ cuando quieras.""",
    },
    "ca": {
        "name": "Sober – Sense alcohol",
        "subtitle": "Dies secs i jardí",
        "keywords": "beure,menys,deixar,addicció,abstinència,recuperació,recaiguda,desig,humor,ratxa",
        "description": """Sober Tracker t'ajuda a mantenir-te sobri amb comptador de dies, check-in diari i un jardí virtual que creix cada dia sense alcohol.

GRATUÏT
• Comptador de dies sense alcohol
• Check-in diari i calendari de sobrietat
• Jardí virtual
• Privat al dispositiu

BLOOM+ (OPCIONAL)
• Salut, diari, assoliments, estalvis
• Apple Watch i widgets

Descarrega gratuïta. Bloom+ quan vulguis.""",
    },
    "it": {
        "name": "Sober – Senza alcol",
        "subtitle": "Giorni secchi: contatore",
        "keywords": "bere,meno,smettere,astinenza,dipendenza,recupero,ricaduta,voglia,craving,umore,sbronzo",
        "description": """Sober Tracker ti aiuta a restare sobrio con contatore dei giorni, check-in quotidiano e un giardino virtuale che cresce a ogni giorno senza alcol.

GRATIS
• Contatore giorni senza alcol – giorni, ore e serie più lunga
• Check-in quotidiano
• Calendario della sobrietà
• Giardino virtuale
• Privato sul dispositivo – nessun account

BLOOM+ (OPZIONALE)
• Timeline salute con fonti
• Diario con spunti
• Traguardi e risparmi
• Apple Watch e widget

Smetti di bere o accumula giorni secchi: Sober Tracker semplifica il percorso.

Download gratuito. Bloom+ quando vuoi.""",
    },
    "pt-BR": {
        "name": "Sober – Sem Álcool",
        "subtitle": "Dias secos e jardim",
        "keywords": "beber,menos,parar,dependência,abstinência,recuperação,recaída,vontade,humor,tarja",
        "description": """O Sober Tracker ajuda você a ficar sóbrio com contador de dias, check-in diário e um jardim virtual que cresce a cada dia sem álcool.

GRÁTIS
• Contador de dias sem álcool – dias, horas e maior sequência
• Check-in diário
• Calendário de sobriedade
• Jardim virtual
• Privado no dispositivo – sem conta

BLOOM+ (OPCIONAL)
• Linha do tempo de saúde
• Diário com prompts
• Conquistas e economia
• Apple Watch e widgets

Pare de beber ou some dias secos: o Sober Tracker simplifica.

Download grátis. Bloom+ quando quiser.""",
    },
    "pt-PT": {
        "name": "Sober – Sem Álcool",
        "subtitle": "Dias secos e jardim",
        "keywords": "beber,menos,parar,dependência,abstinência,recuperação,recaída,vontade,humor,tarja",
        "description": """O Sober Tracker ajuda-o a manter-se sóbrio com contador de dias, check-in diário e um jardim virtual que cresce em cada dia sem álcool.

GRÁTIS
• Contador de dias sem álcool
• Check-in diário e calendário
• Jardim virtual
• Privado no dispositivo

BLOOM+ (OPCIONAL)
• Saúde, diário, conquistas
• Apple Watch e widgets

Transferência gratuita. Bloom+ quando quiser.""",
    },
    "nl-NL": {
        "name": "Sober – Alcoholvrij",
        "subtitle": "Droge dagen en tuin",
        "keywords": "stoppen,minder,drinken,verslaving,ontwenning,nuchter,herstel,terugval,verlangen,stemming,streak",
        "description": """Sober Tracker helpt je alcoholvrij te blijven met een dagteller, dagelijkse check-in en een virtuele tuin die groeit bij elke nuchtere dag.

GRATIS
• Alcoholvrije dagteller – dagen, uren en langste reeks
• Dagelijkse check-in
• Nuchterheidskalender
• Virtuele tuin
• Privé op je apparaat – geen account

BLOOM+ (OPTIONEEL)
• Gezondheidstijdlijn, dagboek, prestaties
• Apple Watch en widgets

Gratis downloaden. Bloom+ wanneer je wilt.""",
    },
    "pl": {
        "name": "Sober – Bez alkoholu",
        "subtitle": "Suche dni i ogród",
        "keywords": "pić,mniej,przestać,uzależnienie,abstynencja,odwyk,nawrót,głód,nastrój,pasmo",
        "description": """Sober Tracker pomaga pozostać trzeźwym dzięki licznikowi dni, codziennemu check-inowi i wirtualnemu ogrodowi rosnącemu z każdym dniem bez alkoholu.

ZA DARMO
• Licznik dni bez alkoholu
• Codzienny check-in
• Kalendarz trzeźwości
• Wirtualny ogród
• Prywatnie na urządzeniu – bez konta

BLOOM+ (OPCJONALNIE)
• Oś czasu zdrowia, dziennik, osiągnięcia
• Apple Watch i widżety

Pobierz za darmo. Bloom+ w dowolnym momencie.""",
    },
    "sv": {
        "name": "Sober – Alkoholfri",
        "subtitle": "Torra dagar och trädgård",
        "keywords": "dricka,mindre,sluta,beroende,abstinens,återhämtning,återfall,sug,humör,streak",
        "description": """Sober Tracker hjälper dig att hålla dig alkoholfri med dagräknare, daglig check-in och en virtuell trädgård som växer för varje nykter dag.

GRATIS
• Alkoholfri dagräknare
• Daglig check-in och nykterhetskalender
• Virtuell trädgård
• Privat på enheten

BLOOM+ (VALFRITT)
• Hälsotidslinje, dagbok, prestationer
• Apple Watch och widgetar

Ladda ner gratis. Bloom+ när du vill.""",
    },
    "da": {
        "name": "Sober – Alkoholfri",
        "subtitle": "Tørre dage og have",
        "keywords": "drikke,mindre,stoppe,afhængighed,afholdenhed,bedring,tilbagefald,trang,humør,stribe",
        "description": """Sober Tracker hjælper dig med at forblive alkoholfri med dagtæller, daglig check-in og en virtuel have, der vokser for hver ædru dag.

GRATIS
• Alkoholfri dagtæller
• Daglig check-in og ædrukalender
• Virtuel have
• Privat på enheden

BLOOM+ (VALGFRIT)
• Sundhedstidslinje, dagbog, præstationer
• Apple Watch og widgets

Gratis download. Bloom+ når du vil.""",
    },
    "no": {
        "name": "Sober – Alkoholfri",
        "subtitle": "Tørre dager og hage",
        "keywords": "drikke,mindre,slutte,avhengighet,avholdenhet,bedring,tilbakefall,sug,humør,streak",
        "description": """Sober Tracker hjelper deg å holde deg alkoholfri med dagteller, daglig innsjekk og en virtuell hage som vokser for hver edru dag.

GRATIS
• Alkoholfri dagteller
• Daglig innsjekk og edrukalender
• Virtuell hage
• Privat på enheten

BLOOM+ (VALGFRITT)
• Helsetidslinje, dagbok, prestasjoner
• Apple Watch og widgeter

Last ned gratis. Bloom+ når du vil.""",
    },
    "fi": {
        "name": "Sober – Alkoholiton",
        "subtitle": "Kuivat päivät ja puutarha",
        "keywords": "juoda,vähemmän,lopettaa,riippuvuus,raittius,toipuminen,retkahdus,himo,mieli,pätkä",
        "description": """Sober Tracker auttaa pysymään alkoholittomana päivälaskurilla, päivittäisellä kirjauksella ja virtuaalisella puutarhalla, joka kasvaa jokaisena raittiina päivänä.

ILMAISEKSI
• Alkoholiton päivälaskuri
• Päivittäinen kirjaus ja raittiuskalenteri
• Virtuaalinen puutarha
• Yksityinen laitteella

BLOOM+ (VALINNAINEN)
• Terveysaikajana, päiväkirja, saavutukset
• Apple Watch ja widgetit

Lataa ilmaiseksi. Bloom+ milloin haluat.""",
    },
    "cs": {
        "name": "Sober – Bez alkoholu",
        "subtitle": "Suché dny: počítadlo",
        "keywords": "pít,méně,přestat,závislost,abstinence,zotavení,relaps,chuť,nálada,pruh",
        "description": """Sober Tracker vám pomůže zůstat střízliví díky počítadlu dní, dennímu check-inu a virtuální zahradě, která roste s každým střízlivým dnem.

ZDARMA
• Počítadlo dnů bez alkoholu
• Denní check-in a kalendář střízlivosti
• Virtuální zahrada
• Soukromě v zařízení

BLOOM+ (VOLITELNÉ)
• Zdravotní časová osa, deník, úspěchy
• Apple Watch a widgety

Stáhněte zdarma. Bloom+ kdykoli.""",
    },
    "sk": {
        "name": "Sober – Bez alkoholu",
        "subtitle": "Suché dni: počítadlo",
        "keywords": "piť,menej,prestať,závislosť,abstinencia,zotavenie,relaps,chuť,nálada,pruh",
        "description": """Sober Tracker vám pomôže zostať triezvymi s počítadlom dní, denným check-inom a virtuálnou záhradou, ktorá rastie s každým triezvym dňom.

ZADARMO
• Počítadlo dní bez alkoholu
• Denný check-in a kalendár
• Virtuálna záhrada
• Súkromne v zariadení

BLOOM+ (VOLITEĽNÉ)
• Zdravie, denník, úspechy
• Apple Watch a widgety

Stiahnite zadarmo. Bloom+ kedykoľvek.""",
    },
    "hu": {
        "name": "Sober – Alkoholmentes",
        "subtitle": "Száraz napok és kert",
        "keywords": "inni,kevesebb,abbahagy,függőség,elvonás,felépülés,visszaesés,vágy,hangulat,sáv",
        "description": """A Sober Tracker segít alkoholmentesen maradni napszámlálóval, napi check-innel és virtuális kerttel, amely minden józansági nappal növekszik.

INGYENES
• Alkoholmentes napszámláló
• Napi check-in és józansági naptár
• Virtuális kert
• Privát az eszközön

BLOOM+ (OPCIONÁLIS)
• Egészségidővonal, napló, eredmények
• Apple Watch és widgetek

Töltsd le ingyen. Bloom+ bármikor.""",
    },
    "ro": {
        "name": "Sober – Fără alcool",
        "subtitle": "Zile uscate și grădină",
        "keywords": "bea,puțin,opri,dependență,abstinență,recuperare,recădere,poftă,dispoziție,dungă",
        "description": """Sober Tracker te ajută să rămâi sobri cu contor de zile, check-in zilnic și o grădină virtuală care crește la fiecare zi fără alcool.

GRATUIT
• Contor zile fără alcool
• Check-in zilnic și calendar de sobrietate
• Grădină virtuală
• Privat pe dispozitiv

BLOOM+ (OPȚIONAL)
• Cronologie sănătate, jurnal, realizări
• Apple Watch și widgeturi

Descarcă gratuit. Bloom+ oricând.""",
    },
    "hr": {
        "name": "Sober – Bez alkohola",
        "subtitle": "Suhi dani i vrt",
        "keywords": "piti,manje,prestati,ovisnost,apstinencija,oporavak,relaps,želja,raspoloženje,niz",
        "description": """Sober Tracker pomaže ostati trijezan uz brojač dana, dnevni check-in i virtualni vrt koji raste sa svakim trijeznim danom.

BESPLATNO
• Brojač dana bez alkohola
• Dnevni check-in i kalendar triježnosti
• Virtualni vrt
• Privatno na uređaju

BLOOM+ (OPCIONALNO)
• Zdravstvena vremenska crta, dnevnik
• Apple Watch i widgeti

Preuzmi besplatno. Bloom+ kad želiš.""",
    },
    "el": {
        "name": "Sober – Χωρίς αλκοόλ",
        "subtitle": "Ξηρές μέρες: μετρητής",
        "keywords": "πίνω,λιγότερο,σταματώ,εξάρτηση,αποχή,ανάρρωση,υποτροπή,λαχτάρα,διάθεση,σειρά",
        "description": """Το Sober Tracker σας βοηθά να μείνετε νηφάλιοι με μετρητή ημερών, καθημερινό check-in και εικονικό κήπο που μεγαλώνει κάθε νηφάλια μέρα.

ΔΩΡΕΑΝ
• Μετρητής ημερών χωρίς αλκοόλ
• Καθημερινό check-in και ημερολόγιο νηηλιακότητας
• Εικονικός κήπος
• Ιδιωτικό στη συσκευή

BLOOM+ (ΠΡΟΑΙΡΕΤΙΚΟ)
• Χρονολόγιο υγείας, ημερολόγιο, επιτεύγματα
• Apple Watch και widgets

Δωρεάν λήψη. Bloom+ όποτε θέλετε.""",
    },
    "tr": {
        "name": "Sober – Alkolsüz",
        "subtitle": "Kuru günler ve bahçe",
        "keywords": "içmek,az,bırakmak,bağımlılık,soğuma,iyileşme,nüks,istek,ruh,hali,seri",
        "description": """Sober Tracker, gün sayacı, günlük check-in ve her ayık günde büyüyen sanal bahçe ile alkolsüz kalmanıza yardımcı olur.

ÜCRETSİZ
• Alkolsüz gün sayacı
• Günlük check-in ve ayıklık takvimi
• Sanal bahçe
• Cihazda gizli – hesap gerekmez

BLOOM+ (İSTEĞE BAĞLI)
• Sağlık zaman çizelgesi, günlük, başarılar
• Apple Watch ve widget'lar

Ücretsiz indirin. Bloom+ istediğiniz zaman.""",
    },
    "ru": {
        "name": "Sober – Без алкоголя",
        "subtitle": "Сухие дни и сад",
        "keywords": "пить,меньше,бросить,зависимость,воздержание,восстановление,срыв,тяга,настроение,серия",
        "description": """Sober Tracker помогает оставаться трезвым: счётчик дней, ежедневный чек-ин и виртуальный сад, который растёт с каждым трезвым днём.

БЕСПЛАТНО
• Счётчик дней без алкоголя
• Ежедневный чек-ин и календарь трезвости
• Виртуальный сад
• Приватно на устройстве — без аккаунта

BLOOM+ (ОПЦИОНАЛЬНО)
• Линия здоровья, дневник, достижения
• Apple Watch и виджеты

Скачайте бесплатно. Bloom+ в любое время.""",
    },
    "uk": {
        "name": "Sober – Без алкоголю",
        "subtitle": "Сухі дні та сад",
        "keywords": "пити,менше,кинути,залежність,утримання,одужання,зрив,тяга,настрій,серія",
        "description": """Sober Tracker допомагає залишатися тверезим: лічильник днів, щоденний чек-ін і віртуальний сад, що росте з кожним тверезим днем.

БЕЗКОШТОВНО
• Лічильник днів без алкоголю
• Щоденний чек-ін і календар тверезості
• Віртуальний сад
• Приватно на пристрої

BLOOM+ (ЗА БАЖАННЯМ)
• Лінія здоров'я, щоденник, досягнення
• Apple Watch і віджети

Завантажте безкоштовно. Bloom+ будь-коли.""",
    },
    "ja": {
        "name": "ソーバー：アルコールフリー",
        "subtitle": "ドライデイズとガーデン",
        "keywords": "飲む,減らす,禁酒,依存,断酒,回復,再発,渇望,気分,連続",
        "description": """Sober Trackerは、日数カウンター、毎日のチェックイン、禁酒するたびに育つバーチャルガーデンで、アルコールフリーな生活を続けやすくします。

無料で始める
• アルコールフリーの日数カウンター（日・時間・最長連続）
• 毎日のチェックイン
• 禁酒カレンダー
• バーチャルガーデン
• 端末内でプライベート — アカウント不要

BLOOM+（オプション）
• 健康ベネフィットのタイムライン
• 日記とプロンプト
• 実績と節目
• 節約額・カロリー
• Apple Watchとウィジェット

禁酒・減酒・乾いた日を積み重ねる — Sober Trackerがシンプルに支えます。

無料ダウンロード。いつでもBloom+にアップグレード。""",
    },
    "ko": {
        "name": "소버 – 무알코올",
        "subtitle": "마른 날과 정원",
        "keywords": "마시다,줄이다,끊다,중독,절주,회복,재발,갈망,기분,연속",
        "description": """Sober Tracker는 일수 카운터, 매일 체크인, 금주할 때마다 자라는 가상 정원으로 금주 생활을 이어가게 돕습니다.

무료로 시작
• 무알코올 일수 카운터
• 매일 체크인
• 금주 캘린더
• 가상 정원
• 기기에만 저장 — 계정 불필요

BLOOM+ (선택)
• 건강 타임라인, 일기, 업적
• Apple Watch 및 위젯

금주·절주·마른 날 쌓기 — Sober Tracker가 단순하게 돕습니다.

무료 다운로드. Bloom+는 언제든 업그레이드.""",
    },
    "zh-Hans": {
        "name": "清醒助手 - 无酒精",
        "subtitle": "干燥天数与花园",
        "keywords": "喝,戒酒,少喝,上瘾,戒断,恢复,复发,渴望,心情,连续",
        "description": """Sober Tracker 用天数计数器、每日签到和随戒酒天数成长的虚拟花园，帮你保持清醒。

免费开始
• 无酒精天数计数（天、小时、最长连续）
• 每日签到
• 清醒日历
• 虚拟花园
• 仅保存在设备上 — 无需账户

BLOOM+（可选）
• 完整健康时间线与来源
• 日记与提示
• 成就与里程碑
• 节省金额与卡路里
• Apple Watch 与小组件

戒酒、减量或积累干燥天数 — Sober Tracker 让恢复更简单。

免费下载，随时升级 Bloom+。""",
    },
    "zh-Hant": {
        "name": "清醒助手 - 無酒精",
        "subtitle": "乾燥天數與花園",
        "keywords": "喝,戒酒,少喝,上癮,戒斷,恢復,復發,渴望,心情,連續",
        "description": """Sober Tracker 用天數計數器、每日簽到和隨戒酒天數成長的虛擬花園，幫你保持清醒。

免費開始
• 無酒精天數計數
• 每日簽到與清醒日曆
• 虛擬花園
• 僅保存在裝置上 — 無需帳戶

BLOOM+（可選）
• 健康時間線、日記、成就
• Apple Watch 與小工具

免費下載，隨時升級 Bloom+。""",
    },
    "ar-SA": {
        "name": "سوبر – بلا كحول",
        "subtitle": "أيام جافة وحديقة",
        "keywords": "شرب,أقل,إقلاع,إدمان,امتناع,تعافي,انتكاسة,شهوة,مزاج,سلسلة",
        "description": """يساعدك Sober Tracker على البقاء بعيدًا عن الكحول بعداد الأيام، وتسجيل يومي، وحديقة افتراضية تنمو مع كل يوم متعافٍ.

مجانًا للبدء
• عداد أيام بدون كحول
• تسجيل يومي وتقويم التعافي
• حديقة افتراضية
• خاص على جهازك — لا حاجة لحساب

BLOOM+ (اختياري)
• خط زمني للصحة، يوميات، إنجازات
• Apple Watch وودجات

حمّل مجانًا. ترقية Bloom+ في أي وقت.""",
    },
    "he": {
        "name": "סובר – נטול אלכוהול",
        "subtitle": "ימים יבשים וגינה",
        "keywords": "שתייה,פחות,הפסקה,התמכרות,התנזרות,החלמה,נפילה,תשוקה,מצב,רוח,רצף",
        "description": """Sober Tracker עוזר לך להישאר פיכח עם מונה ימים, צ'ק-אין יומי וגינה וירטואלית שגדלה בכל יום פיכח.

בחינם
• מונה ימים ללא אלכוהול
• צ'ק-אין יומי ולוח פיכחות
• גינה וירטואלית
• פרטי במכשיר — ללא חשבון

BLOOM+ (אופציונלי)
• ציר זמן בריאות, יומן, הישגים
• Apple Watch ווידג'טים

הורדה חינם. Bloom+ בכל עת.""",
    },
    "hi": {
        "name": "सोबर – शराब मुक्त",
        "subtitle": "सूखे दिन और बगीचा",
        "keywords": "पीना,कम,छोड़ना,लत,संयम,सुधार,पुनरावृत्ति,लालसा,मनोदशा,लकीर",
        "description": """Sober Tracker दिन गिनती, दैनिक चेक-इन और हर शराब-मुक्त दिन पर बढ़ने वाले वर्चुअल बगीचे से आपको शराब-मुक्त रहने में मदद करता है।

मुफ़्त शुरू करें
• शराब-मुक्त दिन काउंटर
• दैनिक चेक-इन और कैलेंडर
• वर्चुअल बगीचा
• डिवाइस पर निजी — खाता नहीं

BLOOM+ (वैकल्पिक)
• स्वास्थ्य टाइमलाइन, जर्नल, उपलब्धियां
• Apple Watch और विजेट

मुफ़्त डाउनलोड। कभी भी Bloom+ अपग्रेड करें।""",
    },
    "th": {
        "name": "โซเบอร์ – ไร้แอลกอฮอล์",
        "subtitle": "วันแห้งและสวน",
        "keywords": "ดื่ม,น้อย,เลิก,ติด,เหล้า,เลิก,เหล้า,หาย,อยาก,อารมณ์, streak",
        "description": """Sober Tracker ช่วยคุณเลิกดื่มด้วยตัวนับวัน เช็คอินรายวัน และสวนเสมือนที่เติบโตทุกวันที่ไม่ดื่ม

ฟรี
• ตัวนับวันไม่ดื่มแอลกอฮอล์
• เช็คอินและปฏิทินความกลับใจ
• สวนเสมือน
• ส่วนตัวบนอุปกรณ์

BLOOM+ (ทางเลือก)
• ไทม์ไลน์สุขภาพ ไดอารี่ ความสำเร็จ
• Apple Watch และวิดเจ็ต

ดาวน์โหลดฟรี อัปเกรด Bloom+ ได้ทุกเมื่อ""",
    },
    "vi": {
        "name": "Sober – Không cồn",
        "subtitle": "Ngày khô và vườn",
        "keywords": "uống,ít,cai,nghiện,kiêng,phục,hồi,tái,phát,thèm,tâm,trạng,chuỗi",
        "description": """Sober Tracker giúp bạn cai rượu với bộ đếm ngày, check-in hàng ngày và khu vườn ảo lớn lên mỗi ngày không uống.

MIỄN PHÍ
• Đếm ngày không cồn
• Check-in và lịch cai rượu
• Vườn ảo
• Riêng tư trên thiết bị

BLOOM+ (TÙY CHỌN)
• Dòng thời gian sức khỏe, nhật ký
• Apple Watch và widget

Tải miễn phí. Nâng cấp Bloom+ bất cứ lúc nào.""",
    },
    "id": {
        "name": "Sober – Bebas Alkohol",
        "subtitle": "Hari kering: kira sedar",
        "keywords": "minum,sedikit,berhenti,kecanduan,pantang,pemulihan,kambuh,hasrat,suasana,hati,streak",
        "description": """Sober Tracker membantu Anda tetap bebas alkohol dengan penghitung hari, check-in harian, dan taman virtual yang tumbuh setiap hari tanpa minum.

GRATIS
• Penghitung hari bebas alkohol
• Check-in harian dan kalender
• Taman virtual
• Privat di perangkat

BLOOM+ (OPSIONAL)
• Linimasa kesehatan, jurnal, pencapaian
• Apple Watch dan widget

Unduh gratis. Bloom+ kapan saja.""",
    },
    "ms": {
        "name": "Sober – Bebas Alkohol",
        "subtitle": "Hari kering: kira sedar",
        "keywords": "minum,kurang,berhenti,ketagihan,pantang,pemulihan,kambuh,hasrat,suasana,hati,streak",
        "description": """Sober Tracker membantu anda kekal tanpa alkohol dengan pembilang hari, daftar masuk harian dan taman maya yang membesar setiap hari tanpa minum.

PERCUMA
• Pembilang hari tanpa alkohol
• Daftar masuk dan kalendar
• Taman maya
• Peribadi pada peranti

BLOOM+ (PILIHAN)
• Garis masa kesihatan, diari
• Apple Watch dan widget

Muat turun percuma. Bloom+ bila-bila masa.""",
    },
    "bn-BD": {
        "name": "সোবার – মদ ছাড়া",
        "subtitle": "শুষ্ক দিন ও বাগান",
        "keywords": "পান,কম,ছাড়া,আসক্তি,সংযম,পুনরুদ্ধার,পুনরাবৃত্তি,লালসা,মেজাজ,ধারা",
        "description": """Sober Tracker দিন গণনা, দৈনিক চেক-ইন এবং প্রতিটি মদমুক্ত দিনে বেড়ে ওঠা ভার্চুয়াল বাগান দিয়ে আপনাকে মদমুক্ত থাকতে সাহায্য করে।

বিনামূল্যে
• মদমুক্ত দিন গণনা
• দৈনিক চেক-ইন ও ক্যালেন্ডার
• ভার্চুয়াল বাগান
• ডিভাইসে ব্যক্তিগত

BLOOM+ (ঐচ্ছিক)
• স্বাস্থ্য টাইমলাইন, ডায়েরি
• Apple Watch ও উইজেট

বিনামূল্যে ডাউনলোড। যেকোনো সময় Bloom+।""",
    },
    "gu-IN": {
        "name": "સોબર – દારૂ મુક્ત",
        "subtitle": "સૂકા દિવસ અને બગીચો",
        "keywords": "પીવું,ઓછું,છોડવું,વ્યસન,ત્યાગ,પુનઃપ્રાપ્તિ,પુનરાવર્તન,તૃષ્ણા,મૂડ,શ્રેણી",
        "description": """Sober Tracker દિવસ ગણતરી, દૈનિક ચેક-ઇન અને દરેક મદમુક્ત દિવસે વધતા વર્ચુઅલ બગીચાથી તમને મદમુક્ત રાખવામાં મદદ કરે છે.

મફત
• મદમુક્ત દિવસ કાઉન્ટર
• દૈનિક ચેક-ઇન અને કેલેન્ડર
• વર્ચુઅલ બગીચો
• ઉપકરણ પર ખાનગી

BLOOM+ (વૈકલ્પિક)
• આરોગ્ય, ડાયરી, સિદ્ધિઓ
• Apple Watch અને વિજેટ

મફત ડાઉનલોડ. Bloom+ ક્યારે પણ.""",
    },
    "kn-IN": {
        "name": "ಸೋಬರ್ – ಮದ್ಯಮುಕ್ತ",
        "subtitle": "ಒಣ ದಿನಗಳು ಮತ್ತು ತೋಟ",
        "keywords": "ಕುಡಿಯುವುದು,ಕಡಿಮೆ,ಬಿಡುವುದು,ಚಟ,ಸಂಯಮ,ಚೇತರಿಕೆ,ಮರುಕಳಿಕೆ,ಹಂಬಲ,ಮನಸ್ಥಿತಿ,ಸರಣಿ",
        "description": """Sober Tracker ದಿನಗಳ ಎಣಿಕೆ, ದೈನಂದಿನ ಚೆಕ್-ಇನ್ ಮತ್ತು ಪ್ರತಿ ಮದ್ಯಮುಕ್ತ ದಿನದಲ್ಲಿ ಬೆಳೆಯುವ ವರ್ಚುವಲ್ ತೋಟದೊಂದಿಗೆ ನಿಮಗೆ ಮದ್ಯಮುಕ್ತವಾಗಿರಲು ಸಹಾಯ ಮಾಡುತ್ತದೆ.

ಉಚಿತ
• ಮದ್ಯಮುಕ್ತ ದಿನ ಎಣಿಕೆ
• ದೈನಂದಿನ ಚೆಕ್-ಇನ್
• ವರ್ಚುವಲ್ ತೋಟ
• ಸಾಧನದಲ್ಲಿ ಖಾಸಗಿ

BLOOM+ (ಐಚ್ಛಿಕ)
• ಆರೋಗ್ಯ, ದಿನಚರಿ, ಸಾಧನೆಗಳು
• Apple Watch ಮತ್ತು ವಿಜೆಟ್

ಉಚಿತ ಡೌನ್‌ಲೋಡ್. Bloom+ ಯಾವುದೇ ಸಮಯ.""",
    },
    "ml-IN": {
        "name": "സോബർ – മദ്യമുക്ത",
        "subtitle": "ഉണങ്ങിയ ദിവസങ്ങളും തോട്ടവും",
        "keywords": "കുടിക്കൽ,കുറവ്,നിർത്തൽ,ആസക്തി,വർജനം,വീണ്ടെടുക്കൽ,വീഴ്ച,ആഗ്രഹം,മാനസികാവസ്ഥ,ശ്രേണി",
        "description": """Sober Tracker ദിവസ എണ്ണം, ദൈനംദിന ചെക്ക്-ഇൻ, മദ്യമുക്ത ഓരോ ദിവസവും വളരുന്ന വെർച്വൽ തോട്ടം എന്നിവയിലൂടെ നിങ്ങളെ സഹായിക്കുന്നു.

സൗജന്യം
• മദ്യമുക്ത ദിവസ എണ്ണി
• ദൈനംദിന ചെക്ക്-ഇൻ
• വെർച്വൽ തോട്ടം
• ഉപകരണത്തിൽ സ്വകാര്യം

BLOOM+ (ഓപ്ഷണൽ)
• ആരോഗ്യം, ഡയറി, നേട്ടങ്ങൾ
• Apple Watch, വിജറ്റ്

സൗജന്യ ഡൗൺലോഡ്. Bloom+ എപ്പോഴും.""",
    },
    "mr-IN": {
        "name": "सोबर – दारूमुक्त",
        "subtitle": "कोरडे दिवस आणि बाग",
        "keywords": "पिणे,कमी,सोडणे,व्यसन,त्याग,पुनर्प्राप्ती,पुनरावृत्ती,तळमळ,मूड,मालिका",
        "description": """Sober Tracker दिवस मोजणी, दैनंदिन चेक-इन आणि प्रत्येक दारूमुक्त दिवशी वाढणारी आभासी बाग यांद्वारे तुम्हाला दारूमुक्त राहण्यास मदत करते.

मोफत
• दारूमुक्त दिवस मोजणी
• दैनंदिन चेक-इन
• आभासी बाग
• डिव्हाइसवर खाजगी

BLOOM+ (पर्यायी)
• आरोग्य, डायरी, यश
• Apple Watch आणि विजेट

मोफत डाउनलोड. Bloom+ कधीही.""",
    },
    "or-IN": {
        "name": "ସୋବର – ମଦ୍ୟମୁକ୍ତ",
        "subtitle": "ଶୁଷ୍କ ଦିନ ଓ ବଗିଚା",
        "keywords": "ପିଇବା,କମ,ଛାଡିବା,ଆସକ୍ତି,ବିରତି,ପୁନରୁଦ୍ଧାର,ପୁନରାବୃତ୍ତି,ଲାଳସା,ମୁଡ୍,ଶୃଙ୍ଖଳା",
        "description": """Sober Tracker ଦିନ ଗଣନା, ଦୈନିକ ଚେକ-ଇନ୍ ଏବଂ ପ୍ରତ୍ୟେକ ମଦ୍ୟମୁକ୍ତ ଦିନରେ ବଢୁଥିବା ଭର୍ଚୁଆଲ୍ ବଗିଚା ସହିତ ଆପଣଙ୍କୁ ସାହାଯ୍ୟ କରେ।

ମାଗଣା
• ମଦ୍ୟମୁକ୍ତ ଦିନ ଗଣନା
• ଦୈନିକ ଚେକ-ଇନ୍
• ଭର୍ଚୁଆଲ୍ ବଗିଚା
• ଉପକରଣରେ ବ୍ୟକ୍ତିଗତ

BLOOM+ (ବିକଳ୍ପ)
• ସ୍ୱାସ୍ଥ୍ୟ, ଡାଇରି
• Apple Watch ଏବଂ ୱିଜେଟ୍

ମାଗଣା ଡାଉନଲୋଡ୍। Bloom+ ଯେକୋଣସି ସମୟରେ।""",
    },
    "pa-IN": {
        "name": "ਸੋਬਰ – ਸ਼ਰਾਬ ਮੁਕਤ",
        "subtitle": "ਸੁੱਕੇ ਦਿਨ ਅਤੇ ਬਾਗ",
        "keywords": "ਪੀਣਾ,ਘੱਟ,ਛੱਡਣਾ,ਆਦੀ,ਸੰਜਮ,ਬਰਾਮਦਗੀ,ਮੁੜ,ਆਉਣਾ,ਤਰਸ,ਮੂਡ,ਲਕੀਰ",
        "description": """Sober Tracker ਦਿਨ ਗਿਣਤੀ, ਰੋਜ਼ਾਨਾ ਚੈਕ-ਇਨ ਅਤੇ ਹਰ ਸ਼ਰਾਬ-ਮੁਕਤ ਦਿਨ ਨਾਲ ਵਧਦੇ ਵਰਚੁਅਲ ਬਾਗ ਨਾਲ ਤੁਹਾਨੂੰ ਸ਼ਰਾਬ-ਮੁਕਤ ਰਹਿਣ ਵਿੱਚ ਮਦਦ ਕਰਦਾ ਹੈ।

ਮੁਫ਼ਤ
• ਸ਼ਰਾਬ-ਮੁਕਤ ਦਿਨ ਗਿਣਤੀ
• ਰੋਜ਼ਾਨਾ ਚੈਕ-ਇਨ
• ਵਰਚੁਅਲ ਬਾਗ
• ਡਿਵਾਈਸ ਤੇ ਨਿੱਜੀ

BLOOM+ (ਵਿਕਲਪਿਕ)
• ਸਿਹਤ, ਡਾਇਰੀ, ਪ੍ਰਾਪਤੀਆਂ
• Apple Watch ਅਤੇ ਵਿਜੇਟ

ਮੁਫ਼ਤ ਡਾਊਨਲੋਡ। Bloom+ ਕਦੇ ਵੀ।""",
    },
    "ta-IN": {
        "name": "சோபர் – மதுவிலா",
        "subtitle": "உலர் நாட்கள் மற்றும் தோட்டம்",
        "keywords": "குடிப்பது,குறைவு,விடுவது,அடிமைத்தனம்,தவிர்ப்பு,மீட்பு,மீள்தொற்று,ஏக்கம்,மனநிலை,தொடர்",
        "description": """Sober Tracker நாள் எண்ணி, தினசரி செக்-இன் மற்றும் ஒவ்வொரு மது இல்லா நாளிலும் வளரும் மெய்நிகர் தோட்டத்துடன் உங்களுக்கு உதவுகிறது.

இலவசம்
• மது இல்லா நாள் எண்ணி
• தினசரி செக்-இன்
• மெய்நிகர் தோட்டம்
• சாதனத்தில் தனிப்பட்ட

BLOOM+ (விருப்பம்)
• ஆரோக்கியம், பதிவு, சாதனைகள்
• Apple Watch மற்றும் விட்ஜெட்

இலவச பதிவிறக்கம். Bloom+ எப்போதும்.""",
    },
    "te-IN": {
        "name": "సోబర్ – మద్యముక్త",
        "subtitle": "ఎండిన రోజులు: స్వచ్ఛత",
        "keywords": "తాగడం,తక్కువ,వదలడం,వ్యసనం,సంయమం,పునరుద్ధరణ,పునరావృత్తి,కోరిక,మానసిక,స్థితి,సిరీస్",
        "description": """Sober Tracker రోజుల లెక్క, రోజువారీ చెక్-ఇన్ మరియు ప్రతి మద్యముక్త రోజుతో పెరిగే వర్చువల్ తోటతో మీకు సహాయం చేస్తుంది.

ఉచితం
• మద్యముక్త రోజుల లెక్క
• రోజువారీ చెక్-ఇన్
• వర్చువల్ తోట
• పరికరంలో ప్రైవేట్

BLOOM+ (ఐచ్ఛికం)
• ఆరోగ్యం, డైరీ, విజయాలు
• Apple Watch మరియు విడ్జెట్

ఉచిత డౌన్‌లోడ్. Bloom+ ఎప్పుడైనా.""",
    },
    "ur-PK": {
        "name": "سوبر – شراب سے پاک",
        "subtitle": "خشک دن اور باغ",
        "keywords": "پینا,کم,چھوڑنا,نشہ,پرہیز,بحالی,دوبارہ,لگنا,آرزو,موڈ,سلسلہ",
        "description": """Sober Tracker دن گنتی، روزانہ چیک اِن اور ہر شراب سے پاک دن پر بڑھنے والے ورچوئل باغ کے ساتھ آپ کی مدد کرتا ہے۔

مفت
• شراب سے پاک دن گنتی
• روزانہ چیک اِن
• ورچوئل باغ
• ڈیوائس پر نجی

BLOOM+ (اختیاری)
• صحت، ڈائری، کامیابیاں
• Apple Watch اور وجیٹ

مفت ڈاؤن لوڈ۔ Bloom+ کبھی بھی۔""",
    },
    "sl-SI": {
        "name": "Sober – Brez alkohola",
        "subtitle": "Suhi dnevi in vrt",
        "keywords": "piti,manj,nehati,odvisnost,abstinenca,okrevanje,povratek,hrepenenje,razpoloženje,niz",
        "description": """Sober Tracker vam pomaga ostati trezni z številcem dni, dnevnim check-inom in virtualnim vrtom, ki raste z vsakim treznim dnem.

BREZPLAČNO
• Števec dni brez alkohola
• Dnevni check-in in koledar
• Virtualni vrt
• Zasebno na napravi

BLOOM+ (IZBIRNO)
• Časovnica zdravja, dnevnik
• Apple Watch in gradniki

Brezplačen prenos. Bloom+ kadarkoli.""",
    },
}
