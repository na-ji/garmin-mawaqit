# Architecture Patterns: Localization & Notifications Integration

**Domain:** Garmin Connect IQ Widget -- v1.1 Feature Integration
**Researched:** 2026-04-12
**Focus:** How multi-language support and prayer time notifications integrate with existing architecture

## Existing Architecture Summary

The v1.0 app has 7 source files following a module pattern:

| Component | Type | Annotation | Role |
|-----------|------|------------|------|
| `GarminMawaqitApp` | Class | `(:glance, :background)` | App lifecycle, onBackgroundData, onSettingsChanged |
| `PrayerLogic` | Module | `(:glance)` | Prayer state machine, countdown formatting, segment building |
| `PrayerDataStore` | Module | `(:glance)` | Storage read accessors for prayer times and iqama data |
| `MawaqitService` | Class (singleton) | none (widget only) | 6-step sequential HTTP fetch chain |
| `MawaqitServiceDelegate` | Class | `(:background)` | Lightweight single-request background fetch |
| `MawaqitGlanceView` | Class | `(:glance)` | 3-row Sunrise-inspired glance drawing |
| `MawaqitWidgetView` | Class | none (widget only) | Full 5-prayer schedule widget drawing |

**Current temporal event:** Registered once daily (86400s Duration) for background data refresh.
**Current manifest permissions:** Background, Communications, PushNotification.
**Current manifest languages:** eng only.
**Current hardcoded strings:** Prayer labels in `PrayerLogic.PRAYER_LABELS`, UI text in GlanceView/WidgetView `drawText()` calls, empty state messages.

---

## Feature 1: Multi-Language Support (French/English)

### Recommended Architecture: Resource-Based Localization

**Approach:** Use Connect IQ's built-in resource override system. Create language-specific resource folders that the compiler resolves automatically based on device language setting.

**Confidence:** HIGH -- this is the standard, documented Connect IQ localization mechanism.

### Folder Structure

```
resources/
  strings/
    strings.xml              <-- Base strings (English, the fallback)
  settings/
    settings.xml             <-- Setting UI definitions (references @Strings)
  properties.xml             <-- Property defaults (unchanged)
  drawables/
    ...

resources-fre/
  strings/
    strings.xml              <-- French string overrides
  settings/
    settings.xml             <-- French setting labels (optional, same structure)
```

The compiler automatically loads `resources-fre/strings/strings.xml` when the device language is French, falling back to `resources/strings/strings.xml` for any string IDs not overridden.

### Manifest Change

```xml
<iq:languages>
    <iq:language>eng</iq:language>
    <iq:language>fre</iq:language>
</iq:languages>
```

Without declaring `fre` in the manifest, the `resources-fre/` folder is silently ignored by the compiler.

### monkey.jungle Change

No change needed for basic localization. The build system automatically discovers `resources-fre/` folders when they follow the naming convention. The existing `base.resourcePath` line handles the base resources, and language-specific folders are resolved separately by the compiler.

### String Resources to Create

All hardcoded UI text must move to `Rez.Strings` resources:

| String ID | English (base) | French | Where Used |
|-----------|---------------|--------|------------|
| `AppName` | Mawaqit | Mawaqit | Already exists in strings.xml |
| `MosqueSettingTitle` | Mosque ID | Identifiant mosquee | Already exists in strings.xml |
| `MosqueSettingPrompt` | Enter your mosque slug from mawaqit.net | Entrez l'identifiant de votre mosquee depuis mawaqit.net | Already exists in strings.xml |
| `PrayerFajr` | Fajr | Fajr | PrayerLogic.PRAYER_LABELS, views |
| `PrayerDhuhr` | Dhuhr | Dhuhr | PrayerLogic.PRAYER_LABELS, views |
| `PrayerAsr` | Asr | Asr | PrayerLogic.PRAYER_LABELS, views |
| `PrayerMaghrib` | Maghrib | Maghrib | PrayerLogic.PRAYER_LABELS, views |
| `PrayerIsha` | Isha | Isha | PrayerLogic.PRAYER_LABELS, views |
| `CountdownIn` | in | dans | PrayerLogic.formatCountdown |
| `CountdownNow` | now | maintenant | PrayerLogic.formatCountdown |
| `EmptyNoMosque` | Set mosque in Connect app | Configurer la mosquee dans l'app Connect | GlanceView empty state |
| `EmptyNoData` | -- in -- | -- dans -- | GlanceView/WidgetView empty state |
| `SetMosqueIn` | Set mosque in | Configurer la mosquee | WidgetView empty state line 1 |
| `GarminConnectApp` | Garmin Connect app | dans l'app Garmin Connect | WidgetView empty state line 2 |
| `NotifSettingTitle` | Notifications | Notifications | New settings for v1.1 |
| `NotifTimingTitle` | Alert timing | Delai d'alerte | New settings for v1.1 |
| `NotifAtPrayerTime` | At prayer time | A l'heure de la priere | New settings for v1.1 |
| `Notif5MinBefore` | 5 min before | 5 min avant | New settings for v1.1 |
| `Notif10MinBefore` | 10 min before | 10 min avant | New settings for v1.1 |
| `Notif15MinBefore` | 15 min before | 15 min avant | New settings for v1.1 |

Note: Prayer names (Fajr, Dhuhr, Asr, Maghrib, Isha) are Arabic transliterations and are the same in English and French. They still go through `Rez.Strings` for correctness and future extensibility (e.g., Turkish or Malay where names differ).

### Component Changes Required

#### Modified: PrayerLogic Module

**Current:** Hardcoded `PRAYER_LABELS` array and `formatCountdown()` string concatenation.

**Problem:** `PrayerLogic` is annotated `(:glance)`. Loading resources via `WatchUi.loadResource(Rez.Strings.X)` in glance context has memory implications -- the first `loadResource()` call loads the entire string resource table into glance memory.

**Architecture decision:** Replace hardcoded string arrays with resource-loaded strings, but load them once and cache.

**Pattern:**
```monkey-c
(:glance)
module PrayerLogic {
    // Resource-loaded labels, populated once on first use
    var _labelsLoaded as Boolean = false;
    var _prayerLabels as Array<String> = ["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"];
    var _inStr as String = "in";
    var _nowStr as String = "now";

    function loadLabels() as Void {
        if (_labelsLoaded) { return; }
        _prayerLabels = [
            WatchUi.loadResource(Rez.Strings.PrayerFajr),
            WatchUi.loadResource(Rez.Strings.PrayerDhuhr),
            WatchUi.loadResource(Rez.Strings.PrayerAsr),
            WatchUi.loadResource(Rez.Strings.PrayerMaghrib),
            WatchUi.loadResource(Rez.Strings.PrayerIsha)
        ];
        _inStr = WatchUi.loadResource(Rez.Strings.CountdownIn);
        _nowStr = WatchUi.loadResource(Rez.Strings.CountdownNow);
        _labelsLoaded = true;
    }
}
```

**Memory cost:** The first `loadResource()` call loads the string resource table. With ~20 string resources, the overhead is approximately 36 + (12 * 20) = 276 bytes for the table, plus the actual string bytes. This fits within the 28KB glance budget.

**Confidence:** HIGH for the pattern; MEDIUM for exact memory numbers (based on forum reports, not official specs).

#### Modified: MawaqitGlanceView

**Current:** Hardcoded "Mawaqit", "Set mosque in Connect app", "-- in --".

**Change:** Replace hardcoded strings with `WatchUi.loadResource(Rez.Strings.X)` calls. Call `PrayerLogic.loadLabels()` in `onShow()` or at the top of `onUpdate()` (once).

#### Modified: MawaqitWidgetView

**Current:** Hardcoded "Mawaqit", "Set mosque in", "Garmin Connect app", "-- in --".

**Change:** Same pattern as GlanceView. Widget has 64-128KB budget, so string loading is not a concern.

#### Modified: resources/strings/strings.xml

**Current:** 3 strings (AppName, MosqueSettingTitle, MosqueSettingPrompt).

**Change:** Add all new string IDs listed above.

#### New: resources-fre/strings/strings.xml

French override file with all translatable strings.

#### Modified: manifest.xml

Add `<iq:language>fre</iq:language>`.

### Data Flow for Localization

```
Device language setting (French/English)
    |
    v
Compiler selects: resources/ (base) + resources-fre/ (if French)
    |
    v
Rez.Strings.X resolves to correct language string
    |
    v
WatchUi.loadResource(Rez.Strings.X) returns localized String
    |
    v
drawText() displays localized text
```

No runtime language detection needed. No Storage/Properties involvement. The system handles everything at compile/resource-load time.

---

## Feature 2: Prayer Time Notifications

### Architecture Decision: Notifications API via Background Temporal Events

**Approach:** Use `Toybox.Notifications.showNotification()` called from the background `ServiceDelegate.onTemporalEvent()`. Switch the temporal event registration from the current daily Duration to prayer-time-specific Moment scheduling.

**Why this approach:**
- `Attention.vibrate()` CANNOT be called from background context (confirmed: "You can only do vibrations in the foreground process")
- `Notifications.showNotification()` CAN be called from background ServiceDelegate (confirmed: SDK 8.1.0+ sample demonstrates this)
- `Background.requestApplicationWake()` is an alternative but requires user confirmation dialog, which is disruptive

**Why NOT Attention.vibrate():** The app is a widget. The user is NOT looking at the widget when prayer time arrives. Background services cannot access the Attention module. Notifications are the correct mechanism.

**Confidence:** HIGH for approach. The Notifications API (CIQ API Level 5.1.0+) is supported on all target devices (Fenix 7+, Venu 2+, Forerunner 265+, Fenix 8). The current minApiLevel of 6.0.0 satisfies the 5.1.0 requirement.

### Temporal Event Strategy Change

**Current:** Single `Duration(86400)` registration for daily data refresh.

**New:** Moment-based registration targeting the next prayer time (minus configured offset). After each notification fires, re-register for the next prayer time.

**Critical constraint:** Only ONE temporal event can be registered at a time. The new strategy must serve BOTH purposes: data refresh AND notification scheduling.

**Recommended pattern:**

```
App starts (getInitialView or onBackgroundData)
    |
    v
Calculate next notification Moment from cached prayer times
    |
    v
registerForTemporalEvent(nextPrayerMoment)  // Overwrites any existing registration
    |
    v
onTemporalEvent() fires at prayer time
    |
    +--> Show notification via Notifications.showNotification()
    +--> Optionally fetch fresh data (if stale)
    +--> Calculate NEXT prayer time Moment
    +--> registerForTemporalEvent(nextPrayerMoment)
    +--> Background.exit(data)
```

**Key advantage of Moment over Duration:** The 5-minute minimum interval restriction is cleared on app startup for Moment-based events. This means if two prayers are less than 5 minutes apart (unlikely but possible with Maghrib/Isha in some seasons), the system handles it gracefully by firing immediately if the Moment is in the past.

### New Components

#### New: NotificationScheduler Module

**Annotation:** `(:background)` -- must be loadable in background context.

**Responsibility:** Calculate the next notification Moment from prayer times and user preferences (which prayers are enabled, timing offset).

**Why a separate module:** Keeps notification scheduling logic isolated from prayer display logic. The background ServiceDelegate needs access to this but NOT to the full PrayerLogic module (which contains display formatting code that wastes background memory).

```
NotificationScheduler module:
  - getNextNotificationMoment(times, settings) -> Moment or null
  - shouldNotifyForPrayer(prayerIndex, settings) -> Boolean
  - getTimingOffset(settings) -> Number (seconds before prayer)
```

**Data inputs:**
- Prayer times from `Storage.getValue("todayTimes")` or calendar data
- Notification preferences from `Properties.getValue()` (per-prayer toggles, timing)

**Memory:** This module must be lean for the 28KB background budget. It should only parse "HH:MM" strings and do seconds arithmetic -- reuse the `parseTimeToSeconds()` pattern from PrayerLogic but as a separate copy (background code cannot access non-`:background` annotated code).

#### Modified: MawaqitServiceDelegate

**Current:** Single HTTP fetch in `onTemporalEvent()`, then `Background.exit(data)`.

**New responsibilities:**
1. Check if current temporal event is a notification trigger (prayer time arrived)
2. If yes: call `Notifications.showNotification()` with prayer name and time
3. Calculate and register next temporal event (next prayer time or next-day data refresh)
4. Optionally fetch fresh data if stale
5. `Background.exit(data)` with both prayer data and "last notified" metadata

**Expanded flow:**
```
onTemporalEvent()
    |
    v
Read prayer times from Storage (available in background via Properties/Storage)
Read notification settings from Properties
    |
    v
Is this a notification trigger? (current time ~= scheduled prayer time)
    |
    +-- YES --> Notifications.showNotification(prayerName, prayerTime, options)
    |           Calculate next notification Moment
    |           registerForTemporalEvent(nextMoment)
    |
    +-- NO  --> This is a data refresh trigger
    |           Fetch prayer data via HTTP
    |           On response: calculate next notification Moment
    |           registerForTemporalEvent(nextMoment)
    |
    v
Background.exit(data)
```

#### Modified: GarminMawaqitApp

**Changes to `getInitialView()`:**
- Replace the current `Duration(86400)` registration with Moment-based scheduling
- Calculate next notification time from cached data + settings
- Register temporal event for that Moment

**Changes to `onBackgroundData(data)`:**
- After storing new prayer data, recalculate next notification Moment
- Re-register temporal event if needed (e.g., new data changes prayer times)

**Changes to `onSettingsChanged()`:**
- When notification preferences change, recalculate next notification Moment
- Re-register temporal event accordingly

### New Properties (Settings)

#### properties.xml additions

```xml
<property id="notifEnabled" type="boolean">false</property>
<property id="notifFajr" type="boolean">true</property>
<property id="notifDhuhr" type="boolean">true</property>
<property id="notifAsr" type="boolean">true</property>
<property id="notifMaghrib" type="boolean">true</property>
<property id="notifIsha" type="boolean">true</property>
<property id="notifTiming" type="number">0</property>
```

`notifTiming` values: `0` = at prayer time, `5` = 5 min before, `10` = 10 min before, `15` = 15 min before.

#### settings.xml additions

```xml
<setting propertyKey="@Properties.notifEnabled"
         title="@Strings.NotifSettingTitle">
    <settingConfig type="boolean" />
</setting>

<setting propertyKey="@Properties.notifFajr"
         title="@Strings.PrayerFajr">
    <settingConfig type="boolean" />
</setting>
<!-- ... repeat for each prayer ... -->

<setting propertyKey="@Properties.notifTiming"
         title="@Strings.NotifTimingTitle">
    <settingConfig type="list">
        <listEntry value="0">@Strings.NotifAtPrayerTime</listEntry>
        <listEntry value="5">@Strings.Notif5MinBefore</listEntry>
        <listEntry value="10">@Strings.Notif10MinBefore</listEntry>
        <listEntry value="15">@Strings.Notif15MinBefore</listEntry>
    </settingConfig>
</setting>
```

#### manifest.xml additions

```xml
<iq:uses-permission id="Notifications"/>
```

Note: `PushNotification` permission is already declared. The `Notifications` permission is a separate, newer permission specifically for `Toybox.Notifications`. Both should be present.

### Notification Content

```
Title:    "Fajr"                    (prayer name, localized)
Subtitle: "05:30"                   (prayer time)
Body:     null                      (keep it minimal)
Icon:     Rez.Drawables.LauncherIcon (app icon)
Actions:  []                        (no actions needed -- informational only)
```

### Data Flow for Notifications

```
User configures settings via phone app
    |
    v
onSettingsChanged() reads Properties
    |
    v
NotificationScheduler.getNextNotificationMoment()
    |
    v
Background.registerForTemporalEvent(moment)
    |
    v
[time passes...]
    |
    v
onTemporalEvent() fires
    |
    v
Read Storage for prayer times + Properties for settings
    |
    v
Notifications.showNotification(title, subtitle, options)
    |
    v
NotificationScheduler.getNextNotificationMoment()
    |
    v
Background.registerForTemporalEvent(nextMoment)
    |
    v
Background.exit(metadata)
    |
    v
onBackgroundData() stores metadata, triggers view update
```

### Storage Keys (New)

| Key | Type | Purpose |
|-----|------|---------|
| `lastNotifPrayer` | String | Key of last prayer notified (e.g., "fajr") to prevent duplicate notifications |
| `lastNotifDate` | String | Date of last notification ("YYYY-MM-DD") |

---

## Integration Points Summary

### New Files

| File | Purpose | Annotation |
|------|---------|------------|
| `source/NotificationScheduler.mc` | Calculate next notification Moment, check per-prayer settings | `(:background)` |
| `resources-fre/strings/strings.xml` | French string overrides | N/A (resource) |

### Modified Files

| File | Changes | Impact |
|------|---------|--------|
| `source/PrayerLogic.mc` | Replace hardcoded PRAYER_LABELS with resource-loaded strings; add loadLabels(); update formatCountdown() to use localized "in"/"now" | **Medium** -- core logic unchanged, display strings change |
| `source/MawaqitGlanceView.mc` | Replace hardcoded strings with loadResource() calls; call PrayerLogic.loadLabels() | **Low** -- text changes only |
| `source/MawaqitWidgetView.mc` | Replace hardcoded strings with loadResource() calls | **Low** -- text changes only |
| `source/GarminMawaqitApp.mc` | Switch temporal event to Moment-based; add notification re-scheduling in onBackgroundData/onSettingsChanged | **High** -- temporal event strategy changes fundamentally |
| `source/MawaqitServiceDelegate.mc` | Add notification logic, next-event scheduling, dual-purpose temporal handling | **High** -- significant new responsibility |
| `source/PrayerDataStore.mc` | Add notification settings readers (optional, or read directly in NotificationScheduler) | **Low** |
| `resources/strings/strings.xml` | Add all new string IDs | **Medium** |
| `resources/properties.xml` | Add notification properties | **Low** |
| `resources/settings/settings.xml` | Add notification settings UI | **Low** |
| `manifest.xml` | Add fre language, Notifications permission | **Low** |
| `monkey.jungle` | No change needed (auto-discovery of resources-fre/) | **None** |

### Unchanged Files

| File | Why Unchanged |
|------|---------------|
| `source/MawaqitService.mc` | Foreground HTTP service; no localization or notification involvement |

---

## Component Boundaries

| Component | Responsibility | Communicates With |
|-----------|---------------|-------------------|
| PrayerLogic | Prayer state machine + localized label loading | PrayerDataStore (read times), Views (provide display data) |
| PrayerDataStore | Storage read accessors | Storage (read), Views + PrayerLogic (provide data) |
| NotificationScheduler | Next notification Moment calculation | Storage (read times), Properties (read settings) |
| MawaqitServiceDelegate | Background: send notifications + optional data fetch + re-schedule | NotificationScheduler, Storage, Properties, Notifications API, Background API |
| GarminMawaqitApp | Lifecycle: initial scheduling, setting changes, background data receipt | NotificationScheduler, Background API, Storage, Properties |
| MawaqitGlanceView | Glance display with localized text | PrayerLogic, PrayerDataStore, Rez.Strings |
| MawaqitWidgetView | Widget display with localized text | PrayerLogic, PrayerDataStore, Rez.Strings |
| MawaqitService | Foreground HTTP fetch chain (unchanged) | Communications API, Storage |

---

## Patterns to Follow

### Pattern 1: Lazy Resource Loading with Cache

**What:** Load string resources once, cache in module-level variables. Do not call `loadResource()` on every `onUpdate()`.

**When:** Any view that uses localized strings, especially the glance (28KB budget).

**Why:** The first `loadResource()` call loads the entire string resource table into memory. Subsequent calls for the same resource return from cache. But calling it repeatedly is wasteful CPU. Load once in `onShow()` or on first `onUpdate()`, store in variables.

**Example:**
```monkey-c
(:glance)
class MawaqitGlanceView extends WatchUi.GlanceView {
    var _noMosqueText as String = "";
    var _loaded as Boolean = false;

    function onUpdate(dc as Graphics.Dc) as Void {
        if (!_loaded) {
            _noMosqueText = WatchUi.loadResource(Rez.Strings.EmptyNoMosque);
            PrayerLogic.loadLabels();
            _loaded = true;
        }
        // ... use _noMosqueText in drawText() ...
    }
}
```

### Pattern 2: Moment-Based Temporal Event Chain

**What:** Register each temporal event as a specific Moment (not Duration). After each event fires, calculate and register the next Moment.

**When:** Notification scheduling where events need to fire at specific prayer times.

**Why:** Moment-based registration allows precise timing. The 5-minute minimum is cleared on app startup for Moment events. Only one event at a time, so the chain must self-perpetuate.

**Example:**
```monkey-c
(:background)
function onTemporalEvent() as Void {
    // ... handle current event (notify or fetch) ...

    // Schedule next event
    var nextMoment = NotificationScheduler.getNextNotificationMoment();
    if (nextMoment != null) {
        Background.registerForTemporalEvent(nextMoment);
    }

    Background.exit(data);
}
```

### Pattern 3: Dual-Purpose Temporal Event

**What:** Use the single temporal event slot for both notification triggers and data refresh, distinguishing by context.

**When:** The app needs both periodic data refresh and prayer-time notifications, but CIQ only allows one temporal event.

**Why:** Cannot register two temporal events. The ServiceDelegate must determine whether the event is a notification trigger (prayer time) or a data refresh trigger (daily), and act accordingly.

**Detection approach:** Compare current time against known prayer times. If within a small window (e.g., 2 minutes) of a prayer time for which notifications are enabled, treat as notification trigger. Otherwise, treat as data refresh or schedule-only event.

### Pattern 4: Shared Time Utilities Across Contexts

**What:** Extract `parseTimeToSeconds()` and `getCurrentSeconds()` into a minimal shared utility module annotated `(:glance, :background)`.

**When:** Background code needs to parse "HH:MM" strings but `PrayerLogic` is annotated `(:glance)` only.

**Why:** Background and glance code are loaded in different contexts. Code annotated only `(:glance)` is NOT available in the `(:background)` context. Rather than duplicating the function, extract shared utilities into a dual-annotated module with zero dependencies on context-specific code.

```monkey-c
(:glance, :background)
module TimeUtil {
    function parseTimeToSeconds(timeStr) as Number? { ... }
    function getCurrentSeconds() as Number { ... }
}
```

This keeps the shared surface area minimal while avoiding code duplication.

---

## Anti-Patterns to Avoid

### Anti-Pattern 1: Loading Resources in Background Context

**What:** Calling `WatchUi.loadResource(Rez.Strings.X)` from the background ServiceDelegate.

**Why bad:** The background context may not have access to WatchUi resources. String resources are meant for UI contexts. The background has a 28KB budget shared with glance code, and loading the string table wastes memory.

**Instead:** For notification text in background: use hardcoded strings or read from Storage/Properties. Since prayer names are the same in EN/FR (Arabic transliterations) and times are numbers, hardcoded names are acceptable in the notification. If fully localized notification text is ever needed, store localized strings in Storage during foreground execution for background to read.

### Anti-Pattern 2: Registering Duration for Notifications

**What:** Using `registerForTemporalEvent(new Duration(300))` to check every 5 minutes if a prayer time has arrived.

**Why bad:** Wastes battery by waking the background process 288 times per day. Only 5 of those wake-ups would produce a notification. The 5-minute polling interval also means notifications could arrive up to 5 minutes late.

**Instead:** Use Moment-based registration targeting the exact prayer time. Maximum 5-10 wake-ups per day.

### Anti-Pattern 3: Overloading PrayerLogic with Background Code

**What:** Annotating PrayerLogic as `(:glance, :background)` to share all logic with the ServiceDelegate.

**Why bad:** PrayerLogic contains display formatting (formatCountdown, buildSegments, getDimColor, SEGMENT_COLORS) that the background never needs. Loading all of this into the 28KB background budget wastes memory.

**Instead:** Extract only the time-parsing utilities into a shared module. Keep display logic in the glance-only PrayerLogic.

### Anti-Pattern 4: Forgetting Fallback Temporal Event

**What:** Only registering temporal events for notification times, with no fallback when all notifications are disabled or all prayers have passed.

**Why bad:** If no next notification is scheduled and no fallback is registered, the background service stops running entirely. Data never refreshes.

**Instead:** Always register a fallback temporal event. If no notifications are pending, register for a midnight or early-morning data refresh (e.g., 3:00 AM). This ensures prayer data stays fresh even when notifications are fully disabled.

---

## Memory Budget Analysis

### Glance Context (28KB shared with background)

| Item | Estimated Size | Notes |
|------|---------------|-------|
| Current glance code | ~8-12KB | Existing PrayerLogic + PrayerDataStore + GlanceView |
| String resource table | ~300 bytes | 36 + (12 * ~22 strings) = ~300 bytes overhead |
| Loaded string values | ~500 bytes | ~20 strings averaging 25 chars |
| Net impact of localization | ~800 bytes | Well within budget |

### Background Context (28KB shared with glance)

| Item | Estimated Size | Notes |
|------|---------------|-------|
| Current background code | ~3-5KB | MawaqitServiceDelegate + Properties/Storage |
| NotificationScheduler | ~2-3KB | Time parsing + Moment calculation |
| Notifications API call | ~1KB | showNotification overhead |
| Net impact of notifications | ~3-4KB | Within budget |

**Confidence:** MEDIUM -- memory estimates are approximations based on forum reports and code size. Actual usage must be tested in the simulator's memory profiler.

---

## Build Order (Dependency-Aware)

### Phase 1: Localization Foundation (no dependencies on notifications)

1. Create `resources-fre/strings/strings.xml` with French strings
2. Add all new string IDs to `resources/strings/strings.xml`
3. Update `manifest.xml` with `fre` language
4. Extract `TimeUtil` module from PrayerLogic (`parseTimeToSeconds`, `getCurrentSeconds`) annotated `(:glance, :background)`
5. Update PrayerLogic to use `TimeUtil` and add resource-loaded labels via `loadLabels()`
6. Update GlanceView to use `loadResource()` and call `loadLabels()`
7. Update WidgetView to use `loadResource()`

**Test gate:** App displays correctly in both English and French simulator settings. No hardcoded user-visible strings remain.

### Phase 2: Notification Settings (depends on localization for setting labels)

1. Add notification properties to `properties.xml`
2. Add notification settings to `settings.xml` (references `@Strings` from Phase 1)
3. Add notification setting strings to both language files

**Test gate:** Settings appear in Garmin Connect phone app simulator. Toggling settings changes Properties values.

### Phase 3: Notification Engine (depends on Phase 2 settings + TimeUtil from Phase 1)

1. Create `NotificationScheduler` module (`(:background)`)
2. Modify `MawaqitServiceDelegate` to handle dual-purpose temporal events
3. Modify `GarminMawaqitApp` to switch from Duration to Moment-based scheduling
4. Add `Notifications` permission to manifest
5. Implement notification content (title = prayer name, subtitle = time)

**Test gate:** Notifications appear in simulator when prayer time arrives. Temporal event chain self-perpetuates. Disabling per-prayer toggles skips that prayer's notification.

### Phase 4: Integration Testing & Edge Cases

1. Test overnight rollover (Isha -> next day Fajr notification)
2. Test mosque change (re-schedule notifications for new times)
3. Test no cached data (graceful degradation -- no notification)
4. Test all-notifications-disabled (reverts to daily Duration refresh for data)
5. Memory profiling in simulator for glance + background contexts

---

## Risk Areas

| Risk | Severity | Mitigation |
|------|----------|------------|
| Background 28KB budget exceeded with NotificationScheduler + existing code | High | Extract minimal TimeUtil; keep NotificationScheduler lean; profile in simulator |
| Temporal event chain breaks (no next event registered) | High | Always register a fallback event (e.g., midnight data refresh) even if no notifications pending |
| Notifications not appearing on real device (simulator behavior differs) | Medium | Test on physical Fenix 8; forum reports suggest simulator dismisses notifications instantly |
| String resource table memory in glance | Low | ~800 bytes for ~22 strings; well within budget |
| loadResource() unavailable in background for notification text | Medium | Use hardcoded prayer names in notification (they are the same across EN/FR) or pre-cache in Storage |

---

## Sources

- [Garmin Connect IQ Attention Module API](https://developer.garmin.com/connect-iq/api-docs/Toybox/Attention.html) -- Vibrate/tone API, foreground-only limitation
- [Garmin Connect IQ Notifications Module API](https://developer.garmin.com/connect-iq/api-docs/Toybox/Notifications.html) -- showNotification API, API Level 5.1.0+
- [Garmin Connect IQ Background Module API](https://developer.garmin.com/connect-iq/api-docs/Toybox/Background.html) -- Temporal events, Moment vs Duration, 5-minute minimum
- [New Notifications API Forum Discussion](https://forums.garmin.com/developer/connect-iq/f/discussion/406092/new-notifications-api) -- Background notification examples, SDK 8.1.0 sample
- [Triggering Vibrations in Background Forum](https://forums.garmin.com/developer/connect-iq/f/discussion/357743/triggering-vibrations-in-the-background) -- Confirms Attention cannot be used in background
- [Jungle Reference Guide](https://developer.garmin.com/connect-iq/reference-guides/jungle-reference/) -- Resource path and language override system
- [Build Configuration](https://developer.garmin.com/connect-iq/core-topics/build-configuration/) -- Language resource folder auto-discovery
- [Localization UX Guidelines](https://developer.garmin.com/connect-iq/user-experience-guidelines/localization/) -- Supported language codes
- [Properties and App Settings](https://developer.garmin.com/connect-iq/core-topics/properties-and-app-settings/) -- Boolean/list setting types
- [WatchUI.loadResource() Overhead Forum](https://forums.garmin.com/developer/connect-iq/f/discussion/5470/watchui-loadresource-overhead) -- String table memory cost: 36 + (12 * N) bytes
- [loadResource Memory Usage Forum](https://forums.garmin.com/developer/connect-iq/f/discussion/224423/loadresource-mem-usage) -- First call loads entire table
- [Localization Forum Discussion](https://forums.garmin.com/developer/connect-iq/f/discussion/4335/localize-application-for-watches) -- resources-fre folder structure
- [Manifest and Permissions](https://developer.garmin.com/connect-iq/core-topics/manifest-and-permissions/) -- Language declaration in manifest
