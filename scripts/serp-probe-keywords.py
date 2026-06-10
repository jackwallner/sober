#!/usr/bin/env python3
"""Thorough SERP probe: test every candidate keyword token against App Store search.
Only keep tokens that actually return relevant results."""
import json, urllib.request, time, sys

astro_url = 'http://127.0.0.1:8089/mcp'
SIGNAL = ['sober','alcohol','drink','sobriety','recovery','addiction','quit','stop','craving','relapse','abstinence','booze','liquor','spirits','cocktail','brew','drunk','hangover','wine','beer']

def search(kw):
    for attempt in range(3):
        try:
            req = urllib.request.Request(astro_url,
                data=json.dumps({'jsonrpc':'2.0','id':1,'method':'tools/call','params':{'name':'search_app_store','arguments':{'keyword':kw,'store':'us'}}}).encode(),
                headers={'Content-Type':'application/json'})
            d = json.loads(urllib.request.urlopen(req, timeout=30).read())
            if 'error' in str(d.get('result',{})):
                time.sleep(5)
                continue
            txt = d['result']['content'][0]['text']
            p = json.loads(txt)
            return p.get('apps', p)
        except Exception as e:
            if attempt < 2:
                time.sleep(5)
            else:
                raise
    return None

# Build exhaustive candidate list - everything that might be relevant
candidates = [
    # Core action/behavior words
    "drink","drinking","quit","stop","less","reduce","reduce alcohol","cut back",
    # Tracking nouns  
    "tracker","tracking","counter","log","logger","diary","journal","calendar","streak","streaks","check in","checkin","daily check",
    # Sobriety specific
    "sobriety","sober","recovery","addiction","relapse","abstinence","sober living","clean time",
    # Feature/benefit words
    "habit","habits","health","wellness","mindful","mindfulness","therapy","support","community","accountability",
    # Body/health results
    "liver","liver recovery","health benefits","body recovery","sleep","energy","anxiety",
    # Money related
    "money saved","savings","cost calculator",
    # App features
    "widget","widgets","watch","apple watch","complication","reminder","notifications","privacy","private",
    # Time related
    "days","day counter","hours","minutes","progress","milestone","goal","goals","achievement",
    # Emotion/mood
    "craving","cravings","mood","mood tracker","anxiety","stress","trigger",
    # Social
    "anonymous","private","no account",
    # General discovery
    "free app","app","tracker app","best app",
    # Related conditions
    "dry january","sober october","sober challenge",
    # Already in our fields - should be excluded but testing anyway
    "dry days","alcohol free","sober tracker",
]

results = []
tested = 0
for c in candidates:
    tested += 1
    try:
        items = search(c)
        if items is None:
            results.append((c, 0, [], "timeout"))
            continue
            
        top5 = items[:5]
        rel_scores = []
        names = []
        for a in top5:
            name = a.get('name','')
            sub = a.get('subtitle','')
            combined = (name + ' ' + sub).lower()
            is_rel = any(w in combined for w in SIGNAL)
            rel_scores.append(1 if is_rel else 0)
            names.append(name[:40])
        
        total = sum(rel_scores)
            
        tag = "✓" if total >= 3 else "△" if total >= 1 else "✗"
        results.append((c, total, names, tag))
        progress = f"[{tested}/{len(candidates)}] {tag} {c:20s} {total}/5"
        if total == 0:
            progress += f"  {names[0]}"
        print(progress)
        sys.stdout.flush()
        time.sleep(1.5)  # rate limit
    except Exception as e:
        results.append((c, 0, [], f"error:{str(e)[:30]}"))
        print(f"[{tested}/{len(candidates)}] ? {c:20s} error: {e}")
        sys.stdout.flush()
        time.sleep(3)

# Summary
print("\n\n=== RESULTS SUMMARY ===")
print(f"\nHIGH RELEVANCE (3-5/5):")
for c, score, names, tag in results:
    if score >= 3:
        print(f"  ✓ {c:20s} {score}/5")

print(f"\nMEDIUM RELEVANCE (1-2/5):")
for c, score, names, tag in results:
    if 1 <= score < 3:
        print(f"  △ {c:20s} {score}/5  {names[0] if names else ''}")

print(f"\nLOW RELEVANCE (0/5):")
for c, score, names, tag in results:
    if score == 0 and not tag.startswith("error"):
        print(f"  ✗ {c:20s}  {names[0] if names else ''}")

print(f"\nERRORS:")
for c, score, names, tag in results:
    if tag.startswith("error") or tag == "timeout":
        print(f"  ? {c:20s}  {tag}")
