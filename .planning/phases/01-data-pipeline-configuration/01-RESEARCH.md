# Phase 1: Data Pipeline & Configuration - Research

**Researched:** 2026-04-10
**Domain:** Garmin Connect IQ HTTP requests, JSON parsing, persistent storage, app settings
**Confidence:** HIGH

## Summary

Phase 1 builds the data backbone: fetching prayer times from the Mawaqit proxy API, storing them in Application.Storage, and letting the user configure their mosque via the Garmin Connect phone app. The research uncovered one **critical constraint** that fundamentally shapes the architecture: the full API response (40.3 KB) far exceeds the practical JSON response size limit (~16-32 KB depending on device) for `Communications.makeWebRequest()`, making it impossible to fetch the entire 12-month calendar in a single request on most devices.

Fortunately, the proxy API at `mawaqit.naj.ovh` exposes fine-grained endpoints -- `/prayer-times` (96 bytes), `/calendar/{month}` (~3.2 KB), and `/calendar-iqama/{month}` (~2.3 KB) -- that individually fit well within safe limits. The architecture must use multiple smaller requests instead of one large request. This changes the user's original decision (D-02) to store the full 12-month calendar: while that goal remains achievable over time via sequential monthly fetches, the initial data fetch and any foreground refresh must use the per-month endpoints.

**Primary recommendation:** Use the per-month API endpoints (`/calendar/{month}` and `/calendar-iqama/{month}`) to fetch 2 months of data (current + next) per refresh cycle, storing results across multiple Storage keys. Use `/prayer-times` for immediate display data. Do NOT attempt to fetch the full endpoint in a single `makeWebRequest()` call.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Store prayer-relevant fields only from the API response: `calendar`, `iqamaCalendar`, `times`, `shuruq`, `jumua`/`jumua2`, `name`, `timezone`, `hijriAdjustment`. Skip announcements, images, facility flags, flash messages, and other mosque metadata.
- **D-02:** Store the full 12-month calendar (not just two days). User confirmed the full calendar response is under 36KB. This gives maximum offline resilience -- accurate prayer times for months without a refresh.
- **D-03:** The API response is wrapped in a `rawdata` top-level key. Calendar is an array of 12 monthly objects, each with days 1-31. Each day has 6 time strings (Fajr, Shuruq, Dhuhr, Asr, Maghrib, Isha). Iqama calendar has 5 offset strings per day (relative offsets like `"+10"`).
- **D-04:** No default mosque slug. `properties.xml` ships with an empty value. User must configure their mosque slug via the Garmin Connect phone app.
- **D-05:** Before a mosque is configured, show an empty state with instructions -- the normal layout with placeholder dashes and a brief message directing the user to Garmin Connect to set their mosque.
- **D-06:** Always show cached data without any staleness warning or age indicator.
- **D-07:** When cached calendar data has fully expired (no entry for the current date and no future data), switch to the empty state.

### Claude's Discretion
- **Error communication:** How much detail to show when things go wrong (bad slug, API down, no BLE connection). Claude has flexibility to design appropriate error handling.
- **Storage key structure:** How to organize keys in Application.Storage (single blob vs. separate keys for calendar, metadata, etc.).
- **HTTP request configuration:** Request headers, timeout handling, retry logic for `Communications.makeWebRequest()`.

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| DATA-01 | App fetches prayer times from Mawaqit API via endpoint | API endpoints verified: `/prayer-times`, `/calendar/{month}`, `/calendar-iqama/{month}`. Per-month endpoints return 2-3 KB each, safely within device limits. |
| DATA-02 | Prayer data cached in Application.Storage for offline use | Storage API verified: `Storage.setValue()`/`getValue()` with 32 KB per-key limit, ~100 KB total. Monthly data fits comfortably. |
| DATA-03 | App displays last cached data when phone/API unavailable | Storage survives app stop/start cycles. Load from Storage on startup, fall back gracefully on HTTP errors (-104 BLE, -300 timeout). |
| DATA-04 | App stores two days of prayer data for Isha-to-Fajr rollover | Per-month calendar endpoint returns all days for a month. Store current + next month to always have tomorrow's Fajr available. |
| DATA-05 | App fetches and displays iqama times from API | `/calendar-iqama/{month}` endpoint returns iqama offsets (~2.3 KB per month). Offsets are relative strings like `"+10"`. |
| CONF-01 | User can set mosque slug via Garmin Connect phone app settings | Properties API + settings.xml with `settingConfig type="alphaNumeric"`. Property syncs from phone to watch automatically. |
| CONF-02 | Settings sync to watch via Properties and trigger data re-fetch | `AppBase.onSettingsChanged()` callback fires when phone changes settings. Read new slug via `Properties.getValue()`, trigger re-fetch. |
</phase_requirements>

## Critical Finding: API Response Size Exceeds Device Limits

### The Problem

The full Mawaqit API response at `https://mawaqit.naj.ovh/api/v1/{slug}/` is **40.3 KB** (36,290 bytes raw, 41,288 bytes as formatted JSON). Even filtering to only prayer-relevant fields, the response is **37.2 KB**. [VERIFIED: live API measurement via curl]

Garmin Connect IQ `makeWebRequest()` with JSON response type has an undocumented practical limit of approximately **16-32 KB** depending on device model. Responses exceeding this limit return error code **-402 (NETWORK_RESPONSE_TOO_LARGE)** or **-403 (NETWORK_RESPONSE_OUT_OF_MEMORY)**. The JSON-to-Dictionary conversion uses 2-3x the raw response size in memory, further reducing effective limits. [VERIFIED: Garmin Forums multiple threads, CITED: https://forums.garmin.com/developer/connect-iq/f/discussion/414966]

### Measured Response Sizes

| Endpoint | Size | Safe for makeWebRequest? |
|----------|------|--------------------------|
| Full endpoint (`/{slug}/`) | 40.3 KB | NO - will cause -402/-403 on most devices |
| Prayer-relevant fields only | 37.2 KB | NO - still too large |
| Calendar alone | 22.1 KB | RISKY - borderline, may fail on older devices |
| IqamaCalendar alone | 14.9 KB | MAYBE - within limit but with overhead risk |
| `/prayer-times` | 96 bytes | YES - trivially safe |
| `/calendar/{month}` | ~3.2 KB | YES - very safe |
| `/calendar-iqama/{month}` | ~2.3 KB | YES - very safe |
| 2 months combined | ~11 KB total (4 requests) | YES - each request individually safe |

[VERIFIED: All sizes measured against live API on 2026-04-10]

### The Solution: Use Per-Month Endpoints

The proxy API exposes fine-grained endpoints discovered via the OpenAPI spec at `/openapi.json`:

```
GET /api/v1/{slug}/prayer-times        -- Today's 5 prayer times (96 bytes)
GET /api/v1/{slug}/calendar/{month}    -- One month of prayer times (~3.2 KB)  
GET /api/v1/{slug}/calendar-iqama/{month} -- One month of iqama offsets (~2.3 KB)
```
[VERIFIED: live API, OpenAPI spec at https://mawaqit.naj.ovh/openapi.json]

### Impact on D-02 (Full 12-Month Calendar)

User decision D-02 says "store the full 12-month calendar." This is still achievable but requires **multiple sequential requests** (24 requests for 12 months of calendar + iqama). This is impractical for a single foreground fetch but could be accomplished over time via background service temporal events.

**Recommended approach:** Fetch 2 months (current + next) initially, which covers DATA-04 (Isha-to-Fajr rollover) and provides ~60 days of offline data. Background service can progressively fetch remaining months. This gives the best balance of immediate usability vs. offline resilience.

### Missing Metadata Problem

The metadata fields (mosque `name`, `timezone`, `jumua`/`jumua2`, `shuruq`, `hijriAdjustment`) are only available from the full endpoint (`/{slug}/`), which is too large. The `/prayer-times` endpoint returns today's times but without mosque name or timezone.

**Options (Claude's discretion):**
1. **Fetch full endpoint as plain text** -- Use `HTTP_RESPONSE_CONTENT_TYPE_TEXT_PLAIN` and manually extract metadata fields. Avoids JSON dictionary overhead but requires string parsing. Available since API 3.0.0. [CITED: Garmin Forums]
2. **Accept the risk on the full endpoint** -- Modern devices (Fenix 7+, Venu 2+) may handle 40 KB. Catch -402/-403 gracefully and fall back.
3. **Request proxy enhancement** -- Ask user to add a `/metadata` endpoint that returns just name, timezone, jumua, shuruq, hijriAdjustment (~193 bytes).
4. **Skip metadata on initial fetch** -- Use slug as display name, infer timezone from device. Fetch full endpoint only as background task where memory budget differs.

**Recommendation:** Option 3 (proxy enhancement) is the cleanest. If not feasible, Option 1 (plain text) is the safest technical fallback. The planner should flag this for user confirmation.

## Standard Stack

### Core (Garmin Connect IQ built-in APIs)

| API | Module | Purpose | Why Standard |
|-----|--------|---------|--------------|
| `Communications.makeWebRequest()` | `Toybox.Communications` | HTTP requests to Mawaqit API | Only HTTP API in Connect IQ. Use with JSON response type for per-month endpoints. | 
| `Application.Storage` | `Toybox.Application.Storage` | Persist cached prayer data | Purpose-built for app-managed data. Survives app restarts. 32 KB per key, ~100 KB total. |
| `Application.Properties` | `Toybox.Application.Properties` | Read user settings (mosque slug) | Purpose-built for user-configurable settings. Syncs from phone app. |
| `Time.Gregorian` | `Toybox.Time.Gregorian` | Date/time calculations | Parse prayer time strings, determine current month/day for calendar lookups. |

### Supporting

| API | Module | Purpose | When to Use |
|-----|--------|---------|-------------|
| `System.getClockTime()` | `Toybox.System` | Current wall-clock time | Quick time checks without full Gregorian conversion |
| `WatchUi.requestUpdate()` | `Toybox.WatchUi` | Trigger view redraw | After data fetch completes or settings change |
| `Lang.Exception` | `Toybox.Lang` | Error handling | Catch StorageFullException, UnexpectedTypeException |

### Not Applicable

No npm packages, no external dependencies. Monkey C has no package manager -- all APIs are built into the Toybox SDK. [VERIFIED: CLAUDE.md]

**Installation:** No package installation needed. All APIs are part of Connect IQ SDK 8.4.0.

## Architecture Patterns

### Recommended Project Structure
```
source/
    GarminMawaqitApp.mc       # AppBase: lifecycle, onSettingsChanged, onBackgroundData
    MawaqitService.mc          # HTTP request logic, response parsing
    PrayerDataStore.mc         # Storage read/write, data model
    MawaqitGlanceView.mc      # Glance view (Phase 2, stub only)
    MawaqitWidgetView.mc      # Widget view (Phase 3, stub only)
    MawaqitDelegate.mc        # BehaviorDelegate (Phase 3, stub only)
resources/
    properties.xml             # Default property values (empty mosque slug)
    settings/
        settings.xml           # Phone app settings UI
    strings/
        strings.xml            # Localized strings
    drawables/
        drawables.xml          # Launcher icon reference
        launcher_icon.png      # App icon
manifest.xml                   # App identity, permissions, devices
monkey.jungle                  # Build configuration
```

### Pattern 1: Multi-Request Data Fetch

**What:** Fetch prayer data through multiple small API calls instead of one large call.
**When to use:** Every data refresh (foreground or background).
**Why:** The full API response exceeds the JSON response size limit on most Garmin devices.

```monkeyc
// Source: Architecture recommendation based on API size analysis
function fetchPrayerData(slug as String) as Void {
    var month = getCurrentMonth(); // 1-12
    var nextMonth = (month % 12) + 1;
    
    // Request 1: Current month calendar
    var url = "https://mawaqit.naj.ovh/api/v1/" + slug + "/calendar/" + month;
    Communications.makeWebRequest(url, null, {
        :method => Communications.HTTP_REQUEST_METHOD_GET,
        :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
    }, method(:onCalendarReceive));
}

function onCalendarReceive(responseCode as Number, data as Dictionary or String or Null) as Void {
    if (responseCode == 200 && data != null) {
        // data is an Array of day objects
        // Store in Application.Storage
        Storage.setValue("cal_" + _currentMonth, data);
        // Chain next request (next month, then iqama months)
        fetchNextMonth();
    } else {
        handleError(responseCode);
    }
}
```

### Pattern 2: Settings-Driven Re-Fetch

**What:** When user changes mosque slug in phone app, detect it and trigger fresh data fetch.
**When to use:** Whenever `onSettingsChanged()` fires.

```monkeyc
// Source: Garmin Forums, official AppBase API
class GarminMawaqitApp extends Application.AppBase {
    function onSettingsChanged() as Void {
        // Read the new mosque slug
        var newSlug = Properties.getValue("mosqueSetting") as String;
        if (newSlug != null && !newSlug.equals("") && !newSlug.equals(_currentSlug)) {
            _currentSlug = newSlug;
            // Clear old cached data since mosque changed
            clearCachedData();
            // Trigger fresh fetch
            fetchPrayerData(newSlug);
        }
        WatchUi.requestUpdate();
    }
}
```
[CITED: https://forums.garmin.com/developer/connect-iq/f/discussion/168736]

### Pattern 3: Storage Key Organization (Claude's Discretion Recommendation)

**What:** Use separate storage keys per data type and month for efficient partial updates.
**Why:** 32 KB per-key limit means calendar data must be split. Separate keys also allow partial updates (refresh one month without touching others).

```
Storage Keys:
    "mosqueMeta"      -> { "name": "...", "timezone": "...", "jumua": "...", "shuruq": "...", "hijriAdj": N }
    "cal_1" ... "cal_12"  -> Array of day objects for each month
    "iqama_1" ... "iqama_12" -> Array of iqama offset objects for each month
    "todayTimes"      -> { "fajr": "...", "dohr": "...", ... } from /prayer-times
    "lastFetchDate"   -> "2026-04-10"  (to know when data was last refreshed)
    "lastFetchSlug"   -> "tawba-bussy-saint-georges" (to detect slug changes)
```

**Size analysis per key:**
- Each `cal_N`: ~3.2 KB (well under 32 KB limit)
- Each `iqama_N`: ~2.3 KB (well under 32 KB limit)
- `mosqueMeta`: ~200 bytes
- `todayTimes`: ~100 bytes
- Total for 12 months: ~66 KB (within ~100 KB total Storage budget)
- Total for 2 months: ~11 KB (very comfortable)

### Pattern 4: Graceful Degradation on Errors

**What:** Handle network failures silently by falling back to cached data.
**When to use:** All HTTP error responses.

```monkeyc
// Source: Architecture recommendation, Garmin API docs
function onReceive(responseCode as Number, data) as Void {
    if (responseCode == 200 && data != null) {
        // Success - store and update
        processAndStoreData(data);
        WatchUi.requestUpdate();
    } else {
        // Error codes:
        //   -104: BLE not connected (phone not nearby)
        //   -300: Request timeout
        //   -400: Invalid response format
        //   -402: Response too large
        //   -403: Out of memory parsing response
        //   Other negative: Various CIQ internal errors
        //   4xx/5xx: HTTP server errors
        
        // Per D-06: silently fall back to cached data
        // No error UI needed if cached data exists
        // Only show error state if no cached data AND no mosque configured
    }
}
```

### Anti-Patterns to Avoid

- **Fetching the full endpoint directly:** The `/{slug}/` endpoint returns 40.3 KB of JSON which will cause -402/-403 errors on most devices. Always use per-month endpoints.
- **Using AppBase.getProperty()/setProperty():** Deprecated since CIQ 4.x. Use `Properties.getValue()` and `Storage.setValue()`. [VERIFIED: CLAUDE.md]
- **Storing all data in a single Storage key:** The 32 KB per-key limit and JSON dictionary memory overhead make this risky. Split data across multiple keys.
- **Using Symbols as Storage keys:** Symbols are not stable across app versions. Use String keys only. [CITED: Toybox.Application.Storage docs]
- **Blocking on sequential requests:** Monkey C is single-threaded but HTTP is async. Chain requests via callbacks, never try to wait/poll.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| HTTP requests | Custom socket/BLE code | `Communications.makeWebRequest()` | Only option on Connect IQ. Built-in JSON parsing. |
| Persistent storage | File I/O, custom serialization | `Application.Storage` | Only persistent storage API. Handles serialization automatically. |
| Settings UI on phone | Custom phone companion app | `properties.xml` + `settings.xml` | Built-in settings system syncs automatically via Garmin Connect. |
| JSON parsing | Manual string tokenizer | `HTTP_RESPONSE_CONTENT_TYPE_JSON` | SDK auto-parses JSON to Dictionary/Array. Only hand-parse if response too large. |
| Date/time math | Custom date arithmetic | `Time.Gregorian.moment()` / `Time.Gregorian.info()` | Handles DST, timezones, month lengths correctly. |

**Key insight:** Connect IQ is an extremely constrained platform. There are no third-party libraries -- you use the Toybox SDK APIs or nothing. The "don't hand-roll" guidance is really "use the SDK API, not a workaround" since there are no library choices to make.

## Common Pitfalls

### Pitfall 1: JSON Response Too Large (-402/-403)
**What goes wrong:** App fetches the full Mawaqit API response and gets -402 or -403 error. No data is returned.
**Why it happens:** The full response (40.3 KB) exceeds the device's JSON parsing memory budget. Dictionary conversion doubles or triples memory usage.
**How to avoid:** Use per-month endpoints. Each request stays under 3.5 KB.
**Warning signs:** Works in simulator but fails on real device. Works on newer devices but fails on older ones.
[VERIFIED: live API measurement + Garmin Forums]

### Pitfall 2: Background.exit() Data Size Limit
**What goes wrong:** Background service fetches data, tries to pass it back via `Background.exit()`, gets `ExitDataSizeLimitException`.
**Why it happens:** `Background.exit()` has an ~8 KB limit. The serialized Dictionary overhead can push even small data over.
**How to avoid:** In background service, write data directly to `Storage.setValue()` (available since API 3.2.0). Use `Background.exit()` only for status codes, not data payload.
**Warning signs:** Exception in background process, data never reaches foreground.
[CITED: https://forums.garmin.com/developer/connect-iq/f/discussion/7550]

### Pitfall 3: Symbols as Storage Keys Break on Updates
**What goes wrong:** App stores data with Symbol keys (`:prayerData`). After app update, keys no longer match and data appears lost.
**Why it happens:** Symbol values are not guaranteed stable across app versions.
**How to avoid:** Always use String keys for `Storage.setValue()`/`getValue()`.
[CITED: Toybox.Application.Storage API docs]

### Pitfall 4: makeWebRequest in Widget Foreground vs Background
**What goes wrong:** Widget calls `makeWebRequest()` during glance display. Request fails silently or never completes.
**Why it happens:** Glance views have severe memory restrictions (28-32 KB) and limited lifecycle. HTTP requests may not complete before the glance is hidden.
**How to avoid:** Make HTTP requests only from the full widget view (`getInitialView`) or from the background service (`ServiceDelegate`). Glance should only read from Storage.
**Warning signs:** Data fetches work in full widget but not from glance.
[VERIFIED: CLAUDE.md memory budgets]

### Pitfall 5: onSettingsChanged Not Called in Background
**What goes wrong:** User changes mosque slug in phone app while background service is running. Background service uses the old slug.
**Why it happens:** `onSettingsChanged()` only fires in the main app process, not in background. Background service has its own memory space.
**How to avoid:** In the background service, always read `Properties.getValue("mosqueSetting")` fresh before making the request. Don't cache the slug in a variable shared between processes.
[CITED: https://forums.garmin.com/developer/connect-iq/f/discussion/168736]

### Pitfall 6: Empty String vs Null for Mosque Setting
**What goes wrong:** App treats empty string as a valid mosque slug and makes API request to `/api/v1//`, getting 404 or garbage.
**Why it happens:** `Properties.getValue()` returns the default value from properties.xml, which is an empty string, not null.
**How to avoid:** Check for both null AND empty string: `if (slug == null || slug.equals(""))`.
**Warning signs:** App appears to work but shows empty state despite setting a mosque.
[ASSUMED]

## Code Examples

### properties.xml
```xml
<!-- Source: Garmin API docs pattern + BCTides example -->
<resources>
    <properties>
        <property id="mosqueSetting" type="string"></property>
    </properties>
</resources>
```
[VERIFIED: BCTides GitHub repo pattern, Garmin resource compiler docs]

### settings.xml
```xml
<!-- Source: Garmin API docs pattern + BCTides/forum examples -->
<resources>
    <settings>
        <setting propertyKey="@Properties.mosqueSetting" 
                 title="@Strings.MosqueSettingTitle"
                 prompt="@Strings.MosqueSettingPrompt">
            <settingConfig type="alphaNumeric" required="false" />
        </setting>
    </settings>
</resources>
```
[VERIFIED: BCTides GitHub repo settings.xml, Garmin Forums alphaNumeric examples]

### strings.xml
```xml
<resources>
    <strings>
        <string id="AppName">Mawaqit</string>
        <string id="MosqueSettingTitle">Mosque ID</string>
        <string id="MosqueSettingPrompt">Enter your mosque slug from mawaqit.net</string>
    </strings>
</resources>
```
[ASSUMED: standard pattern from Garmin examples]

### manifest.xml (minimal)
```xml
<iq:manifest xmlns:iq="http://www.garmin.com/xml/connectiq" version="3">
    <iq:application entry="GarminMawaqitApp" 
                    id="YOUR-APP-UUID-HERE" 
                    launcherIcon="@Drawables.LauncherIcon" 
                    minApiLevel="4.2.0" 
                    name="@Strings.AppName" 
                    type="widget" 
                    version="0.1.0">
        <iq:products>
            <iq:product id="venu2"/>
            <iq:product id="venu2plus"/>
            <iq:product id="fenix7"/>
            <iq:product id="fr265"/>
            <iq:product id="fenix8"/>
        </iq:products>
        <iq:permissions>
            <iq:uses-permission id="Communications"/>
        </iq:permissions>
        <iq:languages/>
        <iq:barrels/>
    </iq:application>
</iq:manifest>
```
[VERIFIED: GarminJSONWebRequestWidget GitHub example + CLAUDE.md device list]

### makeWebRequest with JSON Response
```monkeyc
// Source: GarminJSONWebRequestWidget GitHub + Garmin API docs
using Toybox.Communications;

function fetchCurrentMonthCalendar(slug as String, month as Number) as Void {
    var url = "https://mawaqit.naj.ovh/api/v1/" + slug + "/calendar/" + month;
    Communications.makeWebRequest(
        url,
        null,  // no query params
        {
            :method => Communications.HTTP_REQUEST_METHOD_GET,
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        },
        method(:onCalendarReceive)
    );
}

function onCalendarReceive(responseCode as Number, data as Array or Null) as Void {
    if (responseCode == 200 && data != null) {
        // data is Array of day objects:
        // [{"fajr":"05:56","sunrise":"07:27","dohr":"13:53","asr":"17:27","maghreb":"20:25","icha":"21:51"}, ...]
        Storage.setValue("cal_" + _month, data);
    }
}
```

### Reading Settings with Null Check
```monkeyc
// Source: Garmin Properties API + common pattern
function getMosqueSlug() as String or Null {
    var slug = Properties.getValue("mosqueSetting") as String;
    if (slug == null || slug.equals("")) {
        return null;
    }
    return slug;
}
```

## API Response Format Reference

### /prayer-times Endpoint
```json
{
    "fajr": "05:35",
    "sunrise": "07:08",
    "dohr": "13:50",
    "asr": "17:33",
    "maghreb": "20:39",
    "icha": "22:07"
}
```
**Note:** Uses French-influenced key names: `dohr` (Dhuhr), `maghreb` (Maghrib), `icha` (Isha). [VERIFIED: live API]

### /calendar/{month} Endpoint
Returns an Array (0-indexed by day-1) of objects:
```json
[
    {"fajr":"05:56","sunrise":"07:27","dohr":"13:53","asr":"17:27","maghreb":"20:25","icha":"21:51"},
    {"fajr":"05:54","sunrise":"07:25","dohr":"13:53","asr":"17:28","maghreb":"20:26","icha":"21:53"},
    ...
]
```
Array length matches number of days in the month (28-31). [VERIFIED: live API]

### /calendar-iqama/{month} Endpoint
Returns an Array of iqama offset objects:
```json
[
    {"fajr":"+10","dohr":"+10","asr":"+10","maghreb":"+5","icha":"+10"},
    {"fajr":"+10","dohr":"+10","asr":"+10","maghreb":"+5","icha":"+10"},
    ...
]
```
Offsets are relative strings (minutes after adhan). No sunrise iqama. [VERIFIED: live API]

### Full Endpoint rawdata (Metadata Fields)
```json
{
    "name": "Mosquee Tawba",
    "timezone": "Europe/Paris",
    "hijriAdjustment": -1,
    "jumua": "12:30",
    "jumua2": "13:45",
    "shuruq": "07:08",
    "times": ["05:35","13:50","17:33","20:39","22:07"],
    "calendar": [...],
    "iqamaCalendar": [...]
}
```
**Key difference:** Full endpoint `calendar` uses positional arrays `["07:06","08:43","12:53","14:45","17:08","18:39"]` (6 values per day, keyed by day number "1"-"31"), while `/calendar/{month}` uses named objects. These are different formats. [VERIFIED: live API]

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `AppBase.getProperty()` | `Properties.getValue()` | CIQ 4.x (2022) | Old API deprecated, will be removed |
| `makeJsonRequest()` | `makeWebRequest()` with responseType | CIQ 2.x+ | Old API deprecated |
| Store data in Properties | Separate Properties (settings) and Storage (app data) | CIQ 2.4.0 | Properties for user config, Storage for app data |
| `Background.exit()` for data | `Storage.setValue()` in background | CIQ 3.2.0 | Background can write to Storage directly, then foreground reads via `onStorageChanged()` |

**Deprecated/outdated:**
- `AppBase.getProperty()`/`setProperty()` -- Use `Properties.getValue()` and `Storage.getValue()` [VERIFIED: CLAUDE.md]
- `Communications.makeJsonRequest()` -- Use `makeWebRequest()` with `:responseType` option [VERIFIED: CLAUDE.md]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Empty string is the default for an empty `<property type="string"></property>` tag (not null) | Pitfall 6 | Minor -- just add null check too. Low risk. |
| A2 | Strings.xml format with `<string id="...">` inside `<strings>` inside `<resources>` | Code Examples | Build would fail if wrong. Easy to fix. |
| A3 | `settingConfig required="false"` allows blank/empty mosque slug to be saved | Code Examples | If forced required, user cannot clear the setting. Minor UX issue. |
| A4 | Device product IDs are `venu2`, `venu2plus`, `fenix7`, `fr265`, `fenix8` | Code Examples | Build would fail for invalid device IDs. Check SDK device list during implementation. |

## Open Questions

1. **Mosque metadata without full endpoint**
   - What we know: name, timezone, jumua, shuruq, hijriAdjustment are only in the full 40.3 KB endpoint
   - What's unclear: Can the proxy be modified to add a `/metadata` endpoint? Will the full endpoint work as plain text?
   - Recommendation: Ask user if proxy can be enhanced. If not, implement plain-text fallback or skip metadata (use slug as display name, device timezone).

2. **Background service for initial data fetch in Phase 1**
   - What we know: Background services are covered in Phase 3 (BKGD-01, BKGD-02). Phase 1 is data pipeline only.
   - What's unclear: Should Phase 1 include the background temporal event registration, or just foreground fetch?
   - Recommendation: Phase 1 should implement foreground fetch only (triggered by widget open and settings change). Background service is Phase 3 scope.

3. **Multiple sequential HTTP requests timing**
   - What we know: makeWebRequest is async. Responses come via callbacks. Cannot make parallel requests reliably.
   - What's unclear: Is there a limit on how many sequential requests can be chained? Any throttling?
   - Recommendation: Chain requests via callbacks. Limit to 4-5 requests per refresh cycle (2 calendar + 2 iqama months + 1 prayer-times). Monitor for issues during testing.

## Project Constraints (from CLAUDE.md)

- **Platform:** Garmin Connect IQ SDK 8.4.0, Monkey C, CIQ API Level 4.2.0+
- **Forbidden APIs:** `AppBase.getProperty()`/`setProperty()` (deprecated), `makeJsonRequest()` (deprecated)
- **Required APIs:** `Properties.getValue()`, `Storage.setValue()`/`getValue()`, `Communications.makeWebRequest()`
- **Memory budgets:** Widget 64-128 KB, Glance 28-32 KB, Background 28-32 KB
- **Annotations required:** `(:glance)` for glance code, `(:background)` for background code
- **App type:** Widget (not watch face, not data field)
- **Manifest permissions:** Communications required
- **No barrels:** Project is simple enough to keep all code in main source directory
- **No npm/packages:** Monkey C has no external dependency ecosystem

## Sources

### Primary (HIGH confidence)
- Live Mawaqit API at `https://mawaqit.naj.ovh/api/v1/` -- response sizes measured, all endpoints tested, OpenAPI spec verified
- Garmin Connect IQ API docs: `Toybox.Application.Storage` -- module reference, methods, exceptions
- Garmin Connect IQ API docs: `Toybox.Communications` -- makeWebRequest signature, response codes, options
- CLAUDE.md project instructions -- complete API reference table, memory budgets, device targets

### Secondary (MEDIUM confidence)
- [Garmin Forums - Understanding -402 Response Limit](https://forums.garmin.com/developer/connect-iq/f/discussion/414966) -- device-specific JSON size limits
- [Garmin Forums - Background.exit() data size](https://forums.garmin.com/developer/connect-iq/f/discussion/7550) -- 8 KB limit for Background.exit()
- [Garmin Forums - onSettingsChanged](https://forums.garmin.com/developer/connect-iq/f/discussion/168736) -- callback behavior and location
- [Garmin Forums - Sharing data between background and foreground](https://forums.garmin.com/developer/connect-iq/f/discussion/299331) -- Storage.setValue in background
- [BCTides GitHub repo](https://github.com/bsyrowik/BCTides) -- properties.xml and settings.xml examples
- [GarminJSONWebRequestWidget GitHub repo](https://github.com/LarsThunberg/GarminJSONWebRequestWidget) -- makeWebRequest pattern

### Tertiary (LOW confidence)
- Forum claims about Storage 8 KB per-key limit vs 32 KB -- conflicting reports. Official docs say 32 KB. [Needs validation on target devices]

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- APIs are built-in, well-documented, no version ambiguity
- Architecture: HIGH -- API response sizes empirically measured, endpoints verified, patterns from official examples
- Pitfalls: HIGH -- sourced from multiple forum threads with developer confirmation
- Settings/Properties XML: MEDIUM -- verified against multiple GitHub examples but Garmin docs pages render client-side (could not scrape)
- Storage limits: MEDIUM -- official docs say 32 KB/key, forums report 8 KB in some contexts. Recommend testing.

**Research date:** 2026-04-10
**Valid until:** 2026-05-10 (30 days -- stable platform, proxy API controlled by user)
