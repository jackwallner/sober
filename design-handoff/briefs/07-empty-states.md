# Brief 07 — Empty states

Three illustrations for empty states. Lowest priority — currently shown as plain text.

## Screens

1. **Journal — no entries yet** — invite the user to write.
2. **Calendar — no history yet** — invite to check in.
3. **Achievements — none unlocked yet** — promise.

## Spec

- 400×300 SVG, transparent background.
- Lighter, smaller, less detailed than the main garden art — empty states shouldn't dominate.
- Single-color line illustration is fine. Use `textSecondary` palette token.

## Output

```
output/empty-states/
├── empty-journal.svg
├── empty-calendar.svg
└── empty-achievements.svg
```

## Defer?

Yes — ship v1 with text-only empty states. Revisit when you have user data on which screens get the most empty-state views.
