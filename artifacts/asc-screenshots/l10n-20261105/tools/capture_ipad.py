#!/usr/bin/env python3
"""Capture iPad raws for the live store locales in one gh-sim launch run.

Usage: capture_ipad.py LOCALE [LOCALE ...]   (run from the repo root)
Raws land in raw/<locale>/ipad/<scene>.png, 2064x2752 portrait.
"""
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

kit = Path('artifacts/asc-screenshots/l10n-20261105')
targets = {t['store_locale']: t for t in json.loads((kit / 'app.json').read_text())['targets']}
for loc, lang, region in [('de-DE', 'de', 'de_DE'), ('cs', 'cs', 'cs_CZ'), ('es-MX', 'es', 'es_MX'), ('fi', 'fi', 'fi_FI'),
                          ('fr-FR', 'fr', 'fr_FR'), ('hi', 'hi', 'hi_IN'), ('it', 'it', 'it_IT'), ('nl-NL', 'nl', 'nl_NL'),
                          ('pl', 'pl', 'pl_PL'), ('ru', 'ru', 'ru_RU'), ('sv', 'sv', 'sv_SE'), ('uk', 'uk', 'uk_UA'),
                          ('vi', 'vi', 'vi_VN'), ('zh-Hans', 'zh-Hans', 'zh_CN')]:
    targets.setdefault(loc, {'store_locale': loc, 'apple_languages': f'({lang})', 'apple_locale': region})
targets['en-US'] = {'store_locale': 'en-US', 'apple_languages': '(en)', 'apple_locale': 'en_US'}
scenes = [('home', ''), ('savings', '-showProgress -scrollProgressSaved'), ('health', '-tab 2'), ('journal', '-tab 3'), ('bloom', '-tab 4')]
tasks = [(targets[loc], name, args) for loc in sys.argv[1:] for name, args in scenes
         if not (kit / 'raw' / loc / 'ipad' / f'{name}.png').is_file()]
if not tasks:
    raise SystemExit('nothing to capture')

command = ['gh-sim', 'launch', '--device', 'iPad Pro 13-inch (M5)', '--wait', '11', '--record-seconds', '1',
           '--env', 'SOBER_SCREENSHOT_MODE=1', '--args', '-seedDemo -seedDays 127 -storeScreenshots -demoPro']
for locale, _, args in tasks:
    command += ['--screen', f"-AppleLanguages {locale['apple_languages']} -AppleLocale {locale['apple_locale']} {args}"]

with tempfile.TemporaryDirectory(prefix='sober-ipad-ghsim-') as tmp:
    id_file = Path(tmp) / 'run-id'
    code = subprocess.run(command + ['--id-file', str(id_file)]).returncode
    run_id = id_file.read_text().strip() if id_file.is_file() else ''
    result = Path.home() / '.gh-sim' / 'results' / run_id / 'shots'
    if not run_id or not result.is_dir():
        raise SystemExit(f'no shots for run {run_id!r}')
    missing = []
    for index, (locale, name, _) in enumerate(tasks, 1):
        matches = list(result.glob(f'screen{index}-*.png'))
        if len(matches) != 1:
            missing.append(f"{locale['store_locale']}/{name}")
            continue
        dest = kit / 'raw' / locale['store_locale'] / 'ipad' / f'{name}.png'
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(matches[0], dest)
    print(f'run {run_id} exit {code} captured {len(tasks) - len(missing)} missing {missing}')
