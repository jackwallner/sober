#!/usr/bin/env python3
"""Apply improved keyword strategy + drop 'garden' from subtitles across all 50 ASC locales.

Strategy (from US competitor research): remove low-intent dead weight (mood/duplicate
tokens), add higher-intent native terms (habit, journal/diary, app, day counter), and
replace 'garden' in localized subtitles with the native 'counter' form, mirroring en-US
('Dry Days: Sobriety Counter'). Titles are untouched.
"""
from __future__ import annotations

from pathlib import Path

META = Path("fastlane/metadata")

EN_KW = "countdown,habit,app,quit,drinking,drink,less,control,daily,check,log,time,cut,streak,recovery,diary"
EN_SUB = "Dry Days: Sobriety Counter"

# locale -> (subtitle, keywords)  — name.txt is left unchanged
DATA: dict[str, tuple[str, str]] = {
    "en-US": (EN_SUB, EN_KW),
    "en-GB": (EN_SUB, EN_KW),
    "en-AU": (EN_SUB, EN_KW),
    "en-CA": (EN_SUB, EN_KW),

    "de-DE": ("Trockene Tage: Zähler",
              "trinken,weniger,aufhören,entzug,nüchtern,erholung,abstinenz,rückfall,gewohnheit,tagebuch,app,streak"),
    "fr-FR": ("Jours secs : compteur",
              "boire,moins,arrêter,sevrage,abstinence,envie,rétablissement,rechute,habitude,journal,appli"),
    "fr-CA": ("Jours secs : compteur",
              "boire,moins,arrêter,sevrage,abstinence,envie,rétablissement,rechute,habitude,journal,appli"),
    "es-ES": ("Días secos: contador",
              "beber,menos,dejar,adicción,antojo,abstinencia,recuperación,sobriedad,recaída,hábito,diario,app"),
    "es-MX": ("Días secos: contador",
              "beber,menos,dejar,adicción,antojo,abstinencia,recuperación,sobriedad,recaída,hábito,diario,app"),
    "it":    ("Giorni secchi: contatore",
              "bere,meno,smettere,astinenza,dipendenza,recupero,ricaduta,voglia,craving,abitudine,diario,app"),
    "pt-BR": ("Dias secos: contador",
              "beber,menos,parar,dependência,abstinência,recuperação,recaída,vontade,hábito,diário,app"),
    "pt-PT": ("Dias secos: contador",
              "beber,menos,parar,dependência,abstinência,recuperação,recaída,vontade,hábito,diário,app"),
    "nl-NL": ("Droge dagen: teller",
              "stoppen,minder,drinken,verslaving,ontwenning,nuchter,herstel,terugval,gewoonte,dagboek,streak"),
    "sv":    ("Torra dagar: räknare",
              "dricka,mindre,sluta,beroende,abstinens,återhämtning,återfall,sug,vana,dagbok,streak"),
    "no":    ("Tørre dager: teller",
              "drikke,mindre,slutte,avhengighet,avholdenhet,bedring,tilbakefall,sug,vane,dagbok,streak"),
    "da":    ("Tørre dage: tæller",
              "drikke,mindre,stoppe,afhængighed,afholdenhed,bedring,tilbagefald,trang,vane,dagbog,streak"),
    "fi":    ("Kuivat päivät: laskuri",
              "juoda,vähemmän,lopettaa,riippuvuus,raittius,toipuminen,retkahdus,himo,tapa,päiväkirja,streak"),
    "pl":    ("Suche dni: licznik",
              "pić,mniej,przestać,uzależnienie,abstynencja,odwyk,nawrót,głód,nawyk,dziennik,app"),
    "cs":    ("Suché dny: počítadlo",
              "pít,méně,přestat,závislost,abstinence,zotavení,relaps,chuť,zvyk,deník,app"),
    "sk":    ("Suché dni: počítadlo",
              "piť,menej,prestať,závislosť,abstinencia,zotavenie,relaps,chuť,zvyk,denník,app"),
    "ru":    ("Сухие дни: счётчик",
              "пить,меньше,бросить,зависимость,воздержание,восстановление,срыв,тяга,привычка,дневник,трезвость"),
    "uk":    ("Сухі дні: лічильник",
              "пити,менше,кинути,залежність,утримання,одужання,зрив,тяга,звичка,щоденник,тверезість"),
    "ro":    ("Zile uscate: contor",
              "bea,puțin,opri,dependență,abstinență,recuperare,recădere,poftă,obicei,jurnal,app"),
    "hr":    ("Suhi dani: brojač",
              "piti,manje,prestati,ovisnost,apstinencija,oporavak,relaps,želja,navika,dnevnik,app"),
    "hu":    ("Száraz napok: számláló",
              "inni,kevesebb,abbahagy,függőség,elvonás,felépülés,visszaesés,vágy,szokás,napló,app"),
    "sl-SI": ("Suhi dnevi: števec",
              "piti,manj,nehati,odvisnost,abstinenca,okrevanje,povratek,hrepenenje,navada,dnevnik,app"),
    "el":    ("Ξηρές μέρες: μετρητής",
              "πίνω,λιγότερο,σταματώ,εξάρτηση,αποχή,ανάρρωση,υποτροπή,λαχτάρα,συνήθεια,ημερολόγιο,app"),
    "tr":    ("Kuru günler: sayaç",
              "içmek,az,bırakmak,bağımlılık,ayıklık,iyileşme,nüks,istek,alışkanlık,günlük,uygulama"),
    "ca":    ("Dies secs: comptador",
              "beure,menys,deixar,addicció,abstinència,recuperació,recaiguda,desig,hàbit,diari,app"),
    "id":    ("Hari kering: penghitung",
              "minum,sedikit,berhenti,kecanduan,pantang,pemulihan,kambuh,hasrat,kebiasaan,jurnal,streak"),
    "ms":    ("Hari kering: pembilang",
              "minum,kurang,berhenti,ketagihan,pantang,pemulihan,kambuh,hasrat,tabiat,jurnal,streak"),
    "vi":    ("Ngày khô: bộ đếm",
              "uống,ít,cai,nghiện,kiêng,phục hồi,tái phát,thèm,thói quen,nhật ký,streak"),
    "th":    ("วันแห้ง: ตัวนับ",
              "ดื่ม,น้อย,เลิก,ติดเหล้า,ฟื้นตัว,อยาก,นิสัย,ไดอารี,เลิกเหล้า,streak"),
    "ja":    ("ドライデイズ：カウンター",
              "飲む,減らす,禁酒,依存,断酒,回復,再発,渇望,習慣,日記,アプリ"),
    "ko":    ("마른 날: 카운터",
              "마시다,줄이다,끊다,중독,절주,회복,재발,갈망,습관,일기,앱"),
    "zh-Hans": ("干燥天数：计数器",
              "喝,戒酒,少喝,上瘾,戒断,恢复,复发,渴望,习惯,日记,打卡"),
    "zh-Hant": ("乾燥天數：計數器",
              "喝,戒酒,少喝,上癮,戒斷,恢復,復發,渴望,習慣,日記,打卡"),
    "ar-SA": ("أيام جافة: العدّاد",
              "شرب,أقل,إقلاع,إدمان,امتناع,تعافي,انتكاسة,شهوة,عادة,يوميات,تطبيق"),
    "he":    ("ימים יבשים: מונה",
              "שתייה,פחות,הפסקה,התמכרות,התנזרות,החלמה,נפילה,תשוקה,הרגל,יומן,אפליקציה"),
    "hi":    ("सूखे दिन: काउंटर",
              "पीना,कम,छोड़ना,लत,संयम,सुधार,पुनरावृत्ति,लालसा,आदत,डायरी,ऐप"),
    "bn-BD": ("শুষ্ক দিন: গণনা",
              "পান,কম,ত্যাগ,আসক্তি,সংযম,পুনরুদ্ধার,পুনরাবৃত্তি,লালসা,অভ্যাস,ডায়েরি,অ্যাপ"),
    "gu-IN": ("સૂકા દિવસ: કાઉન્ટર",
              "પીવું,ઓછું,છોડવું,વ્યસન,ત્યાગ,પુનઃપ્રાપ્તિ,પુનરાવર્તન,તૃષ્ણા,આદત,ડાયરી,એપ"),
    "kn-IN": ("ಒಣ ದಿನಗಳು: ಕೌಂಟರ್",
              "ಕುಡಿಯುವುದು,ಕಡಿಮೆ,ಬಿಡುವುದು,ಚಟ,ಸಂಯಮ,ಚೇತರಿಕೆ,ಮರುಕಳಿಕೆ,ಹಂಬಲ,ಅಭ್ಯಾಸ,ಡೈರಿ,ಆಪ್"),
    "ml-IN": ("ഉണങ്ങിയ ദിനങ്ങൾ: കൗണ്ടർ",
              "കുടിക്കൽ,കുറവ്,നിർത്തൽ,ആസക്തി,വർജനം,വീണ്ടെടുക്കൽ,വീഴ്ച,ആഗ്രഹം,ശീലം,ഡയറി,ആപ്പ്"),
    "mr-IN": ("कोरडे दिवस: काउंटर",
              "पिणे,कमी,सोडणे,व्यसन,त्याग,पुनर्प्राप्ती,पुनरावृत्ती,तळमळ,सवय,डायरी,अॅप"),
    "or-IN": ("ଶୁଷ୍କ ଦିନ: ଗଣନା",
              "ପିଇବା,କମ,ଛାଡିବା,ଆସକ୍ତି,ବିରତି,ପୁନରୁଦ୍ଧାର,ପୁନରାବୃତ୍ତି,ଲାଳସା,ଅଭ୍ୟାସ,ଡାଇରୀ,ଆପ୍"),
    "pa-IN": ("ਸੁੱਕੇ ਦਿਨ: ਕਾਊਂਟਰ",
              "ਪੀਣਾ,ਘੱਟ,ਛੱਡਣਾ,ਆਦੀ,ਸੰਜਮ,ਬਰਾਮਦਗੀ,ਮੁੜ ਆਉਣਾ,ਤਰਸ,ਆਦਤ,ਡਾਇਰੀ,ਐਪ"),
    "ta-IN": ("உலர் நாட்கள்: கவுண்டர்",
              "குடிப்பது,குறைவு,விடுவது,அடிமைத்தனம்,தவிர்ப்பு,மீட்பு,மீள்தொற்று,ஏக்கம்,பழக்கம்,டைரி,ஆப்"),
    "te-IN": ("ఎండిన రోజులు: కౌంటర్",
              "తాగడం,తక్కువ,వదలడం,వ్యసనం,సంయమం,పునరుద్ధరణ,పునరావృత్తి,కోరిక,అలవాటు,డైరీ,యాప్"),
    "ur-PK": ("خشک دن: کاؤنٹر",
              "پینا,کم,چھوڑنا,نشہ,پرہیز,بحالی,دوبارہ لگنا,آرزو,عادت,ڈائری,ایپ"),
}


def main() -> int:
    errs = 0
    changed = 0
    for loc, (sub, kw) in sorted(DATA.items()):
        d = META / loc
        if not d.is_dir():
            print(f"MISSING DIR {loc}")
            errs += 1
            continue
        if len(sub) > 30:
            print(f"SUB OVER {len(sub)}/30 {loc}: {sub}")
            errs += 1
        if len(kw) > 100:
            print(f"KW OVER  {len(kw)}/100 {loc}: {kw}")
            errs += 1
        # dedupe guard: no token may repeat a word already in name/subtitle
        name = (d / "name.txt").read_text(encoding="utf-8").strip().lower()
        avoid = set(name.replace("-", " ").replace(":", " ").replace("–", " ").split()) \
            | set(sub.lower().replace(":", " ").replace("&", " ").split())
        toks = [t.strip() for t in kw.split(",")]
        dupes = [t for t in toks if t.lower() in avoid]
        if dupes:
            print(f"KW REPEATS name/sub {loc}: {dupes}")
    if errs:
        print(f"\n{errs} hard errors — not writing.")
        return 1
    for loc, (sub, kw) in sorted(DATA.items()):
        d = META / loc
        (d / "subtitle.txt").write_text(sub + "\n", encoding="utf-8")
        (d / "keywords.txt").write_text(kw + "\n", encoding="utf-8")
        changed += 1
        print(f"OK {loc:7} sub {len(sub):2}/30  kw {len(kw):3}/100")
    print(f"\nWrote {changed} locales.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
