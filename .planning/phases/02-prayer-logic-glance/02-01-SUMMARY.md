---
phase: 02-prayer-logic-glance
plan: 01
subsystem: logic
tags: [monkey-c, prayer-times, countdown, seconds-since-midnight, glance, connect-iq]

# Dependency graph
requires:
  - phase: 01-data-pipeline
    provides: PrayerDataStore with getTodayPrayerTimes()/getTomorrowPrayerTimes() returning "HH:MM" dictionaries
provides:
  - PrayerLogic module with next-prayer identification, overnight rollover, countdown formatting
  - parseTimeToSeconds for "HH:MM" to seconds conversion
  - getNextPrayerResult state machine (no_data/now/normal/overnight)
  - formatCountdown with threshold-based string formatting
  - buildSegments for 5 color-coded progress bar segments
  - getDimColor for 40% brightness dimming
affects: [02-02-PLAN (GlanceView), 03-widget-background (Widget view)]

# Tech tracking
tech-stack:
  added: []
  patterns: [seconds-since-midnight integer arithmetic, state machine result dictionary, module-level (:glance) annotation]

key-files:
  created: [source/PrayerLogic.mc]
  modified: []

key-decisions:
  - "Seconds-since-midnight pattern avoids Gregorian.moment() UTC/local timezone pitfall entirely"
  - "Module pattern (not class) matches PrayerDataStore convention and avoids object allocation in 28KB glance budget"
  - "parseTimeToSeconds accepts untyped parameter with instanceof check for defensive null/type handling from Storage data"
  - "getNextPrayerResult uses untyped parameters for todayTimes/tomorrowTimes to handle null Dictionary inputs from PrayerDataStore"

patterns-established:
  - "State machine result dictionary: all prayer display logic returns {state => string, ...state-specific-data}"
  - "Constants as module-level arrays (PRAYER_KEYS, PRAYER_LABELS, SEGMENT_COLORS) for DRY iteration"
  - "Fallback defaults in buildSegments: null prayer times get reasonable hour defaults to prevent crash"
  - "NOW_WINDOW = 300 seconds (5 minutes) for post-prayer 'now' indicator duration"

requirements-completed: [PRAY-01, PRAY-02, PRAY-03]

# Metrics
duration: 2min
completed: 2026-04-12
---

# Phase 02 Plan 01: PrayerLogic Summary

**Stateless PrayerLogic module with seconds-since-midnight arithmetic for next-prayer identification, Isha-to-Fajr overnight rollover, threshold-based countdown formatting, and 5-segment progress bar data**

## Performance

- **Duration:** 2 min
- **Started:** 2026-04-12T08:25:51Z
- **Completed:** 2026-04-12T08:28:22Z
- **Tasks:** 1
- **Files created:** 1

## Accomplishments
- Created PrayerLogic module with 8 functions covering the full computational pipeline from raw "HH:MM" strings to display-ready data
- Implemented 4-state machine (no_data/now/normal/overnight) handling all edge cases including Isha-to-Fajr rollover and 5-minute "now" window
- All code annotated (:glance) for 28KB memory-safe glance usage with zero Toybox.Time imports and no debug print calls
- Defensive null handling throughout: malformed time strings, missing dictionary keys, and null tomorrow data all handled gracefully

## Task Commits

Each task was committed atomically:

1. **Task 1: Create PrayerLogic module with next-prayer calculation, rollover, and countdown formatting** - `06abb1f` (feat)

**Plan metadata:** [pending final commit]

## Files Created/Modified
- `source/PrayerLogic.mc` - Prayer calculation module: parseTimeToSeconds, getCurrentSeconds, getNextPrayer, getPreviousPrayer, getNextPrayerResult, formatCountdown, buildSegments, getDimColor

## Decisions Made
- Used untyped parameter for parseTimeToSeconds input to handle both null and non-String values from Storage with instanceof check, rather than typed `String` parameter that would crash on null
- Used untyped parameters for getNextPrayerResult's todayTimes/tomorrowTimes to handle null Dictionary inputs without type annotation conflicts
- Constants defined as module-level arrays (PRAYER_KEYS, PRAYER_LABELS, SEGMENT_COLORS) rather than inline literals for DRY code and single source of truth
- buildSegments provides fallback defaults (noon, 15:00, 18:00, 20:00) for null prayer times rather than returning empty/error

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- PrayerLogic module is complete and ready for consumption by MawaqitGlanceView (Plan 02-02)
- All public functions documented with parameter types and return types
- State machine output format documented for each state, enabling straightforward rendering logic in the GlanceView

## Self-Check: PASSED

- FOUND: source/PrayerLogic.mc
- FOUND: .planning/phases/02-prayer-logic-glance/02-01-SUMMARY.md
- FOUND: commit 06abb1f

---
*Phase: 02-prayer-logic-glance*
*Completed: 2026-04-12*
