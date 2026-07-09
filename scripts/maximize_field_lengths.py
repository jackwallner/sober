#!/usr/bin/env python3
"""Push title/subtitle >24 chars (≤30) and keywords ≥94 for all 50 Sober locales."""
from __future__ import annotations

import re
import sys
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPTS))

from pack_sober_keywords import (  # noqa: E402
    US_EN_CANDIDATES,
    pack_keywords,
    validate_packed_keywords,
    validate_title_subtitle,
    title_subtitle_overlap,
)

EN_TITLE = "Sober Tracker - Alcohol Free"
EN_SUBTITLE = "Dry Days, Sobriety & Garden"

MAX_TITLES: dict[str, str] = {
    "en-US": EN_TITLE,
    "en-GB": EN_TITLE,
    "en-CA": EN_TITLE,
    "en-AU": EN_TITLE,
    "de-DE": "Alkohol stoppen: Trockene Tage",
    "fr-FR": "Arrêter alcool: Jours secs",
    "fr-CA": "Arrêter alcool: Jours secs",
    "es-ES": "Dejar alcohol: Días secos",
    "es-MX": "Dejar alcohol: Días secos",
    "it": "Smetti alcol: Giorni secchi",
    "pt-BR": "Parar álcool: Dias secos & app",
    "pt-PT": "Parar álcool: Dias secos & app",
    "nl-NL": "Stop met drinken: Droge dagen",
    "pl": "Rzuć alkohol: Suche dni & app",
    "sv": "Sluta dricka: Torra dagar",
    "da": "Stop med alkohol: Tørre dage",
    "no": "Slutt med alkohol: Tørre dager",
    "fi": "Lopeta alkoholi: Kuivat päivät",
    "cs": "Přestaň pít: Suché dny & app",
    "sk": "Prestaň piť: Suché dni & app",
    "hr": "Prestani piti: Suhi dani & app",
    "sl-SI": "Nehaj piti: Suhi dnevi & app",
    "hu": "Alkohol abbahagy: Száraz napok",
    "ro": "Oprește alcool: Zile uscate",
    "ru": "Брось алкоголь: Сухие дни",
    "uk": "Кинь алкоголь: Сухі дні & app",
    "el": "Σταμάτα αλκοόλ: Ξηρές μέρες",
    "tr": "Bırak alkol: Kuru günler & app",
    "ca": "Deixa l'alcohol: Dies secs",
    "id": "Berhenti alkohol: Hari kering",
    "ms": "Berhenti alkohol: Hari kering",
    "vi": "Bỏ rượu: Ngày khô & theo dõi",
    "th": "เลิกแอลกอฮอล์: วันแห้ง & app",
    "ar-SA": "إقلاع الكحول: أيام جافة تطبيق",
    "he": "הפסקת אלכוהול: ימים יבשים",
    "ja": "アルコール禁酒・ドライデイ追跡SOBERアプリ版APP",
    "ko": "금주 알코올 드라이데이 추적 앱 프로그램 도구",
    "zh-Hans": "戒酒助手｜干酒日酒精戒断追踪SOBER应用APP版",
    "zh-Hant": "戒酒助手｜干酒日酒精戒斷追蹤SOBER應用APP版",
    "hi": "शराब छोड़ें – शुष्क दिन अॅप",
    "bn-BD": "মদ ছাড়ুন – শুষ্ক দিন ট্র্যাক",
    "ta-IN": "மது விடு – உலர் நாள் டிராக்கர்",
    "te-IN": "మద్యం వదులు – ఎండిన రోజులు",
    "mr-IN": "दारू सोडा – कोरडे दिवस अॅप",
    "gu-IN": "દારૂ છોડો – સૂકા દિવસ ટ્રેકર",
    "kn-IN": "ಮದ್ಯ ಬಿಡಿ – ಒಣ ದಿನಗಳ ಟ್ರ್ಯಾಕರ್",
    "ml-IN": "മദ്യം നിർത്തുക – ഉണങ്ങിയ ദിവസം",
    "pa-IN": "ਸ਼ਰਾਬ ਛੱਡੋ – ਸੁੱਕੇ ਦਿਨ ਐਪ",
    "or-IN": "ମଦ୍ୟ ଛାଡ଼ – ଶୁଷ୍କ ଦିନ ଟ୍ରାକର",
    "ur-PK": "شراب چھوڑیں – خشک دن ٹریکر ایپ",
}

MAX_SUBTITLES: dict[str, str] = {
    "en-US": EN_SUBTITLE,
    "en-GB": EN_SUBTITLE,
    "en-CA": EN_SUBTITLE,
    "en-AU": EN_SUBTITLE,
    "de-DE": "Nüchternheitszähler & Garten",
    "fr-FR": "Compteur sobriété & jardin",
    "fr-CA": "Compteur sobriété & jardin",
    "es-ES": "Contador sobriedad & jardín",
    "es-MX": "Contador sobriedad & jardín",
    "it": "Contatore sobrietà & giardino",
    "pt-BR": "Contador recuperação & jardim",
    "pt-PT": "Contador recuperação & jardim",
    "nl-NL": "Herstelteller & virtuele tuin",
    "pl": "Licznik trzeźwości & ogród",
    "sv": "Nykterhetsmätare & trädgård",
    "da": "Genopretning & virtuel have",
    "no": "Gjenoppretting & virtuell hage",
    "fi": "Raittiuslaskuri & puutarha",
    "cs": "Počítadlo abstinence & zahrada",
    "sk": "Počítadlo zotavenia & záhrada",
    "hr": "Brojač abstinencije & vrt",
    "sl-SI": "Števec abstinence & virtualni",
    "hu": "Mérsékletességmérő & kert",
    "ro": "Contor recuperare & grădină",
    "ru": "Счётчик воздержания & сад",
    "uk": "Лічильник тверезості & сад",
    "el": "Μετρητής αποκατάστασης & κήπος",
    "tr": "Bağımlılık sayacı & bahçe",
    "ca": "Comptador abstinència & jardí",
    "id": "Penghitung abstinensi & taman",
    "ms": "Pembilang abstinensi & taman",
    "vi": "Đếm phục hồi & khu vườn ảo",
    "th": "นับวันไม่ดื่ม & สวนเสมือน",
    "ar-SA": "عداد التعافي & حديقة افتراضية",
    "he": "מונה התאוששות וגן וירטואלי",
    "ja": "無アルコール日数カウンター・バーチャル庭園SOBER版",
    "ko": "무알코올 프리 일수 카운터 & 가상 정원 성장",
    "zh-Hans": "无酒精日计数器・虚拟花园成长应用助手SOBERAPP",
    "zh-Hant": "無酒精日計數器・虛擬花園成長應用助手SOBERAPP",
    "hi": "संयम गिनती और वर्चुअल बगीचा",
    "bn-BD": "সংযম গণনা ও ভার্চুয়াল বাগান",
    "ta-IN": "தவிர்ப்பு எண்ணிக்கை & தோட்டம்",
    "te-IN": "సంయమ లెక్క & వర్చువల్ తోట",
    "mr-IN": "संयम मोजणी आणि वर्चुअल बाग",
    "gu-IN": "સંયમ ગણતરી અને વર્ચ્યુઅલ બગીચો",
    "kn-IN": "ಸಂಯಮ ಎಣಿಕೆ ಮತ್ತು ವರ್ಚುವಲ್ ತೋಟ",
    "ml-IN": "സംയമ എണ്ണം & വെർച്വൽ തോട്ടം",
    "pa-IN": "ਅਨੁਸ਼ਾਸਨ ਗਿਣਤੀ & ਵਰਚੁਅਲ ਬਾਗ",
    "or-IN": "ସଂଯମ ଗଣନା ଓ ଭର୍ଚୁଆଲ୍ ବଗିଚା",
    "ur-PK": "پرہیز گنتی اور ورچوئل باغ",
}

EXTRA_KW: dict[str, tuple[str, ...]] = {
    "en-US": ("checkin",),
}

# Import pools from build script after generation; fallback inline extras.
POOL_EXTRAS = (
    "streak", "widget", "calendar", "journal", "health", "private", "detox",
    "wine", "beer", "mood", "clean", "daily", "checkin",
)


def merge_pool(loc: str, pool: tuple[str, ...]) -> tuple[str, ...]:
    extras = POOL_EXTRAS + EXTRA_KW.get(loc, ())
    seen: set[str] = set()
    out: list[str] = []
    for t in (*pool, *extras):
        k = t.strip().lower().replace(" ", "")
        if k and k not in seen:
            seen.add(k)
            out.append(t)
    return tuple(out)


def validate_pair(loc: str, title: str, subtitle: str) -> list[str]:
    errs = validate_title_subtitle(loc, title, subtitle)
    ol = title_subtitle_overlap(title, subtitle)
    if ol:
        errs.append(f"overlap {ol}")
    if len(title) <= 24:
        errs.append(f"title short {len(title)}")
    if len(subtitle) <= 24:
        errs.append(f"subtitle short {len(subtitle)}")
    return errs


def emit() -> str:
    from locale_aso_spec import LOCALE_ASO, LocaleASO  # noqa: WPS433

    errors: list[str] = []
    lines = ["LOCALE_ASO: dict[str, LocaleASO] = {"]
    stats: list[tuple[str, int, int, int]] = []

    for loc in sorted(LOCALE_ASO):
        spec = LOCALE_ASO[loc]
        title = MAX_TITLES[loc]
        subtitle = MAX_SUBTITLES[loc]
        pool = merge_pool(loc, spec.keyword_pool)
        kw = pack_keywords(title, subtitle, pool)

        errs = validate_pair(loc, title, subtitle)
        errs += validate_packed_keywords(loc, kw)
        if len(kw) < 94:
            errs.append(f"kw short {len(kw)}")

        if errs:
            errors.append(f"{loc} T{len(title)}/{len(subtitle)}/{len(kw)}: {errs}")
            continue

        stats.append((loc, len(title), len(subtitle), len(kw)))
        proof = spec.astro_proof if isinstance(spec.astro_proof, tuple) else (spec.astro_proof,)

        lines.append(f'    "{loc}": LocaleASO(')
        lines.append(f"        {title!r},")
        lines.append(f"        {subtitle!r},")
        lines.append("        (")
        for p in pool:
            lines.append(f"            {p!r},")
        lines.append("        ),")
        lines.append(f"        {spec.rationale!r},")
        if proof:
            pl = ", ".join(repr(p) for p in proof[:3])
            lines.append(f"        ({pl}),")
        if spec.store != "us":
            lines.append(f"        store={spec.store!r},")
        lines.append("    ),")

    lines.append("}")
    if errors:
        print("FAILURES:")
        for e in errors:
            print(e)
        raise SystemExit(1)
    for s in stats:
        print(f"  {s[0]}: {s[1]}/{s[2]}/{s[3]}")
    return "\n".join(lines)


def main() -> int:
    path = SCRIPTS / "locale_aso_spec.py"
    text = path.read_text(encoding="utf-8")
    text = re.sub(r'EN_SUBTITLE = "[^"]*"', f'EN_SUBTITLE = "{EN_SUBTITLE}"', text, count=1)
    new_block = emit()
    text = re.sub(
        r"LOCALE_ASO: dict\[str, LocaleASO\] = \{.*\n\}",
        new_block,
        text,
        count=1,
        flags=re.S,
    )
    path.write_text(text, encoding="utf-8")
    print(f"Updated {len(MAX_TITLES)} locales")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
