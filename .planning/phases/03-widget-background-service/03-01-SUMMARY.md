---
phase: 03-widget-background-service
plan: 01
subsystem: ui
tags: [monkey-c, widget, prayer-times, garmin, connect-iq, dc-drawing]

# Dependency graph
requires:
  - phase: 02-prayer-logic-glance
    provides: PrayerLogic module (getNextPrayerResult, formatCountdown, PRAYER_KEYS, PRAYER_LABELS)
  - phase: 01-data-pipeline
    provides: PrayerDataStore module (getTodayPrayerTimes, getTodayIqama, getTomorrowPrayerTimes, isMosqueConfigured, hasCachedData)
provides:
  - Full-screen MawaqitWidgetView with 5-row prayer schedule, countdown header, iqama offsets
  - Clean GarminMawaqitApp.mc without stub widget class
affects: [03-02 background-service, future UI refinement plans]

# Tech tracking
tech-stack:
  added: []
  patterns: [proportional-layout-percentages, green-accent-highlight, empty-state-pattern-widget]

key-files:
  created: [source/MawaqitWidgetView.mc]
  modified: [source/GarminMawaqitApp.mc]

key-decisions:
  - "1-second fixed timer for widget (no adaptive logic like Glance) -- widget has 64-128KB budget"
  - "Proportional layout using percentage-of-screen-size math for multi-resolution support"
  - "Green accent 0x00AA44 with fillRoundedRectangle for highlighted next prayer row"
  - "Two-line mosque setup message instead of single line with newline for better readability"

patterns-established:
  - "Widget Dc drawing: proportional layout with h*N/100 positioning for round AMOLED screens"
  - "Empty state pattern: drawEmptyState() with prayer labels and '--:--' placeholders"
  - "Highlight pattern: fillRoundedRectangle with FONT_SMALL for highlighted row, FONT_XTINY for normal"

requirements-completed: [WDGT-01, WDGT-02, WDGT-03]

# Metrics
duration: 2min
completed: 2026-04-12
---

# Phase 3 Plan 1: Widget View Summary

**Full-screen 5-row prayer schedule widget with countdown header, green-accent highlighted next prayer, iqama offsets, and empty states**

## Performance

- **Duration:** 2 min
- **Started:** 2026-04-12T10:22:43Z
- **Completed:** 2026-04-12T10:24:46Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- Created MawaqitWidgetView.mc (274 lines) with full prayer schedule: countdown header, separator, 5 prayer rows with name/time/iqama
- Next prayer highlighted with green accent (0x00AA44) rounded rectangle background and larger FONT_SMALL
- Empty states for no-mosque-configured (setup instructions) and no-data (dashes placeholders)
- Removed 36-line stub MawaqitWidgetView class from GarminMawaqitApp.mc
- Single MawaqitWidgetView definition across codebase (in dedicated file)

## Task Commits

Each task was committed atomically:

1. **Task 1: Create MawaqitWidgetView with full prayer schedule layout** - `b713eb4` (feat)
2. **Task 2: Remove stub widget from GarminMawaqitApp and verify build** - `f55403e` (refactor)

## Files Created/Modified
- `source/MawaqitWidgetView.mc` - Full-screen widget view with 5-row prayer schedule, countdown, iqama offsets, empty states
- `source/GarminMawaqitApp.mc` - Stub MawaqitWidgetView class removed (74 lines down from 109)

## Decisions Made
- Used 1-second fixed timer interval for widget (no adaptive 30s/1s logic like Glance) since widget has 64-128KB memory budget -- simplicity wins
- Proportional layout using h*N/100 positioning: header at 15%, separator at 24%, rows from 30-82% -- works across 416x416 to 454x454 screens
- Two separate drawText calls for "Set mosque in" / "Garmin Connect app" instead of single string with \n -- more reliable on Garmin Dc
- Left unused imports (Graphics, System) in GarminMawaqitApp.mc -- harmless in Monkey C and avoids risk of breaking compilation

## Deviations from Plan

None - plan executed exactly as written.

## Threat Mitigations Applied

- **T-03-02 (Denial of Service via null data):** Widget checks `isMosqueConfigured()` and `hasCachedData()` before accessing prayer data. Null-safe access on all dictionary lookups with `"--:--"` fallback. `drawEmptyState()` fallback for all no-data paths.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Widget view complete and wired into app via getInitialView()
- Ready for Phase 3 Plan 2: background service for periodic data refresh
- PrayerLogic and PrayerDataStore modules confirmed working from both Glance and Widget contexts

---
*Phase: 03-widget-background-service*
*Completed: 2026-04-12*
