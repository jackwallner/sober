#!/usr/bin/env python3
"""Minimal App Store Connect API client for pre-submission fixes.

Usage: asc_api.py METHOD PATH [JSON_BODY]
  asc_api.py GET /v1/apps?filter[bundleId]=com.jackwallner.sober
Reads ASC_ISSUER_ID / ASC_API_KEY_ID / ASC_KEY_PATH from env or
~/.baseball_credentials.
"""
import json
import os
import re
import sys
import time
import urllib.request

import jwt


def load_creds():
    env = dict(os.environ)
    if not env.get("ASC_ISSUER_ID"):
        creds = os.path.expanduser("~/.baseball_credentials")
        with open(creds) as f:
            for line in f:
                m = re.match(r'export (\w+)="?([^"\n]+)"?', line.strip())
                if m:
                    env.setdefault(m.group(1), m.group(2))
    key_path = os.path.expanduser(env["ASC_KEY_PATH"].replace("$HOME", "~"))
    return env["ASC_ISSUER_ID"], env["ASC_API_KEY_ID"], key_path


def token():
    issuer, key_id, key_path = load_creds()
    with open(key_path) as f:
        key = f.read()
    now = int(time.time())
    return jwt.encode(
        {"iss": issuer, "iat": now, "exp": now + 1200, "aud": "appstoreconnect-v1"},
        key, algorithm="ES256", headers={"kid": key_id},
    )


def call(method, path, body=None):
    url = "https://api.appstoreconnect.apple.com" + path
    req = urllib.request.Request(url, method=method)
    req.add_header("Authorization", f"Bearer {token()}")
    data = None
    if body is not None:
        req.add_header("Content-Type", "application/json")
        data = json.dumps(body).encode()
    try:
        with urllib.request.urlopen(req, data) as resp:
            raw = resp.read()
            return resp.status, json.loads(raw) if raw else {}
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read() or b"{}")


if __name__ == "__main__":
    method, path = sys.argv[1], sys.argv[2]
    body = json.loads(sys.argv[3]) if len(sys.argv) > 3 else None
    status, out = call(method, path, body)
    print(f"HTTP {status}", file=sys.stderr)
    json.dump(out, sys.stdout, indent=2)
    print()
