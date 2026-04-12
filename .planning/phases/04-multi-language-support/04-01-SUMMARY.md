---
phase: 04-multi-language-support
plan: 01
status: complete
started: "2026-04-12T19:19:37Z"
completed: "2026-04-12T19:23:20Z"
subsystem: localization
tags: [i18n, french, strings, glance, resources]
dependency_graph:
  requires: []
  provides: [string-resources, french-strings, localized-formatCountdown, localized-glance]
  affects: [source/MawaqitWidgetView.mc]
tech_stack:
  added: []
  patterns: [loadResource-in-views, token-parameter-passing]
key_files:
  created:
    - resources-fre/strings/strings.xml
  modified:
    - resources/strings/strings.xml
    - manifest.xml
    - source/PrayerLogic.mc
    - source/MawaqitGlanceView.mc
    - source/MawaqitWidgetView.mc
decisions:
  - "loadResource() safe for Glance 28KB budget (~400 bytes / 1.4%)"
  - "Token parameters on formatCountdown() instead of loadResource inside PrayerLogic (background context safety)"
  - "AppName omitted from French strings (brand name inherits from base)"
metrics:
  duration: 223s
  completed: "2026-04-12T19:23:20Z"
  tasks: 2
  files: 6
---

# Phase 04 Plan 01: French/English String Resources & Glance Localization Summary

French/English string resource infrastructure with loadResource()-based Glance localization using token parameter passing to keep PrayerLogic background-safe.

## Objective

Create the French/English string resource infrastructure and localize the Glance view surface. Establishes the localization foundation (string resources, manifest language declaration, French resource folder) and wires the Glance view to use localized strings.

## What Was Built

- **English string resources** (`resources/strings/strings.xml`): Expanded from 3 to 9 entries covering countdown tokens ("in"/"now"), Glance and Widget empty states, and no-data placeholder.
- **French string overrides** (`resources-fre/strings/strings.xml`): 8 French translations (all except AppName which inherits as brand name). Countdown "dans"/"maintenant", settings "ID Mosquee", empty states "Configurer dans l'app Connect".
- **Manifest language declaration**: Added `fre` to `<iq:languages>` block so the build system includes French resources.
- **Localized formatCountdown()**: Added `tokenIn` and `tokenNow` parameters to `PrayerLogic.formatCountdown()`, replacing hardcoded "in"/"now" with caller-provided localized tokens.
- **GlanceView localization**: All display strings now loaded via `WatchUi.loadResource(Rez.Strings.*)` except brand name "Mawaqit" and time format "--:--".

## Tasks Completed

| # | Task | Files Changed | Commit | Status |
|---|------|---------------|--------|--------|
| 1 | Create string resource files and update manifest | resources/strings/strings.xml, resources-fre/strings/strings.xml, manifest.xml | 0852bcd | Done |
| 2 | Localize PrayerLogic.formatCountdown() and MawaqitGlanceView | source/PrayerLogic.mc, source/MawaqitGlanceView.mc, source/MawaqitWidgetView.mc | 47eda7c | Done |

## Key Files

### Created
- `resources-fre/strings/strings.xml` -- French string overrides (8 entries: settings, countdown tokens, empty states, placeholder)

### Modified
- `resources/strings/strings.xml` -- Expanded English defaults from 3 to 9 string entries
- `manifest.xml` -- Added `<iq:language>fre</iq:language>` to languages block
- `source/PrayerLogic.mc` -- formatCountdown() now accepts tokenIn/tokenNow parameters, uses them instead of hardcoded strings
- `source/MawaqitGlanceView.mc` -- All display strings loaded via loadResource(); formatCountdown calls pass localized tokens
- `source/MawaqitWidgetView.mc` -- formatCountdown calls updated to pass tokenIn/tokenNow (Rule 3 deviation)

## Decisions Made

1. **loadResource() in Glance is safe**: ~400 bytes overhead (1.4% of 28KB budget) per research. Unified approach for both Widget and Glance.
2. **Token parameters over internal loadResource**: PrayerLogic.formatCountdown() receives tokens as parameters from view callers, avoiding WatchUi dependency that would crash in background context (Pitfall 2).
3. **AppName omitted from French file**: "Mawaqit" is a brand name, inherits from base resources automatically (D-09).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Updated MawaqitWidgetView.mc formatCountdown() calls**
- **Found during:** Task 2
- **Issue:** Changing formatCountdown() signature from 2 to 4 parameters would break MawaqitWidgetView.mc which still used the old 2-argument calls, preventing compilation.
- **Fix:** Updated all 3 formatCountdown() calls in MawaqitWidgetView.mc to load tokenIn/tokenNow via loadResource() and pass them as arguments, matching the new signature.
- **Files modified:** source/MawaqitWidgetView.mc
- **Commit:** 47eda7c

## Issues Encountered

None -- plan executed cleanly with one anticipated Rule 3 deviation.

## Verification Results

All 7 plan verification checks passed:
1. `CountdownIn` present in English strings.xml
2. `dans` present in French strings.xml
3. `fre` present in manifest.xml
4. `tokenIn as String` present in PrayerLogic.mc
5. `Rez.Strings.CountdownIn` present in MawaqitGlanceView.mc
6. Zero loadResource() code calls in PrayerLogic.mc (only in doc comments)
7. Zero hardcoded English display strings in MawaqitGlanceView.mc code (only in comments)

## Self-Check: PASSED

All 7 files exist on disk. Both commit hashes (0852bcd, 47eda7c) verified in git log.
