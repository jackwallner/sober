---
paths:
  - "Sober/App.swift"
  - "Sober/Utilities/ReadableColumn.swift"
  - "Sober/Utilities/UnfoldedSplit.swift"
  - "Sober/Features/Calendar/TimelineView.swift"
  - "Sober/Features/Onboarding/OnboardingView.swift"
  - "Sober/Features/Paywall/PaywallView.swift"
  - "Sober/Features/Craving/CravingModeView.swift"
  - "SoberUITests/IPadCaptureUITests.swift"
  - "project.yml"
---

# Sober: iPad layout (2026-11-12)

iPad is on: `TARGETED_DEVICE_FAMILY "1,2"` on the app target (the widget and
watch targets are untouched), all four orientations in `Info.plist`
(`UISupportedInterfaceOrientations~ipad`). An iPad version can never be
removed once shipped, so every surface is checked in portrait and landscape.

- Root: the iPhone Duo split (`.claude/rules/iphone-duo.md`) is the iPad
  layout. Any regular width of 720 pt or more puts Home, Health, Journal and
  Bloom+ (with the tab bar) in the leading pane and Timeline in the trailing
  one, each pane compact. Narrower windows (Split View, Slide Over) keep the
  single phone column and the Timeline tab.
- On an iPad the Timeline pane is as tall as the screen, so its day cells grow
  (`dayCellHeight`) to fill it rather than leave the lower third empty.
- Full-screen surfaces that are not lists (onboarding, craving mode, the
  paywall) sit in `readableColumn(_:)`: a width cap plus centring, so a phone
  layout is never stretched across 13 inches. Phones are narrower than every
  cap, so it changes nothing there.
- Captures: `SoberUITests/IPadCaptureUITests` walks every surface in portrait
  and landscape and attaches a frame per surface (it never fails, anything it
  could not reach goes in the `notes` attachment). Run it on GitHub's Mac:
  `gh-sim test --scheme SoberUITests --device "iPad Pro 13-inch (M5)" --only SoberUITests/IPadCaptureUITests`.
  Frames land in `~/.gh-sim/results/<id>/attachments/`. Never configure the
  production RevenueCat key on a simulator run.
