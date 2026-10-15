#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
temporary="$(mktemp -d /tmp/sober-android-export.XXXXXX)"
trap 'rm -rf "$temporary"' EXIT

xcrun swiftc -target arm64-apple-macos14.0 \
  "$root/Shared/Models/JournalEntry.swift" \
  "$root/Shared/Models/GardenState.swift" \
  "$root/Shared/Models/GardenItem.swift" \
  "$root/Shared/Utilities/HabitVocabulary.swift" \
  "$root/Shared/Utilities/DateHelpers.swift" \
  "$root/Shared/Services/GardenService.swift" \
  "$root/Shared/Services/SaveFailureReporter.swift" \
  "$root/Shared/Catalogs/HealthBenefitCatalog.swift" \
  "$root/Shared/Catalogs/AchievementCatalog.swift" \
  "$root/Shared/Catalogs/JournalPromptCatalog.swift" \
  "$root/Shared/Catalogs/CravingCoachCatalog.swift" \
  "$root/scripts/android-export/main.swift" \
  -o "$temporary/export"

"$temporary/export" \
  "$root/android/app/src/main/resources/sober-content.json" \
  "$root/android/app/src/test/resources/sober-parity.json"
