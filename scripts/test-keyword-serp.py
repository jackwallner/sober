#!/usr/bin/env python3
"""Test each keyword token against App Store SERP to check relevance."""
import json, urllib.request, sys

astro_url = 'http://127.0.0.1:8089/mcp'

SOBER_WORDS = ['sober','alcohol','drink','sobriety','recovery','addiction','quit','stop','craving','dry','relapse','abstinence','drink less','stop drinking','sober tracker','addiction recovery']

def search(kw):
    req = urllib.request.Request(astro_url, data=json.dumps({"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"search_app_store","arguments":{"keyword":kw,"store":"us"}}}).encode(), headers={'Content-Type':'application/json'})
    data = json.loads(urllib.request.urlopen(req, timeout=30).read())
    text = data['result']['content'][0]['text']
    parsed = json.loads(text)
    return parsed['apps'] if isinstance(parsed, dict) and 'apps' in parsed else parsed

# Current keyword tokens
tokens = ["drink","less","quit","recovery","streak","widget","watch","journal","calendar","private","milestone"]

# Also test these candidates
candidates = tokens + ["diary","craving","clean","habit","stop","tracker","days","counter","daily","check","minutes","hours","sober","dry"]

for t in sorted(set(candidates)):
    try:
        items = search(t)
        top5 = items[:5]
        names = [(a['name'], a.get('subtitle','')) for a in top5]
        relevant = sum(1 for n,s in names if any(w in (n+' '+s).lower() for w in SOBER_WORDS))
        
        # Score: 5/5 = perfect, 0/5 = useless
        score = f"{relevant}/5"
        
        # Show top names
        first = names[0][0][:40] if names else "—"
        second = names[1][0][:40] if len(names) > 1 else ""
        
        tag = "✓" if relevant >= 2 else "△" if relevant >= 1 else "✗"
        
        print(f"{tag} {t:12s} {score:4s}  {first}")
        if second and relevant == 0:
            print(f"   {'':12s} {'':4s}  {second}")
    except Exception as e:
        print(f"? {t:12s} ERROR: {e}")
