#!/usr/bin/env python3
"""Convert the title-level fonts that are TEXT (not SF Symbol icons) to the
brand voice: stat values + headlines -> serif (heading/display), onboarding
body copy + button labels -> rounded body. Icons keep .title2/.title3."""

EDITS = {
    "Sober/Features/Today/HomeView.swift": [
        # streak stat value -> serif
        (".font(.title3.weight(.semibold))", ".font(Theme.heading(20, weight: .semibold))", 1),
    ],
    "Sober/Features/Calendar/TimelineView.swift": [
        (".font(.title.weight(.semibold))", ".font(Theme.heading(28, weight: .semibold))", 1),
        (".font(.title3.weight(.semibold))", ".font(Theme.heading(20, weight: .semibold))", 1),
    ],
    "Sober/Features/Garden/GardenCollectionView.swift": [
        (".font(.title3.weight(.semibold))", ".font(Theme.heading(20, weight: .semibold))", 2),
    ],
    "Sober/Features/Garden/GardenCustomizationView.swift": [
        (".font(.title2.bold())", ".font(Theme.heading(22, weight: .bold))", 1),
    ],
    "Sober/Features/Garden/GardenItemDetailView.swift": [
        (".font(.title2.bold())", ".font(Theme.display(22, weight: .bold))", 1),
    ],
    "Sober/Features/Onboarding/OnboardingView.swift": [
        (".font(.title2)\n                .padding(.horizontal, Theme.Space.m)",
         ".font(Theme.body(22))\n                .padding(.horizontal, Theme.Space.m)", 1),
        ("Text(formatHour(h)).font(.title2).tag(h)",
         "Text(formatHour(h)).font(Theme.body(22)).tag(h)", 1),
        (".font(.title2)\n                .foregroundStyle(.white.opacity(0.9))",
         ".font(Theme.body(22))\n                .foregroundStyle(.white.opacity(0.9))", 1),
        (".font(.title3.weight(.semibold))", ".font(Theme.body(20, weight: .semibold))", 1),
    ],
}

for path, edits in EDITS.items():
    with open(path) as f:
        src = f.read()
    for old, new, expected in edits:
        n = src.count(old)
        assert n == expected, f"{path}: expected {expected} of {old!r}, found {n}"
        src = src.replace(old, new)
    with open(path, "w") as f:
        f.write(src)
    print(f"ok  {path}")
print("done")
