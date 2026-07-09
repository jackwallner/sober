#!/usr/bin/env python3
"""Generate scripts/locale_aso_spec.py for Sober (alcohol) — all 50 locales."""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPTS))

from pack_sober_keywords import (  # noqa: E402
    US_EN_CANDIDATES,
    pack_keywords,
    title_subtitle_overlap,
    validate_packed_keywords,
    validate_title_subtitle,
)

EN_TITLE = "Sober Tracker - Alcohol Free"
EN_SUBTITLE = "Dry Days, Sobriety & Garden"
EN_PROOF = (
    "dry days pop12 rank82 (subtitle indexes dry+days)",
    "sober tracker SERP: I Am Sober #1, Sober Time #2, Days Since #3",
    "quit drinking extract: stop pop49, alcohol pop9, streak pop6",
)

# Native alcohol quit titles (no bare English Sober outside en-*).
NATIVE_TITLES: dict[str, str] = {
    "en-US": EN_TITLE,
    "en-GB": EN_TITLE,
    "en-CA": EN_TITLE,
    "en-AU": EN_TITLE,
    "de-DE": "Alkohol aufhören: Trockene Tage",
    "fr-FR": "Arrêter alcool: Jours secs",
    "fr-CA": "Arrêter alcool: Jours secs",
    "es-ES": "Dejar alcohol: Días secos",
    "es-MX": "Dejar alcohol: Días secos",
    "it": "Smetti alcol: Giorni secchi",
    "pt-BR": "Parar álcool: Dias secos",
    "pt-PT": "Parar álcool: Dias secos",
    "nl-NL": "Stop met drinken: Droge dagen",
    "pl": "Rzuć alkohol: Suche dni",
    "sv": "Sluta dricka: Torra dagar",
    "da": "Stop med alkohol: Tørre dage",
    "no": "Slutt med alkohol: Tørre dager",
    "fi": "Lopeta alkoholi: Kuivat päivät",
    "cs": "Přestaň pít: Suché dny",
    "sk": "Prestaň piť: Suché dni",
    "hr": "Prestani piti: Suhi dani",
    "sl-SI": "Nehaj piti: Suhi dnevi",
    "hu": "Alkohol abbahagy: Száraz napok",
    "ro": "Oprește alcool: Zile uscate",
    "ru": "Брось алкоголь: Сухие дни",
    "uk": "Кинь алкоголь: Сухі дні",
    "el": "Σταμάτα αλκοόλ: Ξηρές μέρες",
    "tr": "Bırak alkol: Kuru günler",
    "ca": "Deixa l'alcohol: Dies secs",
    "id": "Berhenti alkohol: Hari kering",
    "ms": "Berhenti alkohol: Hari kering",
    "vi": "Bỏ rượu: Ngày khô & lịch",
    "th": "เลิกแอลกอฮอล์: วันแห้ง",
    "ar-SA": "إقلاع الكحول: أيام جافة",
    "he": "הפסקת אלכוהול: ימים יבשים",
    "ja": "禁酒アルコールフリー｜ドライデイ追跡",
    "ko": "금주 알코올 프리｜드라이데이 추적",
    "zh-Hans": "戒酒助手｜干酒日酒精戒断追踪应用",
    "zh-Hant": "戒酒助手｜干酒日酒精戒斷追蹤應用",
    "hi": "शराब छोड़ें – शुष्क दिन ट्रैकर",
    "bn-BD": "মদ ছাড়ুন – শুষ্ক দিন ট্র্যাকার",
    "ta-IN": "மது விடு – உலர் நாட்கள் டிராக்கர்",
    "te-IN": "మద్యం వదులు – ఎండిన రోజులు",
    "mr-IN": "दारू सोडा – कोरडे दिवस ट्रॅकर",
    "gu-IN": "દારૂ છોડો – સૂકા દિવસ ટ્રેકર",
    "kn-IN": "ಮದ್ಯ ಬಿಡಿ – ಒಣ ದಿನಗಳ ಟ್ರ್ಯಾಕರ್",
    "ml-IN": "മദ്യം നിർത്തുക – ഉണങ്ങിയ ദിവസങ്ങൾ",
    "pa-IN": "ਸ਼ਰਾਬ ਛੱਡੋ – ਸੁੱਕੇ ਦਿਨ ਟ੍ਰੈਕਰ",
    "or-IN": "ମଦ୍ୟ ଛାଡ଼ – ଶୁଷ୍କ ଦିନ ଟ୍ରାକର",
    "ur-PK": "شراب چھوڑیں – خشک دن ٹریکر",
}

NATIVE_SUBTITLES: dict[str, str] = {
    "en-US": EN_SUBTITLE,
    "en-GB": EN_SUBTITLE,
    "en-CA": EN_SUBTITLE,
    "en-AU": EN_SUBTITLE,
    "de-DE": "Alkoholfreie Tage & Garten",
    "fr-FR": "Compteur jours sans alcool",
    "fr-CA": "Compteur jours sans alcool",
    "es-ES": "Contador días sin alcohol",
    "es-MX": "Contador días sin alcohol",
    "it": "Contatore giorni senza alcol",
    "pt-BR": "Contador dias sem álcool",
    "pt-PT": "Contador dias sem álcool",
    "nl-NL": "Alcoholvrije dagen & tuin",
    "pl": "Licznik dni bez alkoholu",
    "sv": "Alkoholfria dagar & trädgård",
    "da": "Alkoholfri dagtæller & have",
    "no": "Alkoholfri dagteller & hage",
    "fi": "Alkoholiton päivälaskuri",
    "cs": "Počítadlo dnů bez alkoholu",
    "sk": "Počítadlo dní bez alkoholu",
    "hr": "Brojač dana bez alkohola",
    "sl-SI": "Števec dni brez alkohola",
    "hu": "Alkoholmentes napok & kert",
    "ro": "Contor zile fără alcool",
    "ru": "Счётчик дней без алкоголя",
    "uk": "Лічильник днів без алкоголю",
    "el": "Μετρητής ημερών χωρίς αλκοόλ",
    "tr": "Alkolsüz gün sayacı & bahçe",
    "ca": "Comptador dies sense alcohol",
    "id": "Hitung hari bebas alkohol",
    "ms": "Kira hari bebas alkohol",
    "vi": "Đếm ngày không rượu & vườn",
    "th": "นับวันไม่ดื่ม & สวนเสมือน",
    "ar-SA": "عداد أيام خالية من الكحول",
    "he": "מונה ימים נקיים מאלכוהול",
    "ja": "無アルコール日数カウンター・庭園",
    "ko": "무알코올 일수 카운터 & 정원",
    "zh-Hans": "无酒精日计数器・虚拟花园成长",
    "zh-Hant": "無酒精日計數器・虛擬花園成長",
    "hi": "शराब मुक्त दिन गिनती बगीचा",
    "bn-BD": "মদমুক্ত দিন গণনা ও বাগান",
    "ta-IN": "மது இல்லா நாட்கள் எண்ணிக்கை",
    "te-IN": "మద్యముక్త రోజుల లెక్క తోట",
    "mr-IN": "दारूमुक्त दिवस मोजणी बाग",
    "gu-IN": "મદ્યમુક્ત દિવસ ગણતરી બગીચો",
    "kn-IN": "ಮದ್ಯಮುಕ್ತ ದಿನಗಳ ಎಣಿಕೆ ತೋಟ",
    "ml-IN": "മദ്യമുക്ത ദിവസങ്ങൾ & തോട്ടം",
    "pa-IN": "ਸ਼ਰਾਬ ਮੁਕਤ ਦਿਨ ਗਿਣਤੀ ਬਾਗ",
    "or-IN": "ମଦ୍ୟମୁକ୍ତ ଦିନ ଗଣନା ବଗିଚା",
    "ur-PK": "شراب سے پاک دن گنتی باغ",
}

# Per-locale keyword pools (native quit/alcohol terms first).
LOCALE_POOLS: dict[str, tuple[str, ...]] = {
    "en-US": tuple(US_EN_CANDIDATES),
    "en-GB": tuple(US_EN_CANDIDATES),
    "en-CA": tuple(US_EN_CANDIDATES),
    "en-AU": tuple(US_EN_CANDIDATES),
    "de-DE": (
        "trinken", "weniger", "aufhören", "entzug", "nüchtern", "sucht", "erholung", "serie",
        "abstinenz", "rückfall", "stimmung", "verlangen", "kalender", "tagebuch", "garten",
        "gesundheit", "privat", "wein", "bier", "detox", "streak", "widget",
    ),
    "fr-FR": (
        "boire", "moins", "arrêter", "sevrage", "abstinence", "rétablissement", "envie",
        "habitude", "journal", "série", "dépendance", "rechute", "humeur", "calendrier",
        "jardin", "santé", "privé", "vin", "bière", "détox", "streak", "widget",
    ),
    "fr-CA": (
        "boire", "moins", "arrêter", "sevrage", "abstinence", "rétablissement", "envie",
        "habitude", "journal", "série", "dépendance", "rechute", "humeur", "calendrier",
        "jardin", "santé", "privé", "vin", "bière", "cessation", "streak", "widget",
    ),
    "es-ES": (
        "beber", "menos", "dejar", "adicción", "antojo", "abstinencia", "recuperación",
        "sobriedad", "recaída", "humor", "diario", "serie", "calendario", "jardín",
        "salud", "privado", "vino", "cerveza", "detox", "streak", "widget",
    ),
    "es-MX": (
        "beber", "menos", "dejar", "adicción", "antojo", "abstinencia", "recuperación",
        "sobriedad", "recaída", "humor", "diario", "serie", "calendario", "jardín",
        "salud", "privado", "vino", "cerveza", "detox", "streak", "widget",
    ),
    "it": (
        "bere", "meno", "smettere", "astinenza", "dipendenza", "recupero", "ricaduta",
        "voglia", "umore", "abitudine", "diario", "serie", "calendario", "giardino",
        "salute", "privato", "vino", "birra", "detox", "streak", "widget",
    ),
    "pt-BR": (
        "beber", "menos", "parar", "dependência", "abstinência", "recuperação", "recaída",
        "vontade", "humor", "diário", "serie", "calendário", "jardim", "saúde", "privado",
        "vinho", "cerveja", "detox", "streak", "widget",
    ),
    "pt-PT": (
        "beber", "menos", "parar", "dependência", "abstinência", "recuperação", "recaída",
        "vontade", "humor", "diário", "serie", "calendário", "jardim", "saúde", "privado",
        "vinho", "cerveja", "detox", "streak", "widget",
    ),
    "nl-NL": (
        "drinken", "minder", "stoppen", "verslaving", "ontwenning", "nuchter", "herstel",
        "terugval", "verlangen", "stemming", "gewoonte", "dagboek", "serie", "kalender",
        "tuin", "gezondheid", "privé", "wijn", "bier", "detox", "streak", "widget",
    ),
    "pl": (
        "pić", "mniej", "przestać", "uzależnienie", "abstynencja", "odwyk", "nawrót",
        "głód", "nastrój", "nawyk", "dziennik", "seria", "kalendarz", "ogród", "zdrowie",
        "prywatny", "wino", "piwo", "detox", "streak", "widget",
    ),
    "sv": (
        "dricka", "mindre", "sluta", "beroende", "abstinens", "återhämtning", "återfall",
        "sug", "humör", "vana", "dagbok", "serie", "kalender", "trädgård", "hälsa",
        "privat", "vin", "öl", "detox", "streak", "widget",
    ),
    "da": (
        "drikke", "mindre", "stoppe", "afhængighed", "afholdenhed", "bedring", "tilbagefald",
        "trang", "humør", "vane", "dagbog", "serie", "kalender", "have", "sundhed",
        "privat", "vin", "øl", "detox", "streak", "widget",
    ),
    "no": (
        "drikke", "mindre", "slutte", "avhengighet", "avholdenhet", "bedring", "tilbakefall",
        "sug", "humør", "vane", "dagbok", "serie", "kalender", "hage", "helse", "privat",
        "vin", "øl", "detox", "streak", "widget",
    ),
    "fi": (
        "juoda", "vähemmän", "lopettaa", "riippuvuus", "raittius", "toipuminen", "retkahdus",
        "himo", "mieli", "tapa", "päiväkirja", "sarja", "kalenteri", "puutarha", "terveys",
        "yksityinen", "viini", "olut", "detox", "streak", "widget",
    ),
    "cs": (
        "pít", "méně", "přestat", "závislost", "abstinence", "zotavení", "relaps", "chuť",
        "nálada", "zvyk", "deník", "série", "kalendář", "zahrada", "zdraví", "soukromí",
        "víno", "pivo", "detox", "streak", "widget",
    ),
    "sk": (
        "piť", "menej", "prestať", "závislosť", "abstinencia", "zotavenie", "relaps", "chuť",
        "nálada", "zvyk", "denník", "séria", "kalendár", "záhrada", "zdravie", "súkromie",
        "víno", "pivo", "detox", "streak", "widget",
    ),
    "hr": (
        "piti", "manje", "prestati", "ovisnost", "apstinencija", "oporavak", "relaps", "želja",
        "raspoloženje", "navika", "dnevnik", "niz", "kalendar", "vrt", "zdravlje", "privatno",
        "vino", "pivo", "detox", "streak", "widget",
    ),
    "sl-SI": (
        "piti", "manj", "nehati", "odvisnost", "abstinenca", "okrevanje", "ponovitev", "želja",
        "razpoloženje", "navada", "dnevnik", "niz", "koledar", "vrt", "zdravje", "zasebno",
        "vino", "pivo", "detox", "streak", "widget",
    ),
    "hu": (
        "inni", "kevesebb", "abbahagy", "függőség", "elvonás", "felépülés", "visszaesés",
        "vágy", "hangulat", "szokás", "napló", "sorozat", "naptár", "kert", "egészség",
        "privát", "bor", "sör", "detox", "streak", "widget",
    ),
    "ro": (
        "bea", "mai puțin", "opri", "dependență", "abstinență", "recuperare", "recădere",
        "poftă", "dispoziție", "obicei", "jurnal", "serie", "calendar", "grădină", "sănătate",
        "privat", "vin", "bere", "detox", "streak", "widget",
    ),
    "ru": (
        "пить", "меньше", "бросить", "зависимость", "воздержание", "восстановление", "срыв",
        "тяга", "настроение", "привычка", "дневник", "серия", "календарь", "сад", "здоровье",
        "приватный", "вино", "пиво", "detox", "streak", "widget",
    ),
    "uk": (
        "пити", "менше", "кинути", "залежність", "утримання", "відновлення", "зрив", "тяга",
        "настрій", "звичка", "щоденник", "серія", "календар", "сад", "здоров'я", "приватний",
        "вино", "пиво", "detox", "streak", "widget",
    ),
    "el": (
        "πίνω", "λιγότερο", "σταματώ", "εξάρτηση", "αποχή", "ανάρρωση", "υποτροπή", "λαχτάρα",
        "διάθεση", "συνήθεια", "ημερολόγιο", "σειρά", "κήπος", "υγεία", "ιδιωτικό", "κρασί",
        "μπύρα", "detox", "streak", "widget",
    ),
    "tr": (
        "içmek", "az", "bırakmak", "bağımlılık", "ayıklık", "iyileşme", "nüks", "istek",
        "ruh hali", "alışkanlık", "günlük", "dizi", "takvim", "bahçe", "sağlık", "özel",
        "şarap", "bira", "detox", "streak", "widget",
    ),
    "ca": (
        "beure", "menys", "deixar", "addicció", "abstinència", "recuperació", "recaiguda",
        "desig", "humor", "hàbit", "diari", "sèrie", "calendari", "jardí", "salut", "privat",
        "vi", "cervesa", "detox", "streak", "widget",
    ),
    "ja": (
        "飲む", "減らす", "禁酒", "依存", "断酒", "回復", "再発", "渇望", "習慣", "日記",
        "連続", "記録", "カレンダー", "ウィジェット", "庭", "健康", "非公開", "ワイン", "ビール",
        "ドライ", "デイ", "追跡", "カウンター", "バーチャル", "成長", "アプリ", "ツール", "SOBER",
        "DRYDAY", "アルコール", "フリー", "日数", "仮想", "チェックイン",
    ),
    "ko": (
        "마시다", "줄이다", "끊다", "중독", "절주", "회복", "재발", "갈망", "습관", "일기",
        "연속", "기록", "캘린더", "위젯", "정원", "건강", "비공개", "와인", "맥주", "드라이",
        "데이", "추적", "카운터", "가상", "성장", "앱", "프로그램", "도구", "SOBER", "DRYDAY",
        "알코올", "일수", "성장앱", "가상정원", "절제", "체크인", "서비스", "솔루션",
    ),
    "zh-Hans": (
        "喝酒", "减少", "戒酒", "依赖", "戒断", "渴望", "习惯", "日记", "连续", "记录",
        "日历", "小组件", "花园", "健康", "私密", "复饮", "葡萄酒", "啤酒", "干酒", "追踪",
        "计数器", "虚拟", "成长", "应用", "助手", "SOBER", "DRYDAY", "酒精", "戒断追踪",
        "日计数器", "虚拟花园", "干酒日", "程序", "工具", "服务", "检查", "打卡",
    ),
    "zh-Hant": (
        "喝酒", "減少", "戒酒", "依賴", "戒斷", "渴望", "習慣", "日記", "連續", "記錄",
        "日曆", "小工具", "花園", "健康", "私密", "復飲", "葡萄酒", "啤酒", "干酒", "追蹤",
        "計數器", "虛擬", "成長", "應用", "助手", "SOBER", "DRYDAY", "酒精", "戒斷追蹤",
        "日計數器", "虛擬花園", "干酒日", "程序", "工具", "服務", "檢查", "打卡",
    ),
    "ar-SA": (
        "شرب", "أقل", "إقلاع", "إدمان", "امتناع", "تعافي", "انتكاسة", "شهوة", "عادة",
        "يوميات", "سلسلة", "تقويم", "حديقة", "صحة", "خاص", "نبيذ", "بيرة", "streak",
        "widget", "calendar", "health", "private", "detox", "wine", "beer", "mood", "clean",
        "daily", "journal", "checkin", "recovery",
    ),
    "he": (
        "שתייה", "פחות", "הפסקה", "התמכרות", "התנזרות", "החלמה", "נפילה", "תשוקה", "הרגל",
        "יומן", "רצף", "לוחשנה", "גן", "בריאות", "פרטי", "יין", "בירה",
    ),
    "hi": (
        "पीना", "कम", "छोड़ना", "लत", "संयम", "सुधार", "पुनरावृत्ति", "लालसा", "आदत",
        "डायरी", "स्ट्रीक", "कैलेंडर", "बगीचा", "स्वास्थ्य", "निजी", "शराब", "वाइन",
    ),
    "bn-BD": (
        "পান", "কম", "ছাড়া", "আসক্তি", "সংযম", "পুনরুদ্ধার", "পুনরাবৃত্তি", "লালসা",
        "অভ্যাস", "ডায়েরি", "ধারা", "ক্যালেন্ডার", "বাগান", "স্বাস্থ্য", "ব্যক্তিগত",
    ),
    "gu-IN": (
        "પીવું", "ઓછું", "છોડવું", "વ્યસન", "ત્યાગ", "પુનઃપ્રાપ્તિ", "પુનરાવર્તન", "તૃષ્ણા",
        "આદત", "ડાયરી", "શ્રેણી", "કેલેન્ડર", "બગીચો", "આરોગ્ય", "ખાનગી",
    ),
    "kn-IN": (
        "ಕುಡಿಯುವುದು", "ಕಡಿಮೆ", "ಬಿಡುವುದು", "ಚಟ", "ಸಂಯಮ", "ಚೇತರಿಕೆ", "ಮರುಕಳಿಕೆ", "ಹಂಬಲ",
        "ಅಭ್ಯಾಸ", "ಡೈರಿ", "ಸರಣಿ", "ಕ್ಯಾಲೆಂಡರ್", "ತೋಟ", "ಆರೋಗ್ಯ", "ಖಾಸಗಿ",
    ),
    "ml-IN": (
        "കുടിക്കൽ", "കുറവ്", "നിർത്തൽ", "ആസക്തി", "വർജനം", "വീണ്ടെടുക്കൽ", "വീഴ്ച", "ആഗ്രഹം",
        "ശീലം", "ഡയറി", "സീരീസ്", "കലണ്ടർ", "തോട്ടം", "ആരോഗ്യം", "സ്വകാര്യം",
    ),
    "mr-IN": (
        "पिणे", "कमी", "सोडणे", "व्यसन", "त्याग", "पुनर्प्राप्ती", "पुनरावृत्ती", "तळमळ",
        "सवय", "डायरी", "मालिका", "दिनदर्शिका", "बाग", "आरोग्य", "खाजगी",
    ),
    "or-IN": (
        "ପିଇବା", "କମ", "ଛାଡିବା", "ଆସକ୍ତି", "ବିରତି", "ପୁନରୁଦ୍ଧାର", "ପୁନରାବୃତ୍ତି", "ଲାଳସା",
        "ଅଭ୍ୟାସ", "ଡାଇରୀ", "ଧାରା", "କ୍ୟାଲେଣ୍ଡର", "ବଗିଚା", "ସ୍ୱାସ୍ଥ୍ୟ", "ବ୍ୟକ୍ତିଗତ",
    ),
    "pa-IN": (
        "ਪੀਣਾ", "ਘੱਟ", "ਛੱਡਣਾ", "ਆਦੀ", "ਸੰਜਮ", "ਬਰਾਮਦਗੀ", "ਮੁੜ", "ਤਰਸ", "ਆਦਤ", "ਡਾਇਰੀ",
        "ਲਕੀਰ", "ਕੈਲੰਡਰ", "ਬਾਗ", "ਸਿਹਤ", "ਨਿੱਜੀ", "streak", "widget", "calendar", "health",
        "private", "detox", "wine", "beer", "mood", "clean", "daily", "journal", "checkin",
        "virtual", "counter", "recovery",
    ),
    "ta-IN": (
        "குடிப்பது", "குறைவு", "விடுவது", "அடிமை", "தவிர்ப்பு", "மீட்பு", "மீள்தொற்று", "ஏக்கம்",
        "பழக்கம்", "டைரி", "தொடர்", "நாட்காட்டி", "தோட்டம்", "ஆரோக்கியம்", "தனிப்பட்ட",
    ),
    "te-IN": (
        "తాగడం", "తక్కువ", "వదలడం", "వ్యసనం", "సంయమం", "పునరుద్ధరణ", "పునరావృత్తి", "కోరిక",
        "అలవాటు", "డైరీ", "సిరీస్", "క్యాలెండర్", "తోట", "ఆరోగ్యం", "ప్రైవేట్",
    ),
    "ur-PK": (
        "پینا", "کم", "چھوڑنا", "نشہ", "پرہیز", "بحالی", "دوبارہ", "آرزو", "عادت", "ڈائری",
        "سلسلہ", "کیلنڈر", "باغ", "صحت", "نجی", "streak", "widget", "calendar", "health",
        "private", "detox", "wine", "beer", "mood", "clean", "daily", "journal", "checkin",
        "virtual", "counter", "recovery",
    ),
    "th": (
        "ดื่ม", "น้อยลง", "เลิก", "ติด", "งด", "ฟื้นตัว", "กลับมา", "ความอยาก", "นิสัย",
        "ไดอารี่", "สตรีค", "ปฏิทิน", "สวน", "สุขภาพ", "ส่วนตัว", "ไวน์", "เบียร์",
    ),
    "vi": (
        "uống", "ít hơn", "cai", "nghiện", "kiêng", "phục hồi", "tái nghiện", "thèm", "thóiquen",
        "nhậtký", "chuỗi", "lich", "vuon", "suckhoe", "riengtu", "ruou", "bia",
    ),
    "id": (
        "minum", "sedikit", "berhenti", "kecanduan", "pantang", "pemulihan", "kambuh", "hasrat",
        "kebiasaan", "jurnal", "rangkai", "kalender", "taman", "kesehatan", "pribadi", "anggur",
    ),
    "ms": (
        "minum", "kurang", "berhenti", "ketagihan", "pantang", "pemulihan", "kambuh", "hasrat",
        "tabiat", "diari", "rangkai", "kalendar", "taman", "kesihatan", "peribadi", "anggur",
    ),
}

VERIFICATION: dict[str, str] = {
    "en-US": "US Astro: dry days pop12 rank82; sober tracker SERP all recovery apps.",
    "de-DE": "DE native aufhören+alkohol; trockene Tage=dry days German.",
    "fr-FR": "FR arrêter alcool native; jours secs=dry days French SERP.",
    "es-ES": "ES dejar alcohol native; días secos=dry days Spanish.",
    "sv": "SE sluta dricka native quit-drinking; torra dagar=dry days.",
    "ja": "JP 禁酒+ドライデイ native; no English Sober transliteration.",
    "ko": "KR 금주+드라이데이 native quit alcohol.",
    "zh-Hans": "CN 戒酒+干酒日 native alcohol quit.",
}


def rationale_for(loc: str) -> str:
    base = "Native alcohol quit title; dry-days counter + garden in subtitle."
    extra = VERIFICATION.get(loc, "")
    return f"{base} {extra}".strip()


def astro_proof_for(loc: str) -> tuple[str, ...]:
    if loc.startswith("en-"):
        return EN_PROOF
    v = VERIFICATION.get(loc)
    return (v,) if v else ("Native quit verb + dry-days intent per locale.",)


def store_for(loc: str) -> str:
    stores = {
        "ar-SA": "sa", "de-DE": "de", "fr-FR": "fr", "fr-CA": "ca", "es-ES": "es",
        "es-MX": "mx", "ja": "jp", "ko": "kr", "zh-Hans": "cn", "zh-Hant": "tw",
        "sv": "se", "da": "dk", "no": "no", "fi": "fi", "nl-NL": "nl", "pl": "pl",
        "it": "it", "pt-BR": "br", "pt-PT": "pt", "ru": "ru", "uk": "ua", "tr": "tr",
        "th": "th", "vi": "vn", "id": "id", "ms": "my", "hi": "in", "he": "il",
    }
    return stores.get(loc, "us")


def validate_pair(loc: str, title: str, subtitle: str, pool: tuple[str, ...]) -> list[str]:
    errs = validate_title_subtitle(loc, title, subtitle)
    kw = pack_keywords(title, subtitle, pool)
    if len(kw) < 80:
        errs.append(f"kw short {len(kw)}")
    return errs


def emit() -> str:
    from maximize_field_lengths import MAX_SUBTITLES, MAX_TITLES  # noqa: WPS433

    lines = [
        '#!/usr/bin/env python3',
        '"""Per-locale ASO spec for Sober Tracker (alcohol). Generated by build_sober_locale_aso_spec.py."""',
        "from __future__ import annotations",
        "",
        "from dataclasses import dataclass",
        "",
        "",
        "@dataclass(frozen=True)",
        "class LocaleASO:",
        "    title: str",
        "    subtitle: str",
        "    keyword_pool: tuple[str, ...]",
        "    rationale: str",
        "    astro_proof: tuple[str, ...] = ()",
        '    store: str = "us"',
        "",
        f"EN_TITLE = {EN_TITLE!r}",
        f"EN_SUBTITLE = {EN_SUBTITLE!r}",
        f"EN_KEYWORDS: tuple[str, ...] = {tuple(US_EN_CANDIDATES)!r}",
        f"EN_PROOF = {EN_PROOF!r}",
        "",
        "LOCALE_ASO: dict[str, LocaleASO] = {",
    ]
    errors: list[str] = []
    locales = sorted(set(MAX_TITLES) | set(MAX_SUBTITLES) | set(LOCALE_POOLS))

    for loc in locales:
        title = MAX_TITLES[loc]
        subtitle = MAX_SUBTITLES[loc]
        pool = LOCALE_POOLS.get(loc, LOCALE_POOLS.get("en-US", tuple(US_EN_CANDIDATES)))
        errs = validate_pair(loc, title, subtitle, pool)
        if errs:
            errors.append(f"{loc} T{len(title)} S{len(subtitle)}: {errs}")
            continue
        proof = astro_proof_for(loc)
        store = store_for(loc)
        lines.append(f'    "{loc}": LocaleASO(')
        lines.append(f"        {title!r},")
        lines.append(f"        {subtitle!r},")
        lines.append("        (")
        for p in pool:
            lines.append(f"            {p!r},")
        lines.append("        ),")
        lines.append(f"        {rationale_for(loc)!r},")
        pl = ", ".join(repr(p) for p in proof[:3])
        lines.append(f"        ({pl}),")
        if store != "us":
            lines.append(f'        store={store!r},')
        lines.append("    ),")

    lines.append("}")
    if errors:
        print("VALIDATION FAILURES:")
        for e in errors:
            print(e)
        raise SystemExit(1)
    return "\n".join(lines) + "\n"


def main() -> int:
    out = SCRIPTS / "locale_aso_spec.py"
    out.write_text(emit(), encoding="utf-8")
    print(f"Wrote {out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
