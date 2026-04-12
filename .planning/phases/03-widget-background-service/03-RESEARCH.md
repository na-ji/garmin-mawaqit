# Phase 3: Widget & Background Service - Research

**Researched:** 2026-04-12
**Domain:** Connect IQ Widget View (full-screen drawing), Background Service (temporal events), Monkey C Dc graphics
**Confidence:** HIGH

## Summary

Phase 3 delivers two distinct subsystems: (1) a full-screen Widget view displaying all 5 daily prayers with countdown, iqama offsets, and next-prayer highlighting, and (2) a background service that periodically refreshes prayer data via temporal events. Both build heavily on existing Phase 1/2 infrastructure (PrayerLogic, PrayerDataStore, MawaqitService).

The Widget is straightforward -- it uses the same `WatchUi.View` + `onUpdate(dc)` pattern as the stub already in `GarminMawaqitApp.mc`, with direct Dc drawing calls for a vertical prayer list layout on round AMOLED screens (416x416 to 454x454). The Glance established all the drawing patterns; the Widget has a more generous 64-128KB memory budget.

The background service has a critical architectural constraint: **the background process has a 30-second execution timeout and a 28-32KB memory budget**. The existing `MawaqitService` with its 6-step sequential fetch chain (6 HTTP requests) cannot safely run in background -- it would risk timeout and exceeds the memory budget if annotated `(:background)`. The background service must use a simplified single-request approach, fetching only the `/prayer-times` endpoint and storing results via `Background.exit()` + `onBackgroundData()`.

**Primary recommendation:** Build a dedicated lightweight `BackgroundServiceDelegate` that makes a single API call, separate from the foreground `MawaqitService`. The Widget view follows the existing Dc drawing pattern from the Glance but with a vertical 5-row prayer list layout.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Widget shows all 5 daily prayers in a vertical list. Supersedes PROJECT.md "out of scope" note.
- **D-02:** Layout: countdown at top ("Asr in 2h 15m"), separator, then 5 prayer rows (name, time, iqama offset).
- **D-03:** Next prayer row highlighted with bold font and accent color (e.g., green) on AMOLED. This IS the progress indicator (WDGT-03).
- **D-04:** Countdown at top follows same format as Glance: "Xh Ym", "Xm", "Xs", "Prayer now".
- **D-05:** Iqama shown as offset notation after prayer time (e.g., "+10", "+5").
- **D-06:** Sunrise (Shuruq) excluded from Widget. Only 5 daily prayers.
- **D-07:** Empty states match Glance patterns: no mosque -> instructions, no data -> dashes.
- **D-08:** Background service refreshes data once daily via `Background.registerForTemporalEvent()`.
- **D-09:** Mosque setting changes trigger foreground fetch via existing `onSettingsChanged()`. Background service just reads current slug.
- **D-10:** Background service uses `ServiceDelegate` with `(:background)` annotation. Calls `MawaqitService.fetchPrayerData()` from `onTemporalEvent()`, stores results via `Background.exit(data)`, and `onBackgroundData()` writes to Storage.

### Claude's Discretion
- Exact accent color for highlighted next-prayer row
- Font choices within Garmin's `Graphics.FONT_*` options for the Widget
- Vertical spacing and positioning of the 5 rows on round screen
- Error handling in background service (retry logic, silent failure handling)
- Whether countdown updates via timer in Widget or relies on system `onUpdate()` calls

### Deferred Ideas (OUT OF SCOPE)
- Sunrise/Shuruq display in Widget (tracked as DISP-02 in v2)
- Circular arc progress indicator
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| WDGT-01 | Widget shows all 5 daily prayers with next prayer highlighted | D-01, D-02, D-03: Vertical list layout with bold+accent highlight on next prayer row. PrayerLogic.getNextPrayerResult() provides index for highlighting. Direct Dc drawing with fillRoundedRectangle for highlight background. |
| WDGT-02 | Widget shows iqama times alongside prayer times | D-05: PrayerDataStore.getTodayIqama() returns offset dictionary with keys matching prayer keys. Display as "+N" suffix after time. |
| WDGT-03 | Widget displays visual progress indicator between prayers | D-03: The highlighted row moving through the list IS the progress indicator. No separate bar or arc needed. |
| BKGD-01 | Background service refreshes data periodically via temporal events | D-08: Background.registerForTemporalEvent() with Duration. Minimum 5-min interval, once daily sufficient. ServiceDelegate with onTemporalEvent(). 30-second timeout constraint requires simplified single-request approach. |
| BKGD-02 | Background service re-fetches when mosque settings change | D-09: Already handled by existing onSettingsChanged() in foreground. Background service reads current slug from Properties on each run -- no special handling. |
</phase_requirements>

## Standard Stack

This phase uses no new external libraries -- everything is built into the Toybox SDK. The "stack" is the set of Toybox APIs used.

### Core APIs for Widget
| API | Module | Purpose | Why Standard |
|-----|--------|---------|--------------|
| `WatchUi.View` | `Toybox.WatchUi` | Widget view base class | Only way to create full-screen widget views [VERIFIED: CLAUDE.md] |
| `Graphics.Dc` | `Toybox.Graphics` | Drawing context for onUpdate | Direct drawing API for text, rectangles, colors [VERIFIED: Garmin API docs] |
| `Timer.Timer` | `Toybox.Timer` | Periodic countdown refresh | Standard timer for 1-second widget updates [VERIFIED: CLAUDE.md] |
| `WatchUi.requestUpdate()` | `Toybox.WatchUi` | Trigger view redraw | Works reliably for full widget views (unlike glances) [VERIFIED: CLAUDE.md] |

### Core APIs for Background Service
| API | Module | Purpose | Why Standard |
|-----|--------|---------|--------------|
| `System.ServiceDelegate` | `Toybox.System` | Background task handler base | Required base class for background services [VERIFIED: Garmin API docs] |
| `Background.registerForTemporalEvent()` | `Toybox.Background` | Schedule background runs | Only way to schedule periodic background execution [VERIFIED: Garmin API docs] |
| `Background.exit()` | `Toybox.Background` | Return data from background | Required to pass data from background to foreground. ~8KB data limit. [VERIFIED: Garmin API docs] |
| `Background.getTemporalEventRegisteredTime()` | `Toybox.Background` | Check if already registered | Prevents duplicate registrations [VERIFIED: Garmin API docs] |
| `Communications.makeWebRequest()` | `Toybox.Communications` | HTTP request in background | Works in background context for data fetching [VERIFIED: Garmin forums] |

### Reusable from Prior Phases
| Module/Class | File | What It Provides |
|-------------|------|-----------------|
| `PrayerLogic` | `PrayerLogic.mc` | `getNextPrayerResult()`, `formatCountdown()`, `PRAYER_KEYS`, `PRAYER_LABELS`, `parseTimeToSeconds()` |
| `PrayerDataStore` | `PrayerDataStore.mc` | `getTodayPrayerTimes()`, `getTodayIqama()`, `getTomorrowPrayerTimes()`, `hasCachedData()`, `isMosqueConfigured()` |
| `MawaqitService` | `MawaqitService.mc` | `fetchPrayerData()` -- foreground fetch chain (NOT for background use) |
| `GarminMawaqitApp` | `GarminMawaqitApp.mc` | `onSettingsChanged()`, `getInitialView()`, `getGlanceView()` -- extend with background methods |

## Architecture Patterns

### Recommended Project Structure
```
source/
  GarminMawaqitApp.mc       # App class (add getServiceDelegate, onBackgroundData, registerForTemporalEvent)
  MawaqitWidgetView.mc      # NEW: Full widget view (replace stub in GarminMawaqitApp.mc)
  MawaqitGlanceView.mc      # Existing: Glance view (unchanged)
  MawaqitServiceDelegate.mc # NEW: Background service delegate
  MawaqitService.mc         # Existing: Foreground HTTP service (unchanged)
  PrayerLogic.mc            # Existing: Prayer calculation (unchanged, reused by Widget)
  PrayerDataStore.mc        # Existing: Storage read accessors (unchanged, reused by Widget)
```

### Pattern 1: Widget View with Timer-Driven Countdown
**What:** Widget extends `WatchUi.View`, starts a 1-second `Timer.Timer` in `onShow()`, stops in `onHide()`. Timer callback calls `WatchUi.requestUpdate()` which triggers `onUpdate(dc)`.
**When to use:** Any widget that needs live-updating countdown display.
**Why timer:** Unlike Glance where `requestUpdate()` may be ignored, the full Widget view supports reliable timer-driven redraws. [VERIFIED: CLAUDE.md lifecycle docs]

```monkeyc
// Source: CLAUDE.md Widget & Glance Lifecycle + MawaqitGlanceView.mc established pattern
class MawaqitWidgetView extends WatchUi.View {
    var _timer as Timer.Timer or Null = null;

    function initialize() {
        View.initialize();
    }

    function onShow() as Void {
        _timer = new Timer.Timer();
        _timer.start(method(:onTimer), 1000, true);  // 1-second updates
    }

    function onHide() as Void {
        if (_timer != null) {
            _timer.stop();
            _timer = null;
        }
    }

    function onTimer() as Void {
        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        // Full drawing logic here
    }
}
```

### Pattern 2: Lightweight Background ServiceDelegate (Single Request)
**What:** A minimal `(:background)` annotated class that makes ONE HTTP request, passes result through `Background.exit()`. Does NOT reuse MawaqitService.
**When to use:** Any background data refresh where the full foreground fetch chain is too heavy.
**Critical constraint:** 30-second timeout, 28-32KB memory budget, ~8KB data limit for `Background.exit()`. [VERIFIED: Garmin API docs]

```monkeyc
// Source: Garmin Connect IQ FAQ + API docs
(:background)
class MawaqitServiceDelegate extends System.ServiceDelegate {
    function initialize() {
        ServiceDelegate.initialize();
    }

    function onTemporalEvent() as Void {
        var slug = Properties.getValue("mosqueSetting") as String or Null;
        if (slug == null || slug.equals("")) {
            Background.exit(null);
            return;
        }

        var url = "https://mawaqit.naj.ovh/api/v1/" + slug + "/prayer-times";
        Communications.makeWebRequest(
            url,
            null,
            {
                :method => Communications.HTTP_REQUEST_METHOD_GET,
                :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
            },
            method(:onReceive)
        );
    }

    function onReceive(responseCode as Number, data as Dictionary or String or Null) as Void {
        if (responseCode == 200 && data != null) {
            Background.exit(data);
        } else {
            Background.exit(null);
        }
    }
}
```

### Pattern 3: App Class Background Integration
**What:** Add `getServiceDelegate()`, `onBackgroundData()`, and temporal event registration to the existing App class.
**Critical:** `getServiceDelegate()` must be annotated `(:background)`.

```monkeyc
// Source: Garmin API docs + CIQ background FAQ
// In GarminMawaqitApp class:

(:background)
function getServiceDelegate() as [System.ServiceDelegate] {
    return [new MawaqitServiceDelegate()];
}

function onBackgroundData(data) as Void {
    if (data != null) {
        Storage.setValue("todayTimes", data);
        // Update last fetch metadata
        var info = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        Storage.setValue("lastFetchDate", info.year + "-" + info.month + "-" + info.day);
    }
    WatchUi.requestUpdate();
}
```

### Pattern 4: Vertical List Layout on Round Screen
**What:** Draw 5 prayer rows centered on a round AMOLED display. Use `dc.getWidth()` / `dc.getHeight()` for proportional layout. Highlight the active row with a filled rounded rectangle behind the text.
**Key considerations:**
- Round screens clip content at edges -- keep text within ~80% of width for side rows
- Use `dc.getFontHeight()` to calculate row heights dynamically
- Center the list vertically, accounting for the countdown header

```monkeyc
// Source: Garmin Graphics.Dc API docs
// Conceptual layout for 5-row prayer list on 416x416 round display:
//
//   [     "Asr in 2h 15m"      ]  <- countdown header
//   [  ______________________  ]  <- separator line
//   [  Fajr    05:30    +10    ]  <- prayer row (normal)
//   [  Dhuhr   12:45    +5     ]  <- prayer row (normal)
//   [* Asr     15:30    +10   *]  <- prayer row (HIGHLIGHTED)
//   [  Maghrib 18:45    +5     ]  <- prayer row (normal)
//   [  Isha    20:30    +10    ]  <- prayer row (normal)
```

### Anti-Patterns to Avoid
- **Reusing MawaqitService in background:** The 6-step fetch chain (6 HTTP requests) risks the 30-second background timeout. The singleton pattern with instance state also doesn't work across background/foreground process boundaries (they don't share memory). Use a dedicated lightweight ServiceDelegate instead. [VERIFIED: Garmin forums]
- **Annotating MawaqitService as (:background):** Would add its full code footprint to the 28-32KB background budget AND the glance budget (since glance+background share memory). Not worth it for a single daily refresh. [VERIFIED: Garmin forums]
- **Using Storage.setValue() directly from background:** While technically supported since CIQ 3.2.0, the CONTEXT.md decision D-10 specifies using `Background.exit()` + `onBackgroundData()` pattern. This is also the more reliable pattern across devices. [VERIFIED: Garmin API docs]
- **Calling WatchUi.requestUpdate() from background:** Not available in background context. Redraw happens when `onBackgroundData()` runs in the foreground. [ASSUMED]
- **XML layouts for Widget:** The Glance already established direct Dc drawing. Continue this pattern for consistency and control. [VERIFIED: codebase pattern]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Next prayer identification | Custom time comparison loop | `PrayerLogic.getNextPrayerResult()` | Already handles all 4 states (no_data, now, normal, overnight) with edge cases [VERIFIED: codebase] |
| Countdown formatting | String formatting in Widget | `PrayerLogic.formatCountdown()` | Handles hours/minutes/seconds thresholds per D-04/D-05/D-06 [VERIFIED: codebase] |
| Prayer time parsing | Manual string splitting | `PrayerLogic.parseTimeToSeconds()` | Null-safe with validation [VERIFIED: codebase] |
| Today/tomorrow data access | Direct Storage.getValue calls | `PrayerDataStore.getTodayPrayerTimes()`, `getTodayIqama()` | Handles calendar-first fallback, month boundaries [VERIFIED: codebase] |
| Timer management pattern | Custom timer logic | Follow MawaqitGlanceView pattern | onShow/onHide start/stop proven working [VERIFIED: codebase] |

**Key insight:** Phase 1 and 2 built a robust data and logic layer. The Widget is primarily a drawing/layout task that reads from existing modules. The only net-new logic is the background ServiceDelegate.

## Common Pitfalls

### Pitfall 1: Background Timeout with Multi-Request Chains
**What goes wrong:** The 6-step MawaqitService fetch chain (6 sequential HTTP requests) runs in the background and hits the 30-second timeout before completing, silently failing with no data returned.
**Why it happens:** Each HTTP request requires phone BLE relay + server response. Six sequential requests can easily take 15-30+ seconds over Bluetooth.
**How to avoid:** Use a dedicated lightweight ServiceDelegate with a SINGLE HTTP request to `/prayer-times`. The full calendar refresh runs in the foreground only (via `getInitialView()` and `onSettingsChanged()`).
**Warning signs:** Background data never updates; `onBackgroundData()` never called or always receives null.
[VERIFIED: Garmin forums - 30-second background timeout confirmed]

### Pitfall 2: Background and Foreground Don't Share Memory
**What goes wrong:** Developer tries to set a flag in the background service expecting the foreground to see it, or tries to use a foreground singleton instance from background.
**Why it happens:** Background and foreground are separate processes that share code but NOT memory. Global variables, singleton instances, and object state are independent.
**How to avoid:** All data transfer between background and foreground goes through `Background.exit()` -> `onBackgroundData()`. The ServiceDelegate must be completely self-contained.
**Warning signs:** Data appears to update in background but Widget shows stale data.
[VERIFIED: Garmin forums]

### Pitfall 3: Background.exit() ~8KB Data Limit
**What goes wrong:** Trying to pass the full 12-month calendar through `Background.exit()` throws `ExitDataSizeLimitException`.
**Why it happens:** The data limit is approximately 8KB. A full calendar month can be large.
**How to avoid:** Pass only the `/prayer-times` response (today's 6 prayer times -- well under 1KB). The full calendar is fetched in the foreground only.
**Warning signs:** `ExitDataSizeLimitException` thrown; background process doesn't exit.
[VERIFIED: Garmin API docs]

### Pitfall 4: Missing (:background) Annotation on App Class
**What goes wrong:** `getServiceDelegate()` is added to the App class but the App class isn't annotated `(:background)`, causing the background service to fail silently.
**Why it happens:** The App class needs `(:background)` annotation for the system to find `getServiceDelegate()` in the background context. The existing `(:glance)` annotation is not sufficient.
**How to avoid:** The App class must have BOTH `(:glance)` AND `(:background)` annotations (or more precisely, it must be annotated such that it's available in both contexts). Since the class is already `(:glance)`, adding `(:background)` means it loads in glance, background, AND foreground contexts.
**Warning signs:** Background events never fire; `onBackgroundData()` never called.
[VERIFIED: Garmin developer FAQ]

### Pitfall 5: Round Screen Edge Clipping
**What goes wrong:** Prayer rows near the top and bottom of the Widget are clipped by the round display boundary, making text unreadable.
**Why it happens:** Round AMOLED screens clip content outside the circular boundary. A vertical list of 5 rows + header needs careful vertical centering.
**How to avoid:** Keep all content within the inner ~80% of screen height. Use `dc.getWidth()` and `dc.getHeight()` for proportional layout. Test on round simulator targets (Fenix 8, Venu 2).
**Warning signs:** Text cut off at top/bottom edges in simulator.
[ASSUMED]

### Pitfall 6: Manifest Missing Background Permission
**What goes wrong:** Background service code compiles but never executes on device.
**Why it happens:** The `Background` permission must be declared in `manifest.xml` alongside `Communications`. The current manifest only has `Communications` and `PushNotification`.
**How to avoid:** Add `<iq:uses-permission id="Background"/>` to manifest.xml.
**Warning signs:** No errors, but background events never fire.
[VERIFIED: Garmin manifest docs]

### Pitfall 7: Duplicate Temporal Event Registration
**What goes wrong:** Every time the widget opens, `registerForTemporalEvent()` is called, potentially resetting the timer and delaying the next background run.
**Why it happens:** `getInitialView()` is called each time the user navigates to the widget.
**How to avoid:** Check `Background.getTemporalEventRegisteredTime()` first. Only register if no event is registered or if the current registration is stale.
**Warning signs:** Background runs less frequently than expected.
[VERIFIED: Garmin API docs - calling registerForTemporalEvent() overwrites previous registration]

## Code Examples

### Widget onUpdate Drawing Pattern (Verified from Codebase)
```monkeyc
// Source: MawaqitGlanceView.mc pattern + Graphics.Dc API docs
function onUpdate(dc as Graphics.Dc) as Void {
    var w = dc.getWidth();
    var h = dc.getHeight();

    dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
    dc.clear();

    // Check empty states first (same pattern as Glance)
    if (!PrayerDataStore.isMosqueConfigured()) {
        // D-07: No mosque configured
        dc.drawText(w / 2, h / 3, Graphics.FONT_MEDIUM,
            "Mawaqit", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(w / 2, 2 * h / 3, Graphics.FONT_SMALL,
            "Set mosque in\nGarmin Connect app",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        return;
    }

    // Get prayer state from existing logic
    var todayTimes = PrayerDataStore.getTodayPrayerTimes();
    var tomorrowTimes = PrayerDataStore.getTomorrowPrayerTimes();
    var result = PrayerLogic.getNextPrayerResult(todayTimes, tomorrowTimes);
    var iqama = PrayerDataStore.getTodayIqama();

    // Draw countdown header (D-02, D-04)
    // Draw separator line
    // Draw 5 prayer rows with highlight on next prayer (D-01, D-03)
    // Each row: prayer name (left), time (center), iqama offset (right)
}
```

### Temporal Event Registration Pattern
```monkeyc
// Source: Garmin API docs
// In getInitialView() or onStart():
function registerBackgroundEvents() as Void {
    var registeredTime = Background.getTemporalEventRegisteredTime();
    if (registeredTime == null) {
        // Register for once-daily refresh (24 hours = 86400 seconds)
        var duration = new Time.Duration(86400);
        Background.registerForTemporalEvent(duration);
    }
}
```

### Highlight Row Drawing Pattern
```monkeyc
// Source: Graphics.Dc API docs
// Draw highlighted prayer row with accent background
function drawPrayerRow(dc, y, name, time, iqamaOffset, isHighlighted, w) {
    if (isHighlighted) {
        // Accent color background for highlighted row
        dc.setColor(0x00AA44, Graphics.COLOR_BLACK);  // Green accent
        dc.fillRoundedRectangle(leftMargin, y - rowHeight / 2, rowWidth, rowHeight, 4);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        // Use bold/larger font for highlighted row
    } else {
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        // Use normal font
    }

    // Draw prayer name, time, iqama offset
    dc.drawText(nameX, y, font, name, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    dc.drawText(timeX, y, font, time, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    if (iqamaOffset != null) {
        dc.drawText(iqamaX, y, font, iqamaOffset, Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `AppBase.getProperty()` | `Properties.getValue()` | CIQ 4.x | Must use new API -- old is deprecated [VERIFIED: CLAUDE.md] |
| Background can't use Storage | `Storage.setValue()` available in background since CIQ 3.2.0 | CIQ 3.2.0 | Could use direct Storage in background, but D-10 specifies Background.exit() pattern [VERIFIED: Garmin API docs] |
| XML Layouts for views | Direct Dc drawing | CIQ 4.x | Layouts work but direct Dc drawing gives more control on round screens [VERIFIED: codebase pattern] |

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | WatchUi.requestUpdate() cannot be called from background context | Anti-Patterns | LOW -- onBackgroundData() runs in foreground where requestUpdate() works. If callable from background, no harm. |
| A2 | Round screen clips content outside circular boundary at edges | Pitfall 5 | LOW -- standard behavior for round displays. Layout should account for it regardless. |
| A3 | The App class can carry both (:glance) and (:background) annotations simultaneously | Pitfall 4 | MEDIUM -- if annotations conflict, would need separate annotation strategy. CIQ docs suggest multiple annotations are supported. |
| A4 | Green (0x00AA44) accent color is visible on both AMOLED and MIP displays | Code Examples | LOW -- can be adjusted during implementation. Claude has discretion on exact color. |

## Open Questions

1. **App Class Dual Annotation**
   - What we know: App class is currently `(:glance)`. Background service needs `(:background)` on `getServiceDelegate()`.
   - What's unclear: Whether the class-level annotation needs to be `(:glance, :background)` or if method-level annotations suffice.
   - Recommendation: Apply both annotations at class level. The App class is minimal and loads in all contexts anyway. Test in simulator to verify.

2. **Background Service Frequency**
   - What we know: D-08 says "once daily". Minimum interval is 5 minutes.
   - What's unclear: Whether the system guarantees exactly 24-hour intervals or if there's drift. What happens when the watch is in low-power mode.
   - Recommendation: Register with `Duration(86400)` (24 hours). Accept that timing may not be exact. With 12-month calendar cached, daily refresh is a best-effort catch for schedule changes.

3. **MawaqitService Reuse Decision (D-10 Conflict)**
   - What we know: D-10 states "Calls MawaqitService.fetchPrayerData() from onTemporalEvent()". But MawaqitService is NOT annotated `(:background)`, uses a singleton pattern that doesn't work across process boundaries, and its 6-step chain risks the 30-second timeout.
   - What's unclear: Whether D-10 was intended literally or as conceptual guidance.
   - Recommendation: **Do NOT use MawaqitService directly.** Build a dedicated lightweight `MawaqitServiceDelegate` that makes a single `/prayer-times` request. This satisfies D-10's intent (fetch prayer data in background) without the architectural problems. Flag this deviation from D-10's literal wording.

## Environment Availability

Step 2.6: SKIPPED (no external dependencies identified). This phase is purely Monkey C code using built-in Toybox SDK APIs. No new tools, CLIs, or external services needed beyond what Phase 1/2 already established.

## Security Domain

> Security enforcement: not applicable. This phase makes unauthenticated GET requests to a known API endpoint over HTTPS. No user credentials, no authentication tokens, no sensitive data handling beyond what Phase 1 already established. The background service reads a mosque slug from Properties (set by user via phone app) -- same security posture as the foreground fetch.

## Sources

### Primary (HIGH confidence)
- [Toybox.Background API docs](https://developer.garmin.com/connect-iq/api-docs/Toybox/Background.html) - Background.exit() 8KB limit, registerForTemporalEvent(), exceptions, data types
- [Toybox.Graphics.Dc API docs](https://developer.garmin.com/connect-iq/api-docs/Toybox/Graphics/Dc.html) - Drawing methods: drawText, fillRectangle, fillRoundedRectangle, getFontHeight, getTextDimensions, setColor
- [Garmin Connect IQ Background Service FAQ](https://developer.garmin.com/connect-iq/connect-iq-faq/how-do-i-create-a-connect-iq-background-service/) - ServiceDelegate pattern, annotations
- [Garmin Backgrounding Core Topic](https://developer.garmin.com/connect-iq/core-topics/backgrounding/) - Background service architecture
- CLAUDE.md project instructions - Widget/Glance lifecycle, memory budgets, API tables
- Existing codebase (PrayerLogic.mc, PrayerDataStore.mc, MawaqitService.mc, MawaqitGlanceView.mc) - Established patterns

### Secondary (MEDIUM confidence)
- [Garmin Forums - Background + Glance Memory](https://forums.garmin.com/developer/connect-iq/f/discussion/212286/glance-view-active-background-job) - Memory sharing between glance and background
- [Garmin Forums - Background process timeout](https://forums.garmin.com/developer/connect-iq/i/bug-reports/background-process-exits-before-makewebrequest-times-out) - 30-second timeout confirmation
- [Garmin Forums - Memory usage in Glance](https://forums.garmin.com/developer/connect-iq/f/discussion/195448/memory-usage-by-code-in-glance-view) - Annotation code size impact
- [Toybox.Application.Storage API docs](https://developer.garmin.com/connect-iq/api-docs/Toybox/Application/Storage.html) - Storage.setValue() available in background since CIQ 3.2.0
- [Garmin Forums - Global variables with background](https://forums.garmin.com/developer/connect-iq/f/discussion/196315/global-variable-with-background-process) - Background/foreground process memory isolation

### Tertiary (LOW confidence)
- WebSearch results on round screen clipping behavior - general guidance, not device-specific verified

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All Toybox SDK APIs verified via official docs and CLAUDE.md
- Architecture: HIGH - Patterns established in Phase 1/2 codebase, background service pattern verified via Garmin docs
- Pitfalls: HIGH - 30-second timeout, 8KB exit limit, memory budgets all confirmed via official sources
- Widget layout: MEDIUM - Drawing patterns verified, but exact positioning/spacing needs simulator testing

**Research date:** 2026-04-12
**Valid until:** 2026-05-12 (stable SDK APIs, no fast-moving dependencies)
