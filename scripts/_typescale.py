#!/usr/bin/env python3
"""One-shot: collapse the Theme.body/heading/display size-smear onto the tight
six-token editorial scale (display/title/heading + body/subhead/caption).

Mapping:
  rounded  body(11|12|13) -> caption   body(15) -> subhead   body(16|17|20|22) -> body
  serif    heading(20|22) -> heading    heading(24|28) -> title
           display(22|26) -> title      display(34) -> display
           display(64)    -> display(64)  (wordmark keeps its explicit size)
"""
import re
import sys

FILES = [
    "Shared/Bonsai/BonsaiRenderer.swift",
    "Sober/Features/Calendar/TimelineView.swift",
    "Sober/Features/Garden/GardenCollectionView.swift",
    "Sober/Features/Garden/GardenCustomizationView.swift",
    "Sober/Features/Garden/GardenItemDetailView.swift",
    "Sober/Features/Garden/GardenItemRenderer.swift",
    "Sober/Features/Garden/GardenSceneView.swift",
    "Sober/Features/Garden/PannableGardenView.swift",
    "Sober/Features/Garden/UnlockCelebrationView.swift",
    "Sober/Features/Health/HealthView.swift",
    "Sober/Features/Journal/JournalView.swift",
    "Sober/Features/Onboarding/OnboardingView.swift",
    "Sober/Features/Paywall/PaywallView.swift",
    "Sober/Features/Settings/SettingsView.swift",
    "Sober/Features/Today/HomeView.swift",
    "Sober/Views/ReviewPromptSheet.swift",
]

PAT = re.compile(r"Theme\.(body|heading|display)\(\s*(\d+)\s*(?:,\s*weight:\s*([^)]+?))?\s*\)")


def token_and_keep_size(func, size):
    """Return (token, keep_size_or_None)."""
    if func == "body":  # rounded voice
        if size <= 13:
            return "caption", None
        if size == 15:
            return "subhead", None
        return "body", None  # 16,17,20,22
    if func == "heading":  # serif
        return ("heading" if size <= 22 else "title"), None
    # display (serif)
    if size == 64:
        return "display", 64  # wordmark
    if size <= 26:
        return "title", None  # 22,26
    return "display", None  # 34


def repl(m):
    func, size_s, weight = m.group(1), m.group(2), m.group(3)
    token, keep = token_and_keep_size(func, int(size_s))
    args = []
    if keep is not None:
        args.append(str(keep))
    if weight is not None:
        args.append(f"weight: {weight.strip()}")
    return f"Theme.{token}({', '.join(args)})"


total = 0
for path in FILES:
    with open(path) as f:
        src = f.read()
    new, n = PAT.subn(repl, src)
    if n:
        with open(path, "w") as f:
            f.write(new)
    total += n
    print(f"{n:3d}  {path}")
print(f"--- {total} call sites migrated ---")

# Fail loudly if any old-style size call survives.
leftovers = []
for path in FILES:
    with open(path) as f:
        for i, line in enumerate(f, 1):
            if re.search(r"Theme\.(body|heading|display)\(\s*\d", line):
                leftovers.append(f"{path}:{i}: {line.strip()}")
if leftovers:
    print("LEFTOVER raw-size calls:", file=sys.stderr)
    print("\n".join(leftovers), file=sys.stderr)
    sys.exit(1)
print("clean: no raw-size Theme font calls remain")
