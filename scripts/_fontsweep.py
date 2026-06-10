#!/usr/bin/env python3
"""One-shot: route raw chatty-layer SwiftUI fonts through Theme.body (rounded).
Skips the title family (title/title2/title3/largeTitle) — those are a
serif-vs-rounded judgment handled by hand."""
import re
import sys

# chatty layer only -> Theme.body(size)
SIZE = {
    "headline": 17,
    "body": 17,
    "callout": 16,
    "subheadline": 15,
    "footnote": 13,
    "caption2": 11,
    "caption": 12,
}
# longest / most-specific names first so caption2 wins over caption
NAMES = ["headline", "callout", "subheadline", "footnote", "caption2", "caption", "body"]

CHAIN = r"((?:\.[a-zA-Z]+\([^()]*\)|\.[a-zA-Z]+\(\))*)"
PAT = re.compile(r"\.font\(\.(" + "|".join(NAMES) + r")" + CHAIN + r"\)")

WEIGHT_RE = re.compile(r"\.weight\(\.([a-zA-Z]+)\)")


def repl(m):
    name = m.group(1)
    chain = m.group(2) or ""
    size = SIZE[name]
    weight = None
    # pull an explicit weight out of the chain into the Theme.body arg
    wm = WEIGHT_RE.search(chain)
    if wm:
        weight = wm.group(1)
        chain = WEIGHT_RE.sub("", chain, count=1)
    if ".bold()" in chain:
        weight = "bold"
        chain = chain.replace(".bold()", "", 1)
    base = f"Theme.body({size}"
    if weight:
        base += f", weight: .{weight}"
    base += ")"
    return f".font({base}{chain})"


changed = 0
for path in sys.argv[1:]:
    with open(path) as f:
        src = f.read()
    new, n = PAT.subn(repl, src)
    if n:
        with open(path, "w") as f:
            f.write(new)
        changed += n
        print(f"{n:3d}  {path}")
print(f"total {changed}")
