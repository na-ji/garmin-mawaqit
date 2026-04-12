---
phase: 02-prayer-logic-glance
plan: 02
status: completed
started: 2026-04-12
completed: 2026-04-12
tasks_completed: 2
tasks_total: 2
---

## What Was Built

Full MawaqitGlanceView implementation with Sunrise-inspired 3-row layout:

- **Top line**: Next prayer name + countdown via `PrayerLogic.formatCountdown()` (e.g., "Asr in 2h 15m")
- **Middle**: 5-segment colored progress bar via `PrayerLogic.buildSegments()` with white current-time marker
- **Bottom line**: Previous prayer time (left) and next prayer time (right)
- **Empty states**: D-09 ("Mawaqit" / "Set mosque in Connect app"), D-10 ("-- in --" with gray bar)
- **Timer**: 30s refresh normally, 1s when countdown < 60s for seconds accuracy

## Key Files

### Created
- `source/MawaqitGlanceView.mc` — 289 lines, (:glance) annotated, direct Dc drawing, no XML layouts

### Modified
- `source/GarminMawaqitApp.mc` — Stub MawaqitGlanceView removed; added `(:glance)` to class; moved `MawaqitService.fetchPrayerData()` from `onStart()` to `getInitialView()`; added proper return type to `getGlanceView()`
- `source/PrayerDataStore.mc` — Added `(:glance)` annotation to module so glance context can access prayer data

## Critical Bug Fix

**Root cause**: `onStart()` runs in ALL CIQ contexts including glance. It referenced `MawaqitService.fetchPrayerData()` — a symbol whose code is not loaded in glance context. This caused an uncatchable VM-level "Illegal Access (Out of Bounds)" crash that killed the app before `getGlanceView()` was ever called. The system then showed the default glance.

**Why `$ has :MawaqitService` didn't help**: In CIQ SDK 9.1.0, the `has` operator checks symbol declaration (APPTYPE bitmask), not runtime code availability. All symbols are declared globally (APPTYPE 127), so `has` returns `true` even when the method body isn't loaded. The subsequent invocation then crashes at the VM level — an error that `try/catch` also cannot intercept.

**Fix**: Moved `MawaqitService.fetchPrayerData()` to `getInitialView()`, which only runs in widget context (never in glance context). Added `(:glance)` to `PrayerDataStore` module and `GarminMawaqitApp` class so their code is available in glance context.

## Deviations from Plan

1. **MawaqitService call moved from onStart to getInitialView** — Not in original plan. Required to prevent glance crash. Fetch now only triggers when user opens widget, not on app start. Background service (Phase 3) will handle periodic refresh.
2. **(:glance) added to GarminMawaqitApp class** — Original plan only annotated `getGlanceView()`. Class-level annotation needed for lifecycle methods to work in glance context.
3. **(:glance) added to PrayerDataStore module** — Not in Phase 2 plan (was a Phase 1 artifact). Required because GlanceView calls `PrayerDataStore.isMosqueConfigured()`, `.hasCachedData()`, `.getTodayPrayerTimes()`, `.getTomorrowPrayerTimes()`.

## Verification

- [x] Build succeeds for fenix847mm (SDK 9.1.0)
- [x] Glance displays 3-row layout: countdown text, progress bar, time window
- [x] Empty state D-09 renders ("Mawaqit" + "Set mosque in Connect app")
- [x] Empty state D-10 renders ("-- in --" with gray bar)
- [x] Timer refreshes display periodically
- [x] No System.println() in any new file
- [x] GarminMawaqitApp.mc stub removed, getGlanceView works
- [x] Human verification confirmed in simulator

## Self-Check: PASSED
