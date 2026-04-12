---
status: testing
phase: 02-prayer-logic-glance
source: [02-01-SUMMARY.md, 02-02-SUMMARY.md]
started: 2026-04-12T10:00:00Z
updated: 2026-04-12T10:00:00Z
---

## Current Test

number: 1
name: Glance Layout - Normal Prayer Display
expected: |
  Open the glance with cached prayer data (mosque configured, data fetched).
  Top line shows next prayer name + countdown (e.g., "Asr in 2h 15m").
  Middle shows a 5-segment colored progress bar with a white current-time marker.
  Bottom shows previous prayer time on the left and next prayer time on the right.
awaiting: user response

## Tests

### 1. Glance Layout - Normal Prayer Display
expected: Open the glance with cached prayer data. Top line shows next prayer name + countdown (e.g., "Asr in 2h 15m"). Middle shows 5-segment colored progress bar with white marker. Bottom shows previous prayer time (left) and next prayer time (right).
result: [pending]

### 2. Next Prayer Identification
expected: The glance correctly identifies the next upcoming prayer based on current time. If current time is between two prayers, it shows the upcoming one with accurate countdown.
result: [pending]

### 3. Empty State - No Mosque Configured (D-09)
expected: When no mosque slug is set in settings, the glance shows "Mawaqit" on the top line and "Set mosque in Connect app" below it.
result: [pending]

### 4. Empty State - No Cached Data (D-10)
expected: When mosque is configured but no prayer data is cached yet, the glance shows "-- in --" with a gray progress bar.
result: [pending]

### 5. Overnight Rollover (Isha-to-Fajr)
expected: After Isha prayer time passes, the display rolls over to show tomorrow's Fajr as the next prayer with the correct countdown spanning midnight.
result: [pending]

### 6. Countdown Timer Refresh
expected: The countdown updates automatically. Under normal conditions it refreshes roughly every 30 seconds. When countdown drops below 60 seconds, it shows seconds precision and refreshes every second.
result: [pending]

## Summary

total: 6
passed: 0
issues: 0
pending: 6
skipped: 0
blocked: 0

## Gaps

[none yet]
