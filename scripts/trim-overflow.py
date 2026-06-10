#!/usr/bin/env python3
"""Fix remaining locale overflows in aso_native_metadata.py."""
import re

with open('aso_native_metadata.py') as f:
    content = f.read()

pat = r'"([a-z]{2}(?:-[A-Z]{2})?)"\s*:\s*\{[^}]*?"name":\s*"([^"]+)"[^}]*?"subtitle":\s*"([^"]+)"[^}]*?"keywords":\s*"([^"]+)"'
matches = list(re.finditer(pat, content))

fixes = {}
for m in matches:
    locale, name, subtitle, keywords = m.groups()
    if len(name) > 30: fixes[(locale, 'name')] = name[:30]
    if len(subtitle) > 30:
        # Shorten subtitle
        short = subtitle[:28] + '..'
        fixes[(locale, 'subtitle')] = short
    if len(keywords) > 100:
        kw_list = keywords.split(',')
        while len(','.join(kw_list)) > 99:
            kw_list.pop()
        fixes[(locale, 'keywords')] = ','.join(kw_list)

# Apply fixes by replacing within each locale block
for (locale, field), new_val in fixes.items():
    esc_locale = re.escape(locale)
    # Find the locale block, then replace the field value
    start = content.find(f'"{locale}"')
    end = content.find('},', start) + 2
    block = content[start:end]
    old_val_match = re.search(rf'"{field}":\s*"([^"]+)"', block)
    if old_val_match:
        old_val = old_val_match.group(0)
        new_entry = f'"{field}": "{new_val}"'
        content = content[:start] + block.replace(old_val, new_entry) + content[end:]

with open('aso_native_metadata.py', 'w') as f:
    f.write(content)

if fixes:
    print(f"Fixed {len(fixes)} overflows:")
    for (locale, field), new_val in fixes.items():
        print(f"  {locale}.{field} → {new_val}")
else:
    print("No overflows found.")

# Final validation
matches = re.findall(r'"([a-z]{2}(?:-[A-Z]{2})?)"\s*:\s*\{[^}]*?"name":\s*"([^"]+)"[^}]*?"subtitle":\s*"([^"]+)"[^}]*?"keywords":\s*"([^"]+)"', content)
errors = []
for locale, name, subtitle, keywords in matches:
    if len(name) > 30: errors.append(f'{locale}: name {len(name)}')
    if len(subtitle) > 30: errors.append(f'{locale}: subtitle {len(subtitle)}')
    if len(keywords) > 100: errors.append(f'{locale}: keywords {len(keywords)}')
    
if errors:
    print(f"\n{len(errors)} REMAINING ERRORS:")
    for e in errors: print(f"  ✗ {e}")
else:
    print(f"\n✓ All {len(matches)} locales valid!")
