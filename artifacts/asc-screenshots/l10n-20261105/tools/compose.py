#!/usr/bin/env python3
"""Compose, check and make contact sheets for all captured locales."""
import json
from pathlib import Path
import shutil
import subprocess
import sys

kit = Path(__file__).resolve().parent.parent
python = kit / '.venv/bin/python'
config = kit / 'frames.json'
raw = kit / 'raw'
headers = kit / 'copy/headers.json'
out = kit / 'out'
results = {}
targets = json.loads((kit / 'app.json').read_text())['targets']
targets.sort(key=lambda target: {'hi': -2, 'de-DE': -1}.get(target['store_locale'], target['rank']))
for target in targets:
    locale, lang = target['store_locale'], target['lang']
    if len(sys.argv) > 1 and locale not in sys.argv[1:]:
        continue
    print(f'{locale}: composing', flush=True)
    locale_output = out / locale / 'phone'
    if locale_output.exists():
        for old in locale_output.glob('*.png'):
            old.unlink()
    common = ['--config', str(config)]
    subprocess.run([str(python), str(kit / 'tools/reskin.py'), *common, '--raw-root', str(raw), '--headers', str(headers), '--locale', locale, '--out', str(out)], check=True)
    gate = subprocess.run([str(python), str(kit / 'tools/gate.py'), *common, '--raw-root', str(raw), '--headers', str(headers), '--out-root', str(out), '--locale', locale, '--catalog', 'Shared/Localizable.xcstrings', '--lang', lang], text=True, capture_output=True)
    print(gate.stdout, flush=True)
    results[locale] = 'PASS' if gate.returncode == 0 else 'FAIL'
    subprocess.run([str(python), str(kit / 'tools/sheet.py'), *common, '--locale', locale, '--out-root', str(out), '--base-label', 'en'], check=True)
    (kit / 'sheets').mkdir(exist_ok=True)
    shutil.copyfile(out / 'sheets' / f'{locale}-phone.jpg', kit / 'sheets' / f'{locale}-phone.jpg')
(kit / 'gate-results.json').write_text(json.dumps(results, indent=2) + '\n')
if 'FAIL' in results.values():
    sys.exit(1)
