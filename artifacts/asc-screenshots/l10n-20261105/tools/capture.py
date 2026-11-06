#!/usr/bin/env python3
"""Capture all requested locales in one gh-sim launch and sort the results."""
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

kit = Path('artifacts/asc-screenshots/l10n-20261105')
targets = json.loads((kit / 'app.json').read_text())['targets']
locales = [{'store_locale': 'en-US', 'apple_languages': '(en)', 'apple_locale': 'en_US'}] + targets
if len(sys.argv) > 1:
    wanted = set(sys.argv[1:]) | {'en-US'}
    locales = [locale for locale in locales if locale['store_locale'] in wanted]
scenes = [('home', ''), ('savings', '-showProgress -scrollProgressSaved'), ('health', '-tab 2'), ('journal', '-tab 3'), ('bloom', '-tab 4')]
command = ['gh-sim', 'launch', '--device', 'iPhone 17 Pro Max', '--wait', '14', '--record-seconds', '1', '--args', '-seedDemo -seedDays 127 -storeScreenshots -demoPro']
for locale in locales:
    for _, args in scenes:
        command += ['--screen', f"-AppleLanguages {locale['apple_languages']} -AppleLocale {locale['apple_locale']} {args}"]
with tempfile.NamedTemporaryFile() as run_id:
    result_code = subprocess.run(command + ['--id-file', run_id.name]).returncode
    missing = []
    result = Path.home() / '.gh-sim/results' / Path(run_id.name).read_text().strip() / 'shots'
    for index, (locale, scene) in enumerate(((loc, scene) for loc in locales for scene in scenes), 1):
        matches = list(result.glob(f'screen{index}-*.png'))
        if len(matches) != 1:
            missing.append(f'{locale["store_locale"]}/{scene[0]}')
            continue
        dest = kit / 'raw' / locale['store_locale'] / 'phone' / f'{scene[0]}.png'
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(matches[0], dest)
        print(dest, flush=True)

    if result_code or missing:
        raise RuntimeError(f'gh-sim exit {result_code}; missing captures: {missing}')
