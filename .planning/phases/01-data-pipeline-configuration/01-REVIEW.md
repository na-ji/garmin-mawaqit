---
phase: 01-data-pipeline-configuration
reviewed: 2026-04-10T12:00:00Z
depth: standard
files_reviewed: 9
files_reviewed_list:
  - manifest.xml
  - monkey.jungle
  - resources/drawables/drawables.xml
  - resources/properties.xml
  - resources/settings/settings.xml
  - resources/strings/strings.xml
  - source/GarminMawaqitApp.mc
  - source/MawaqitService.mc
  - source/PrayerDataStore.mc
findings:
  critical: 0
  warning: 3
  info: 3
  total: 6
status: issues_found
---

# Phase 01: Code Review Report

**Reviewed:** 2026-04-10T12:00:00Z
**Depth:** standard
**Files Reviewed:** 9
**Status:** issues_found

## Summary

Reviewed the full Phase 01 data pipeline: the main app class (GarminMawaqitApp), the HTTP fetch service (MawaqitService), the read-side storage accessor (PrayerDataStore), plus all resource/config files (manifest, properties, settings, strings, drawables, monkey.jungle).

The code is well-structured with clean separation between write-side (MawaqitService) and read-side (PrayerDataStore). The sequential fetch chain pattern is a reasonable design for the constrained Garmin environment. Error handling follows a "fail silently, keep cache" strategy which is appropriate for a watch widget.

Three warnings were found: unsanitized user input in URL construction (the mosque slug), unconditional data fetching on every app start without staleness checks, and an inconsistent date format string. Three informational items were also noted.

No critical security or crash-inducing bugs were found.

## Warnings

### WR-01: Unsanitized user input in URL construction

**File:** `source/MawaqitService.mc:75`
**Issue:** The mosque slug from user settings is concatenated directly into API URLs without any validation or sanitization. This occurs in four places: `_fetchCalendar` (line 75), `_fetchIqama` (line 107), `_fetchMetadata` (line 139), and `_fetchPrayerTimes` (line 169). A slug containing characters like `../`, `?`, or `#` could alter the request path or inject query parameters. While the attack surface is limited (the user configures this on their own phone), malformed input could cause unexpected API behavior or errors.
**Fix:** Add a slug validation function that rejects or strips non-alphanumeric characters (allowing hyphens and underscores, which are valid in Mawaqit slugs):
```monkey-c
// Add to GarminMawaqitApp or MawaqitService
function isValidSlug(slug as String) as Boolean {
    // Only allow alphanumeric, hyphens, underscores
    var len = slug.length();
    for (var i = 0; i < len; i++) {
        var ch = slug.substring(i, i + 1);
        if (!ch.equals("-") && !ch.equals("_")) {
            var code = ch.toCharArray()[0];
            if (code < 48 || (code > 57 && code < 65) || (code > 90 && code < 97) || code > 122) {
                return false;
            }
        }
    }
    return len > 0;
}
```
Apply the validation in `getMosqueSlug()` before returning the slug.

### WR-02: Unconditional data fetch on every app start

**File:** `source/GarminMawaqitApp.mc:18-20`
**Issue:** `onStart` calls `MawaqitService.fetchPrayerData(_currentSlug)` every time the app starts, regardless of whether fresh data was already fetched today. This triggers 6 HTTP requests (calendar x2, iqama x2, metadata, prayer-times) even if identical data was fetched minutes ago. On Garmin watches, each HTTP request goes through the phone's Bluetooth connection, consuming battery on both devices. Frequent redundant network calls can also cause the system to throttle or reject requests.
**Fix:** Check `lastFetchDate` and `lastFetchSlug` before initiating the fetch chain:
```monkey-c
function onStart(state as Dictionary?) as Void {
    _currentSlug = getMosqueSlug();
    if (_currentSlug != null) {
        // Only fetch if data is stale or for a different mosque
        var lastDate = PrayerDataStore.getLastFetchDate();
        var lastSlug = PrayerDataStore.getLastFetchSlug();
        var info = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var todayString = info.year + "-" + info.month + "-" + info.day;
        if (lastDate == null || !lastDate.equals(todayString) ||
            lastSlug == null || !lastSlug.equals(_currentSlug)) {
            MawaqitService.fetchPrayerData(_currentSlug);
        }
    }
}
```

### WR-03: Date string format inconsistency

**File:** `source/MawaqitService.mc:191`
**Issue:** The date string is built as `info.year + "-" + info.month + "-" + info.day`, which produces non-zero-padded values like `"2026-4-10"` or `"2026-12-5"`. The `PrayerDataStore.getLastFetchDate()` docstring (line 48) claims the format is `"YYYY-MM-DD"`, but the actual output is `"YYYY-M-D"`. While this currently only matters for self-comparison (today vs. last fetch), the inconsistency could cause bugs if any future code parses or compares these strings with zero-padded values.
**Fix:** Use a consistent format by zero-padding month and day:
```monkey-c
var monthStr = (info.month < 10) ? "0" + info.month : "" + info.month;
var dayStr = (info.day < 10) ? "0" + info.day : "" + info.day;
var dateString = info.year + "-" + monthStr + "-" + dayStr;
```

## Info

### IN-01: Missing `(:background)` annotation on MawaqitService for future background use

**File:** `source/MawaqitService.mc:9`
**Issue:** The `MawaqitService` module is not annotated with `(:background)`. Per the Connect IQ annotation system documented in CLAUDE.md, code without `(:background)` is not loaded during background service execution. If a future phase adds a `ServiceDelegate` that calls `MawaqitService.fetchPrayerData()` from a temporal event, the module will not be available.
**Fix:** When background services are implemented in a future phase, ensure either: (a) `MawaqitService` is annotated `(:background)`, or (b) a separate lightweight fetch module is created for background use to minimize memory footprint in the 28-32 KB background budget.

### IN-02: Fenix 8 product ID may need sub-variant specification

**File:** `manifest.xml:14`
**Issue:** The product ID `fenix8` is declared, but Garmin Fenix 8 comes in multiple variants (47mm, 43mm, solar, etc.) with different screen sizes and resolutions. Depending on the SDK version, the generic `fenix8` ID may not match all variants, or it may need to be specified as separate product entries.
**Fix:** Verify against the Connect IQ SDK device list which Fenix 8 variants are available and whether `fenix8` covers all of them. Add specific variant IDs if needed (e.g., `fenix847mm`, `fenix8solar47mm`).

### IN-03: Stub views have placeholder-only content

**File:** `source/GarminMawaqitApp.mc:75-115`
**Issue:** `MawaqitWidgetView` and `MawaqitGlanceView` are stub implementations that display a static "Mawaqit" string. These are explicitly noted as "replaced in Phase 2/3" in comments, but they do not display any of the fetched prayer data, making it impossible to visually verify that the data pipeline works without inspecting Storage values in the simulator.
**Fix:** No action needed for Phase 01 delivery. Consider adding minimal data display (e.g., showing the cached mosque name or next prayer time) in Phase 02 to enable visual verification.

---

_Reviewed: 2026-04-10T12:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
