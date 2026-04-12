# Feature Research: Localization & Notifications for Garmin Mawaqit v1.1

**Domain:** Connect IQ widget localization (French/English) and prayer time notifications
**Researched:** 2026-04-12
**Confidence:** MEDIUM (localization HIGH, notifications MEDIUM -- Toybox.Notifications API is newer with device-dependent vibration behavior)

## Feature Landscape

### Table Stakes (Users Expect These)

Features users assume exist when "multi-language" and "notifications" are advertised.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| French prayer names in Glance/Widget | Primary localization ask; Mawaqit's user base is heavily French-speaking | LOW | Replace hardcoded `PRAYER_LABELS` array with `WatchUi.loadResource(Rez.Strings.*)` calls. Currently hardcoded in `PrayerLogic.mc` as `["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"]`. Prayer names are identical in French/English (Arabic-origin transliterations), but "in", "now", "Set mosque in Connect app" need translation. |
| French settings labels in phone app | Users see settings in their phone's language | LOW | Create `resources-fre/strings/strings.xml` with French translations of `MosqueSettingTitle`, `MosqueSettingPrompt`, and new notification setting labels. Settings.xml `title` and `prompt` already use `@Strings` references. |
| French UI text (countdown, empty states) | All user-visible text matches device language | MEDIUM | Countdown format strings ("Fajr in 2h 15m", "Fajr now"), empty states ("Set mosque in Connect app", "-- in --") are currently hardcoded in `PrayerLogic.formatCountdown()`, `MawaqitGlanceView.onUpdate()`, and `MawaqitWidgetView.onUpdate()`. Must extract to string resources or use conditional logic. |
| Automatic language detection | App uses watch/phone language without manual toggle | LOW | Connect IQ does this automatically. Resource folder `resources-fre` is selected when device language is French. No code needed -- just provide the folder and declare `fre` in `manifest.xml` `<iq:languages>`. |
| Per-prayer notification toggle | Users want to enable/disable alerts per prayer (Fajr ON, Dhuhr OFF, etc.) | MEDIUM | 5 boolean properties in `properties.xml`, 5 boolean settings in `settings.xml`. Read via `Properties.getValue("notifyFajr")` etc. Standard pattern in every major prayer app (Muslim Pro, Athan, Pillars). |
| Notification at prayer time | The core ask: alert when prayer time arrives | HIGH | Two complementary mechanisms: (1) `Notifications.showNotification()` from background service (SDK 8.1+, API level 5.1.0+) -- pushes system-style notification with title/body, MAY vibrate depending on device; (2) `Attention.vibrate()` in foreground when widget is active. Requires Moment-based background scheduling instead of current fixed Duration. |
| Notification timing (at prayer time) | Minimum viable: alert exactly when prayer time arrives | HIGH | Requires changing background scheduling from fixed 24h `Duration` to dynamic `Moment`-based scheduling. Background service calculates next prayer time, calls `registerForTemporalEvent(nextPrayerMoment)` to wake at the exact time. 5-minute minimum between events is not an issue since prayers are hours apart. |

### Differentiators (Competitive Advantage)

Features that set the product apart from existing prayer time apps on Garmin.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Pre-prayer notification (5/10/15 min before) | Lets users prepare for prayer; popular feature in Muslim Pro and Athan mobile apps | MEDIUM | Calculate `prayerMoment - offsetDuration` for the temporal event. Single list setting for offset (0/5/10/15 min). Same `registerForTemporalEvent(Moment)` mechanism. Must pick the SOONEST upcoming prayer minus offset as the next wake time. |
| Notifications API with actionable buttons | SDK 8.1+ `Notifications.showNotification()` supports action buttons (e.g., "Dismiss" / "View Schedule") that can wake the full widget | MEDIUM | Enhances the notification beyond a simple toast. Callback via `registerForNotificationMessages()` handles user taps. Differentiates from `requestApplicationWake()` which only shows plain text. |
| Reliable vibration when app is active | Competitor apps note widget background vibration is impossible; we can at least vibrate when widget is in foreground/glance | LOW | Call `Attention.vibrate()` in the timer callback when countdown hits zero. Works in widget view (foreground). Does NOT work from background or when app is not visible. Partial but honest value. |
| Global notification master toggle | Single switch to disable all prayer notifications | LOW | One boolean property. Check before any notification scheduling. Reduces user friction for "silent mode" during meetings etc. |
| Localized countdown format | "Asr dans 2h 15m" instead of "Asr in 2h 15m" for French | LOW | Localize "in" and "now" strings. Small touch that feels polished. |
| Arabic prayer names option | Many Mawaqit users prefer Arabic transliteration | LOW | Prayer names (Fajr, Dhuhr, Asr, Maghrib, Isha) are already Arabic transliterations. This is effectively free -- just document that names are already transliterated. No separate Arabic UI needed for v1.1. |

### Anti-Features (Commonly Requested, Often Problematic)

Features that seem good but create problems in this context.

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| Guaranteed background vibration for every prayer | Users expect watch to vibrate for every prayer like a phone alarm | `Attention.vibrate()` is foreground-only. Cannot be called from background service. `Notifications.showNotification()` MAY vibrate on some devices (confirmed on Epix2 Pro, NOT on FR955) but behavior is device-dependent and inconsistent. No way to guarantee vibration across all target devices. | Use `Notifications.showNotification()` for best-effort notification (some devices vibrate, all show visual notification). Document the limitation honestly. Add foreground `Attention.vibrate()` as supplementary alert when widget is visible. |
| Full Arabic language UI | Arabic-speaking users want full RTL Arabic UI | Connect IQ has no RTL text rendering support. Arabic (`ara`) IS in the supported language codes list for string resources, but Garmin's built-in fonts have limited Arabic glyph support and no RTL layout. The ISO 639-2 code `ara` is listed but practical rendering is unreliable. | Keep Arabic transliterated prayer names (already present). Full Arabic UI is not feasible on this platform. |
| On-watch language picker | Let user choose language independently of device language | Adds complexity for no gain. Connect IQ's resource system automatically selects language based on device settings. A manual override would require loading all language strings into memory simultaneously (wasteful in 28-64KB budget) and managing state. | Rely on automatic device language detection. User changes language in watch settings, app follows. |
| Adhan audio playback | Play the call to prayer audio on the watch | Watch speakers (if present) are tiny and low quality. Most watches have no speaker. Audio files consume significant storage. `Attention.playTone()` only supports predefined system tones or custom ToneProfile (frequency+duration), not audio file playback. | Use vibration patterns instead. Short distinctive pattern for prayer alert. |
| Custom vibration patterns per prayer | Different vibration pattern for each prayer so user knows which prayer without looking | `Attention.vibrate()` VibeProfile duty cycle differences are subtle and hard to distinguish on wrist. Forerunner devices ignore duty cycle entirely. Users will not reliably differentiate 5 patterns. | Single clear vibration pattern for all prayers. Prayer name shown in notification text. |
| Iqama notification (separate from prayer time) | Alert when iqama (congregation) starts, not just prayer time | Doubles the notification scheduling complexity. Iqama times are offsets, not absolute times. Would need to compute iqama moment = prayer moment + offset for each prayer. Only one temporal event can be registered at a time, complicating scheduling further. | Defer to v2. Prayer time notification is the primary ask. Iqama notification adds value but doubles scope. |
| Notification sound (tone) | Audible alert in addition to vibration | Most Garmin watches used for this app (Fenix, Forerunner, Venu) are worn during activities where sound is unwanted. `Attention.playTone()` is available in foreground but system tones are generic beeps, not adhan. Some devices lack tone generators entirely (vivoactive). | Offer as optional setting if requested post-launch. Vibration-first is the right default for a wrist device. |

## Feature Dependencies

```
[Localized string resources]
    |
    +--requires--> [Resource folder structure: resources-fre/strings/strings.xml]
    |                  |
    |                  +--requires--> [manifest.xml declares <iq:language>fre</iq:language>]
    |
    +--requires--> [Extract hardcoded strings from PrayerLogic, GlanceView, WidgetView]
    |
    +--requires--> [WatchUi.loadResource() calls replace hardcoded string literals]

[Per-prayer notification toggles]
    |
    +--requires--> [5 boolean properties in properties.xml]
    |
    +--requires--> [5 boolean settings in settings.xml]
    |
    +--requires--> [Localized setting labels (depends on localization)]

[Notification at prayer time]
    |
    +--requires--> [Per-prayer notification toggles]
    |
    +--requires--> [Background scheduling change: Duration -> Moment-based]
    |                  |
    |                  +--modifies--> [MawaqitServiceDelegate.mc]
    |                  +--modifies--> [GarminMawaqitApp.mc registerForTemporalEvent]
    |
    +--requires--> [Next prayer time calculation in background context]
    |                  |
    |                  +--requires--> [PrayerLogic available in (:background) annotation scope]
    |
    +--uses------> [Notifications.showNotification() from background (SDK 8.1+)]
    |                  |
    |                  +--requires--> [Notifications permission in manifest (already present as PushNotification)]
    |                  +--requires--> [minApiLevel >= 5.1.0 (already 6.0.0)]
    |
    +--fallback--> [requestApplicationWake() for older approach]

[Pre-prayer notification offset]
    |
    +--requires--> [Notification at prayer time (base mechanism)]
    |
    +--requires--> [Offset list setting in settings.xml (0/5/10/15 min)]
    |
    +--requires--> [Moment arithmetic: prayerMoment - offsetDuration]

[Foreground vibration on countdown zero]
    |
    +--requires--> [Per-prayer notification toggles]
    |
    +--enhances--> [Notification at prayer time]
    |
    +--requires--> [Attention module import + has check]

[Localization] --independent-of-- [Notifications]
    (can be developed and shipped separately)
```

### Dependency Notes

- **Localization is fully independent of notifications.** They share no code paths. Localization modifies string resources and display code. Notifications modify background scheduling and settings. They can be developed in parallel or sequenced in either order.
- **Notification toggles require localization to be in place** for the setting labels to appear correctly in both languages. If notification settings are added before localization, French users see English setting labels. Sequence: localization first, then notification settings.
- **Pre-prayer offset requires the base notification mechanism.** The offset is just a modifier on the Moment calculation. Build "at prayer time" first, then add offset.
- **Foreground vibration enhances but does not replace background notification.** Foreground vibration works reliably but only when the user is actively viewing the widget. `Notifications.showNotification()` (or fallback `requestApplicationWake()`) is the mechanism when the app is not active.
- **Background annotation scope expansion is required.** Currently `PrayerLogic` is likely only annotated `(:glance)` but NOT `(:background)`. The background service delegate needs prayer time calculations to determine the next notification time. Must add `(:background)` annotation to `PrayerLogic` module (or at minimum the functions it needs).
- **Notifications.showNotification() is the preferred approach over requestApplicationWake().** The Notifications API (SDK 8.1+, API level 5.1.0+) provides richer notification content (title, body, icon, action buttons) compared to `requestApplicationWake()` which only shows a plain text confirmation dialog. The app already has `PushNotification` permission and minApiLevel 6.0.0, so Notifications API is available. However, `has` checks should still be used since notification behavior varies by device.

## MVP Definition

### Launch With (v1.1 Milestone)

- [ ] **French string resources** -- Create `resources-fre/strings/strings.xml`, declare `fre` in manifest
- [ ] **Extract hardcoded strings to Rez.Strings** -- Replace all hardcoded English in views and PrayerLogic
- [ ] **Localized countdown and empty states** -- "dans" instead of "in", "Configurez la mosquee" instead of "Set mosque"
- [ ] **Localized settings labels** -- French labels for mosque setting and new notification settings
- [ ] **Per-prayer notification boolean settings** -- 5 toggles in settings.xml/properties.xml + master toggle
- [ ] **Global notification master toggle** -- Single on/off for all notifications
- [ ] **Background scheduling to Moment-based** -- `registerForTemporalEvent(Moment)` targeting next prayer time
- [ ] **Notifications.showNotification() from background** -- Push notification with prayer name and time when prayer time arrives
- [ ] **Foreground vibration at countdown zero** -- `Attention.vibrate()` when widget timer hits zero and notifications enabled

### Add After Validation (v1.x)

- [ ] **Pre-prayer offset setting (5/10/15 min before)** -- Trigger: users request "heads up" before prayer
- [ ] **Notification action buttons** -- Trigger: users want to tap notification to open full widget
- [ ] **Notification sound option** -- Trigger: users in quiet environments request audible alert
- [ ] **Additional languages (Turkish, German, etc.)** -- Trigger: user base demands beyond French

### Future Consideration (v2+)

- [ ] **Full Arabic RTL UI** -- Why defer: platform does not support RTL or Arabic fonts
- [ ] **Iqama notification** -- Why defer: doubles scheduling complexity, only one temporal event at a time
- [ ] **Adhan audio playback** -- Why defer: hardware limitations, storage cost
- [ ] **Smart notification scheduling (quiet hours)** -- Why defer: complexity vs value

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority | Phase |
|---------|------------|---------------------|----------|-------|
| French string resources + manifest | HIGH | LOW | P1 | Localization |
| Extract hardcoded strings to Rez.Strings | HIGH | MEDIUM | P1 | Localization |
| Localized countdown/empty states | HIGH | MEDIUM | P1 | Localization |
| Localized settings labels | HIGH | LOW | P1 | Localization |
| Per-prayer notification toggles | HIGH | LOW | P1 | Notifications |
| Global notification master toggle | MEDIUM | LOW | P1 | Notifications |
| Moment-based background scheduling | HIGH | HIGH | P1 | Notifications |
| Notifications.showNotification() from background | HIGH | MEDIUM | P1 | Notifications |
| Foreground vibration at prayer time | MEDIUM | LOW | P1 | Notifications |
| Pre-prayer offset (5/10/15 min) | MEDIUM | MEDIUM | P2 | Notifications |
| Notification action buttons | LOW | MEDIUM | P3 | Notifications |
| Notification sound option | LOW | LOW | P3 | Notifications |

**Priority key:**
- P1: Must have for v1.1 launch
- P2: Should have, add in same milestone if time permits
- P3: Nice to have, defer to v1.2+

## Competitor Feature Analysis

| Feature | Muslim Prayer Times Widget | Muslim Prayer Time Pro | Garmin Mawaqit (v1.1 plan) |
|---------|---------------------------|----------------------|---------------------------|
| Prayer time display | Yes, 5 prayers | Yes, 5 prayers + Sunrise | Yes, 5 prayers + iqama offsets |
| Glance view | Unknown (older app) | Yes | Yes, with progress bar |
| Language support | English only | Auto from device language | Auto from device language (eng + fre) |
| Notification/alert | "Cannot add alarm" (dev stated) | "Notification of prayers" (Watch App type) | Notifications.showNotification() from background + foreground vibration |
| Pre-prayer alert | No | Appears supported | P2 feature (offset setting) |
| Data source | Calculation-based (praytimes.org) | Calculation-based (15 methods) | Mawaqit API (mosque-specific, includes iqama) |
| Notification API | None (older app, pre-SDK 8.1) | requestApplicationWake (Watch App) | Notifications API (SDK 8.1+) -- newer, richer |

**Key insight:** Muslim Prayer Time Pro is a **Watch App** (not a Widget), which gives it different lifecycle behavior. Our app is a Widget with a Glance, which provides the carousel advantage. The new Notifications API (SDK 8.1+) partially closes the notification gap that Widgets historically had vs Watch Apps, since `showNotification()` can be called from background service and delivers visual notifications even when the widget is not active.

## Implementation Notes

### Localization Architecture

**Current state of hardcoded strings (must be extracted):**

1. `PrayerLogic.mc` line 22: `const PRAYER_LABELS = ["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"];`
2. `PrayerLogic.mc` `formatCountdown()`: `" in "`, `" now"`, `"h "`, `"m"`, `"s"`
3. `MawaqitGlanceView.mc`: `"Mawaqit"`, `"Set mosque in Connect app"`, `"-- in --"`, `"--:--"`
4. `MawaqitWidgetView.mc`: `"Mawaqit"`, `"Set mosque in"`, `"Garmin Connect app"`, `"-- in --"`

**Resource folder structure needed:**
```
resources/                          (default = English)
  strings/strings.xml               (English strings, already exists -- needs expansion)
resources-fre/                      (French overrides)
  strings/strings.xml               (French translations)
```

**Supported language codes (ISO 639-2) for future expansion:**
`ara`, `bul`, `ces`, `dan`, `deu`, `dut`, `eng`, `est`, `fin`, `fre`, `hrv`, `hun`, `ind`, `ita`, `jpn`, `kor`, `lav`, `lit`, `nob`, `pol`, `por`, `ron`, `rus`, `slo`, `slv`, `spa`, `swe`, `tha`, `tur`, `ukr`, `vie`, `zsm`, `zhs`, `zht`

**Memory concern for Glance:** `WatchUi.loadResource()` permanently loads the resource table into RAM once called. Each string resource costs ~12 bytes of table overhead plus the string data. With ~15-20 strings, overhead is ~240-360 bytes. In a 28KB glance budget this is acceptable but must be monitored. Alternative: use conditional hardcoded strings in glance only (check `System.getDeviceSettings().systemLanguage`), use `loadResource()` in widget only. This trades code duplication for memory safety.

**Prayer name convention:** Prayer names (Fajr, Dhuhr, Asr, Maghrib, Isha) are Arabic transliterations used universally in both English and French Islamic contexts. The Mawaqit website itself uses these same names in both English and French versions. Alternative names exist (Sobh for Fajr, Dhohr for Dhuhr) but are less standard. Use the standard transliterations as string resources so they CAN be changed per language if needed, but default both English and French to the same names.

**monkey.jungle change:** NOT needed. Connect IQ's build system automatically includes language-qualified resource folders (`resources-fre`) when the language is declared in manifest.xml.

**manifest.xml change:** Add French language declaration:
```xml
<iq:languages>
    <iq:language>eng</iq:language>
    <iq:language>fre</iq:language>
</iq:languages>
```

### Notification Architecture

**Two-tier notification strategy:**

1. **Background notification (primary):** `Notifications.showNotification()` called from `ServiceDelegate.onTemporalEvent()`. Displays visual notification with prayer name and time. MAY vibrate depending on device (confirmed working on Epix2 Pro, NOT on FR955). This is the mechanism that works even when the widget is not being viewed.

2. **Foreground vibration (supplementary):** `Attention.vibrate()` called from widget's timer callback when countdown reaches zero. This is the reliable vibration mechanism but only works when the user happens to be viewing the widget.

**Why Notifications.showNotification() over requestApplicationWake():**
- `showNotification()` displays a proper notification with title, subtitle, and body text
- Supports action buttons for user interaction
- Designed for background use (explicit in API docs and samples)
- Does not require user to confirm "launch app?" dialog (unlike `requestApplicationWake()`)
- App already has `PushNotification` permission and minApiLevel 6.0.0 (exceeds 5.1.0 requirement)
- Forum discussion from SDK 8.1 launch thread confirms background usage is supported

**Background scheduling change (current vs proposed):**

Current (`GarminMawaqitApp.mc`):
```
Background.registerForTemporalEvent(new Time.Duration(86400));  // Every 24 hours
```

Proposed:
```
// In onBackgroundData() or getInitialView():
// 1. Read prayer times from Storage
// 2. Find next prayer time with notifications enabled
// 3. Calculate Moment for that prayer (or prayer minus offset)
// 4. registerForTemporalEvent(nextPrayerMoment)
```

**Dual-purpose background service:** The background service currently only fetches data. It must now also:
1. Check if it was woken for a notification (prayer time arrived) vs data refresh
2. If notification: call `Notifications.showNotification(title, subtitle, options)` then `Background.exit(notificationData)`
3. If data refresh: fetch from API then `Background.exit(prayerData)`
4. Re-register for the next event (next prayer or next data refresh, whichever sooner)

**Distinguishing wake reasons:** Use time-based heuristic: if current time is within +/- 30 seconds of a prayer time that has notifications enabled, treat as notification wake. Otherwise treat as data refresh wake. Alternative: store the "expected wake reason" in Storage before registering the temporal event.

**Critical constraint -- single temporal event registration:** Connect IQ only allows ONE registered temporal event at a time. Strategy: always schedule the sooner of (next notification time, next data refresh time). In the background handler, decide what action to take and re-register for the next event.

**Foreground vibration pattern:**
```
// In widget timer callback, when countdown reaches zero and notification enabled:
if (Attention has :vibrate) {
    Attention.vibrate([
        new Attention.VibeProfile(100, 500),   // Strong 500ms
        new Attention.VibeProfile(0, 200),      // Pause 200ms
        new Attention.VibeProfile(100, 500),    // Strong 500ms
        new Attention.VibeProfile(0, 200),      // Pause 200ms
        new Attention.VibeProfile(100, 500)     // Strong 500ms
    ]);
}
```

### Settings Structure

**properties.xml additions:**
```xml
<property id="notificationsEnabled" type="boolean">false</property>
<property id="notifyFajr" type="boolean">true</property>
<property id="notifyDhuhr" type="boolean">true</property>
<property id="notifyAsr" type="boolean">true</property>
<property id="notifyMaghrib" type="boolean">true</property>
<property id="notifyIsha" type="boolean">true</property>
```

**settings.xml additions (per-prayer boolean toggles):**
```xml
<setting propertyKey="@Properties.notificationsEnabled"
         title="@Strings.NotificationsTitle">
    <settingConfig type="boolean" />
</setting>
<setting propertyKey="@Properties.notifyFajr"
         title="@Strings.NotifyFajrTitle">
    <settingConfig type="boolean" />
</setting>
<!-- repeat for Dhuhr, Asr, Maghrib, Isha -->
```

## Sources

### Localization
- [Garmin Localization UX Guidelines](https://developer.garmin.com/connect-iq/user-experience-guidelines/localization/) - Official localization patterns
- [Connect IQ Resources Documentation](https://developer.garmin.com/connect-iq/core-topics/resources/) - Resource folder structure and qualifiers
- [Garmin Forums: Available Languages](https://forums.garmin.com/developer/connect-iq/f/discussion/290576/resources-strings-available-languages) - Supported ISO 639-2 language codes (full list)
- [Garmin Forums: Localize Application](https://forums.garmin.com/developer/connect-iq/f/discussion/4335/localize-application-for-watches) - Localization folder structure and workflow
- [Garmin Forums: Settings Localization](https://forums.garmin.com/developer/connect-iq/f/discussion/297735/how-to-properly-localize-a-app-settings-title) - Localizing settings titles and manifest requirements

### Notifications
- [Toybox.Notifications API](https://developer.garmin.com/connect-iq/api-docs/Toybox/Notifications.html) - showNotification(), registerForNotificationMessages(), NotificationMessage -- API level 5.1.0+
- [Garmin Forums: New Notifications API](https://forums.garmin.com/developer/connect-iq/f/discussion/406092/new-notifications-api) - SDK 8.1.0 introduction, background usage confirmed, device-dependent vibration (Epix2 Pro yes, FR955 no)
- [Toybox.Attention API](https://developer.garmin.com/connect-iq/api-docs/Toybox/Attention.html) - Vibrate and playTone (foreground-only)
- [Toybox.Background API](https://developer.garmin.com/connect-iq/api-docs/Toybox/Background.html) - registerForTemporalEvent, requestApplicationWake, exit()
- [Garmin Forums: Triggering Vibrations in Background](https://forums.garmin.com/developer/connect-iq/f/discussion/357743/triggering-vibrations-in-the-background) - Confirms Attention.vibrate() is foreground-only
- [Connect IQ Core Topics: Notifications](https://developer.garmin.com/connect-iq/core-topics/notifications/) - Official notification documentation

### Settings
- [Properties and App Settings](https://developer.garmin.com/connect-iq/core-topics/properties-and-app-settings/) - Boolean and list setting types

### Competitor/Domain
- [Muslim Prayer Times Widget](https://apps.garmin.com/apps/4143d035-816f-4790-bb33-da31d8d0201b) - CIQ competitor, no notification support
- [Muslim Prayer Time Pro](https://apps.garmin.com/apps/984912bd-1413-4ef3-a062-e6bc52d335de) - CIQ competitor, Watch App type with notifications
- [Muslim Pro Help: Prayer Notifications](https://support.muslimpro.com/hc/en-us/articles/360029518492-How-to-set-prayer-notifications-or-adhan) - Mobile app notification UX patterns (per-prayer toggle, pre-prayer reminder)
- [Muslim Pro Help: Pre-Prayer Reminders](https://support.muslimpro.com/hc/en-us/articles/360029518552-How-to-receive-reminder-ahead-for-each-prayer-time) - Pre-prayer offset pattern
- [Pray Watch App](https://praywatch.app/help/articles/how-to-change-the-adhan-alert-sound/) - Notification type options (vibrate/silent/off per prayer)

---
*Feature research for: Garmin Mawaqit v1.1 Localization and Notifications*
*Researched: 2026-04-12*
