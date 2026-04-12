# Technology Stack: v1.1 Localization & Notifications

**Project:** Garmin Mawaqit - Islamic Prayer Times Widget
**Milestone:** v1.1 Localization & Notifications
**Researched:** 2026-04-12
**Overall Confidence:** MEDIUM-HIGH

This document covers ONLY the stack additions/changes needed for multi-language support (French/English) and optional prayer notifications. The existing v1.0 stack (SDK, Communications, Properties, Storage, Background, Timer, PrayerLogic) is validated and not repeated here.

---

## 1. Localization (Multi-Language Support)

### 1.1 Resource-Based String Localization

**Mechanism:** Connect IQ uses language-qualified resource directories. The device automatically loads the correct `strings.xml` based on the watch's system language. No code-level language switching is needed.

| Component | What to Do | Confidence |
|-----------|-----------|------------|
| Default strings | `resources/strings/strings.xml` (already exists) -- this is the fallback (English) | HIGH |
| French strings | Create `resources-fre/strings/strings.xml` with French translations | HIGH |
| Language code | `fre` (ISO 639-2/B code for French) -- NOT `fra` | HIGH |
| Manifest declaration | Add `<iq:language>fre</iq:language>` to `manifest.xml` `<iq:languages>` block | HIGH |
| Jungle file | Add `base.lang.fre = resources-fre` to `monkey.jungle` | HIGH |

**How it works:**
1. The base `resources/strings/strings.xml` serves as the English default (loaded when device language has no matching override)
2. `resources-fre/strings/strings.xml` contains French overrides -- only strings that differ need to be included; missing strings fall back to the base
3. The CIQ compiler bakes the correct strings into each locale variant at build time
4. At runtime, the device selects the right variant based on its system language setting

**Language codes confirmed from official Garmin sources:**
`hrv, ces, chs, cht, dan, dut, eng, fin, fre, deu, gre, hun, ita, jpn, nob, pol, por, rus, slo, slv, spa, swe, ara, bul, heb, kor, tha, tur, ukr, vie, zsm`

### 1.2 Folder Structure Changes

```
garmin-mawaqit/
  resources/
    strings/
      strings.xml                 # English (default/fallback)
    settings/
      settings.xml                # Settings UI (string refs auto-localize)
    properties.xml
    drawables/
  resources-fre/
    strings/
      strings.xml                 # French overrides
    settings/                     # Optional: only if settings labels differ
      settings.xml                # (usually not needed -- string refs resolve automatically)
```

### 1.3 monkey.jungle Changes

Current:
```
project.manifest = manifest.xml
base.sourcePath = source
base.resourcePath = resources;resources/drawables;resources/settings;resources/strings
```

Add language qualifier:
```
base.lang.fre = resources-fre
```

The `lang` qualifier in monkey.jungle tells the compiler: "when building for the `fre` locale, overlay these resources on top of the base." String references in `settings.xml` like `@Strings.MosqueSettingTitle` resolve automatically to the correct locale -- no code changes needed for settings UI localization.

### 1.4 manifest.xml Changes

Current:
```xml
<iq:languages>
    <iq:language>eng</iq:language>
</iq:languages>
```

Change to:
```xml
<iq:languages>
    <iq:language>eng</iq:language>
    <iq:language>fre</iq:language>
</iq:languages>
```

### 1.5 Accessing Localized Strings in Code

**For UI strings (settings, app name):** Already works via `@Strings.AppName` references in XML. No code changes.

**For programmatic strings (prayer names in PrayerLogic, empty state messages in views):**

| API | Usage | Notes | Confidence |
|-----|-------|-------|------------|
| `WatchUi.loadResource(Rez.Strings.StringId)` | Load a localized string at runtime | Returns the device-locale-appropriate string. Use this for prayer names and display messages. | HIGH |
| `Rez.Strings.*` | Compiled resource references | Auto-generated from `strings.xml` `id` attributes. Available as constants. | HIGH |

**Current problem in codebase:** Prayer names are hardcoded as constants in `PrayerLogic.mc`:
```monkey-c
const PRAYER_LABELS = ["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"];
```

And empty state messages are hardcoded in view files:
```monkey-c
"Set mosque in Connect app"   // MawaqitGlanceView.mc line 106
"Set mosque in"               // MawaqitWidgetView.mc line 66
"Garmin Connect app"          // MawaqitWidgetView.mc line 71
```

**Solution:** Define all user-visible strings in `strings.xml`, load them via `WatchUi.loadResource()` at view initialization or in `onUpdate()`. The `Rez.Strings.*` constants are lightweight (just resource IDs, not the strings themselves), so calling `loadResource()` is the actual memory allocation.

**Memory consideration:** `WatchUi.loadResource()` allocates the string on the heap. The first call triggers creation of the resource table: 36 bytes fixed overhead + 12 bytes per string entry. With ~20 string entries, total overhead is ~276 bytes. In the 28KB glance context, load strings on demand in `onUpdate()` rather than caching them as instance variables. For the 64-128KB widget context, caching in `onShow()` is acceptable.

### 1.6 Strings to Localize

| String ID | English | French | Where Used |
|-----------|---------|--------|------------|
| `AppName` | Mawaqit | Mawaqit | Manifest, Glance header |
| `PrayerFajr` | Fajr | Fajr | Prayer labels (same in both) |
| `PrayerDhuhr` | Dhuhr | Dhuhr | Prayer labels (same in both) |
| `PrayerAsr` | Asr | Asr | Prayer labels (same in both) |
| `PrayerMaghrib` | Maghrib | Maghrib | Prayer labels (same in both) |
| `PrayerIsha` | Isha | Isha | Prayer labels (same in both) |
| `CountdownIn` | in | dans | Countdown format "Asr in 2h" / "Asr dans 2h" |
| `CountdownNow` | now | maintenant | "Asr now" / "Asr maintenant" |
| `EmptyMosque` | Set mosque in Connect app | Mosquee via Connect app | Glance empty state |
| `EmptyMosqueWidget1` | Set mosque in | Mosquee via | Widget empty state line 1 |
| `EmptyMosqueWidget2` | Garmin Connect app | Garmin Connect app | Widget empty state line 2 |
| `MosqueSettingTitle` | Mosque ID | Identifiant mosquee | Settings screen |
| `MosqueSettingPrompt` | Enter your mosque slug | Entrez le slug de votre mosquee | Settings prompt |
| `NotifySettingTitle` | Notifications | Notifications | Notification settings group |
| `NotifyBeforeTitle` | Alert timing | Delai d'alerte | Timing preset setting |
| `NotifyAtTime` | At prayer time | A l'heure de la priere | List option |
| `Notify5Min` | 5 min before | 5 min avant | List option |
| `Notify10Min` | 10 min before | 10 min avant | List option |
| `Notify15Min` | 15 min before | 15 min avant | List option |

**Note:** Prayer names (Fajr, Dhuhr, etc.) are Arabic-origin words used universally in French and English Islamic contexts. They should NOT be translated -- they remain identical across locales. The localization effort is primarily for UI chrome and the countdown format strings.

---

## 2. Notifications (Prayer Time Alerts)

### 2.1 Primary Mechanism: Toybox.Notifications (Background-Capable)

**Module:** `Toybox.Notifications`
**Introduced:** API Level 5.1.0 (SDK 8.1.0, mid-2025)
**Available in:** Foreground AND background contexts
**Permission:** `PushNotification` (already declared in current manifest.xml)
**Confidence:** MEDIUM -- API is relatively new. Real-device behavior varies for vibration/sound.

This is the recommended primary notification mechanism because it is the ONLY API that can push an alert to the user from the background ServiceDelegate context.

| API | Signature | Purpose | Confidence |
|-----|-----------|---------|------------|
| `Notifications.showNotification(title, subtitle, options)` | `showNotification(title as String or ResourceId, subTitle as String or ResourceId, options as Dictionary or Null) as Void` | Push a full-screen notification to the watch display | MEDIUM |
| `Notifications.registerForNotificationMessages(callback)` | `registerForNotificationMessages(callback as Method or Null) as Void` | Receive user's response (dismissed or action selected) | MEDIUM |

**Options dictionary keys:**
- `:body` -- Additional notification text (String or ResourceId)
- `:icon` -- Custom bitmap or resource ID
- `:data` -- Context data passed back to app via callback
- `:actions` -- Array of action dictionaries with labels
- `:dismissPrevious` -- Boolean, defaults to true (clears prior unviewed notifications from this app)

**Notification message types (received in callback):**
- `Notifications.NOTIFICATION_MESSAGE_TYPE_DISMISSED` (value: 1) -- User dismissed
- `Notifications.NOTIFICATION_MESSAGE_TYPE_SELECTED` (value: 2) -- User selected an action

**Example usage from background ServiceDelegate:**
```monkey-c
function onTemporalEvent() as Void {
    // Can call showNotification directly from background
    Notifications.showNotification(
        "Fajr",                           // title
        "05:30",                          // subtitle (prayer time)
        {
            :body => "Prayer time has arrived",
            :dismissPrevious => true
        }
    );
    
    // Still need to exit the background process
    Background.exit(notificationData);
}
```

**Real-device behavior (from developer reports):**

| Device | Visual | Vibration | Sound |
|--------|--------|-----------|-------|
| Epix 2 Pro 51mm | Full-screen popup | YES | YES |
| FR955 | Full-screen popup | Unknown | Reported NO |
| Fenix 8 (target) | Expected full-screen | Expected YES | Expected YES |

The visual notification (icon + title animating from bottom, then body) is consistent across devices. Vibration and sound behavior varies -- this is a known inconsistency in the Notifications API.

**Key limitation:** CIQ notifications do NOT appear in the device's native notification glance/history. Once dismissed, they are gone. Users cannot review past prayer notifications.

### 2.2 Secondary Mechanism: Toybox.Attention (Foreground-Only Enhancement)

**Module:** `Toybox.Attention`
**Available in:** Widget, Watch App, Data Field, Glance, Audio Content Provider
**NOT available in:** Watch Face, Background Service
**Confidence:** HIGH -- Mature API, well-documented.

Use Attention as a supplementary enhancement when the widget is actively in the foreground. This provides reliable vibration on devices where `Notifications.showNotification()` may not vibrate.

| API | Signature | Purpose | Confidence |
|-----|-----------|---------|------------|
| `Attention.vibrate(profiles)` | `vibrate(profiles as Array<VibeProfile>) as Void` | Trigger vibration sequence | HIGH |
| `Attention.playTone(tone)` | `playTone(tone as Number) as Void` | Play a predefined tone | HIGH |
| `Attention.VibeProfile` | `new VibeProfile(dutyCycle as Number, duration as Number)` | Define one vibration step (0-100% intensity, duration in ms) | HIGH |

**Vibration pattern example (prayer alert):**
```monkey-c
if (Attention has :vibrate) {
    var vibePattern = [
        new Attention.VibeProfile(50, 500),   // medium 500ms
        new Attention.VibeProfile(0, 200),    // pause 200ms
        new Attention.VibeProfile(100, 800),  // strong 800ms
    ];
    Attention.vibrate(vibePattern);
}
```

**Tone constants for prayer alerts:**
- `Attention.TONE_ALERT_HI` -- High alert, good for prayer time arrival
- `Attention.TONE_TIME_ALERT` -- Time-based alert, semantically appropriate

**Critical constraints:**
1. **Foreground ONLY** -- cannot be called from background ServiceDelegate or onTemporalEvent. Confirmed by Garmin developer: "You can only do vibrations in the foreground process."
2. **Maximum 8 VibeProfile objects** per vibrate() call
3. **Forerunner devices** ignore VibeProfile duty cycle (vibrate at constant intensity)
4. **Always check `Attention has :vibrate`** and `Attention has :playTone` before calling
5. **No permission declaration needed** -- Attention does not require a manifest permission

### 2.3 Notification Architecture: Recommended Approach

Use a **two-tier strategy** combining both APIs:

**Tier 1 (Primary): Notifications.showNotification() from background**
When a temporal event fires at prayer time, the ServiceDelegate calls `showNotification()` to push a full-screen notification. This works regardless of whether the widget is in the foreground. The notification appears immediately with title (prayer name), subtitle (prayer time), and body (descriptive text).

**Tier 2 (Enhancement): Attention.vibrate() from foreground**
When the widget IS actively displayed at prayer time (checked in `onUpdate()` or `onBackgroundData()`), additionally call `Attention.vibrate()` to provide a guaranteed vibration. This covers the edge case where `showNotification()` may not vibrate on certain devices.

**Why two tiers:**
- `showNotification()` reaches the user even when they are not viewing the widget (primary value)
- `Attention.vibrate()` guarantees a physical vibration when the widget is open (reliability backstop)
- Neither alone covers all cases: showNotification lacks reliable vibration on some devices; Attention only works in foreground

### 2.4 Temporal Event Scheduling for Notifications

**Current state:** The app registers a periodic Duration-based temporal event for background data refresh.

**Change needed:** Switch from a fixed Duration to a calculated Moment targeting the next prayer time (minus notification offset). The data refresh piggybacks on the same background wake.

| API | Signature | Purpose | Confidence |
|-----|-----------|---------|------------|
| `Background.registerForTemporalEvent(moment)` | `registerForTemporalEvent(time as Time.Moment) as Void` | Schedule background run at specific time | HIGH |
| `Background.deleteTemporalEvent()` | `deleteTemporalEvent() as Void` | Cancel scheduled event | HIGH |
| `Background.getTemporalEventRegisteredTime()` | Returns `Moment or Duration or Null` | Check current registration | HIGH |
| `Background.getLastTemporalEventTime()` | Returns `Moment or Null` | When the last event fired | HIGH |

**Scheduling strategy (chain pattern):**

```
1. In onBackgroundData() or getInitialView():
   a. Read cached prayer times from Storage
   b. Read notification settings (enabled prayers, timing offset)
   c. Find the next prayer time that has notifications enabled
   d. Subtract the timing offset (0, 5, 10, or 15 minutes)
   e. Create a Moment for that target time
   f. Call registerForTemporalEvent(moment) to schedule

2. In onTemporalEvent() (background ServiceDelegate):
   a. Call Notifications.showNotification() with prayer name and time
   b. Optionally re-fetch prayer data (piggyback on background wake)
   c. Calculate and pass the NEXT prayer event time via Background.exit(data)

3. In onBackgroundData() (foreground, called when background exits):
   a. If widget is active and prayer time is now: trigger Attention.vibrate()
   b. Store refreshed data if fetched
   c. Schedule the NEXT prayer notification via registerForTemporalEvent()
```

**Critical rules for Moment-based scheduling:**
- If the Moment is in the past, the event fires immediately (on next system check)
- Minimum 5 minutes between events (throws `InvalidBackgroundTimeException` otherwise)
- Only ONE temporal event can be registered at a time (new registration overwrites old)
- The 5-minute restriction clears on fresh app startup (for widgets)
- `Background.exit()` data limited to ~8KB (String, Number, Float, Boolean, Array, Dictionary types)

**Chain scheduling implication:** If user wants Fajr at 05:30 and Dhuhr at 12:45, only one can be scheduled at a time. After the Fajr event fires, the handler must schedule the Dhuhr event. This is the standard pattern -- not a workaround.

### 2.5 Notification Settings

**Properties (in `properties.xml`):**

```xml
<!-- Per-prayer notification toggles -->
<property id="notifyFajr" type="boolean">false</property>
<property id="notifyDhuhr" type="boolean">false</property>
<property id="notifyAsr" type="boolean">false</property>
<property id="notifyMaghrib" type="boolean">false</property>
<property id="notifyIsha" type="boolean">false</property>

<!-- Notification timing preset (applies to all enabled prayers) -->
<property id="notifyTiming" type="number">0</property>
<!-- 0 = at prayer time, 5 = 5 min before, 10 = 10 min before, 15 = 15 min before -->
```

**Settings UI (in `settings.xml`):**

```xml
<!-- Notification settings group -->
<group title="@Strings.NotifySettingTitle">

    <!-- Per-prayer toggles -->
    <setting propertyKey="@Properties.notifyFajr"
             title="@Strings.PrayerFajr">
        <settingConfig type="boolean" />
    </setting>
    <setting propertyKey="@Properties.notifyDhuhr"
             title="@Strings.PrayerDhuhr">
        <settingConfig type="boolean" />
    </setting>
    <setting propertyKey="@Properties.notifyAsr"
             title="@Strings.PrayerAsr">
        <settingConfig type="boolean" />
    </setting>
    <setting propertyKey="@Properties.notifyMaghrib"
             title="@Strings.PrayerMaghrib">
        <settingConfig type="boolean" />
    </setting>
    <setting propertyKey="@Properties.notifyIsha"
             title="@Strings.PrayerIsha">
        <settingConfig type="boolean" />
    </setting>

    <!-- Timing preset dropdown -->
    <setting propertyKey="@Properties.notifyTiming"
             title="@Strings.NotifyBeforeTitle">
        <settingConfig type="list">
            <listEntry value="0">@Strings.NotifyAtTime</listEntry>
            <listEntry value="5">@Strings.Notify5Min</listEntry>
            <listEntry value="10">@Strings.Notify10Min</listEntry>
            <listEntry value="15">@Strings.Notify15Min</listEntry>
        </settingConfig>
    </setting>

</group>
```

**Reading settings in code:**
```monkey-c
var fajrEnabled = Properties.getValue("notifyFajr") as Boolean;
var timing = Properties.getValue("notifyTiming") as Number;
```

Boolean settings appear as ON/OFF toggles in the Garmin Connect phone app. List settings appear as dropdown selectors. The `<group>` element renders as a section header.

### 2.6 onSettingsChanged Integration

The existing `onSettingsChanged()` in `GarminMawaqitApp.mc` handles mosque slug changes. It must be extended to re-schedule the next notification when notification settings change:

```monkey-c
function onSettingsChanged() as Void {
    // ... existing mosque slug logic ...
    
    // Re-schedule notifications when settings change
    scheduleNextNotification();
    
    WatchUi.requestUpdate();
}
```

---

## 3. Integration with Existing Architecture

### 3.1 Memory Impact Assessment

| Addition | Glance (28KB) | Widget (64-128KB) | Background (28KB) |
|----------|--------------|-------------------|-------------------|
| Localized string loading | +276 bytes (table) + strings on demand | +276 bytes (table) + cached strings ~400 bytes | None (background has no UI strings) |
| Notification scheduling logic | None (not needed in glance) | +1KB for scheduling helper | +0.5KB for showNotification call |
| Attention vibration | None (glance should not vibrate) | +0.5KB for vibe pattern code | N/A (cannot vibrate in background) |
| Per-prayer settings reads | +0.2KB if reading in glance | +0.5KB | +0.5KB for scheduling |
| **Total additional** | **~500 bytes** | **~2.5KB** | **~1KB** |

All additions are well within memory budgets. The glance's 28KB budget remains the tightest constraint but 500 bytes of additional overhead is manageable.

### 3.2 Annotation Impact

| New Code | Required Annotations | Why |
|----------|---------------------|-----|
| Notification scheduling helper | `(:background)` if called from ServiceDelegate | Background needs to determine which prayer to notify for |
| Notification settings reader | `(:background)` if called from ServiceDelegate | Background needs notification prefs to decide whether to notify |
| Localized string loading | `(:glance)` for any helper used in GlanceView | Glance needs localized prayer labels and UI text |
| Attention vibration code | None (widget-only, no special annotation needed) | Widget is default context |
| showNotification call | `(:background)` annotation on ServiceDelegate | Already annotated; showNotification is called from onTemporalEvent |

**Key decision:** The notification scheduling logic must read prayer times from Storage AND notification preferences from Properties. Both `Storage.getValue()` and `Properties.getValue()` are available in background context. Place the scheduling logic in a `(:background)` annotated module function that both `onBackgroundData()` (foreground) and `onTemporalEvent()` (background) can call.

### 3.3 PrayerLogic Changes for Localization

Current `PrayerLogic` uses hardcoded `PRAYER_LABELS` constants. Two options:

**Option A (Recommended): Keep constants in PrayerLogic, localize at display time.**
PrayerLogic stays pure computation (no resource loading). Views call `WatchUi.loadResource()` to get localized labels when drawing. PrayerLogic continues to return index-based results that views map to localized strings.

**Option B: Load localized strings into PrayerLogic.**
Would require `WatchUi.loadResource()` calls inside `(:glance)` module code. Adds UI dependency to computation module. Violates current separation of concerns.

**Recommendation: Option A.** PrayerLogic returns prayer index (0-4). Each view maintains a localized labels array loaded from Rez.Strings. This keeps PrayerLogic annotation-safe and testable.

### 3.4 Background String Access for Notifications

`WatchUi.loadResource()` may NOT be available in the background ServiceDelegate context (the background has no UI context). Two approaches for notification text:

**Approach A (Recommended): Use plain string literals in background notifications.**
Prayer names are the same in English and French (Arabic-origin). The notification title can be the prayer name (a constant) and the time string (from Storage). No localized resource loading needed in background.

**Approach B: Pre-cache localized strings in Storage.**
On foreground launch, load localized strings and store them in `Storage.setValue()`. The background reads from Storage. Adds complexity and Storage overhead.

**Recommendation: Approach A.** Since prayer names are not localized and times are numeric, the background notification content does not need localized strings. Only the body text (e.g., "Prayer time has arrived") would differ, and this can be kept as a simple constant or omitted.

---

## 4. What NOT to Add

| Technology/Approach | Why Not |
|---------------------|---------|
| Push notifications via phone companion app | Requires a separate iOS/Android companion app. Massive scope increase for minimal gain over `showNotification()`. |
| Custom fonts for Arabic/French characters | System fonts handle Latin characters fine. Arabic prayer names are transliterated to Latin. Not needed. |
| `Attention.vibrate()` from background service | Impossible. The API only works in foreground. Will silently fail or crash. |
| `Attention.playTone()` as primary notification | Many devices lack tone generators. Vibration is more universal. Use tone only as optional enhancement alongside vibration in foreground. |
| Per-prayer timing offsets (different offset per prayer) | Adds 5 more settings for minimal UX benefit. A single global timing preset keeps settings simple. Can add later if users request it. |
| Watch-face-based notifications | Watch faces cannot use Attention module. The app is a widget -- this is the correct app type. |
| Locale-aware date/time formatting | Prayer times come from the API as "HH:MM" strings. The format is universal. No locale-specific formatting needed. |
| Dynamic language switching (in-app) | Connect IQ selects locale at build/load time from device settings. There is no runtime API to switch languages. Follow the device language. |
| `Background.requestApplicationWake()` for notifications | Inferior to `Notifications.showNotification()`. requestApplicationWake shows a dialog requiring user acceptance, behavior is inconsistent across devices (some hang), and it does not reliably vibrate. showNotification is the modern replacement. |

---

## 5. Alternatives Considered

| Category | Recommended | Alternative | Why Not Alternative |
|----------|-------------|-------------|---------------------|
| Localization mechanism | Resource-based `strings.xml` per locale | Hardcoded language arrays in code | Resource system is the standard CIQ approach. Auto-selects from device language. No code branching. |
| French language code | `fre` | `fra` | Garmin uses ISO 639-2/B codes. `fre` is the correct code; `fra` (ISO 639-2/T) is not in the supported list. |
| Background notification | `Notifications.showNotification()` | `Background.requestApplicationWake()` | showNotification is the modern API (SDK 8.1.0+). Shows a proper notification without requiring user acceptance dialog. requestApplicationWake is the old approach with inconsistent behavior. |
| Background notification | `Notifications.showNotification()` | `Attention.vibrate()` from background | Attention cannot be called from background. Hard platform limitation. |
| Notification trigger | Moment-based temporal event | Duration-based polling every 5 min | Moment scheduling is precise (fires at prayer time). Polling wastes battery and still has 5-min imprecision. |
| Notification UX | showNotification (background) + vibrate (foreground) | showNotification only | Adding Attention.vibrate in foreground provides guaranteed vibration for the edge case where showNotification does not vibrate on certain devices. |
| Notification settings | Per-prayer boolean toggles + global timing preset | Single "notifications on/off" toggle | Per-prayer control is the expected UX for prayer apps. Users commonly want Fajr alerts but not Dhuhr. |
| Settings UI | Phone app via `settings.xml` | On-watch settings menu | Settings change infrequently. Phone app provides better UX for toggles and lists. On-watch settings would consume widget memory budget. |
| PrayerLogic localization | Localize at display time (view layer) | Localize in PrayerLogic module | Keeps PrayerLogic as pure computation without UI dependencies. Views map indices to localized strings. |

---

## 6. manifest.xml Final State

```xml
<iq:permissions>
    <iq:uses-permission id="Background"/>
    <iq:uses-permission id="Communications"/>
    <iq:uses-permission id="PushNotification"/>
</iq:permissions>
<iq:languages>
    <iq:language>eng</iq:language>
    <iq:language>fre</iq:language>
</iq:languages>
```

**No new permissions needed.** `PushNotification` permission (required for `Toybox.Notifications`) is already declared. Background and Communications are already declared. Attention module does not require a permission.

---

## 7. Version Compatibility

| Component | Required Version | Current Project | Status |
|-----------|-----------------|-----------------|--------|
| Connect IQ SDK | 8.1.0+ (for Notifications API) | 8.4.0 | COMPATIBLE |
| API Level | 5.1.0+ (for Toybox.Notifications) | 6.0.0 minimum | COMPATIBLE |
| `PushNotification` permission | Required for Notifications | Already declared | NO CHANGE |
| `Background` permission | Required for temporal events | Already declared | NO CHANGE |
| Target devices (Fenix 8 43mm/47mm, Fenix 8 Pro 47mm) | System 8, API 6.0.0 | System 8 | COMPATIBLE |

No version changes or new SDK installations needed. The existing project configuration already supports all required APIs.

---

## Sources

- [Toybox.Notifications API](https://developer.garmin.com/connect-iq/api-docs/Toybox/Notifications.html) -- showNotification(), registerForNotificationMessages(), API level 5.1.0 (HIGH confidence)
- [Toybox.Attention API](https://developer.garmin.com/connect-iq/api-docs/Toybox/Attention.html) -- Vibrate, playTone, backlight methods and supported app types (HIGH confidence)
- [Toybox.Attention.VibeProfile](https://developer.garmin.com/connect-iq/api-docs/Toybox/Attention/VibeProfile.html) -- VibeProfile constructor (dutyCycle, duration) (HIGH confidence)
- [Toybox.Background API](https://developer.garmin.com/connect-iq/api-docs/Toybox/Background.html) -- registerForTemporalEvent (Moment/Duration), exit, data size limits (HIGH confidence)
- [Getting the User's Attention](https://developer.garmin.com/connect-iq/core-topics/getting-the-users-attention/) -- Attention module usage patterns (HIGH confidence)
- [Background Services](https://developer.garmin.com/connect-iq/core-topics/backgrounding/) -- Temporal event scheduling, 5-minute minimum (HIGH confidence)
- [Properties and App Settings](https://developer.garmin.com/connect-iq/core-topics/properties-and-app-settings/) -- Boolean/list settingConfig types, settings.xml structure (HIGH confidence)
- [Core Topics - Resources](https://developer.garmin.com/connect-iq/core-topics/resources/) -- Resource localization, language-qualified directories (HIGH confidence)
- [Jungle Reference](https://developer.garmin.com/connect-iq/reference-guides/jungle-reference/) -- lang qualifier in monkey.jungle (HIGH confidence)
- [Manifest and Permissions](https://developer.garmin.com/connect-iq/core-topics/manifest-and-permissions/) -- Language declarations, permission entries (HIGH confidence)
- [Localization UX Guidelines](https://developer.garmin.com/connect-iq/user-experience-guidelines/localization/) -- Localization best practices (HIGH confidence)
- [Connect IQ SDK 8.1.0 Release Notes](https://forums.garmin.com/developer/connect-iq/b/news-announcements/posts/connect-iq-sdk-8-1-0-now-available) -- Notifications API introduction (HIGH confidence)
- [Garmin Forums: New Notifications API](https://forums.garmin.com/developer/connect-iq/f/discussion/406092/new-notifications-api) -- Real-device behavior, background usage confirmed, vibration inconsistencies (MEDIUM confidence)
- [Garmin Forums: Background Vibration](https://forums.garmin.com/developer/connect-iq/f/discussion/357743/triggering-vibrations-in-the-background) -- Confirmed: Attention vibration only in foreground (HIGH confidence)
- [Garmin Forums: Background Alerts](https://forums.garmin.com/developer/connect-iq/f/discussion/8141/background-task-sending-alerts-notifications) -- requestApplicationWake limitations and inconsistencies (HIGH confidence)
- [Garmin Forums: String Resources in Jungle](https://forums.garmin.com/developer/connect-iq/f/discussion/250943/string-resource-files-specified-in-jungle) -- lang qualifier syntax, manifest language requirement (HIGH confidence)
- [Garmin Forums: loadResource() Overhead](https://forums.garmin.com/developer/connect-iq/f/discussion/5470/watchui-loadresource-overhead) -- 12 bytes per entry + 36 byte fixed cost (HIGH confidence)
- [Garmin Forums: Language Codes](https://forums.garmin.com/developer/connect-iq/f/discussion/290576/resources-strings-available-languages) -- ISO 639-2 codes, "fre" for French (HIGH confidence)
