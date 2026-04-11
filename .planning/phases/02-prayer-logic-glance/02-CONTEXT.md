# Phase 2: Prayer Logic & Glance - Context

**Gathered:** 2026-04-11
**Status:** Ready for planning

<domain>
## Phase Boundary

This phase delivers the prayer calculation logic (next prayer identification, Isha-to-Fajr rollover) and the Glance view that displays the next prayer name, countdown, and a visual day progress bar. The Glance is the primary user touchpoint — this is the core UX of the app. No full Widget (Phase 3) or background service (Phase 3) work here.

</domain>

<decisions>
## Implementation Decisions

### Glance Layout
- **D-01:** Glance follows the Sunrise glance design pattern from Garmin's built-in apps. Three-row layout:
  - **Top line:** Next prayer name + countdown (e.g., "Asr in 2h 15m")
  - **Middle:** Day progress bar with 5 colored prayer-period segments and a current-time marker
  - **Bottom line:** Previous prayer time (left) and next prayer time (right), flanking the bar
- **D-02:** Progress bar has 5 segments representing prayer periods (Fajr-to-Dhuhr, Dhuhr-to-Asr, Asr-to-Maghrib, Maghrib-to-Isha, Isha-to-Fajr). Each segment gets a distinct color. The active segment is highlighted. A white marker shows current position in the day.
- **D-03:** Bottom times show the "window" the user is in: left = time of prayer that just passed (current period start), right = time of next prayer (current period end).

### Countdown Format
- **D-04:** Countdown format follows the Sunrise glance convention: "Xh Ym" (e.g., "Asr in 2h 15m").
- **D-05:** Threshold behavior:
  - More than 1 hour: "Asr in 2h 15m"
  - Under 1 hour: minutes only — "Asr in 45m"
  - Under 1 minute: seconds — "Asr in 45s"
- **D-06:** No seconds display above 1 minute. Hours and minutes only for normal countdown.

### Prayer Transition
- **D-07:** When a prayer time arrives (countdown hits 0), show "now" indicator for 5 minutes (e.g., "Asr now"), then flip to the next prayer.
- **D-08:** After Isha, the display rolls to next day's Fajr with identical format — no visual distinction for overnight countdown. "Fajr in 8h 30m" looks the same as any daytime countdown.

### Glance Empty States
- **D-09:** No mosque configured: show "Mawaqit" on top line and "Set mosque in Connect app" on second line. No progress bar or times.
- **D-10:** Mosque configured but data expired/unavailable: show dashes as placeholders — "-- in --" top line, empty progress bar, "--:--" for both bottom times. Maintains the visual structure.

### Claude's Discretion
- During the 5-min "now" window, Claude decides how the bottom times and progress bar behave (e.g., marker position, which times to show).
- Color palette for the 5 prayer segments — Claude picks colors that are visually distinct on AMOLED and readable at glance size.
- Font choices within Garmin's available `Graphics.FONT_*` options for the glance.
- Timer/redraw strategy for countdown updates on the glance (noting that `WatchUi.requestUpdate()` may be ignored on some devices for GlanceView).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Platform APIs
- CLAUDE.md "Widget & Glance Lifecycle" section — `WatchUi.GlanceView`, `onUpdate(dc)`, `onShow()`/`onHide()`, `Timer.Timer` for countdown updates
- CLAUDE.md "Time Handling" section — `Gregorian.info()`, `Gregorian.moment()`, `Moment.subtract()`, `Duration.value()` for prayer time comparison and countdown calculation
- CLAUDE.md "Code Annotations" section — `(:glance)` annotation requirements for all glance-accessible code
- CLAUDE.md "Memory Budgets" section — Glance view 28-32KB budget constraint

### Project Documentation
- `.planning/PROJECT.md` — Core value, constraints, key decisions
- `.planning/REQUIREMENTS.md` — PRAY-01, PRAY-02, PRAY-03, GLNC-01, GLNC-02
- `.planning/ROADMAP.md` — Phase 2 success criteria and requirement mapping

### Phase 1 Context
- `.planning/phases/01-data-pipeline-configuration/01-CONTEXT.md` — Data model decisions (D-01 through D-08), storage keys, API response structure

### Visual Reference
- Garmin built-in Sunrise glance — layout model for the Mawaqit glance (3-row: text, progress bar, times)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `PrayerDataStore` module (`source/PrayerDataStore.mc`): provides `getTodayPrayerTimes()`, `getTomorrowPrayerTimes()`, `getTodayIqama()`, `hasCachedData()`, `isMosqueConfigured()` — all needed for prayer logic
- `MawaqitGlanceView` stub (`source/GarminMawaqitApp.mc:113`): already declared with `(:glance)` annotation, wired to `getGlanceView()` — replace stub with real implementation
- `GarminMawaqitApp.getGlanceView()` (`source/GarminMawaqitApp.mc:34`): already returns the glance view array

### Established Patterns
- Module pattern for stateless data access (`PrayerDataStore`)
- Singleton class pattern for services (`MawaqitService`)
- Prayer time keys from storage: `fajr`, `sunrise`, `dohr`, `asr`, `maghreb`, `icha` (6 time strings per day)
- Iqama keys: `fajr`, `dohr`, `asr`, `maghreb`, `icha` (5 offset strings)

### Integration Points
- `PrayerDataStore.getTodayPrayerTimes()` returns Dictionary with time strings — prayer logic must parse these into comparable Moment objects
- `PrayerDataStore.getTomorrowPrayerTimes()` — needed for Isha-to-Fajr rollover
- `PrayerDataStore.hasCachedData()` and `isMosqueConfigured()` — drive empty state logic (D-09, D-10)
- Target devices: Fenix 8 variants (round AMOLED 454x454) — high-res screens

</code_context>

<specifics>
## Specific Ideas

- Glance should look and feel like Garmin's built-in Sunrise glance — same layout rhythm, similar information density
- The 5 colored segments map to the 5 prayer periods between consecutive prayers
- The white progress marker shows where "now" falls in the current prayer period
- Bottom times bracket the current prayer period (just-passed prayer on left, next prayer on right)

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 02-prayer-logic-glance*
*Context gathered: 2026-04-11*
