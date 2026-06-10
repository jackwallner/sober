#!/usr/bin/env python3
"""Regenerate aso_native_metadata.py with corrected strategy:

Name:     "Alcohol Free" for title-weight dominance over "alcohol free *" queries
Subtitle: "Dry Days" (pop 8/diff 44 — best indie-winnable term) + "Garden" differentiator
Keywords: Only pop >= 6 tokens not in name/subtitle. Combo fuel, not primary drivers.
"""

import re, json

# Read current file
with open('aso_native_metadata.py', 'r') as f:
    content = f.read()

# ── 1. Fix EN_DESCRIPTION ──
content = content.replace(
    "Sober Tracker helps you track dry days",
    "Sober Tracker helps you stay alcohol free"
)
content = content.replace(
    "• Dry day counter — see days, hours, and your longest streak",
    "• Alcohol-free day counter — see days, hours, and your longest streak"
)

# ── 2. New locale data ──
# Name: localized "Alcohol Free Tracker" (title weight for all "alcohol free *" queries)
# Subtitle: localized "Dry Days & Garden" (indie-winnable pop 8/diff 44 term + differentiator)
# Keywords: only pop>=6 tokens not in name/subtitle. EN base set:
#   drink,less,quit,recovery,streak,widget,watch,journal,calendar,private,milestone

EN_KW = "drink,less,quit,recovery,streak,widget,watch,journal,calendar,private,milestone"

LOCALES = {
    "en-US": ("Sober Tracker - Alcohol Free", "Dry Days Counter & Garden", EN_KW),
    "en-GB": ("Sober Tracker - Alcohol Free", "Dry Days Counter & Garden", EN_KW),
    "en-AU": ("Sober Tracker - Alcohol Free", "Dry Days Counter & Garden", EN_KW),
    "en-CA": ("Sober Tracker - Alcohol Free", "Dry Days Counter & Garden", EN_KW),
    "de-DE": ("Sober: Alkoholfrei Tracker", "Trockene Tage & Garten", "trinken,weniger,aufhören,sucht,serie,widget,uhr,tagebuch,kalender,privat,meilenstein"),
    "fr-FR": ("Sober – Sans alcool", "Jours secs & jardin", "boire,moins,arrêter,rétablissement,widget,montre,série,journal,calendrier,privé,jalon"),
    "fr-CA": ("Sober – Sans alcool", "Jours secs et jardin", "boire,moins,arrêter,rétablissement,widget,montre,série,journal,calendrier,privé,jalon"),
    "es-ES": ("Sober – Sin alcohol", "Días secos y jardín", "beber,menos,dejar,recuperación,widget,reloj,racha,diario,calendario,privado,hito"),
    "es-MX": ("Sober – Sin alcohol", "Días secos y jardín", "beber,menos,dejar,recuperación,widget,reloj,racha,diario,calendario,privado,hito"),
    "ca": ("Sober – Sense alcohol", "Dies secs i jardí", "beure,menys,deixar,recuperació,widget,rellotge,diari,calendari,privat,fita"),
    "it": ("Sober – Senza alcol", "Giorni secchi e giardino", "bere,meno,smettere,recupero,widget,orologio,serie,diario,calendario,privato,pietra"),
    "nl-NL": ("Sober – Alcoholvrij", "Droge dagen en tuin", "stoppen,minder,drinken,herstel,widget,horloge,reeks,dagboek,kalender,privé,mijlpaal"),
    "pt-BR": ("Sober – Sem Álcool", "Dias secos e jardim", "beber,menos,parar,recuperação,widget,relógio,sequência,diário,calendário,privado,marco"),
    "pt-PT": ("Sober – Sem Álcool", "Dias secos e jardim", "beber,menos,parar,recuperação,widget,relógio,sequência,diário,calendário,privado,marco"),
    "pl": ("Sober – Bez alkoholu", "Suche dni i ogród", "pić,mniej,przestać,odwyk,widget,zegarek,seria,dziennik,kalendarz,prywatny,kamień"),
    "sv": ("Sober – Alkoholfri", "Torra dagar och trädgård", "dricka,mindre,sluta,återhämtning,widget,klocka,dagbok,kalender,privat,milstolpe"),
    "da": ("Sober – Alkoholfri", "Tørre dage og have", "drikke,mindre,stoppe,bedring,widget,ur,dagbog,kalender,privat,milepæl"),
    "no": ("Sober – Alkoholfri", "Tørre dager og hage", "drikke,mindre,slutte,bedring,widget,klokke,dagbok,kalender,privat,milepæl"),
    "fi": ("Sober – Alkoholiton", "Kuivat päivät ja puutarha", "juoda,vähemmän,lopettaa,toipuminen,widget,kello,päiväkirja,kalenteri,yksityinen,virstanpylväs"),
    "cs": ("Sober – Bez alkoholu", "Suché dny a zahrada", "pít,méně,přestat,zotavení,widget,hodinky,série,deník,kalendář,soukromý,milník"),
    "sk": ("Sober – Bez alkoholu", "Suché dni a záhrada", "piť,menej,prestať,zotavenie,widget,hodinky,séria,denník,kalendár,súkromný,míľnik"),
    "hu": ("Sober – Alkoholmentes", "Száraz napok és kert", "inni,kevesebb,abbahagy,felépülés,widget,óra,sorozat,napló,naptár,privát,mérföldkő"),
    "ro": ("Sober – Fără alcool", "Zile uscate și grădină", "bea,puțin,opri,recuperare,widget,ceas,serie,jurnal,calendar,privat,prag"),
    "hr": ("Sober – Bez alkohola", "Suhi dani i vrt", "piti,manje,prestati,oporavak,widget,sat,niz,dnevnik,kalendar,privatno,kamen"),
    "el": ("Sober – Χωρίς αλκοόλ", "Ξηρές μέρες και κήπος", "ποτό,λιγότερο,σταμάτημα,widget,ρολόι,σειρά,ημερολόγιο,ιδιωτικό,ορόσημο"),
    "sl-SI": ("Sober – Brez alkohola", "Suhi dnevi in vrt", "piti,manj,nehati,okrevanje,widget,ura,niz,dnevnik,koledar,zasebno,mejnik"),
    "tr": ("Sober – Alkolsüz", "Kuru günler ve bahçe", "içmek,az,bırakmak,iyileşme,widget,saat,seri,günlük,takvim,özel,dönüm"),
    "ru": ("Sober – Без алкоголя", "Сухие дни и сад", "пить,меньше,бросить,восстановление,виджет,часы,серия,дневник,календарь,приват,веха"),
    "uk": ("Sober – Без алкоголю", "Сухі дні та сад", "пити,менше,кинути,одужання,віджет,годинник,серія,щоденник,календар,приват,віха"),
    "ar-SA": ("سوبر – بلا كحول", "أيام جافة وحديقة", "إقلاع,شرب,تعافي,ودجت,ساعة,سلسلة,يوميات,تقويم,خاص,معلم"),
    "he": ("סובר – נטול אלכוהול", "ימים יבשים וגינה", "הפסקה,שתייה,החלמה,ווידג'ט,שעון,רצף,יומן,לוח,פרטי,אבן"),
    "hi": ("सोबर – शराब मुक्त", "सूखे दिन और बगीचा", "पीना,कम,छोड़ना,सुधार,विजेट,घड़ी,स्ट्रीक,डायरी,कैलेंडर,निजी,मीलपत्थर"),
    "bn-BD": ("সোবার – মদ ছাড়া", "শুষ্ক দিন ও বাগান", "পান,কম,ছাড়া,পুনরুদ্ধার,উইজেট,ঘড়ি,ধারা,ডায়েরি,ক্যালেন্ডার,ব্যক্তিগত,প্রান্তিক"),
    "gu-IN": ("સોબર – દારૂ મુક્ત", "સૂકા દિવસ અને બગીચો", "પીવું,ઓછું,છોડવું,પુનઃપ્રાપ્તિ,વિજેટ,ઘડિયાળ,શ્રેણી,ડાયરી,કેલેન્ડર,ખાનગી,માઇલસ્ટોન"),
    "kn-IN": ("ಸೋಬರ್ – ಮದ್ಯಮುಕ್ತ", "ಒಣ ದಿನಗಳು ಮತ್ತು ತೋಟ", "ಕುಡಿಯುವುದು,ಕಡಿಮೆ,ಬಿಡುವುದು,ಚೇತರಿಕೆ,ವಿಜೆಟ್,ಗಡಿಯಾರ,ಸರಣಿ,ದಿನಚರಿ,ಕ್ಯಾಲೆಂಡರ್,ಖಾಸಗಿ,ಮೈಲ್ಸ್ಟೋನ್"),
    "ml-IN": ("സോബർ – മദ്യമുക്ത", "ഉണങ്ങിയ ദിവസങ്ങളും തോട്ടവും", "കുടിക്കൽ,കുറവ്,നിർത്തൽ,വീണ്ടെടുക്കൽ,വിജറ്റ്,വാച്ച്,സീരീസ്,ഡയറി,കലണ്ടർ,സ്വകാര്യം,മൈൽസ്റ്റോൺ"),
    "mr-IN": ("सोबर – दारूमुक्त", "कोरडे दिवस आणि बाग", "पिणे,कमी,सोडणे,पुनर्प्राप्ती,विजेट,घड्याळ,मालिका,डायरी,कॅलेंडर,खाजगी,मैलाचा"),
    "or-IN": ("ସୋବର – ମଦ୍ୟମୁକ୍ତ", "ଶୁଷ୍କ ଦିନ ଓ ବଗିଚା", "ପିଇବା,କମ,ଛାଡିବା,ପୁନରୁଦ୍ଧାର,ୱିଜେଟ,ଘଣ୍ଟା,ଧାରା,ଡାଇରି,କ୍ୟାଲେଣ୍ଡର,ବ୍ୟକ୍ତିଗତ"),
    "pa-IN": ("ਸੋਬਰ – ਸ਼ਰਾਬ ਮੁਕਤ", "ਸੁੱਕੇ ਦਿਨ ਅਤੇ ਬਾਗ", "ਪੀਣਾ,ਘੱਟ,ਛੱਡਣਾ,ਬਰਾਮਦਗੀ,ਵਿਜੇਟ,ਘੜੀ,ਲੜੀ,ਡਾਇਰੀ,ਕੈਲੰਡਰ,ਨਿੱਜੀ,ਮੀਲਪੱਥਰ"),
    "ta-IN": ("சோபர் – மதுவிலா", "உலர் நாட்கள் மற்றும் தோட்டம்", "குடிப்பது,குறைவு,விடுவது,மீட்பு,விட்ஜெட்,கடிகாரம்,தொடர்,நாள்,பதிவு,நாள்காட்டி,தனிப்பட்ட,மைல்கல்"),
    "te-IN": ("సోబర్ – మద్యముక్త", "ఎండిన రోజులు మరియు తోట", "తాగడం,తక్కువ,వదలడం,పునరుద్ధరణ,విడ్జెట్,గడియారం,సిరీస్,డైరీ,క్యాలెండర్,ప్రైవేట్"),
    "th": ("โซเบอร์ – ไร้แอลกอฮอล์", "วันแห้งและสวน", "ดื่ม,น้อย,เลิก,ฟื้นตัว,วิดเจ็ต,นาฬิกา,สตรีค,ไดอารี่,ปฏิทิน,ส่วนตัว,หมุด"),
    "vi": ("Sober – Không cồn", "Ngày khô và vườn", "uống,ít,cai,phục,hồi,widget,đồng,hồ,nhật,ký,lịch,riêng,tư"),
    "id": ("Sober – Bebas Alkohol", "Hari kering dan taman", "minum,sedikit,berhenti,pemulihan,widget,jam,rentetan,diari,kalender,pribadi,tonggak"),
    "ms": ("Sober – Bebas Alkohol", "Hari kering dan taman", "minum,kurang,berhenti,pemulihan,widget,jam,rentetan,diari,kalendar,peribadi,tonggak"),
    "ja": ("ソーバー：アルコールフリー", "ドライデイズとガーデン", "飲む,減らす,禁酒,ウィジェット,ウォッチ,連続,日記,カレンダー,非公開,節目"),
    "ko": ("소버 – 무알코올", "마른 날과 정원", "마시다,줄이다,끊다,위젯,워치,연속,일기,캘린더,비공개,이정표"),
    "zh-Hans": ("清醒助手 - 无酒精", "干燥天数与花园", "喝,戒酒,少喝,恢复,小组件,手表,连续,日记,日历,私密,里程碑"),
    "zh-Hant": ("清醒助手 - 無酒精", "乾燥天數與花園", "喝,戒酒,少喝,恢復,小工具,手錶,連續,日記,日曆,私密,里程碑"),
    "ur-PK": ("سوبر – شراب سے پاک", "خشک دن اور باغ", "پینا,کم,چھوڑنا,بحالی,وجیٹ,گھڑی,سلسلہ,ڈائری,کیلنڈر,نجی"),
}

# ── 3. Apply updates ──
for locale, (name, subtitle, keywords) in LOCALES.items():
    # Escape locale key
    esc = re.escape(locale)
    
    def make_replacer(field, new_val):
        def replacer(m):
            block = m.group(1)
            block = re.sub(rf'("{field}":\s*)"[^"]*"', f'\\1"{new_val}"', block)
            return block
        return replacer
    
    content = re.sub(
        rf'("{locale}"\s*:\s*{{[^}}]*?"name":\s*"[^"]*"[^}}]*?"subtitle":\s*"[^"]*"[^}}]*?"keywords":\s*"[^"]*")',
        make_replacer("name", name),
        content
    )
    content = re.sub(
        rf'("{locale}"\s*:\s*{{[^}}]*?"name":\s*"[^"]*"[^}}]*?"subtitle":\s*"[^"]*"[^}}]*?"keywords":\s*"[^"]*")',
        make_replacer("subtitle", subtitle),
        content
    )
    content = re.sub(
        rf'("{locale}"\s*:\s*{{[^}}]*?"name":\s*"[^"]*"[^}}]*?"subtitle":\s*"[^"]*"[^}}]*?"keywords":\s*"[^"]*")',
        make_replacer("keywords", keywords),
        content
    )

with open('aso_native_metadata.py', 'w') as f:
    f.write(content)

# ── 4. Verify ──
errors = []
pattern = r'"([a-z]{2}(?:-[A-Z]{2})?)"\s*:\s*\{[^}]*?"name":\s*"([^"]+)"[^}]*?"subtitle":\s*"([^"]+)"[^}]*?"keywords":\s*"([^"]+)"'
matches = re.findall(pattern, content)
# Also match zh-* and other non-standard patterns
pattern2 = r'"([^"]{2,10})"\s*:\s*\{[^}]*?"name":\s*"([^"]+)"[^}]*?"subtitle":\s*"([^"]+)"[^}]*?"keywords":\s*"([^"]+)"'
all_matches = re.findall(pattern2, content)

seen = set()
for locale, name, subtitle, keywords in all_matches:
    if locale in seen or locale == "LOCALES":
        continue
    seen.add(locale)
    
    # Validate lengths
    if len(name) > 30:
        errors.append(f"{locale}: NAME OVERFLOW ({len(name)}): {name}")
    if len(subtitle) > 30:
        errors.append(f"{locale}: SUBTITLE OVERFLOW ({len(subtitle)}): {subtitle}")
    if len(keywords) > 100:
        errors.append(f"{locale}: KEYWORDS OVERFLOW ({len(keywords)}): {keywords}")
    
    # Check for duplicates between name/subtitle and keywords
    name_tokens = set(name.lower().replace('-',' ').replace('–',' ').replace('—',' ').replace(':',' ').replace('&','').split())
    sub_tokens = set(subtitle.lower().replace('-',' ').replace('–',' ').replace('—',' ').replace(':',' ').replace('&','').split())
    kw_tokens = set(keywords.lower().split(','))
    dupes = name_tokens.union(sub_tokens) & kw_tokens
    if dupes:
        errors.append(f"{locale}: DUPLICATES in keywords: {dupes}")
    
    # Verify no 5-pop token waste
    # (We can't verify Astro pop from here, but at least check no single letters)
    for t in keywords.split(','):
        if len(t.strip()) <= 1:
            errors.append(f"{locale}: single-char keyword token: '{t}'")
    
    print(f"{locale:15s} n=({len(name):2d}){name[:28]:28s} s=({len(subtitle):2d}){subtitle[:28]:28s} k=({len(keywords):3d})")

# Verify EN_DESCRIPTION
if "alcohol free" in content.split('EN_DESCRIPTION')[1].split('"""')[0]:
    print("\n✓ EN_DESCRIPTION updated (alcohol free)")
else:
    errors.append("EN_DESCRIPTION not properly updated")

if errors:
    print(f"\n=== {len(errors)} ERRORS ===")
    for e in errors:
        print(f"  ✗ {e}")
    import sys; sys.exit(1)
else:
    print(f"\n✓ All {len(seen)} locales valid!")
