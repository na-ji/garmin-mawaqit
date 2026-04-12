# Phase 2: Prayer Logic & Glance - Research

**Researched:** 2026-04-11
**Domain:** Prayer time calculation, countdown logic, Garmin Connect IQ GlanceView rendering
**Confidence:** HIGH

## Summary

This phase implements two tightly coupled concerns: (1) prayer time logic that identifies the next prayer, handles Isha-to-Fajr overnight rollover, and calculates countdowns, and (2) a GlanceView that renders a Sunrise-inspired 3-row layout with progress bar within a 28KB memory budget. The codebase already has a working data layer (`PrayerDataStore`) that provides `getTodayPrayerTimes()` and `getTomorrowPrayerTimes()` returning dictionaries with "HH:MM" time strings keyed as `fajr`, `sunrise`, `dohr`, `asr`, `maghreb`, `icha`.

The critical technical challenge is **timezone handling**: `Gregorian.moment()` interprets input as UTC, but prayer times from the API are local time. The correct approach is to use `System.getClockTime().timeZoneOffset` to adjust, or to sidestep Moment-based comparison entirely by working in "seconds since local midnight" for all time comparisons. The Glance has a strict 28-32KB memory budget shared with background service code, requiring careful use of `(:glance)` annotations and minimal object allocation.

**Primary recommendation:** Build a `PrayerLogic` module (annotated `(:glance)`) that converts "HH:MM" strings to seconds-since-midnight integers, finds the next prayer by comparing against current local time in the same units, and returns a simple result dictionary. The GlanceView draws directly with `Dc` primitives -- no layouts, no drawables, no buffered bitmaps needed for this simple 3-row design.

<user_constraints>

## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Glance follows the Sunrise glance design pattern from Garmin's built-in apps. Three-row layout:
  - **Top line:** Next prayer name + countdown (e.g., "Asr in 2h 15m")
  - **Middle:** Day progress bar with 5 colored prayer-period segments and a current-time marker
  - **Bottom line:** Previous prayer time (left) and next prayer time (right), flanking the bar
- **D-02:** Progress bar has 5 segments representing prayer periods (Fajr-to-Dhuhr, Dhuhr-to-Asr, Asr-to-Maghrib, Maghrib-to-Isha, Isha-to-Fajr). Each segment gets a distinct color. The active segment is highlighted. A white marker shows current position in the day.
- **D-03:** Bottom times show the "window" the user is in: left = time of prayer that just passed (current period start), right = time of next prayer (current period end).
- **D-04:** Countdown format follows the Sunrise glance convention: "Xh Ym" (e.g., "Asr in 2h 15m").
- **D-05:** Threshold behavior:
  - More than 1 hour: "Asr in 2h 15m"
  - Under 1 hour: minutes only -- "Asr in 45m"
  - Under 1 minute: seconds -- "Asr in 45s"
- **D-06:** No seconds display above 1 minute. Hours and minutes only for normal countdown.
- **D-07:** When a prayer time arrives (countdown hits 0), show "now" indicator for 5 minutes (e.g., "Asr now"), then flip to the next prayer.
- **D-08:** After Isha, the display rolls to next day's Fajr with identical format -- no visual distinction for overnight countdown.
- **D-09:** No mosque configured: show "Mawaqit" on top line and "Set mosque in Connect app" on second line. No progress bar or times.
- **D-10:** Mosque configured but data expired/unavailable: show dashes as placeholders -- "-- in --" top line, empty progress bar, "--:--" for both bottom times.

### Claude's Discretion
- During the 5-min "now" window, Claude decides how the bottom times and progress bar behave (e.g., marker position, which times to show).
- Color palette for the 5 prayer segments -- Claude picks colors that are visually distinct on AMOLED and readable at glance size.
- Font choices within Garmin's available `Graphics.FONT_*` options for the glance.
- Timer/redraw strategy for countdown updates on the glance (noting that `WatchUi.requestUpdate()` may be ignored on some devices for GlanceView).

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope

</user_constraints>

<phase_requirements>

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| PRAY-01 | App calculates the next prayer from current time | PrayerLogic module using seconds-since-midnight comparison against 5 prayer times + sunrise from PrayerDataStore |
| PRAY-02 | After Isha, app rolls over to show next day's Fajr with countdown | PrayerDataStore.getTomorrowPrayerTimes() provides next-day Fajr; overnight countdown calculated by adding seconds remaining today + Fajr seconds tomorrow |
| PRAY-03 | Countdown updates in real-time (minutes/hours remaining) | Timer.Timer in GlanceView.onShow() calling WatchUi.requestUpdate(); graceful degradation on devices without live_update support |
| GLNC-01 | Glance displays next prayer name, scheduled time, and countdown | Three-row GlanceView layout: top line with name+countdown, middle progress bar, bottom times |
| GLNC-02 | Glance fits within 28KB memory budget using annotations | All glance code annotated (:glance); PrayerLogic module annotated (:glance); no layouts/drawables, direct Dc drawing only |

</phase_requirements>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Connect IQ SDK | 8.4.0 | Build toolchain | Already installed per Phase 1 [VERIFIED: project manifest.xml] |
| Monkey C | (bundled) | Language | Only option for CIQ development [VERIFIED: CLAUDE.md] |
| Toybox.WatchUi.GlanceView | API 3.1.0+ | Glance base class | Required base class for widget glance views [VERIFIED: Garmin API docs] |
| Toybox.Time / Toybox.Time.Gregorian | CIQ 4.x+ | Time calculation | Prayer time parsing, countdown computation [VERIFIED: CLAUDE.md] |
| Toybox.Graphics.Dc | CIQ 4.x+ | Drawing context | Direct rendering of text, rectangles, lines [VERIFIED: Garmin API docs] |
| Toybox.Timer.Timer | CIQ 4.x+ | Periodic callback | Countdown refresh trigger [VERIFIED: CLAUDE.md] |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Toybox.System.ClockTime | CIQ 4.x+ | UTC offset access | Getting `timeZoneOffset` for local-to-UTC conversion [VERIFIED: Garmin API docs] |
| Toybox.Application.Storage | CIQ 4.x+ | Read cached data | PrayerDataStore reads from Storage [VERIFIED: existing code] |
| Toybox.Application.Properties | CIQ 4.x+ | Read settings | Check mosque configuration state [VERIFIED: existing code] |

**No external packages.** Monkey C has no package manager. All APIs are built into the Toybox SDK. [VERIFIED: CLAUDE.md]

## Architecture Patterns

### Recommended Project Structure
```
source/
  GarminMawaqitApp.mc     # App class (existing) -- update MawaqitGlanceView stub
  MawaqitService.mc       # HTTP service (existing, untouched this phase)
  PrayerDataStore.mc      # Data access (existing, untouched this phase)
  PrayerLogic.mc          # NEW: Prayer calculation module (:glance)
  MawaqitGlanceView.mc    # NEW: Full glance view implementation (:glance)
```

### Pattern 1: Seconds-Since-Midnight for Time Comparison
**What:** Convert all prayer time strings ("HH:MM") and current time to integer seconds since midnight for comparison. Avoid `Gregorian.moment()` timezone pitfalls entirely.
**When to use:** All prayer-to-current-time comparisons and countdown calculations.
**Why:** `Gregorian.moment()` interprets input as UTC [VERIFIED: Garmin bug report forum], but prayer times are local. Using seconds-since-midnight avoids the UTC/local trap completely, uses less memory (integers vs. Moment objects), and is simpler to reason about.

**Example:**
```monkeyc
// Source: Derived from Garmin API docs + forum workarounds
(:glance)
module PrayerLogic {
    // Parse "HH:MM" to seconds since midnight
    function parseTimeToSeconds(timeStr as String) as Number {
        // "13:30" -> 48600
        var parts = splitTime(timeStr);  // returns [hour, minute]
        return parts[0] * 3600 + parts[1] * 60;
    }

    // Get current local time as seconds since midnight
    function getCurrentSeconds() as Number {
        var clock = System.getClockTime();
        return clock.hour * 3600 + clock.min * 60 + clock.sec;
    }
}
```

### Pattern 2: Module Pattern for Glance-Safe Logic
**What:** Use a `module` (not a `class`) for PrayerLogic, matching the established PrayerDataStore pattern.
**When to use:** Stateless computation that needs `(:glance)` annotation.
**Why:** Modules avoid object allocation overhead. Every byte matters in the 28KB glance budget. The project already uses this pattern (PrayerDataStore is a module). [VERIFIED: existing codebase]

### Pattern 3: Direct Dc Drawing (No Layouts)
**What:** Draw all glance UI directly in `onUpdate(dc)` using `dc.drawText()`, `dc.fillRectangle()`, `dc.drawLine()`, etc. No XML layouts, no Drawable objects.
**When to use:** All glance rendering.
**Why:** Layouts and Drawables consume memory for object allocation. Direct Dc drawing is the most memory-efficient approach for a simple 3-row layout. [CITED: forums.garmin.com - Widget Glances best practices]

### Pattern 4: Extract GlanceView to Separate File
**What:** Move the `MawaqitGlanceView` class from `GarminMawaqitApp.mc` into its own `MawaqitGlanceView.mc` file.
**When to use:** This phase -- replaces the stub.
**Why:** Separation of concerns. The glance view will have significant drawing logic. Keeping it in the app file makes the app file unwieldy. The build system loads all `.mc` files from the source directory automatically via `monkey.jungle`. [VERIFIED: monkey.jungle config]

### Anti-Patterns to Avoid
- **Using Gregorian.moment() with local prayer times directly:** It interprets input as UTC. A prayer time of "13:30" local would be treated as 13:30 UTC, giving wrong countdown values. [VERIFIED: Garmin forum bug report]
- **Allocating Moment objects in the glance:** Each Moment allocation consumes heap memory. Use integer arithmetic (seconds-since-midnight) instead.
- **Using XML layouts in glance:** Layouts add memory overhead from Drawable object trees. Direct Dc drawing is cheaper.
- **Forgetting (:glance) annotation:** Any code called from the glance MUST have the `(:glance)` annotation. Unannotated code is not loaded in glance context, causing runtime crashes. [VERIFIED: CLAUDE.md Code Annotations section]
- **Using System.println() in glance code:** Causes memory spikes that can push past the 28KB limit. [CITED: forums.garmin.com - memory optimization best practices]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Time string parsing | Regex or complex parser | Simple `substring()` + `toNumber()` | Monkey C has no regex. "HH:MM" is fixed 5-char format, trivially parseable. |
| Current local time | `Gregorian.info(Time.now())` chain | `System.getClockTime()` | Direct access to local `.hour`, `.min`, `.sec` with no timezone confusion. Cheaper than Gregorian conversion. |
| Countdown formatting | Complex duration formatter | Simple integer division | `totalSeconds / 3600` for hours, `(totalSeconds % 3600) / 60` for minutes. Three lines of code. |
| Progress bar rendering | BufferedBitmap approach | Direct `fillRectangle()` calls | For 5 colored rectangles, direct drawing is simpler and uses less memory than allocating a bitmap buffer. |

**Key insight:** In the 28KB glance budget, every object allocation costs. Prefer integer arithmetic and direct drawing over object-oriented abstractions.

## Common Pitfalls

### Pitfall 1: UTC vs Local Time Confusion
**What goes wrong:** Prayer countdown shows wrong time (off by timezone offset hours).
**Why it happens:** `Gregorian.moment()` interprets hour/minute values as UTC, but prayer times from the API are local. Developers assume the input is local time because the documentation is misleading.
**How to avoid:** Use seconds-since-midnight integer comparison exclusively. Get current time via `System.getClockTime()` (returns local), parse prayer times to seconds. Never create Moment objects from prayer time strings.
**Warning signs:** Countdown jumps by several hours when tested in a non-UTC timezone. Works perfectly in UTC+0 simulator but breaks in UTC+3.
[VERIFIED: Garmin forum bug report - "Docs for Gregorian.moment() imply input is interpreted as local time... but... suggest otherwise"]

### Pitfall 2: Glance Memory Budget Exceeded
**What goes wrong:** App crashes with `OutOfMemoryError` when the glance loads.
**Why it happens:** Glance + background code share a 28-32KB budget. Object allocations (Strings, Arrays, Dictionaries) eat into this fast. `System.println()` calls cause memory spikes.
**How to avoid:** (1) Annotate everything with `(:glance)` so only needed code loads. (2) Minimize object allocation in `onUpdate()`. (3) Avoid `System.println()`. (4) Pre-compute values rather than creating intermediate objects. (5) Test in simulator's memory profiler.
**Warning signs:** Memory usage approaching 24KB in simulator's memory view.
[CITED: forums.garmin.com - Glance memory discussions]

### Pitfall 3: requestUpdate() Ignored on Some Devices
**What goes wrong:** Countdown display shows stale values -- never refreshes while the glance is visible.
**Why it happens:** Not all devices support `live_update` for glance views. On those devices, `WatchUi.requestUpdate()` from a Timer callback is silently ignored.
**How to avoid:** Still set up the Timer (it works on Pro/AMOLED devices which are this app's targets). Accept that on unsupported devices the glance shows the time as of when it was first drawn. The target devices (Fenix 8, Venu 2, FR265) are all AMOLED/Pro models that support live glance updates.
**Warning signs:** Timer fires (callback runs) but `onUpdate()` is never called. Test on actual target device simulators, not generic ones.
[CITED: forums.garmin.com/developer/connect-iq/f/discussion/289191]

### Pitfall 4: Isha-to-Fajr Rollover Edge Case
**What goes wrong:** After Isha, countdown shows negative or wraps around incorrectly.
**Why it happens:** Fajr of tomorrow has a "smaller" time value than current time (e.g., Fajr at 05:00 vs. current 23:00). Simple subtraction gives a negative number.
**How to avoid:** When current time is past Isha: countdown = (86400 - currentSeconds) + tomorrowFajrSeconds. This is "seconds remaining in today" plus "seconds into tomorrow until Fajr".
**Warning signs:** Negative countdown values, or impossibly large countdown (>24 hours).

### Pitfall 5: Missing Tomorrow's Data
**What goes wrong:** After Isha, no Fajr time is available for the countdown.
**Why it happens:** `PrayerDataStore.getTomorrowPrayerTimes()` returns null if the calendar data for tomorrow's month isn't cached (e.g., at month boundary when next month wasn't fetched, or data simply expired).
**How to avoid:** Fall back gracefully: if tomorrow's data is unavailable, estimate next Fajr using today's Fajr time (same value as a reasonable approximation). Show the estimate rather than crashing or showing dashes. Document this as a known limitation.
**Warning signs:** Null return from `getTomorrowPrayerTimes()` on the last day of the month.

### Pitfall 6: String Parsing on Short/Malformed Time Strings
**What goes wrong:** `substring().toNumber()` crashes or returns null on unexpected input.
**Why it happens:** API data could have unexpected format. Storage corruption. Missing keys in dictionary.
**How to avoid:** Validate string length before parsing. Handle null returns from `toNumber()`. Default to 0 or skip the prayer if data is bad.
**Warning signs:** Unexpected null values, app crash in `onUpdate()`.

## Code Examples

### Example 1: Parse Prayer Time String to Seconds
```monkeyc
// Source: Derived from Garmin API patterns + existing PrayerDataStore key format
(:glance)
function parseTimeToSeconds(timeStr as String) as Number or Null {
    if (timeStr == null || timeStr.length() < 5) {
        return null;
    }
    var colonPos = timeStr.find(":");
    if (colonPos == null) {
        return null;
    }
    var hour = timeStr.substring(0, colonPos).toNumber();
    var min = timeStr.substring(colonPos + 1, timeStr.length()).toNumber();
    if (hour == null || min == null) {
        return null;
    }
    return hour * 3600 + min * 60;
}
```

### Example 2: Find Next Prayer
```monkeyc
// Source: Derived from CONTEXT.md decisions D-07, D-08, prayer key naming from PrayerDataStore
(:glance)
function findNextPrayer(times as Dictionary, currentSec as Number) as Dictionary {
    // Prayer order (excluding sunrise -- not a prayer)
    var names = ["fajr", "dohr", "asr", "maghreb", "icha"];
    var labels = ["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"];

    for (var i = 0; i < names.size(); i++) {
        var prayerSec = parseTimeToSeconds(times[names[i]] as String);
        if (prayerSec != null && prayerSec > currentSec) {
            return {
                "name" => labels[i],
                "time" => times[names[i]],
                "seconds" => prayerSec,
                "index" => i
            };
        }
    }
    // Past all prayers today -- return null to trigger tomorrow rollover
    return null;
}
```

### Example 3: Format Countdown String
```monkeyc
// Source: CONTEXT.md decisions D-04, D-05, D-06, D-07
(:glance)
function formatCountdown(remainingSec as Number, prayerName as String) as String {
    if (remainingSec <= 0) {
        // D-07: "now" indicator
        return prayerName + " now";
    }
    var hours = remainingSec / 3600;
    var mins = (remainingSec % 3600) / 60;
    var secs = remainingSec % 60;

    if (hours > 0) {
        // D-05: "Asr in 2h 15m"
        return prayerName + " in " + hours + "h " + mins + "m";
    } else if (mins > 0) {
        // D-05: "Asr in 45m"
        return prayerName + " in " + mins + "m";
    } else {
        // D-05: "Asr in 45s"
        return prayerName + " in " + secs + "s";
    }
}
```

### Example 4: GlanceView Timer Pattern
```monkeyc
// Source: Garmin forum pattern + CLAUDE.md lifecycle docs
(:glance)
class MawaqitGlanceView extends WatchUi.GlanceView {
    var _timer as Timer.Timer or Null = null;

    function initialize() {
        GlanceView.initialize();
    }

    function onShow() as Void {
        _timer = new Timer.Timer();
        // Update every 30 seconds (good balance of accuracy vs battery)
        _timer.start(method(:onTimer), 30000, true);
    }

    function onHide() as Void {
        if (_timer != null) {
            _timer.stop();
            _timer = null;
        }
    }

    (:glance)
    function onTimer() as Void {
        WatchUi.requestUpdate();
    }

    (:glance)
    function onUpdate(dc as Graphics.Dc) as Void {
        // All drawing happens here
        var w = dc.getWidth();
        var h = dc.getHeight();
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();
        // ... draw 3-row layout
    }
}
```

### Example 5: Progress Bar Drawing
```monkeyc
// Source: Derived from Garmin Dc.fillRectangle API docs + CONTEXT.md D-02
(:glance)
function drawProgressBar(dc as Graphics.Dc, x as Number, y as Number,
                         barWidth as Number, barHeight as Number,
                         segments as Array, currentSec as Number) as Void {
    // segments: array of { "start" => seconds, "end" => seconds, "color" => colorInt }
    var totalDaySec = 86400;
    for (var i = 0; i < segments.size(); i++) {
        var seg = segments[i] as Dictionary;
        var startFrac = (seg["start"] as Number).toFloat() / totalDaySec;
        var endFrac = (seg["end"] as Number).toFloat() / totalDaySec;
        var segX = x + (startFrac * barWidth).toNumber();
        var segW = ((endFrac - startFrac) * barWidth).toNumber();

        dc.setColor(seg["color"] as Number, Graphics.COLOR_BLACK);
        dc.fillRectangle(segX, y, segW, barHeight);
    }

    // White marker for current time
    var markerX = x + ((currentSec.toFloat() / totalDaySec) * barWidth).toNumber();
    dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
    dc.fillRectangle(markerX - 1, y - 2, 3, barHeight + 4);
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `AppBase.getProperty()` | `Properties.getValue()` | CIQ 4.x | Must use new API; old is deprecated [VERIFIED: CLAUDE.md] |
| XML layouts for all views | Direct Dc drawing for glances | CIQ 3.1+ (glances introduced) | Layouts waste memory in tight glance budget |
| `Gregorian.moment()` for local time | Seconds-since-midnight integer math | Ongoing (docs still misleading) | Avoids UTC/local trap that has bitten many devs |
| BufferedBitmap for glance graphics | Direct drawing for simple layouts | Community consensus | BufferedBitmap only needed for complex/animated graphics |

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Prayer time strings from the API are in "HH:MM" 24-hour local time format | Architecture Patterns | Time parsing logic would break. Mitigation: validated against Mawaqit API documentation and similar implementations. |
| A2 | Target devices (Fenix 8, Venu 2, FR265) all support live glance updates via Timer + requestUpdate() | Common Pitfalls | Countdown would not refresh live. Low risk -- these are all AMOLED/Pro devices. |
| A3 | Glance drawing area is approximately 200+ pixels wide on Fenix 8 (454x454 screen) | Architecture Patterns | Progress bar may be too narrow or too wide. Mitigation: use `dc.getWidth()` and `dc.getHeight()` for responsive layout. |
| A4 | 30-second timer interval is sufficient for countdown accuracy | Code Examples | Under-1-minute countdown shows seconds (D-05), so 30s interval may miss some second transitions. Could increase to 1s when under 1 minute. |

## Open Questions

1. **Exact glance dimensions on target devices**
   - What we know: Dimensions vary by device. Fenix 6 series had ~150-190 x 63px. Fenix 8 with 454x454 screen likely has proportionally larger glance area.
   - What's unclear: Exact pixel dimensions for Fenix 8 43mm, 47mm, and Fenix 8 Pro 47mm glance views.
   - Recommendation: Use `dc.getWidth()` and `dc.getHeight()` for fully responsive layout. Test in simulator to see actual dimensions. Do NOT hardcode pixel values.

2. **FONT_GLANCE vs FONT_GLANCE_NUMBER sizing**
   - What we know: Both fonts exist. FONT_GLANCE is for text, FONT_GLANCE_NUMBER is for numbers. Size is between FONT_XTINY and FONT_TINY.
   - What's unclear: Whether 3 rows of text fit in the glance area using these fonts on all target devices.
   - Recommendation: Use `dc.getFontHeight(Graphics.FONT_GLANCE)` to compute row positioning dynamically. If 3 rows don't fit, collapse bottom row.

3. **Timer interval for sub-minute countdown**
   - What we know: D-05 specifies seconds display under 1 minute. A 30-second timer would skip beats.
   - What's unclear: Battery impact of 1-second vs 30-second timer in glance context.
   - Recommendation: Use 30-second timer normally, switch to 1-second timer when countdown < 60 seconds. This minimizes battery use while maintaining accuracy for the seconds display.

## Environment Availability

Step 2.6: SKIPPED (no external dependencies identified). This phase is purely Monkey C code within the existing Connect IQ SDK project. No new tools, services, or dependencies required beyond what Phase 1 already established.

## Security Domain

Not applicable. This phase involves only local time computation and UI rendering. No network requests, no user input processing, no data persistence changes. Security is not a concern for this phase.

## Discretion Recommendations

Per CONTEXT.md, Claude has discretion over these areas. Research-backed recommendations:

### Color Palette for 5 Prayer Segments
Recommended colors optimized for AMOLED visibility and distinctiveness at glance size:

| Segment | Period | Color | Hex Value | Rationale |
|---------|--------|-------|-----------|-----------|
| 1 | Fajr-to-Dhuhr | Deep Blue | 0x3366CC | Dawn/morning feel, high contrast on black |
| 2 | Dhuhr-to-Asr | Amber/Gold | 0xFFAA00 | Midday warmth, distinct from blue |
| 3 | Asr-to-Maghrib | Orange | 0xFF6633 | Afternoon warmth, bridges gold and red |
| 4 | Maghrib-to-Isha | Deep Red/Crimson | 0xCC3333 | Sunset association, strong contrast |
| 5 | Isha-to-Fajr | Dark Purple | 0x6633CC | Night/darkness, distinct from blue |

Inactive segments: dimmed version at ~40% brightness (e.g., 0x1A2952 for inactive blue). Active segment: full brightness. [ASSUMED -- color palette choice; verify against AMOLED rendering in simulator]

### Font Choices
- **Top line (name + countdown):** `Graphics.FONT_GLANCE` -- purpose-built for glance text [VERIFIED: Garmin API docs]
- **Bottom line (times):** `Graphics.FONT_GLANCE` -- same font for visual consistency [VERIFIED: Garmin API docs]
- **Alternative if FONT_GLANCE is too large for 3 rows:** `Graphics.FONT_SYSTEM_XTINY` as fallback [ASSUMED]

### Timer/Redraw Strategy
- **Normal mode (>60s to next prayer):** Timer every 30 seconds. Sufficient for "Xh Ym" display where minutes change slowly. [ASSUMED -- 30s is balanced for battery]
- **Imminent mode (<60s to next prayer):** Timer every 1 second. Required for accurate seconds display per D-05.
- **"Now" window (D-07, 5 minutes after prayer):** Timer every 30 seconds. Display is static "Asr now" text, no countdown to update.
- **Fallback for non-live-update devices:** Glance shows data as computed at render time. Stale but functional.

### "Now" Window Behavior (D-07)
- **Progress bar:** Marker stays at the prayer time position (does not advance during the 5-min window).
- **Bottom times:** Show the prayer that just arrived on the left, next prayer on the right. E.g., during "Asr now", left shows Asr time, right shows Maghrib time.
- **After 5 minutes:** Transition to showing Maghrib countdown with bar advancing normally.

## Sources

### Primary (HIGH confidence)
- [Garmin GlanceView API docs](https://developer.garmin.com/connect-iq/api-docs/Toybox/WatchUi/GlanceView.html) - GlanceView class, methods, drawing context
- [Garmin Graphics.Dc API docs](https://developer.garmin.com/connect-iq/api-docs/Toybox/Graphics/Dc.html) - All drawing methods for Dc
- [Garmin Graphics module](https://developer.garmin.com/connect-iq/api-docs/Toybox/Graphics.html) - FONT_GLANCE (18), FONT_GLANCE_NUMBER (19), color constants
- [Garmin Time.Gregorian API](https://developer.garmin.com/connect-iq/api-docs/Toybox/Time/Gregorian.html) - moment() takes UTC input
- [CLAUDE.md](./CLAUDE.md) - Full Monkey C API reference, lifecycle docs, memory budgets, code annotations
- Existing codebase: PrayerDataStore.mc, GarminMawaqitApp.mc, MawaqitService.mc

### Secondary (MEDIUM confidence)
- [Garmin Forums - Widget Glances announcement](https://forums.garmin.com/developer/connect-iq/b/news-announcements/posts/widget-glances---a-new-way-to-present-your-data) - Glance memory limit 32KB, canvas dimensions for Fenix 6 series, BufferedBitmap optimization
- [Garmin Forums - Glance live update discussion](https://forums.garmin.com/developer/connect-iq/f/discussion/289191/is-it-possible-to-update-every-second-in-glance-view-fenix-6x) - Timer + requestUpdate() pattern, device compatibility
- [Garmin Forums - Gregorian.moment() UTC bug](https://forums.garmin.com/developer/connect-iq/i/bug-reports/docs-for-gregorian-moment-imply-that-the-input-is-in-local-time-gregorian-info-and-utcinfo-suggest-otherwise) - Critical timezone behavior documentation
- [Garmin Forums - today() UTC timezone](https://forums.garmin.com/developer/connect-iq/f/discussion/1093/ciqbug-gregorian-today-returns-a-moment-specified-in-the-utc-timezone) - LocalTime workaround code
- [Garmin Forums - Memory optimization](https://forums.garmin.com/developer/connect-iq/f/discussion/252057/best-practices-for-reducing-memory-usage) - Glance memory strategies
- [Garmin Forums - Glance + background memory](https://forums.garmin.com/developer/connect-iq/f/discussion/212286/glance-view-active-background-job) - Shared memory architecture

### Tertiary (LOW confidence)
- [Mawaqit API repos](https://github.com/mrsofiane/mawaqit-api) - Time string format assumption ("HH:MM")

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- using only built-in Toybox APIs, all verified in Garmin docs
- Architecture: HIGH -- seconds-since-midnight pattern is well-established in CIQ community, module pattern matches existing codebase
- Pitfalls: HIGH -- UTC/local timezone trap and memory constraints verified through multiple forum sources and bug reports
- Glance dimensions: MEDIUM -- exact pixel sizes unknown but responsive layout with dc.getWidth()/getHeight() handles this
- Color palette: LOW -- aesthetic choice, needs simulator testing

**Research date:** 2026-04-11
**Valid until:** 2026-05-11 (Garmin SDK stable, glance APIs unchanged since CIQ 3.1)
