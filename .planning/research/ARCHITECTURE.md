# Architecture Patterns

**Domain:** Garmin Connect IQ Widget + Glance (Prayer Times)
**Researched:** 2026-04-10
**Overall Confidence:** MEDIUM-HIGH (official docs + community forums; some details from training data flagged)

## Recommended Architecture

### High-Level Overview

A Connect IQ 4.x "widget" app is a single application with two presentation modes sharing a common data layer:

```
                    Garmin Connect Phone App
                            |
                  (Settings sync via BLE)
                            |
                            v
    +--------------------------------------------+
    |           AppBase (MawaqitApp)              |
    |  onStart() / onStop() / onSettingsChanged() |
    +--------------------------------------------+
            |                       |
    getGlanceView()          getInitialView()
            |                       |
            v                       v
    +----------------+     +-------------------+
    | GlanceView     |     | WidgetView        |
    | (compact strip)|     | (full screen)     |
    +----------------+     +-------------------+
            \                      /
             \                    /
              v                  v
         +---------------------------+
         |    PrayerDataManager      |
         |  (shared business logic)  |
         +---------------------------+
                    |
         +-------------------+
         | Application.Storage |
         | (cached API data) |
         +-------------------+
                    ^
                    |
         +-------------------+
         | BackgroundService  |
         | (temporal events)  |
         | makeWebRequest()   |
         +-------------------+
                    |
              (BLE to phone)
                    |
                    v
         +-------------------+
         | Mawaqit API       |
         | (via phone proxy) |
         +-------------------+
```

### The CIQ 4.x Widget Model

On Connect IQ 4.x devices, the traditional "widget" app type is effectively an "app with glance." The manifest declares type `widget`, but the compiler produces a device app. The user sees:

1. **Glance mode** -- A compact strip in the scrollable glance carousel (accessed by swiping up/down from watch face). Shows a small preview. No user input except tap/START to open full view.
2. **Widget mode** -- Full-screen view launched when the user taps the glance. Accepts full input (buttons, touch, swipe). Auto-closes after inactivity.

Both modes are served by the **same AppBase subclass**. The system calls `getGlanceView()` for the glance and `getInitialView()` for the full widget.

**Confidence:** HIGH -- official Garmin docs confirm this model for CIQ 4.x.

---

## Component Boundaries

| Component | Class | Responsibility | Lifecycle | Communicates With |
|-----------|-------|---------------|-----------|-------------------|
| **App Entry** | `MawaqitApp extends AppBase` | Lifecycle orchestration, settings handling, view routing | Entire app lifetime | All components |
| **Glance View** | `MawaqitGlanceView extends WatchUi.GlanceView` | Compact display of next prayer name + time + countdown | Active only in glance carousel | PrayerDataManager (read-only) |
| **Widget View** | `MawaqitWidgetView extends WatchUi.View` | Full-screen display of next prayer, countdown, mosque info | Active when user opens from glance | PrayerDataManager (read-only) |
| **Widget Delegate** | `MawaqitWidgetDelegate extends WatchUi.BehaviorDelegate` | Handle button/touch input in widget mode | Paired with WidgetView | WidgetView |
| **Prayer Data Manager** | `PrayerDataManager` (module or class) | Parse prayer times, determine next prayer, compute countdown | Stateless logic, instantiated by views | Storage (read), Time module |
| **Background Service** | `MawaqitServiceDelegate extends System.ServiceDelegate` | Fetch prayer data from API on schedule | Runs independently on temporal events | Communications, Storage |
| **Settings/Properties** | XML config + `Properties` module | Mosque slug, user preferences | Managed by phone app + system | AppBase.onSettingsChanged() |

### Annotation-Based Code Separation

This is a critical architectural concern. Garmin uses **annotations** to control which code is loaded in each execution context:

- **`(:glance)` annotation** -- Code loaded when the glance view is active
- **No annotation** -- Code loaded only in the full widget context
- **Shared code** -- Must be annotated with `(:glance)` if the glance needs it

```
source/
  MawaqitApp.mc           -- (:glance) annotated (shared entry point)
  MawaqitGlanceView.mc    -- (:glance) annotated
  MawaqitWidgetView.mc    -- NOT annotated (widget-only)
  MawaqitWidgetDelegate.mc -- NOT annotated (widget-only)
  PrayerDataManager.mc    -- (:glance) annotated (both contexts need it)
  MawaqitServiceDelegate.mc -- (:background) annotated
```

**Why this matters:** The glance runs in a constrained memory context. Any code or resource the glance references MUST be annotated `(:glance)` or the app will crash. Conversely, widget-only code should NOT be annotated `(:glance)` to save glance memory.

**Confidence:** HIGH -- official docs and multiple forum posts confirm this pattern.

---

## Data Flow

### 1. Settings Flow (Phone to Watch)

```
User configures mosque slug in Garmin Connect phone app
    |
    v
Phone syncs settings to watch via BLE
    |
    v
AppBase.onSettingsChanged() fires on watch
    |
    v
App reads Properties.getValue("mosqueSlugs") 
    |
    v
Triggers background data fetch with new slug
```

**Key details:**
- Settings are defined in `resources/settings/settings.xml` (UI schema for phone) and `resources/properties.xml` (default values)
- Phone app auto-generates a settings UI from `settings.xml` -- no custom phone app needed
- Read settings with `Properties.getValue("key")` -- keys must be declared in XML
- `onSettingsChanged()` is called when settings arrive from phone -- use this to trigger a data refresh

**Properties vs Storage:**
- **Properties** = user-configurable settings synced from phone. Defined in XML. Read with `Properties.getValue()`. The phone app can change these.
- **Storage** = app-internal persistent data (cached prayer times, last fetch timestamp). Read/write with `Storage.getValue()` / `Storage.setValue()`. Phone cannot see or change these.

Never mix them: use Properties for settings (mosque slug), use Storage for cached data (prayer times JSON).

**Confidence:** HIGH -- official docs clearly distinguish Properties from Storage.

### 2. API Data Flow (Internet to Watch)

```
Background temporal event fires (every ~30 min or at specific time)
    |
    v
MawaqitServiceDelegate.onTemporalEvent()
    |
    v
Read mosque slug from Properties.getValue("mosqueSlug")
    |
    v
Communications.makeWebRequest(
    "https://mawaqit.naj.ovh/api/v1/{slug}/",
    null,  // no params
    { :method => Communications.HTTP_REQUEST_METHOD_GET,
      :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON },
    method(:onReceive)
)
    |
    v (response via phone BLE proxy)
    |
    v
onReceive(responseCode, data)
    |
    +-- responseCode == 200:
    |     Parse prayer times from JSON
    |     Storage.setValue("prayerTimes", parsedData)
    |     Storage.setValue("lastFetch", Time.now().value())
    |     Background.exit(parsedData)  // passes to foreground
    |
    +-- responseCode < 0:
    |     BLE/connection error (e.g., -104 = BLE_CONNECTION_UNAVAILABLE)
    |     Background.exit(null)  // signal failure
    |
    +-- responseCode >= 400:
          API error
          Background.exit(null)
```

**Critical constraint:** All HTTP requests go through the phone as a BLE proxy. The watch has no direct internet access (WiFi-capable watches may use WiFi for some operations, but the Connect IQ HTTP API always routes through the phone connection). If the phone is out of BLE range, requests fail with `-104 BLE_CONNECTION_UNAVAILABLE`.

**Confidence:** HIGH -- well-documented in official API docs.

### 3. Display Data Flow (Storage to Screen)

```
View.onShow() fires (glance enters carousel OR widget opens)
    |
    v
Read cached data: Storage.getValue("prayerTimes")
    |
    v
PrayerDataManager.getNextPrayer(cachedData, Time.now())
    |
    v
Returns: { name: "Asr", time: "15:30", countdownMinutes: 47 }
    |
    v
View.onUpdate(dc)
    |
    v
Draw to device context (dc):
  - Glance: prayer name + time + countdown in compact strip
  - Widget: same data with larger fonts, more detail, mosque name
```

**Update mechanism:**
- In the **widget view**, use a `Timer.Timer()` started in `onShow()` that calls `WatchUi.requestUpdate()` every 1-60 seconds (for countdown updates). Stop the timer in `onHide()`.
- In the **glance view**, `WatchUi.requestUpdate()` may be ignored on some devices. The system calls `onUpdate()` at its own pace. Design the glance to be correct whenever `onUpdate()` is called, without relying on frequent updates.

**Confidence:** MEDIUM -- Timer pattern is well-established for widgets; glance update behavior varies by device per forum reports.

### 4. Background Data Delivery to Foreground

```
Background.exit(data) called from ServiceDelegate
    |
    v
AppBase.onBackgroundData(data) fires in foreground
    |
    v
App stores data or updates view
    |
    v
WatchUi.requestUpdate() to refresh display
```

The background service and foreground app are separate execution contexts. They communicate through:
- `Background.exit(data)` -- background sends data out
- `AppBase.onBackgroundData(data)` -- foreground receives it
- `Application.Storage` -- shared persistent store (background can write, foreground can read)

**Confidence:** HIGH -- official API documentation.

---

## Project File Structure

```
garmin-mawaqit/
  manifest.xml                    -- App metadata, permissions, supported devices
  monkey.jungle                   -- Build configuration
  source/
    MawaqitApp.mc                 -- AppBase subclass (entry point)
    MawaqitGlanceView.mc          -- GlanceView subclass
    MawaqitWidgetView.mc          -- Full-screen View subclass
    MawaqitWidgetDelegate.mc      -- Input delegate for widget
    MawaqitServiceDelegate.mc     -- Background service for API calls
    PrayerDataManager.mc          -- Prayer time logic (shared)
  resources/
    properties.xml                -- Property defaults (mosque slug default)
    settings/
      settings.xml                -- Phone settings UI schema
    strings/
      strings.xml                 -- Localized strings
    drawables/
      launcher_icon.png           -- App icon
    layouts/
      layout.xml                  -- Widget layout (optional, can draw manually)
```

### manifest.xml Key Configuration

```xml
<iq:manifest xmlns:iq="http://www.garmin.com/xml/connectiq" version="5">
    <iq:application
        entry="MawaqitApp"
        id="your-app-uuid"
        launcherIcon="@Drawables.launcher_icon"
        minApiLevel="4.0.0"
        name="@Strings.AppName"
        type="widget">
        
        <iq:permissions>
            <iq:uses-permission id="Communications"/>
            <iq:uses-permission id="Background"/>
        </iq:permissions>
        
        <iq:languages>
            <iq:language>eng</iq:language>
            <iq:language>fre</iq:language>
        </iq:languages>
        
        <iq:devices>
            <!-- CIQ 4.x+ devices -->
            <iq:product id="venu2"/>
            <iq:product id="fenix7"/>
            <iq:product id="fr265"/>
            <!-- etc. -->
        </iq:devices>
        
        <iq:barrels/>
    </iq:application>
</iq:manifest>
```

**Key points:**
- `type="widget"` -- on CIQ 4.x this compiles to an app with glance support
- `minApiLevel="4.0.0"` -- targets modern devices only (per project requirements)
- `Communications` permission -- required for HTTP requests
- `Background` permission -- required for temporal events / background service

**Confidence:** HIGH -- manifest structure is well-documented.

---

## Patterns to Follow

### Pattern 1: Shared Data Manager (Stateless Logic)

**What:** A single `PrayerDataManager` module/class that contains all prayer-time computation logic, shared between glance and widget views.

**When:** Always. Both views need to determine the next prayer.

**Why:** Avoids duplicating business logic. Annotated `(:glance)` so both contexts can use it.

```monkey-c
(:glance)
module PrayerDataManager {
    // Returns dictionary with :name, :time, :countdown
    function getNextPrayer(prayerTimes as Array, now as Moment) as Dictionary {
        // Compare current time against each prayer time
        // After Isha, roll to next day's Fajr
        // Return the next upcoming prayer
    }
    
    function formatCountdown(targetMoment as Moment, now as Moment) as String {
        // "2h 15m" or "47m" format
    }
}
```

### Pattern 2: Storage-Backed Caching

**What:** Cache the full day's prayer times in `Application.Storage` after each API fetch. Views read from cache, never from the network directly.

**When:** Always. Network requests can only happen in background service or when phone is connected.

**Why:** The watch may be disconnected from the phone. Cached data ensures the app always has something to display.

```monkey-c
// In BackgroundService after successful fetch:
Storage.setValue("prayerData", {
    "fajr" => "05:12",
    "dhuhr" => "12:45", 
    "asr" => "15:30",
    "maghrib" => "18:47",
    "isha" => "20:15",
    "fetchDate" => "2026-04-10",
    "mosqueName" => "Tawba Bussy"
});
Storage.setValue("lastFetchTime", Time.now().value());

// In any View:
var data = Storage.getValue("prayerData");
if (data != null) {
    var nextPrayer = PrayerDataManager.getNextPrayer(data, Time.now());
}
```

### Pattern 3: Defensive onUpdate()

**What:** Every `onUpdate()` call must handle the case where there is no cached data (first launch, storage cleared, fetch failed).

**When:** Always.

**Why:** The app may launch before any API data has been fetched. The glance cannot make network requests.

```monkey-c
function onUpdate(dc as Dc) as Void {
    dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
    dc.clear();
    
    var data = Storage.getValue("prayerData");
    if (data == null) {
        dc.drawText(x, y, font, "Open settings\nto configure", 
                    Graphics.TEXT_JUSTIFY_CENTER);
        return;
    }
    
    var next = PrayerDataManager.getNextPrayer(data, Time.now());
    // Draw prayer info...
}
```

### Pattern 4: Timer Management in Widget View

**What:** Start a repeating timer in `onShow()`, stop it in `onHide()`. The timer calls `WatchUi.requestUpdate()` to refresh the countdown.

**When:** Widget (full-screen) view only. Not in glance.

**Why:** The countdown needs to update regularly. Timers that are not stopped leak resources and drain battery.

```monkey-c
class MawaqitWidgetView extends WatchUi.View {
    var _timer as Timer.Timer?;
    
    function onShow() as Void {
        _timer = new Timer.Timer();
        _timer.start(method(:onTimer), 60000, true); // every 60s
    }
    
    function onTimer() as Void {
        WatchUi.requestUpdate();
    }
    
    function onHide() as Void {
        if (_timer != null) {
            _timer.stop();
            _timer = null;
        }
    }
}
```

---

## Anti-Patterns to Avoid

### Anti-Pattern 1: Making HTTP Requests from Views

**What:** Calling `Communications.makeWebRequest()` directly from the glance or widget view code.

**Why bad:** Glance views cannot make web requests. Widget views can, but it ties network logic to UI lifecycle. If the widget auto-closes due to inactivity, the request callback may fire with no active view.

**Instead:** Use the background service (`ServiceDelegate`) for all HTTP requests. Store results in `Application.Storage`. Views only read from storage.

### Anti-Pattern 2: Storing API Data in Properties

**What:** Using `Properties.setValue()` to cache fetched prayer times.

**Why bad:** Properties are for user-configurable settings synced from the phone app. They must be declared in XML. Writing arbitrary data to Properties confuses the settings system and Properties are only persisted on graceful exit (data loss risk).

**Instead:** Use `Application.Storage.setValue()` for app-internal cached data. Storage persists immediately and supports up to ~100KB.

### Anti-Pattern 3: Forgetting (:glance) Annotations

**What:** Not annotating shared code with `(:glance)`, causing the glance to crash when it tries to reference that code.

**Why bad:** The glance runs in a restricted memory context. Unannoted code is excluded from the glance build. If the glance view references it, the app crashes with an undefined symbol error.

**Instead:** Annotate every class, module, and function that the glance needs with `(:glance)`. Test the glance view separately in the simulator.

### Anti-Pattern 4: Not Handling Stale Data

**What:** Displaying cached prayer times without checking if they are from today.

**Why bad:** Yesterday's prayer times are wrong. The user sees incorrect times without any indication.

**Instead:** Compare `Storage.getValue("fetchDate")` or `lastFetchTime` against today. If stale, show the data with a visual indicator (dimmed, with "updating..." text) and ensure background service is scheduled to fetch fresh data.

---

## Key Monkey C Classes Reference

| Class | Module | Role in This App |
|-------|--------|-----------------|
| `Application.AppBase` | `Toybox.Application` | Base class for `MawaqitApp`. Override `getInitialView()`, `getGlanceView()`, `getServiceDelegate()`, `onSettingsChanged()`, `onBackgroundData()`. |
| `WatchUi.GlanceView` | `Toybox.WatchUi` | Base class for `MawaqitGlanceView`. Override `onUpdate(dc)`. Constrained drawing area, no layers, no input handling. |
| `WatchUi.View` | `Toybox.WatchUi` | Base class for `MawaqitWidgetView`. Override `onShow()`, `onUpdate(dc)`, `onHide()`. Full screen, full drawing API. |
| `WatchUi.BehaviorDelegate` | `Toybox.WatchUi` | Base class for input handling in widget view. Override `onSelect()`, `onBack()`, etc. |
| `System.ServiceDelegate` | `Toybox.System` | Base class for `MawaqitServiceDelegate`. Override `onTemporalEvent()` for scheduled background work. |
| `Communications` | `Toybox.Communications` | Static module. `makeWebRequest()` for HTTP calls. Only use from ServiceDelegate or active widget (prefer ServiceDelegate). |
| `Application.Properties` | `Toybox.Application` | `getValue(key)` / `setValue(key, value)` for settings declared in XML. Phone-syncable. |
| `Application.Storage` | `Toybox.Application` | `getValue(key)` / `setValue(key, value)` for internal persistent data. Immediate persistence. Background-accessible (CIQ 3.2+). |
| `Timer.Timer` | `Toybox.Timer` | Repeating or one-shot timers. Use for countdown refresh in widget view. |
| `Background` | `Toybox.Background` | `registerForTemporalEvent()` to schedule, `exit(data)` to return data from background. |

---

## Build Order (What Depends on What)

This defines the implementation order based on component dependencies:

### Phase 1: Foundation (no dependencies)
1. **Project scaffold** -- `manifest.xml`, `monkey.jungle`, directory structure
2. **Properties/Settings XML** -- `properties.xml` with mosque slug default, `settings.xml` for phone UI
3. **MawaqitApp (AppBase)** -- Skeleton with `getInitialView()` returning a placeholder view

### Phase 2: Data Layer (depends on Phase 1)
4. **PrayerDataManager** -- Prayer time parsing, next-prayer logic, countdown calculation. Pure logic, testable independently.
5. **Storage schema** -- Define storage keys and data format for cached prayer times

### Phase 3: Background Service (depends on Phase 1 + 2)
6. **MawaqitServiceDelegate** -- Background HTTP fetch from Mawaqit API, parse response, write to Storage, `Background.exit()`
7. **AppBase background wiring** -- `getServiceDelegate()`, `onBackgroundData()`, `onSettingsChanged()` triggering re-fetch

### Phase 4: Widget View (depends on Phase 2)
8. **MawaqitWidgetView** -- Full-screen display reading from Storage via PrayerDataManager. Timer-based countdown refresh.
9. **MawaqitWidgetDelegate** -- Input handling (back button to exit)

### Phase 5: Glance View (depends on Phase 2)
10. **MawaqitGlanceView** -- Compact strip display. Must be annotated `(:glance)`. Reads from Storage.

### Phase 6: Integration and Polish
11. **Error states** -- No data, stale data, no phone connection, API errors
12. **After-Isha rollover** -- Correctly show next day's Fajr when past Isha
13. **Edge cases** -- Midnight rollover, Ramadan schedule changes, timezone handling

**Rationale:** The data layer (PrayerDataManager) is the core dependency -- both views and the background service depend on it. The widget view is built before the glance because it is easier to test (full screen, supports timers, accepts input). The glance is built last because it has the most constraints and relies on the same data layer already being solid.

---

## Scalability Considerations

| Concern | Current (v1) | Future Consideration |
|---------|-------------|---------------------|
| **Multiple mosques** | Single mosque slug | Could support a list in settings; rotate or let user pick |
| **Data freshness** | Fetch once, cache for day | Background temporal event every 30 min; daily fetch at midnight |
| **Memory** | ~5 prayers + metadata | Well within 100KB Storage limit |
| **Device support** | CIQ 4.x+ only | CIQ 3.x would need separate widget type handling (out of scope) |
| **Localization** | English + French | `strings.xml` per language folder, prayer names translatable |

---

## Sources

- [Garmin Connect IQ Glances Documentation](https://developer.garmin.com/connect-iq/core-topics/glances/) -- HIGH confidence
- [AppBase API Reference](https://developer.garmin.com/connect-iq/api-docs/Toybox/Application/AppBase.html) -- HIGH confidence
- [Properties and App Settings](https://developer.garmin.com/connect-iq/core-topics/properties-and-app-settings/) -- HIGH confidence
- [Persisting Data (Storage)](https://developer.garmin.com/connect-iq/core-topics/persisting-data/) -- HIGH confidence
- [Application.Storage API](https://developer.garmin.com/connect-iq/api-docs/Toybox/Application/Storage.html) -- HIGH confidence
- [JSON REST Requests (Communications)](https://developer.garmin.com/connect-iq/core-topics/https/) -- HIGH confidence
- [Background Module API](https://developer.garmin.com/connect-iq/api-docs/Toybox/Background.html) -- HIGH confidence
- [Manifest and Permissions](https://developer.garmin.com/connect-iq/core-topics/manifest-and-permissions/) -- HIGH confidence
- [Widget Glances Announcement (Forum)](https://forums.garmin.com/developer/connect-iq/b/news-announcements/posts/widget-glances---a-new-way-to-present-your-data) -- MEDIUM confidence
- [Super Apps and Widgets in CIQ 4.0 (Forum)](https://forums.garmin.com/developer/connect-iq/f/discussion/245387/super-apps-and-widgets-in-ciq-4-0) -- MEDIUM confidence
- [App Lifecycle Discussion (Forum)](https://forums.garmin.com/developer/connect-iq/f/discussion/214445/a-little-help-understanding-app-view-lifecycles) -- MEDIUM confidence
- [BLE_CONNECTION_UNAVAILABLE Discussion (Forum)](https://forums.garmin.com/developer/connect-iq/f/discussion/268781/what-causes-and-how-can-i-advise-a-customer-to-avoid-error--104-ble_connection_unavailable) -- MEDIUM confidence
- [How to Create a Background Service (FAQ)](https://developer.garmin.com/connect-iq/connect-iq-faq/how-do-i-create-a-connect-iq-background-service/) -- HIGH confidence
- [Monkey C Annotations](https://developer.garmin.com/connect-iq/monkey-c/annotations/) -- HIGH confidence
