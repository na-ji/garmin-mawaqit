# Technology Stack

**Project:** Garmin Mawaqit - Islamic Prayer Times Widget
**Researched:** 2026-04-10
**Overall Confidence:** MEDIUM-HIGH (Garmin CIQ ecosystem is well-documented but official docs could not be deep-scraped; findings cross-verified across multiple sources)

## Recommended Stack

### Platform & SDK

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| Connect IQ SDK | 8.4.0 (Dec 2025) | Build toolchain, simulator, compiler | Latest stable release. Supports System 8 devices and all CIQ 4.x+ targets. Install via SDK Manager. | HIGH |
| Monkey C | (bundled with SDK) | Programming language | Only language for Connect IQ development -- no choice here. Typed, object-oriented, Java-like syntax. | HIGH |
| Connect IQ API Level | 4.2.0 minimum | Minimum device API target | CIQ 4.x+ provides: GlanceView, Application.Properties, Application.Storage, Background services. Targeting 4.2.0+ covers Venu 2+, Fenix 7+, Forerunner 265+, which aligns with "modern devices only" requirement. | HIGH |
| System Target | System 5+ (minimum), System 8 (latest) | Runtime environment on device | System 5+ guarantees Properties/Storage APIs are available. System 8 is latest (Fenix 8, new 2025 devices). No need to target System 8-specific features for this app. | MEDIUM |

### Development Environment

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| Visual Studio Code | Latest | IDE | Official Garmin-supported IDE. Eclipse support was dropped. VS Code is the only actively maintained development path. | HIGH |
| Monkey C VS Code Extension | Latest (from Garmin) | Language support, build, debug, simulate | Official Garmin extension. Provides: syntax highlighting, autocompletion, build integration, simulator launch, real-time warnings, find references. Install from VS Code Marketplace (publisher: "garmin"). | HIGH |
| Connect IQ SDK Manager | Latest | SDK and device simulator management | Downloads SDK versions and device simulators. Required for initial setup. Available from developer.garmin.com/connect-iq/sdk/. | HIGH |
| Java Runtime (JRE) | 8+ | SDK dependency | The CIQ SDK tools are Java-based. JRE 8 or higher is required. A full JDK is NOT needed -- JRE suffices. | HIGH |

### Key Monkey C APIs

#### Communications (HTTP Requests)

| API | Module | Purpose | Notes | Confidence |
|-----|--------|---------|-------|------------|
| `Communications.makeWebRequest()` | `Toybox.Communications` | Fetch prayer times from Mawaqit API | Primary HTTP method. Accepts URL, params dict, options dict, and callback method. Returns JSON parsed into Monkey C Dictionary. | HIGH |
| Response callback | `method(:onReceive)` | Handle API response | Signature: `onReceive(responseCode as Number, data as Dictionary or String or Null)`. Check `responseCode == 200` for success. Negative codes are CIQ-internal errors (e.g., -400 = invalid response format, -104 = BLE not connected). | HIGH |
| `Communications.makeWebRequest()` options | Options Dictionary | Configure request | Key options: `:method` (GET/POST/PUT/DELETE), `:headers` (Dictionary), `:responseType` (HttpContentType). For JSON API: set `:responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON`. | HIGH |

**Critical for this project:** The watch does NOT make HTTP requests directly. All requests route through the paired phone via Bluetooth. If the phone is not connected, requests fail with error code -104 (BLE_CONNECTION_UNAVAILABLE). The app must handle this gracefully.

**Permission required:** `Communications` must be declared in `manifest.xml`:
```xml
<iq:permissions>
    <iq:uses-permission id="Communications"/>
</iq:permissions>
```

#### Application Settings (Mosque Configuration via Phone)

| API | Module | Purpose | Notes | Confidence |
|-----|--------|---------|-------|------------|
| `Properties.getValue(key)` | `Toybox.Application.Properties` | Read user settings (mosque slug) | Reads values defined in `properties.xml` and configurable via Garmin Connect Mobile app. Use for the mosque slug setting. | HIGH |
| `Properties.setValue(key, value)` | `Toybox.Application.Properties` | Write settings programmatically | Rarely needed -- settings are typically set by user via phone app. | HIGH |
| `Storage.getValue(key)` | `Toybox.Application.Storage` | Read persisted app data (cached prayer times) | Use for caching fetched prayer data across app restarts. Survives app stop/start cycles. | HIGH |
| `Storage.setValue(key, value)` | `Toybox.Application.Storage` | Write persisted app data | Store fetched prayer times here so the widget can display cached data immediately on startup before a fresh fetch completes. | HIGH |

**Settings file structure:** Define the mosque slug in `resources/properties.xml`:
```xml
<properties>
    <property id="mosqueSetting" type="string">tawba-bussy-saint-georges</property>
</properties>
```

And the UI for the phone settings in `resources/settings/settings.xml`:
```xml
<settings>
    <setting propertyKey="@Properties.mosqueSetting"
             title="@Strings.mosqueSettingTitle">
        <settingConfig type="alphaNumeric"/>
    </setting>
</settings>
```

**DEPRECATED -- DO NOT USE:**
- `AppBase.getProperty()` / `AppBase.setProperty()` -- Deprecated since CIQ 4.x. Garmin planned removal in System 5. Use `Properties.getValue()` and `Storage.getValue()` instead.

#### Time Handling

| API | Module | Purpose | Notes | Confidence |
|-----|--------|---------|-------|------------|
| `Time.now()` | `Toybox.Time` | Current moment (UTC-based) | Returns a `Moment` object. Use for comparing against prayer times. | HIGH |
| `Time.today()` | `Toybox.Time` | Midnight of current day | Returns a `Moment` at the start of today. Useful as a baseline. | HIGH |
| `Gregorian.info(moment, format)` | `Toybox.Time.Gregorian` | Break moment into components | Returns `Info` object with `hour`, `min`, `sec`, `day`, `month`, `year`. Use `Time.FORMAT_SHORT` for numeric values. | HIGH |
| `Gregorian.moment(options)` | `Toybox.Time.Gregorian` | Create moment from components | Build a Moment from `{:year, :month, :day, :hour, :minute, :second}`. Use to construct prayer time Moments from API string data. | HIGH |
| `Moment.subtract(moment)` | `Toybox.Time.Moment` | Calculate time difference | Returns a `Duration`. Use for countdown calculation (prayer time minus now). | HIGH |
| `Duration.value()` | `Toybox.Time.Duration` | Get seconds in duration | Returns total seconds as Number. Convert to hours:minutes:seconds for display. | HIGH |
| `System.getClockTime()` | `Toybox.System` | Current wall-clock time | Returns `ClockTime` with `.hour`, `.min`, `.sec`. Quick way to get display time without Gregorian conversion. Respects 12/24h device setting. | HIGH |

**Key pattern for this app:** Parse the API response times (e.g., "05:30") into Moments using `Gregorian.moment()`, then compare with `Time.now()` to find the next prayer and compute the countdown via `Moment.subtract()`.

#### Widget & Glance Lifecycle

| API | Class/Method | Purpose | Notes | Confidence |
|-----|-------------|---------|-------|------------|
| `AppBase.getInitialView()` | App class | Return widget view | Returns `[View, BehaviorDelegate]` array. Called when user opens the full widget. | HIGH |
| `AppBase.getGlanceView()` | App class | Return glance view | Returns `[GlanceView]` array. Annotate with `(:glance)`. Called when widget appears in glance carousel. | HIGH |
| `WatchUi.GlanceView` | Base class | Glance view base | Extend this for the compact glance display. Limited drawing area (roughly top 1/3 of screen). | HIGH |
| `WatchUi.View` | Base class | Full widget view base | Extend this for the full-screen widget display. | HIGH |
| `View.onUpdate(dc)` | View method | Draw to screen | Called by system when view needs redrawing. `dc` is the Graphics.Dc drawing context. | HIGH |
| `View.onShow()` / `View.onHide()` | View methods | View visibility changes | Use `onShow()` to start a timer for countdown updates. Use `onHide()` to stop it. | HIGH |
| `WatchUi.requestUpdate()` | Static method | Request view redraw | Triggers `onUpdate()` call. Use with a Timer for periodic countdown refresh. **Ignored on some devices for GlanceView** -- glances may not support live updates. | HIGH |
| `Timer.Timer` | `Toybox.Timer` | Periodic callback | Use `timer.start(callback, 1000, true)` for 1-second countdown updates in the full widget view. | HIGH |

#### Background Service (Data Refresh)

| API | Class/Method | Purpose | Notes | Confidence |
|-----|-------------|---------|-------|------------|
| `Background.registerForTemporalEvent(duration)` | Registration | Schedule background runs | Register in `getInitialView()` or `onStart()`. Minimum interval: 5 minutes. For prayer times, hourly or every 30 min is sufficient. | HIGH |
| `ServiceDelegate` | Base class | Background task handler | Extend to implement `onTemporalEvent()`. This is where you call `makeWebRequest()` in the background. | HIGH |
| `Background.exit(data)` | Static method | Return data from background | Pass fetched prayer data back. Data is delivered to `AppBase.onBackgroundData(data)`. | HIGH |
| `AppBase.onBackgroundData(data)` | App method | Receive background data | Store received data in `Storage.setValue()` and call `WatchUi.requestUpdate()` to refresh display. | HIGH |
| `AppBase.getServiceDelegate()` | App method | Return background service | Returns `[ServiceDelegate]`. Annotate with `(:background)`. | HIGH |

**Memory constraint:** Background + Glance share a ~28-32KB memory budget on most devices. The background service code loads at the beginning of the PRG file along with glance code. Keep both minimal.

### Build & Configuration Files

| File | Purpose | Notes |
|------|---------|-------|
| `manifest.xml` | App identity, type, permissions, supported devices | Set `type="widget"`. Declare `Communications` permission. List target device IDs. |
| `monkey.jungle` | Build configuration | Defines source paths, resource paths, exclude annotations per target. Default generated by VS Code project wizard. |
| `resources/properties.xml` | Default property values | Define `mosqueSetting` with default slug value. |
| `resources/settings/settings.xml` | Phone app settings UI | Define the text input for mosque slug. |
| `resources/strings/strings.xml` | Localized strings | App name, setting labels, prayer names. |
| `source/*.mc` | Monkey C source files | App, Views, Delegate, ServiceDelegate classes. |

### Code Annotations

| Annotation | Purpose | When to Use |
|------------|---------|-------------|
| `(:glance)` | Mark code available to glance view | Apply to `getGlanceView()`, GlanceView class, and any helper functions/classes called from the glance. Code WITHOUT this annotation is NOT loaded during glance display. |
| `(:background)` | Mark code available to background service | Apply to `getServiceDelegate()`, ServiceDelegate class, and any helpers called from background. Code WITHOUT this annotation is NOT loaded during background execution. |
| `(:release)` | Exclude from debug builds | Use for production-only optimizations. |
| `(:debug)` | Exclude from release builds | Use for debug logging, test helpers. |

**Critical rule:** Glance and background code loads from the beginning of the PRG file. Any code they reference MUST have the appropriate annotation, or it will not be available and will cause a runtime crash.

## Memory Budgets

| Context | Typical Budget | Notes |
|---------|---------------|-------|
| Widget (full view) | 64-128 KB | Varies by device. Modern devices (Fenix 7+, Venu 2+) have more generous limits. |
| Glance view | 28-32 KB | Very constrained. Shared with background code. Keep glance view minimal. |
| Background service | 28-32 KB | Shared with glance code. Only load what you need for the HTTP request and data parsing. |

## Alternatives Considered

| Category | Recommended | Alternative | Why Not Alternative |
|----------|-------------|-------------|---------------------|
| Language | Monkey C | None | Only option for Connect IQ. No JS, TS, or other language support. |
| IDE | VS Code + Monkey C Extension | Eclipse | Eclipse support was dropped by Garmin. VS Code is the only actively maintained path. |
| Settings API | `Properties.getValue()` | `AppBase.getProperty()` | Deprecated since CIQ 4.x. Will be removed. New code must use Properties/Storage modules. |
| HTTP API | `Communications.makeWebRequest()` | `Communications.makeJsonRequest()` | `makeJsonRequest()` is deprecated. `makeWebRequest()` is the current API with full options support. |
| Data persistence | `Application.Storage` | `Application.Properties` | Properties is for user-editable settings (mosque slug). Storage is for app-managed data (cached prayer times). Use both for their intended purposes. |
| App type | Widget (with Glance) | Watch Face / Data Field | Widget is the correct app type: it appears in the widget carousel, supports glances, and allows Communications API (watch faces cannot use Communications). |
| Background refresh | Temporal Event | None (foreground only) | Without background refresh, prayer data would only update when the user is actively viewing the widget. Temporal events allow periodic data refresh even when the widget is not in foreground. |

## What NOT to Use

| Technology/API | Why Not |
|----------------|---------|
| `AppBase.getProperty()` / `setProperty()` | Deprecated. Will cause warnings and eventual removal. Use `Properties.getValue()` and `Storage.getValue()`. |
| `Communications.makeJsonRequest()` | Deprecated. Use `makeWebRequest()` with `:responseType => HTTP_RESPONSE_CONTENT_TYPE_JSON`. |
| Eclipse IDE | Garmin dropped Eclipse support. The VS Code extension is now the sole official IDE tooling. |
| Watch Face app type | Watch Faces cannot use `Toybox.Communications`. Since this app needs HTTP requests, it must be a Widget. |
| Data Field app type | Data Fields are for activity-screen overlays. Not suitable for a standalone prayer times display. |
| Barrels (for this project) | Barrels are shared libraries. This project is simple enough that barrels add complexity without benefit. Keep all code in the main source directory. |
| CIQ 3.x support | Older API levels lack GlanceView, Properties/Storage modules, and have tighter memory. The project scope explicitly excludes older devices. |

## Target Devices (Recommended Starting Set)

Target CIQ 4.2.0+ devices. Start with a representative set for testing:

| Device | CIQ System | Screen Shape | Resolution | Why Include |
|--------|-----------|--------------|------------|-------------|
| Venu 2 / Venu 2 Plus | System 5 | Round AMOLED | 416x416 | Popular AMOLED watch, good baseline |
| Fenix 7 | System 5 | Round MIP | 260x260 | Popular outdoor watch |
| Forerunner 265 | System 5+ | Round AMOLED | 416x416 | Popular running watch |
| Fenix 8 | System 8 | Round AMOLED | 454x454 | Latest flagship |

Add more devices in the manifest.xml as needed. The VS Code extension lets you select target devices during project creation.

## Installation & Setup

```bash
# 1. Install VS Code (if not already installed)
# Download from https://code.visualstudio.com/

# 2. Install Java Runtime 8+ (if not already installed)
# macOS:
brew install openjdk@17

# 3. Install Connect IQ SDK Manager
# Download from https://developer.garmin.com/connect-iq/sdk/
# Run the SDK Manager, download SDK 8.4.0, and select target device simulators

# 4. Install VS Code Extension
# In VS Code: Extensions > Search "Monkey C" > Install (publisher: Garmin)

# 5. Verify installation
# In VS Code: Cmd+Shift+P > "Monkey C: Verify Installation"

# 6. Create new project
# In VS Code: Cmd+Shift+P > "Monkey C: New Project"
# Select: Widget
# Name: GarminMawaqit
# Select target devices

# No npm/package manager -- Monkey C has no external dependency ecosystem.
# All APIs are built into the Toybox SDK.
```

## Project File Structure (Generated + Customized)

```
garmin-mawaqit/
  manifest.xml                    # App identity, permissions, devices
  monkey.jungle                   # Build configuration
  resources/
    properties.xml                # Default settings values (mosque slug)
    strings/
      strings.xml                 # App name, prayer names, labels
    settings/
      settings.xml                # Phone app settings UI definition
    drawables/
      launcher_icon.png           # App icon for widget list
  source/
    GarminMawaqitApp.mc           # AppBase subclass (lifecycle, background data handling)
    GarminMawaqitView.mc          # Widget full view (main display)
    GarminMawaqitDelegate.mc      # Widget input delegate
    GarminMawaqitGlanceView.mc    # Glance view (compact display)
    GarminMawaqitServiceDelegate.mc  # Background service (API fetch)
    PrayerTimeHelper.mc           # Prayer time parsing, comparison, countdown logic
```

## Sources

- [Garmin Connect IQ SDK Download](https://developer.garmin.com/connect-iq/sdk/) - SDK versions and download
- [Connect IQ Core Topics - Glances](https://developer.garmin.com/connect-iq/core-topics/glances/) - Glance lifecycle and constraints
- [Connect IQ Core Topics - HTTPS/JSON](https://developer.garmin.com/connect-iq/core-topics/https/) - makeWebRequest documentation
- [Toybox.Communications API](https://developer.garmin.com/connect-iq/api-docs/Toybox/Communications.html) - Communications module reference
- [Connect IQ Core Topics - Properties and App Settings](https://developer.garmin.com/connect-iq/core-topics/properties-and-app-settings/) - Settings system
- [Connect IQ Core Topics - Persisting Data](https://developer.garmin.com/connect-iq/core-topics/persisting-data/) - Storage module
- [Toybox.Time.Gregorian API](https://developer.garmin.com/connect-iq/api-docs/Toybox/Time/Gregorian.html) - Time handling
- [Connect IQ Core Topics - Background Services](https://developer.garmin.com/connect-iq/core-topics/backgrounding/) - Temporal events and background processing
- [Connect IQ Manifest and Permissions](https://developer.garmin.com/connect-iq/core-topics/manifest-and-permissions/) - Permission declarations
- [Monkey C Annotations](https://developer.garmin.com/connect-iq/monkey-c/annotations/) - Code annotation system
- [VS Code Monkey C Extension](https://marketplace.visualstudio.com/items?itemName=garmin.monkey-c) - Official IDE extension
- [Garmin Forums - SDK 8.4.0](https://forums.garmin.com/developer/connect-iq/f/discussion/427394/connect-iq-sdk-8-4-0) - Latest SDK version discussion
- [Garmin Forums - SDK 8.3 Announcement](https://forums.garmin.com/developer/connect-iq/b/news-announcements/posts/connect-iq-sdk-8-3-now-available) - SDK release notes
- [Garmin Forums - Widget Glances](https://forums.garmin.com/developer/connect-iq/b/news-announcements/posts/widget-glances---a-new-way-to-present-your-data) - Glance system overview
- [Garmin Forums - App Lifecycles](https://forums.garmin.com/developer/connect-iq/f/discussion/214445/a-little-help-understanding-app-view-lifecycles) - Lifecycle behavior details
- [Garmin Forums - Background + Glance Memory](https://forums.garmin.com/developer/connect-iq/f/discussion/212286/glance-view-active-background-job) - Memory constraints
- [Garmin Forums - Properties Migration](https://forums.garmin.com/developer/connect-iq/f/discussion/328008/migrate-from-appbase-getproperty-to-storage-getvalue) - Deprecated API migration
