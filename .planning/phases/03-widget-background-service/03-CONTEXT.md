# Phase 3: Widget & Background Service - Context

**Gathered:** 2026-04-12
**Status:** Ready for planning

<domain>
## Phase Boundary

This phase delivers the full-screen Widget view showing all 5 daily prayer times with the next prayer highlighted, iqama offsets, and a countdown — plus a background service that refreshes data once daily via temporal events. The Glance (Phase 2) is the quick-peek; the Widget is the detailed view. The background service ensures data stays fresh without user intervention.

</domain>

<decisions>
## Implementation Decisions

### Widget Layout & Content
- **D-01:** Widget shows all 5 daily prayers in a vertical list. This supersedes the PROJECT.md "out of scope" note — the Glance covers "next prayer only", while the Widget provides the full schedule as a complement.
- **D-02:** Layout is: countdown at top ("Asr in 2h 15m"), separator, then 5 prayer rows (name, time, iqama offset).
- **D-03:** Next prayer row is highlighted with bold font and an accent color (e.g., green) on AMOLED. Other rows are white/gray. The highlighted row IS the progress indicator (WDGT-03) — no separate progress bar needed.
- **D-04:** Countdown at the top follows the same format as the Glance: "Xh Ym", "Xm" under 1 hour, "Xs" under 1 minute, "Prayer now" for 5 minutes after prayer time.

### Iqama Display
- **D-05:** Iqama shown as offset notation after the prayer time (e.g., "+10", "+5"). Compact, matches API data format, avoids needing a second column of absolute times.
- **D-06:** Sunrise (Shuruq) is excluded from the Widget. Only the 5 daily prayers are shown. Sunrise display is deferred (DISP-02 in v2).

### Widget Empty States
- **D-07:** Empty states match the Glance patterns for consistency:
  - No mosque configured: "Mawaqit" title + "Set mosque in Garmin Connect app" instructions
  - Data unavailable: "-- in --" countdown placeholder, all 5 rows show "--:--" for times

### Background Service
- **D-08:** Background service refreshes data once daily via `Background.registerForTemporalEvent()`. With the 12-month calendar cached, this is primarily to catch mosque schedule changes. Minimal battery impact.
- **D-09:** Mosque setting changes trigger an immediate foreground fetch via the existing `onSettingsChanged()` in GarminMawaqitApp (Phase 1 code). The background service simply reads the current slug on each run — no special handling needed for setting changes.
- **D-10:** Background service uses `ServiceDelegate` with `(:background)` annotation. Calls `MawaqitService.fetchPrayerData()` from `onTemporalEvent()`, stores results via `Background.exit(data)`, and `onBackgroundData()` writes to Storage.

### Claude's Discretion
- Exact accent color for the highlighted next-prayer row — Claude picks something that's visible on AMOLED and harmonizes with the prayer period colors from the Glance.
- Font choices within Garmin's `Graphics.FONT_*` options for the Widget — balance readability of 5 rows + countdown within screen space.
- Vertical spacing and positioning of the 5 rows on the round Widget screen.
- Error handling in the background service — retry logic, what happens when fetch fails silently.
- Whether the countdown updates via timer in the Widget (like the Glance) or relies on `onUpdate()` system calls.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Platform APIs
- CLAUDE.md "Widget & Glance Lifecycle" section — `WatchUi.View`, `onUpdate(dc)`, `onShow()`/`onHide()`, `AppBase.getInitialView()`
- CLAUDE.md "Background Service" section — `Background.registerForTemporalEvent()`, `ServiceDelegate`, `Background.exit()`, `AppBase.onBackgroundData()`, `AppBase.getServiceDelegate()`
- CLAUDE.md "Code Annotations" section — `(:background)` annotation for background service code
- CLAUDE.md "Memory Budgets" section — Widget 64-128KB budget, background 28-32KB budget (shared with glance)

### Project Documentation
- `.planning/PROJECT.md` — Core value, constraints (note: D-01 supersedes the "full schedule out of scope" note)
- `.planning/REQUIREMENTS.md` — WDGT-01, WDGT-02, WDGT-03, BKGD-01, BKGD-02
- `.planning/ROADMAP.md` — Phase 3 success criteria and requirement mapping

### Prior Phase Context
- `.planning/phases/01-data-pipeline-configuration/01-CONTEXT.md` — Data model (D-01 through D-08), storage keys, API endpoints, fetch chain
- `.planning/phases/02-prayer-logic-glance/02-CONTEXT.md` — Countdown format (D-04 through D-06), prayer transition (D-07/D-08), empty states (D-09/D-10)

### Existing Code
- `source/GarminMawaqitApp.mc` — App class with `getInitialView()`, `onSettingsChanged()`, stub `MawaqitWidgetView` (replace in this phase)
- `source/PrayerLogic.mc` — `formatCountdown()`, `getNextPrayerResult()`, `PRAYER_KEYS`, `PRAYER_LABELS` — all reusable for Widget
- `source/PrayerDataStore.mc` — `getTodayPrayerTimes()`, `getTodayIqama()`, `hasCachedData()`, `isMosqueConfigured()` — data source for Widget
- `source/MawaqitService.mc` — `fetchPrayerData()` — called by background service

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `PrayerLogic` module: `getNextPrayerResult()` state machine, `formatCountdown()`, `PRAYER_KEYS`/`PRAYER_LABELS` constants — all (:glance) annotated but usable from Widget context too
- `PrayerDataStore` module: all read accessors for prayer times, iqama offsets, mosque config status
- `MawaqitService` class: singleton with `fetchPrayerData()` — can be called from both foreground and background
- `GarminMawaqitApp.onSettingsChanged()`: already handles slug changes with cache clear and re-fetch

### Established Patterns
- Module pattern for stateless logic (PrayerLogic, PrayerDataStore)
- Singleton class pattern for services (MawaqitService)
- Seconds-since-midnight arithmetic for time comparisons (PrayerLogic)
- State machine result dictionary from `getNextPrayerResult()`: `{state => no_data|now|normal|overnight, ...}`
- Direct Dc drawing with no XML layouts (MawaqitGlanceView)
- Prayer time keys: `fajr`, `dohr`, `asr`, `maghreb`, `icha`
- Iqama keys match prayer keys with offset strings like `"+10"`

### Integration Points
- `MawaqitWidgetView` stub in `GarminMawaqitApp.mc:78` — replace with real implementation
- `getInitialView()` returns `MawaqitWidgetView` — already wired
- `AppBase.getServiceDelegate()` — needs to be added for background service
- `AppBase.onBackgroundData()` — needs to be added to receive background fetch results
- `Background.registerForTemporalEvent()` — register in `getInitialView()` or `onStart()`

</code_context>

<specifics>
## Specific Ideas

- Widget countdown reuses the exact same format as the Glance (PrayerLogic.formatCountdown) for consistency
- Iqama offset notation matches the raw API format — no conversion needed, just display the stored string
- The highlighted row (bold + accent color) satisfies WDGT-03's "visual progress indicator" requirement — the highlight moving through the prayer list as the day progresses IS the progress indicator
- Background service can be minimal: read slug, call fetchPrayerData, exit. All the complex fetch chain logic is already in MawaqitService

</specifics>

<deferred>
## Deferred Ideas

- Sunrise/Shuruq display in Widget — already tracked as DISP-02 in v2 requirements
- Circular arc progress indicator — interesting for round displays but adds complexity

</deferred>

---

*Phase: 03-widget-background-service*
*Context gathered: 2026-04-12*
