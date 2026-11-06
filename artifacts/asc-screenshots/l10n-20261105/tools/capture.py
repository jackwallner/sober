#!/usr/bin/env python3
"""Capture missing locale raws in one gh-sim run and sort the results."""
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

kit = Path('artifacts/asc-screenshots/l10n-20261105')
targets = json.loads((kit / 'app.json').read_text())['targets']
scenes = [('home', ''), ('savings', '-showProgress -scrollProgressSaved'), ('health', '-tab 2'), ('journal', '-tab 3'), ('bloom', '-tab 4')]
english = {'store_locale': 'en-US', 'apple_languages': '(en)', 'apple_locale': 'en_US'}
run_tests = '--with-tests' in sys.argv[1:]
requested = set(sys.argv[1:]) - {'--with-tests'}
known = {locale['store_locale'] for locale in targets} | {'en-US'}
if requested - known - {'all'}:
    raise SystemExit(f'unknown store locales: {sorted(requested - known - {"all"})}')
target_request = requested - {'en-US', 'all'}
selected = targets if not requested or 'all' in requested else [
    locale for locale in targets if locale['store_locale'] in target_request
]

# Keep existing English reference raws. Capture them only if one is missing,
# then capture only absent target raws so an interrupted run can resume cheaply.
tasks = []
for locale in selected:
    for name, args in scenes:
        dest = kit / 'raw' / locale['store_locale'] / 'phone' / f'{name}.png'
        if not dest.is_file():
            tasks.append((locale, name, args))
if 'en-US' in requested or any(
    not (kit / 'raw' / 'en-US' / 'phone' / f'{name}.png').is_file()
    for name, _ in scenes
):
    tasks = [(english, name, args)
             for name, args in scenes
             if not (kit / 'raw' / 'en-US' / 'phone' / f'{name}.png').is_file()] + tasks

if not tasks and not run_tests:
    print('all requested raw captures already exist', flush=True)
    raise SystemExit(0)

mode = 'all' if run_tests else 'launch'
wait = '11' if len(tasks) > 20 else '14'
command = ['gh-sim', mode]
if run_tests:
    command += ['--only', 'SoberTests']
command += [
    '--device', 'iPhone 17 Pro Max',
    '--wait', wait, '--record-seconds', '1', '--env', 'SOBER_SCREENSHOT_MODE=1',
    '--args', '-seedDemo -seedDays 127 -storeScreenshots -demoPro',
]
for locale, _, args in tasks:
    command += [
        '--screen',
        f"-AppleLanguages {locale['apple_languages']} -AppleLocale {locale['apple_locale']} {args}",
    ]

with tempfile.TemporaryDirectory(prefix='sober-shots-ghsim-') as tmp:
    id_file = Path(tmp) / 'run-id'
    result_code = subprocess.run(command + ['--id-file', str(id_file)]).returncode
    run_id = id_file.read_text().strip() if id_file.is_file() else ''
    if not run_id:
        raise RuntimeError(f'gh-sim did not write a run id to {id_file}')
    result = Path.home() / '.gh-sim' / 'results' / run_id / 'shots'
    if not result.is_dir():
        raise RuntimeError(f'gh-sim run {run_id} has no shots directory: {result}')

    missing = []
    for index, (locale, name, _) in enumerate(tasks, 1):
        matches = list(result.glob(f'screen{index}-*.png'))
        if len(matches) != 1:
            missing.append(f'{locale["store_locale"]}/{name}')
            continue
        dest = kit / 'raw' / locale['store_locale'] / 'phone' / f'{name}.png'
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(matches[0], dest)
        print(dest, flush=True)

    if result_code or missing:
        raise RuntimeError(f'gh-sim run {run_id} exit {result_code}; missing captures: {missing}')
    print(f'gh-sim run {run_id}: captured {len(tasks)} missing screens', flush=True)
