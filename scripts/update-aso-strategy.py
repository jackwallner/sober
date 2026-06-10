#!/usr/bin/env python3
"""Update aso_native_metadata.py with new indie-focused keyword strategy.

Strategy:
  Name: "{Localized Sober Tracker} - {Localized Dry Days}" 
  Subtitle: "{Localized Sobriety Counter} & {Localized Garden}"
  Keywords: localized winnable tokens (pop/diff < 55, no repeats from name/sub)
  
  Rationale: Dropping high-difficulty terms like "alcohol free" (pop 7/diff 66) 
  and "alcohol free tracker" (pop 30/diff 67). Focusing on winnable indie terms
  like "dry days" (pop 8/diff 44) and niche long-tail.
"""
import re

# Read current file
with open('aso_native_metadata.py', 'r') as f:
    content = f.read()

# 1. Update EN_DESCRIPTION
old_desc_line = "• Alcohol-free day counter — see days, hours, and your longest streak"
new_desc_line = "• Dry day counter — see days, hours, and your longest streak"
content = content.replace(old_desc_line, new_desc_line)

# 2. Define new locale data
UPDATES = {
    # English locales
    "en-US": {
        "name": "Sober Tracker - Dry Days",
        "subtitle": "Sobriety Counter & Garden",
        "keywords": "drink,less,quit,alcohol,widget,watch,streak,journal,calendar,private,milestone,relapse,diary,craving,clean",
    },
    "en-GB": {
        "name": "Sober Tracker - Dry Days",
        "subtitle": "Sobriety Counter & Garden",
        "keywords": "drink,less,quit,alcohol,widget,watch,streak,journal,calendar,private,milestone,relapse,diary,craving,clean",
    },
    "en-AU": {
        "name": "Sober Tracker - Dry Days",
        "subtitle": "Sobriety Counter & Garden",
        "keywords": "drink,less,quit,alcohol,widget,watch,streak,journal,calendar,private,milestone,relapse,diary,craving,clean",
    },
    "en-CA": {
        "name": "Sober Tracker - Dry Days",
        "subtitle": "Sobriety Counter & Garden",
        "keywords": "drink,less,quit,alcohol,widget,watch,streak,journal,calendar,private,milestone,relapse,diary,craving,clean",
    },
    # Western European
    "de-DE": {
        "name": "Sober: Trockene Tage",
        "subtitle": "Nüchternzähler & Garten",
        "keywords": "trinken,weniger,aufhören,alkohol,widget,uhr,serie,tagebuch,kalender,privat,meilenstein,rückfall,sucht,rein",
    },
    "fr-FR": {
        "name": "Sober – Jours secs",
        "subtitle": "Compteur sobriété & jardin",
        "keywords": "boire,moins,arrêter,alcool,widget,montre,série,journal,calendrier,privé,jalon,rechute,envie,propre",
    },
    "fr-CA": {
        "name": "Sober – Jours secs",
        "subtitle": "Compteur sobriété et jardin",
        "keywords": "boire,moins,arrêter,alcool,widget,montre,série,journal,calendrier,privé,jalon,rechute,envie,propre",
    },
    "es-ES": {
        "name": "Sober – Días secos",
        "subtitle": "Contador sobriedad & jardín",
        "keywords": "beber,menos,dejar,alcohol,widget,reloj,racha,diario,calendario,privado,hito,recaída,antojo,limpio",
    },
    "es-MX": {
        "name": "Sober – Días secos",
        "subtitle": "Contador sobriedad y jardín",
        "keywords": "beber,menos,dejar,alcohol,widget,reloj,racha,diario,calendario,privado,hito,recaída,antojo,limpio",
    },
    "it": {
        "name": "Sober – Giorni secchi",
        "subtitle": "Contatore sobrietà & giardino",
        "keywords": "bere,meno,smettere,alcol,widget,orologio,serie,diario,calendario,privato,pietra,ricaduta,voglia,pulito",
    },
    "pt-BR": {
        "name": "Sober – Dias secos",
        "subtitle": "Contador sóbrio & jardim",
        "keywords": "beber,menos,parar,álcool,widget,relógio,sequência,diário,calendário,privado,marco,recaída,anseio,limpo",
    },
    "pt-PT": {
        "name": "Sober – Dias secos",
        "subtitle": "Contador sóbrio e jardim",
        "keywords": "beber,menos,parar,álcool,widget,relógio,sequência,diário,calendário,privado,marco,recaída,anseio,limpo",
    },
    "nl-NL": {
        "name": "Sober – Droge dagen",
        "subtitle": "Nuchterteller & tuin",
        "keywords": "stoppen,minder,drinken,alcohol,widget,horloge,reeks,dagboek,kalender,privé,mijlpaal,terugval,schoon",
    },
    # Nordic
    "sv": {
        "name": "Sober – Torra dagar",
        "subtitle": "Nykterhetsräknare & trädgård",
        "keywords": "dricka,mindre,sluta,alkohol,widget,klocka,streak,dagbok,kalender,privat,milstolpe,återfall,sug,ren",
    },
    "da": {
        "name": "Sober – Tørre dage",
        "subtitle": "Ædru-tæller & have",
        "keywords": "drikke,mindre,stoppe,alkohol,widget,ur,streak,dagbog,kalender,privat,milepæl,tilbagefald,trang,ren",
    },
    "no": {
        "name": "Sober – Tørre dager",
        "subtitle": "Edru-teller & hage",
        "keywords": "drikke,mindre,slutte,alkohol,widget,klokke,streak,dagbok,kalender,privat,milepæl,tilbakefall,sug,ren",
    },
    "fi": {
        "name": "Sober – Kuivat päivät",
        "subtitle": "Raittiuslaskuri & puutarha",
        "keywords": "juoda,vähemmän,lopettaa,alkoholi,widget,kello,putki,päiväkirja,kalenteri,yksityinen,virstanpylväs,relapsi,puhdas",
    },
    # Central/Eastern European
    "pl": {
        "name": "Sober – Suche dni",
        "subtitle": "Licznik trzeźwości & ogród",
        "keywords": "pić,mniej,przestać,alkohol,widget,zegarek,seria,dziennik,kalendarz,prywatny,kamień,nawrót,głód,czysty",
    },
    "cs": {
        "name": "Sober – Suché dny",
        "subtitle": "Počítadlo střízlivosti & zahrada",
        "keywords": "pít,méně,přestat,alkohol,widget,hodinky,série,deník,kalendář,soukromý,milník,relaps,chuť,čistý",
    },
    "sk": {
        "name": "Sober – Suché dni",
        "subtitle": "Počítadlo triezvosti & záhrada",
        "keywords": "piť,menej,prestať,alkohol,widget,hodinky,séria,denník,kalendár,súkromný,míľnik,relaps,chuť,čistý",
    },
    "hu": {
        "name": "Sober – Száraz napok",
        "subtitle": "Józanságszámláló & kert",
        "keywords": "inni,kevesebb,abbahagy,alkohol,widget,óra,sorozat,napló,naptár,privát,mérföldkő,visszaesés,vágy,tiszta",
    },
    "ro": {
        "name": "Sober – Zile uscate",
        "subtitle": "Contor sobrietate & grădină",
        "keywords": "bea,mai,puțin,opri,alcool,widget,ceas,serie,jurnal,calendar,privat,prag,recădere,poftă,curat",
    },
    "hr": {
        "name": "Sober – Suhi dani",
        "subtitle": "Brojač trijeznosti & vrt",
        "keywords": "piti,manje,prestati,alkohol,widget,sat,niz,dnevnik,kalendar,privatno,kamen,relaps,želja,čist",
    },
    "el": {
        "name": "Sober – Ξηρές μέρες",
        "subtitle": "Μετρητής νηφαλιότητας & κήπος",
        "keywords": "ποτό,λιγότερο,σταμάτημα,αλκοόλ,widget,ρολόι,σειρά,ημερολόγιο,ιδιωτικό,ορόσημο,υποτροπή,λαχτάρα,καθαρός",
    },
    "sl-SI": {
        "name": "Sober – Suhi dnevi",
        "subtitle": "Števec treznosti & vrt",
        "keywords": "piti,manj,nehati,alkohol,widget,ura,niz,dnevnik,koledar,zasebno,mejnik,povratek,čisto",
    },
    # Turkish
    "tr": {
        "name": "Sober – Kuru günler",
        "subtitle": "Ayıklık sayacı & bahçe",
        "keywords": "içmek,daha,az,bırakmak,alkol,widget,saat,seri,günlük,takvim,özel,dönüm,nüks,istek,temiz",
    },
    # Russian/Ukrainian
    "ru": {
        "name": "Sober – Трезвые дни",
        "subtitle": "Счётчик трезвости и сад",
        "keywords": "пить,меньше,бросить,алкоголь,виджет,часы,серия,дневник,календарь,приват,веха,срыв,тяга,чистый",
    },
    "uk": {
        "name": "Sober – Тверезі дні",
        "subtitle": "Лічильник тверезості та сад",
        "keywords": "пити,менше,кинути,алкоголь,віджет,годинник,серія,щоденник,календар,приват,віха,зрив,тяга,чистий",
    },
    # Arabic/Hebrew/Urdu
    "ar-SA": {
        "name": "سوبر - أيام جافة",
        "subtitle": "عداد التعافي والحديقة",
        "keywords": "شرب,أقل,إقلاع,كحول,ودجت,ساعة,سلسلة,يوميات,تقويم,خاص,معلم,انتكاسة,شهوة,نظيف",
    },
    "he": {
        "name": "סובר - ימים יבשים",
        "subtitle": "מונה פיכחון וגינה",
        "keywords": "שתייה,פחות,הפסקה,אלכוהול,ווידג'ט,שעון,רצף,יומן,לוח,פרטי,אבן,נפילה,השתוקקות,נקי",
    },
    "ur-PK": {
        "name": "سوبر - خشک دن",
        "subtitle": "پاکائی کا شمار اور باغ",
        "keywords": "پینا,کم,چھوڑنا,شراب,وجیٹ,گھڑی,سلسلہ,ڈائری,کیلنڈر,نجی,سنگ,میل,بحالی,صاف",
    },
    # South Asian
    "hi": {
        "name": "सोबर – सूखे दिन",
        "subtitle": "शराबमुक्ति काउंटर और बगीचा",
        "keywords": "पीना,कम,छोड़ना,शराब,विजेट,घड़ी,स्ट्रीक,डायरी,कैलेंडर,निजी,मीलपत्थर,रिलैप्स,लालसा,साफ",
    },
    "bn-BD": {
        "name": "সোবার – শুষ্ক দিন",
        "subtitle": "পুনরুদ্ধার কাউন্টার ও বাগান",
        "keywords": "পান,কম,ছাড়া,মদ,উইজেট,ঘড়ি,ধারা,ডায়েরি,ক্যালেন্ডার,ব্যক্তিগত,প্রান্তিক,পুনরাবৃত্তি,লালসা,পরিষ্কার",
    },
    "gu-IN": {
        "name": "સોબર – સૂકા દિવસ",
        "subtitle": "શુદ્ધતા ગણતરી અને બગીચો",
        "keywords": "પીવું,ઓછું,છોડવું,દારૂ,વિજેટ,ઘડિયાળ,શ્રેણી,ડાયરી,કેલેન્ડર,ખાનગી,માઇલસ્ટોન,રિલેપ્સ,તૃષ્ણા,સ્વચ્છ",
    },
    "kn-IN": {
        "name": "ಸೋಬರ್ – ಒಣ ದಿನಗಳು",
        "subtitle": "ಶುದ್ಧತೆ ಎಣಿಕೆ ಮತ್ತು ತೋಟ",
        "keywords": "ಕುಡಿಯುವುದು,ಕಡಿಮೆ,ಬಿಡುವುದು,ಮದ್ಯ,ವಿಜೆಟ್,ಗಡಿಯಾರ,ಸರಣಿ,ದಿನಚರಿ,ಕ್ಯಾಲೆಂಡರ್,ಖಾಸಗಿ,ಮೈಲ್ಸ್ಟೋನ್,ಹಂಬಲ,ಸ್ವಚ್ಛ",
    },
    "ml-IN": {
        "name": "സോബർ – ഉണങ്ങിയ ദിവസങ്ങൾ",
        "subtitle": "ശുദ്ധത എണ്ണലും തോട്ടവും",
        "keywords": "കുടിക്കൽ,കുറവ്,നിർത്തൽ,മദ്യം,വിജറ്റ്,വാച്ച്,സീരീസ്,ഡയറി,കലണ്ടർ,സ്വകാര്യം,മൈൽസ്റ്റോൺ,ആഗ്രഹം,വൃത്തിയുള്ള",
    },
    "mr-IN": {
        "name": "सोबर – कोरडे दिवस",
        "subtitle": "शुद्धता मोजणी आणि बाग",
        "keywords": "पिणे,कमी,सोडणे,दारू,विजेट,घड्याळ,मालिका,डायरी,कॅलेंडर,खाजगी,मैलाचा,दगड,तळमळ,स्वच्छ",
    },
    "or-IN": {
        "name": "ସୋବର – ଶୁଷ୍କ ଦିନ",
        "subtitle": "ପବିତ୍ରତା ଗଣନା ଏବଂ ବଗିଚା",
        "keywords": "ପିଇବା,କମ,ଛାଡିବା,ମଦ,ୱିଜେଟ,ଘଣ୍ଟା,ଧାରା,ଡାଇରି,କ୍ୟାଲେଣ୍ଡର,ବ୍ୟକ୍ତିଗତ,ମଦ,ଲାଳସା,ପରିଷ୍କାର",
    },
    "pa-IN": {
        "name": "ਸੋਬਰ – ਸੁੱਕੇ ਦਿਨ",
        "subtitle": "ਪਵਿੱਤਰਤਾ ਗਿਣਤੀ ਅਤੇ ਬਾਗ",
        "keywords": "ਪੀਣਾ,ਘੱਟ,ਛੱਡਣਾ,ਸ਼ਰਾਬ,ਵਿਜੇਟ,ਘੜੀ,ਲੜੀ,ਡਾਇਰੀ,ਕੈਲੰਡਰ,ਨਿੱਜੀ,ਮੀਲਪੱਥਰ,ਤਰਸ,ਸਾਫ",
    },
    "ta-IN": {
        "name": "சோபர் – உலர் நாட்கள்",
        "subtitle": "தூய்மை எண்ணிக்கை & தோட்டம்",
        "keywords": "குடிப்பது,குறைவு,விடுவது,மது,விட்ஜெட்,கடிகாரம்,தொடர்,நாள்,பதிவு,நாள்காட்டி,தனிப்பட்ட,மைல்கல்,ஏக்கம்,சுத்தமான",
    },
    "te-IN": {
        "name": "సోబర్ – పొడి రోజులు",
        "subtitle": "స్వచ్ఛత లెక్కింపు & తోట",
        "keywords": "తాగడం,తక్కువ,వదలడం,మద్యం,విడ్జెట్,గడియారం,సిరీస్,డైరీ,క్యాలెండర్,ప్రైవేట్,మద్యం,కోరిక,శుభ్రంగా",
    },
    # South-East Asian
    "th": {
        "name": "โซเบอร์ – วันแห้ง",
        "subtitle": "นับความกลับใจและสวน",
        "keywords": "ดื่ม,น้อย,เลิก,แอลกอฮอล์,วิดเจ็ต,นาฬิกา,สตรีค,ไดอารี่,ปฏิทิน,ส่วนตัว,หมุด,ถอย,ความอยาก,สะอาด",
    },
    "vi": {
        "name": "Sober – Ngày khô",
        "subtitle": "Đếm tỉnh táo & vườn",
        "keywords": "uống,ít,cai,rượu,widget,đồng,hồ,chuỗi,nhật,ký,lịch,riêng,tư,mốc,tái,nghiện,tham,muốn,sạch",
    },
    "id": {
        "name": "Sober – Hari kering",
        "subtitle": "Penghitung sadar & taman",
        "keywords": "minum,lebih,sedikit,berhenti,alkohol,widget,jam,rentetan,diari,kalender,pribadi,tonggak,kambuh,hasrat,bersih",
    },
    "ms": {
        "name": "Sober – Hari kering",
        "subtitle": "Kira sedar & taman",
        "keywords": "minum,kurang,berhenti,alkohol,widget,jam,rentetan,diari,kalendar,peribadi,tonggak,kambuh,hasrat,bersih",
    },
    # East Asian
    "ja": {
        "name": "ソーバー：乾いた日々",
        "subtitle": "禁酒カウンター＆ガーデン",
        "keywords": "飲む,減らす,断酒,アルコール,ウィジェット,ウォッチ,連続,日記,カレンダー,非公開,節目,再発,渇望,クリーン",
    },
    "ko": {
        "name": "소버 – 마른 날",
        "subtitle": "금주 카운터 & 정원",
        "keywords": "마시다,줄이다,끊다,알코올,위젯,워치,연속,일기,캘린더,비공개,이정표,재발,갈망,깨끗한",
    },
    "zh-Hans": {
        "name": "清醒 - 干燥天数",
        "subtitle": "清醒计数器与花园",
        "keywords": "喝,少点,戒掉,酒精,小组件,手表,连续,日记,日历,私密,里程碑,复发,渴望,干净",
    },
    "zh-Hant": {
        "name": "清醒 - 乾燥天數",
        "subtitle": "清醒計數器與花園",
        "keywords": "喝,少點,戒掉,酒精,小工具,手錶,連續,日記,日曆,私密,里程碑,復發,渴望,乾淨",
    },
    # Caucasian
    "ca": {
        "name": "Sober – Dies secs",
        "subtitle": "Comptador sobrietat & jardí",
        "keywords": "beure,menys,deixar,alcohol,widget,rellotge,racha,diari,calendari,privat,fita,recaiguda,desig,neta",
    },
}

# 3. Apply updates to the LOCALES dict
for locale, data in UPDATES.items():
    # Update name
    old_name_pattern = r'"' + re.escape(locale) + r'":\s*\{[^}]*?"name":\s*"[^"]*"'
    match = re.search(old_name_pattern, content)
    if match:
        # Update name line
        content = re.sub(
            r'(' + re.escape(locale) + r'":\s*\{.*?"name":\s*")[^"]*(")',
            r'\1' + data['name'] + r'\2',
            content
        )
        # Update subtitle line
        content = re.sub(
            r'(' + re.escape(locale) + r'":\s*\{.*?"subtitle":\s*")[^"]*(")',
            r'\1' + data['subtitle'] + r'\2',
            content
        )
        # Update keywords line
        content = re.sub(
            r'(' + re.escape(locale) + r'":\s*\{.*?"keywords":\s*")[^"]*(")',
            r'\1' + data['keywords'] + r'\2',
            content
        )
    else:
        print(f"WARNING: Locale '{locale}' not found in file")

# 4. Write back
with open('aso_native_metadata.py', 'w') as f:
    f.write(content)

# 5. Verify
print("=== VERIFICATION ===")
for locale in list(UPDATES.keys())[:5]:
    pattern = r'"' + re.escape(locale) + r'":\s*\{[^}]*?"name":\s*"([^"]+)"[^}]*?"subtitle":\s*"([^"]+)"[^}]*?"keywords":\s*"([^"]+)"'
    m = re.search(pattern, content)
    if m:
        name = m.group(1)
        subtitle = m.group(2)
        keywords = m.group(3)
        print(f"\n{locale}:")
        print(f"  Name ({len(name)}): {name}")
        print(f"  Subtitle ({len(subtitle)}): {subtitle}")
        print(f"  Keywords ({len(keywords)}): {keywords}")
        assert len(name) <= 30, f"Name too long: {len(name)}"
        assert len(subtitle) <= 30, f"Subtitle too long: {len(subtitle)}"
        assert len(keywords) <= 100, f"Keywords too long: {len(keywords)}"
        print(f"  ✓ All chars OK")
    else:
        print(f"\n{locale}: NOT FOUND")

# Check EN_DESCRIPTION
if "Dry day counter — see days" in content:
    print("\nEN_DESCRIPTION: ✓ Updated")
else:
    print("\nEN_DESCRIPTION: ✗ NOT UPDATED")

print("\nDone!")
