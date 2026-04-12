---
phase: 03-widget-background-service
reviewed: 2026-04-12T12:00:00Z
depth: standard
files_reviewed: 5
files_reviewed_list:
  - source/MawaqitWidgetView.mc
  - source/MawaqitServiceDelegate.mc
  - source/GarminMawaqitApp.mc
  - source/PrayerDataStore.mc
  - manifest.xml
findings:
  critical: 0
  warning: 3
  info: 3
  total: 6
status: issues_found
---

# Phase 03: Code Review Report

**Reviewed:** 2026-04-12T12:00:00Z
**Depth:** standard
**Files Reviewed:** 5
**Status:** issues_found

## Summary

Reviewed the Phase 03 implementation: widget view (full-screen 5-row prayer schedule), background service delegate (periodic prayer data refresh), app lifecycle (background registration, settings change handling, background data reception), prayer data store (read-side storage layer), and manifest. The code is well-structured with thorough comments, clean separation of concerns between foreground service (MawaqitService, 6-step chain) and background delegate (single lightweight request), and proper Monkey C annotation usage for `:glance` and `:background` contexts.

No critical issues found. Three warnings relate to missing input validation on background data, unvalidated user input in URL construction, and an unnecessary manifest permission. Three informational items cover date string format inconsistency, a missing type annotation, and duplicated layout calculation code.

## Warnings

### WR-01: Background data stored without structural validation

**File:** `source/GarminMawaqitApp.mc:59`
**Issue:** `onBackgroundData` stores the API response directly into `Storage.setValue("todayTimes", data)` without validating that it contains expected prayer time keys (`fajr`, `dohr`, `asr`, `maghreb`, `icha`). If the Mawaqit API changes its response format (noted as a project constraint -- "may change without notice"), malformed data gets cached and `PrayerLogic.parseTimeToSeconds()` will return null for all prayers, producing a `"no_data"` state. While PrayerLogic handles null parse results gracefully, the stale bad data persists in Storage and blocks recovery until the next successful fetch (24 hours later, per the temporal event interval).
**Fix:** Add a minimal structural check before storing:
```monkey-c
function onBackgroundData(data) as Void {
    if (data != null && data instanceof Dictionary) {
        var dict = data as Dictionary;
        // Validate at least one expected key exists before caching
        if (dict["fajr"] != null) {
            Storage.setValue("todayTimes", dict);
            var info = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
            var dateStr = info.year + "-" + info.month + "-" + info.day;
            Storage.setValue("lastFetchDate", dateStr);
        }
    }
    WatchUi.requestUpdate();
}
```

### WR-02: User-provided mosque slug used in URL without encoding

**File:** `source/MawaqitServiceDelegate.mc:32`
**Issue:** The `slug` value comes from user input via `Properties.getValue("mosqueSetting")` (typed in Garmin Connect phone app). It is concatenated directly into the URL without any encoding or sanitization. While Garmin's `makeWebRequest` may handle some encoding internally, characters like spaces, slashes, or query string delimiters in the slug could cause malformed requests or unintended path traversal against the API server. The same pattern exists in `MawaqitService.mc` (lines 101, 130, 159, 187) but those files are not in the review scope.
**Fix:** Sanitize the slug to allow only alphanumeric characters and hyphens, which matches typical Mawaqit mosque slug format:
```monkey-c
function onTemporalEvent() as Void {
    var slug = Properties.getValue("mosqueSetting") as String or Null;
    if (slug == null || slug.equals("")) {
        Background.exit(null);
        return;
    }

    // Basic slug validation: reject if it contains path separators or query chars
    if (slug.find("/") != null || slug.find("?") != null || slug.find("&") != null) {
        Background.exit(null);
        return;
    }

    var url = "https://mawaqit.naj.ovh/api/v1/" + slug + "/prayer-times";
    // ...
}
```

### WR-03: Unnecessary PushNotification permission declared

**File:** `manifest.xml:11`
**Issue:** The manifest declares `<iq:uses-permission id="PushNotification"/>` but no source file in the project uses push notification APIs. Unnecessary permissions can cause user hesitation during app installation (users see what permissions the app requests) and violate Garmin's Connect IQ store review guidelines which may reject apps requesting unused permissions.
**Fix:** Remove the unused permission:
```xml
<iq:permissions>
    <iq:uses-permission id="Background"/>
    <iq:uses-permission id="Communications"/>
</iq:permissions>
```

## Info

### IN-01: Date string format inconsistency with documented contract

**File:** `source/GarminMawaqitApp.mc:61`
**Issue:** The date string is built as `info.year + "-" + info.month + "-" + info.day` which produces unpadded output like `"2026-4-2"` instead of `"2026-04-02"`. PrayerDataStore's doc comment on line 49 states the format is `"YYYY-MM-DD"`, implying zero-padded ISO 8601. The same pattern appears in `MawaqitService.mc:208`. Since the date string is currently only used for cache staleness checks (comparing stored date to current date), both sides produce the same unpadded format, so no functional bug exists today. However, the documented contract does not match the implementation, which could cause bugs if a future consumer expects ISO 8601 format.
**Fix:** Either update the doc comment in PrayerDataStore to reflect the actual format (`"YYYY-M-D"`), or pad the values:
```monkey-c
var monthStr = (info.month < 10) ? "0" + info.month : "" + info.month;
var dayStr = (info.day < 10) ? "0" + info.day : "" + info.day;
var dateStr = info.year + "-" + monthStr + "-" + dayStr;
```

### IN-02: Missing type annotation on onBackgroundData parameter

**File:** `source/GarminMawaqitApp.mc:57`
**Issue:** The `data` parameter in `onBackgroundData(data)` lacks a type annotation. Per the CIQ API, `Background.exit()` can pass any type, but in this app it only passes `Dictionary or Null` (from MawaqitServiceDelegate). Adding the type annotation improves readability and enables type-checker warnings if the contract changes.
**Fix:**
```monkey-c
function onBackgroundData(data as Dictionary or Null) as Void {
```

### IN-03: Duplicated layout calculation constants between onUpdate and drawEmptyState

**File:** `source/MawaqitWidgetView.mc:98-103` and `source/MawaqitWidgetView.mc:235-239`
**Issue:** The layout constants (`headerY`, `sepY`, `leftMargin`, `rowStartY`, `rowSpacing`) are computed identically in both `onUpdate()` and `drawEmptyState()`. If the layout proportions are adjusted, both locations must be updated in sync. The same duplication exists in `MawaqitGlanceView.mc` between `onUpdate()` and `drawEmptyState()`.
**Fix:** Extract layout constants into a helper method or compute them once and pass as parameters to `drawEmptyState`:
```monkey-c
// In drawEmptyState, the parameters w and h are already passed.
// Consider passing pre-computed layout values or extracting to a shared method.
```

---

_Reviewed: 2026-04-12T12:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
