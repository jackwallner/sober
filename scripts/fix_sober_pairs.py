#!/usr/bin/env python3
"""Find valid title/subtitle pairs (>24, ≤30, zero overlap, kw≥94) per locale."""
from __future__ import annotations

import sys
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPTS))

from build_sober_locale_aso_spec import LOCALE_POOLS, NATIVE_SUBTITLES, NATIVE_TITLES  # noqa: E402
from pack_sober_keywords import (  # noqa: E402
    pack_keywords,
    title_subtitle_overlap,
    validate_packed_keywords,
    validate_title_subtitle,
)

# Curated non-overlapping subtitle alternatives (counter/garden/sobriety — no alcohol/days repeat).
SUB_ALT: dict[str, list[str]] = {
    "de-DE": ["Nüchternheitszähler & Garten", "Abstinenz-Zähler & Garten", "Zähler für nüchtern & Garten"],
    "fr-FR": ["Compteur sobriété & jardin", "Compteur abstinence & jardin", "Sobriété compteur & jardin"],
    "fr-CA": ["Compteur sobriété & jardin", "Compteur abstinence & jardin"],
    "es-ES": ["Contador sobriedad & jardín", "Recuperación & jardín virtual", "Contador abstinencia & jardín"],
    "es-MX": ["Contador sobriedad & jardín", "Recuperación & jardín virtual"],
    "it": ["Contatore sobrietà & giardino", "Contatore astinenza & giardino", "Recupero & giardino virtuale"],
    "pt-BR": ["Contador recuperação & jardim", "Contador abstinência & jardim", "Sobriedade & jardim virtual"],
    "pt-PT": ["Contador recuperação & jardim", "Contador abstinência & jardim"],
    "nl-NL": ["Nuchterheidsmeter & tuin", "Abstinentieteller & tuin", "Herstelteller & virtuele tuin"],
    "pl": ["Licznik trzeźwości & ogród", "Licznik abstynencji & ogród", "Licznik wolny & ogród"],
    "sv": ["Nykterhetsmätare & trädgård", "Abstinensräknare & trädgård", "Återhämtning & trädgård"],
    "da": ["Ædruhedstæller & have", "Abstinenstæller & have", "Genopretning & virtuel have"],
    "no": ["Edru dagteller & hage", "Abstinensteller & hage", "Gjenoppretting & hage"],
    "fi": ["Raittiuslaskuri & puutarha", "Abstinenssilaskuri & puutarha", "Toipumislaskuri & puutarha"],
    "cs": ["Počítadlo abstinence & zahrada", "Počítadlo zotavení & zahrada"],
    "sk": ["Počítadlo abstinencie & záhrada", "Počítadlo zotavenia & záhrada"],
    "hr": ["Brojač abstinencije & vrt", "Brojač oporavka & vrt"],
    "sl-SI": ["Števec abstinence & vrt", "Števec okrevanja & vrt"],
    "hu": ["Mérsékletességmérő & kert", "Abstinencia-számláló & kert"],
    "ro": ["Contor recuperare & grădină", "Contor abstinență & grădină"],
    "ru": ["Счётчик трезвости & сад", "Счётчик воздержания & сад"],
    "uk": ["Лічильник тверезості & сад", "Лічильник утримання & сад"],
    "el": ["Μετρητής αποχής & κήπος", "Μετρητής αποκατάστασης & κήπος"],
    "tr": ["Bağımlılık sayacı & bahçe", "İyileşme sayacı & bahçe"],
    "ca": ["Comptador abstinència & jardí", "Comptador recuperació & jardí"],
    "id": ["Hitung pemulihan & taman", "Penghitung abstinensi & taman"],
    "ms": ["Kira pemulihan & taman", "Pembilang abstinensi & taman"],
    "vi": ["Đếm kiêng rượu & vườn", "Đếm phục hồi & vườn ảo"],
    "th": ["นับการฟื้นตัว & สวนเสมือน", "นับงดเหล้า & สวนเสมือน"],
    "ar-SA": ["عداد التعافي & حديقة", "عداد الامتناع & حديقة"],
    "he": ["מונה התאוששות & גן", "מונה התמכרות & גן"],
    "ja": [
        "無アルコール日数カウンター・バーチャル庭園SOBER版",
        "日数カウンター・バーチャル庭園成長アプリAPP",
        "無アルコール日数カウンター・バーチャル庭園アプリ",
    ],
    "ko": [
        "무알코올 프리 일수 카운터 & 정원 성장",
        "금주 일수 카운터 & 가상 정원 성장",
        "무알코올 일수 카운터 & 가상 정원앱",
    ],
    "zh-Hans": [
        "无酒精日计数器・虚拟花园成长应用助手APP",
        "无酒精日计数器・虚拟花园成长应用助手版",
        "无酒精日计数器与虚拟花园成长应用版",
    ],
    "zh-Hant": [
        "無酒精日計數器・虛擬花園成長應用助手APP",
        "無酒精日計數器・虛擬花園成長應用助手版",
    ],
    "hi": ["मद्यमुक्त गिनती & बगीचा", "अनुशासन गिनती & बगीचा"],
    "bn-BD": ["মদমুক্ত গণনা & বাগান", "সংযম গণনা & বাগান"],
    "ta-IN": ["மது இல்லா எண்ணிக்கை & தோட்டம்", "தவிர்ப்பு எண்ணிக்கை & தோட்டம்"],
    "te-IN": ["మద్యముక్త లెక్క & తోట", "సంయమ లెక్క & తోట"],
    "mr-IN": ["दारूमुक्त मोजणी & बाग", "संयम मोजणी & बाग"],
    "gu-IN": ["મદ્યમુક્ત ગણતરી & બગીચો", "સંયમ ગણતરી & બગીચો"],
    "kn-IN": ["ಮದ್ಯಮುಕ್ತ ಎಣಿಕೆ & ತೋಟ", "ಸಂಯಮ ಎಣಿಕೆ & ತೋಟ"],
    "ml-IN": ["മദ്യമുക്ത എണ്ണം & തോട്ടം", "സംയമ എണ്ണം & തോട്ടം"],
    "pa-IN": ["ਸ਼ਰਾਬ ਮੁਕਤ ਗਿਣਤੀ & ਬਾਗ", "ਸੰਜਮ ਗਿਣਤੀ & ਬਾਗ"],
    "or-IN": ["ମଦ୍ୟମୁକ୍ତ ଗଣନା & ବଗିଚା", "ସଂଯମ ଗଣନା & ବଗିଚା"],
    "ur-PK": ["شراب سے پاک گنتی & باغ", "پرہیز گنتی & باغ"],
}

TITLE_ALT: dict[str, list[str]] = {
    "de-DE": ["Alkohol stoppen: Trockene Tage", "Alkohol aufhören: Trinken stop"],
    "bn-BD": ["মদ ছাড়ুন – শুষ্ক দিন ট্র্যাক", "মদ ছাড়ুন – শুষ্ক দিন অ্যাপ"],
    "ml-IN": ["മദ്യം നിർത്തുക – ഉണങ്ങിയ ദിവസം", "മദ്യം നിർത്തുക – ഉണങ്ങിയ ദിവസ"],
    "ta-IN": ["மது விடு – உலர் நாட்கள்", "மது விடு – உலர் நாள் டிராக்கர்"],
    "ja": [
        "禁酒アルコールフリー｜ドライデイ追跡アプリツール",
        "禁酒アルコールフリー｜ドライデイ追跡アプリAPP",
        "禁酒・アルコールフリー｜ドライデイ追跡版",
    ],
    "ko": [
        "금주 알코올 프리 드라이데이 추적 프로그램",
        "금주 알코올 프리 드라이데이 추적 앱",
        "금주 알코올 프리｜드라이데이 추적앱",
    ],
    "zh-Hans": [
        "戒酒助手｜干酒日酒精戒断追踪应用助手APP",
        "戒酒助手｜干酒日酒精戒断追踪与应用版",
    ],
    "zh-Hant": [
        "戒酒助手｜干酒日酒精戒斷追蹤應用助手APP",
        "戒酒助手｜干酒日酒精戒斷追蹤與應用版",
    ],
    "cs": ["Přestaň pít: Suché dny & app", "Přestaň pít: Suché dny tracker"],
    "sk": ["Prestaň piť: Suché dni & app", "Prestaň piť: Suché dni tracker"],
    "hr": ["Prestani piti: Suhi dani & app", "Prestani piti: Suhi dani trk"],
    "sl-SI": ["Nehaj piti: Suhi dnevi & app", "Nehaj piti: Suhi dnevi trk"],
    "pl": ["Rzuć alkohol: Suche dni & app", "Rzuć alkohol: Suche dni trk"],
    "pt-BR": ["Parar álcool: Dias secos & app", "Parar álcool: Dias secos trk"],
    "pt-PT": ["Parar álcool: Dias secos & app", "Parar álcool: Dias secos trk"],
    "th": ["เลิกแอลกอฮอล์: วันแห้ง & app", "เลิกดื่ม: วันแห้ง & ติดตาม"],
    "uk": ["Кинь алкоголь: Сухі дні & app", "Кинь алкоголь: Сухі дні trk"],
    "vi": ["Bỏ rượu: Ngày khô & theo dõi", "Bỏ rượu: Ngày khô & ứng dụng"],
    "ar-SA": ["إقلاع الكحول: أيام جافة & تطبيق", "إقلاع الكحول: أيام صحية"],
}


def valid(loc: str, title: str, subtitle: str) -> tuple[bool, list[str]]:
    pool = LOCALE_POOLS.get(loc, LOCALE_POOLS["en-US"])
    errs = validate_title_subtitle(loc, title, subtitle)
    ol = title_subtitle_overlap(title, subtitle)
    if ol:
        errs.append(f"overlap {ol}")
    kw = pack_keywords(title, subtitle, pool)
    errs.extend(validate_packed_keywords(loc, kw))
    if len(kw) < 94:
        errs.append(f"kw {len(kw)}")
    if len(title) <= 24:
        errs.append(f"t {len(title)}")
    if len(subtitle) <= 24:
        errs.append(f"s {len(subtitle)}")
    return not errs, errs


def main() -> int:
    fixes: dict[str, tuple[str, str]] = {}
    failures: list[str] = []

    for loc in sorted(NATIVE_TITLES):
        titles = [NATIVE_TITLES[loc]] + TITLE_ALT.get(loc, [])
        subs = [NATIVE_SUBTITLES.get(loc, "")] + SUB_ALT.get(loc, [])
        found = False
        for t in titles:
            for s in subs:
                if not t or not s:
                    continue
                ok, errs = valid(loc, t, s)
                if ok:
                    fixes[loc] = (t, s)
                    found = True
                    break
            if found:
                break
        if not found:
            failures.append(f"{loc}: best attempt {errs}")

    print("FIXES:")
    for loc, (t, s) in sorted(fixes.items()):
        print(f"  {loc!r}: ({t!r}, {s!r}),")
    if failures:
        print("\nFAILURES:")
        for f in failures:
            print(f)
        return 1
    print(f"\n{len(fixes)}/{len(NATIVE_TITLES)} OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
