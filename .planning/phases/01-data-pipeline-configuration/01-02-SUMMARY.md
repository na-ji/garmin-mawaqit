---
phase: 01-data-pipeline-configuration
plan: 02
subsystem: api
tags: [garmin, connect-iq, monkey-c, http, storage, mawaqit-api, prayer-times, iqama, metadata]

# Dependency graph
requires:
  - phase: 01-01
    provides: AppBase class with getMosqueSlug, clearCachedData, stub views, and TODO comments for fetch wiring
provides:
  - MawaqitService HTTP fetch chain (6 sequential requests: 2 calendar + 2 iqama + metadata + prayer-times)
  - PrayerDataStore read layer for cached prayer data, iqama offsets, and mosque metadata
  - AppBase wiring of fetchPrayerData on onStart and onSettingsChanged
  - Offline fallback via silent error abort preserving cached data (DATA-03)
  - Two months of calendar/iqama data for Isha-to-Fajr rollover (DATA-04)
affects: [02-glance-view, 03-widget-background]

# Tech tracking
tech-stack:
  added: []
  patterns: [Module-based service pattern for HTTP fetch chain, Module-based storage read layer, Sequential callback chaining for multi-request fetch, _isFetching guard for concurrent request prevention]

key-files:
  created:
    - source/MawaqitService.mc
    - source/PrayerDataStore.mc
  modified:
    - source/GarminMawaqitApp.mc

key-decisions:
  - "Module pattern (not class) for MawaqitService and PrayerDataStore -- singleton behavior, simpler than class instances"
  - "6-step fetch chain order: calendar(current), calendar(next), iqama(current), iqama(next), metadata, prayer-times"
  - "WatchUi.requestUpdate() called only after full chain completes (last step), not after each intermediate response"
  - "getTodayPrayerTimes prefers calendar data over /prayer-times cache for accuracy"

patterns-established:
  - "Module-level state variables for fetch chain tracking (_fetchStep, _isFetching, _fetchSlug)"
  - "Silent abort on HTTP error: set _isFetching=false and return, leaving cached data intact (D-06)"
  - "String keys for all Storage access (never Symbols) per Pitfall 3"
  - "Calendar 0-indexed access: cal[day-1] for current day's data"

requirements-completed: [DATA-01, DATA-02, DATA-03, DATA-04, DATA-05]

# Metrics
duration: 2min
completed: 2026-04-10
---

# Phase 1 Plan 2: Data Fetch Service & Storage Layer Summary

**MawaqitService HTTP fetch chain with 6 sequential per-month/metadata requests, PrayerDataStore read layer, and AppBase lifecycle wiring for prayer data pipeline**

## Performance

- **Duration:** 2 min
- **Started:** 2026-04-10T21:10:38Z
- **Completed:** 2026-04-10T21:12:46Z
- **Tasks:** 2
- **Files created:** 2, modified: 1

## Accomplishments
- MawaqitService fetches prayer data through 6 sequential HTTP requests using per-month endpoints (~3KB each), safely within device JSON size limits
- PrayerDataStore provides 9 read accessors including getTodayPrayerTimes, getTomorrowPrayerTimes (month boundary rollover), getTodayIqama, getMosqueMeta, and hasCachedData
- Mosque metadata (name, timezone, jumua, jumua2, shuruq, hijriAdjustment) fetched from dedicated /metadata endpoint (D-08) and stored in "mosqueMeta" key
- AppBase wired to trigger fetch on app start (if slug configured) and on settings change (when slug changes)
- Silent error abort on any HTTP failure preserves existing cached data for offline use (D-06)

## Task Commits

Each task was committed atomically:

1. **Task 1: Create MawaqitService with chained HTTP request pipeline including metadata fetch** - `a1e392f` (feat)
2. **Task 2: Create PrayerDataStore read layer and wire fetch into AppBase** - `610dbfc` (feat)

## Files Created/Modified
- `source/MawaqitService.mc` - HTTP fetch chain module: 6 sequential API requests (calendar, iqama, metadata, prayer-times), Storage writes, error handling
- `source/PrayerDataStore.mc` - Storage read layer module: 9 accessor functions for calendar, iqama, metadata, today/tomorrow times, and data validity checks
- `source/GarminMawaqitApp.mc` - Replaced TODO comments with MawaqitService.fetchPrayerData calls in onStart and onSettingsChanged

## Decisions Made
- Used Monkey C module pattern (not class) for both MawaqitService and PrayerDataStore -- provides singleton behavior without requiring object instantiation
- Fetch chain order prioritizes calendar data first (most important for display), metadata second, prayer-times last (least critical since calendar covers today)
- WatchUi.requestUpdate() called only once after full chain completes, not after each intermediate step -- avoids unnecessary redraws with partial data
- getTodayPrayerTimes prefers calendar data over /prayer-times endpoint cache for better accuracy (calendar has all 6 time fields including sunrise)
- Days-in-month calculation uses Gregorian.moment to construct first-of-next-month then subtract 86400 seconds -- avoids hardcoding month lengths

## Deviations from Plan

None - plan executed exactly as written.

## Known Stubs

| File | Line | Stub | Resolution |
|------|------|------|------------|
| source/GarminMawaqitApp.mc | 75-84 | MawaqitWidgetView stub (draws "Mawaqit" text only) | Phase 3 (widget view) |
| source/GarminMawaqitApp.mc | 90-103 | MawaqitGlanceView stub (draws "Mawaqit" text only) | Phase 2 (glance view) |

All stubs are intentional scaffolding from Plan 01-01. They do not prevent this plan's goals from being achieved.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Data pipeline complete: MawaqitService fetches, PrayerDataStore reads, AppBase triggers
- Phase 2 (Glance View) can use PrayerDataStore.getTodayPrayerTimes(), getMosqueMeta(), hasCachedData() to display next prayer
- Phase 3 (Widget + Background) can use PrayerDataStore.getTomorrowPrayerTimes() for Isha-to-Fajr rollover display
- Background service (Phase 3) can call MawaqitService.fetchPrayerData() for periodic refresh

## Self-Check: PASSED

- All 3 source files verified as existing on disk
- SUMMARY.md verified as existing on disk
- Commit a1e392f (Task 1) verified in git log
- Commit 610dbfc (Task 2) verified in git log

---
*Phase: 01-data-pipeline-configuration*
*Completed: 2026-04-10*
