# Domain Pitfalls: v1.1 Localization & Notifications

**Domain:** Adding multi-language support and prayer notifications to existing Garmin Connect IQ widget
**Researched:** 2026-04-12
**Scope:** Pitfalls specific to adding localization (French/English) and prayer time notifications to an existing 1,890-line Monkey C app with 28KB glance budget, module pattern architecture, and single temporal event for daily data refresh.

---

## Critical Pitfalls

Mistakes that cause rewrites, break the existing working app, or are architecturally impossible to recover from.

---

### Pitfall 1: Single Temporal Event -- Notification Scheduling Destroys Data Refresh

**What goes wrong:** Connect IQ allows only ONE temporal event registration at a time. `registerForTemporalEvent()` overwrites any previous registration. The existing app registers a once-daily Duration(86400) for background data refresh. Adding notification scheduling (e.g., "vibrate at Fajr time") requires registering a Moment-based temporal event at the exact prayer time. This OVERWRITES the data refresh registration. Now the app vibrates once but never refreshes prayer data again until the user manually opens the widget.

**Why it happens:** Developers think they can schedule multiple background events -- one for data refresh, one per prayer notification. Connect IQ does not support this. There is no event queue, no multiple registrations, no priority system. One registration. Period.

**Consequences:** Either notifications work but data goes stale (no daily refresh), or data refreshes but notifications never fire. The v1.0 daily refresh pattern is incompatible with per-prayer notification timing out of the box.

**Prevention -- Unified Temporal Event Strategy:**
1. Switch from Duration-based to Moment-based temporal event registration entirely.
2. The single temporal event always points to the NEXT interesting time -- whichever comes first: the next prayer notification time OR the next data refresh time.
3. In `onTemporalEvent()`, determine WHY you woke up:
   - If it is prayer notification time: call `Background.requestApplicationWake()` with the prayer name message, then re-register for the next event.
   - If it is data refresh time: make the HTTP request, then in `onBackgroundData()` re-register for the next event.
4. Store a "schedule" in `Application.Storage`: an array of upcoming events with their type ("notify" or "refresh") and timestamps.
5. After every temporal event fires, compute and register the next one from the schedule.
6. Re-register in `onBackgroundData()` (foreground context) -- this is the safe place to call `registerForTemporalEvent()` after background work completes.

**Critical detail:** The 5-minute minimum interval between temporal events means you CANNOT schedule two prayers that are less than 5 minutes apart (unlikely for actual prayer times, but edge cases exist around Maghrib/Isha in summer). Using a Moment parameter clears the 5-minute restriction on widget startup, but NOT between consecutive background runs.

**Detection:** Data stops refreshing after notification feature is added. Or notifications never fire after a data refresh runs.

**Confidence:** HIGH -- single temporal event limitation is documented in official API docs and confirmed across multiple forum threads.

**Phase:** Must be the FIRST thing designed in the notifications phase. The entire notification architecture depends on solving this correctly.

---

### Pitfall 2: Attention.vibrate() Cannot Be Called From Background -- Notifications Are Foreground-Only

**What goes wrong:** Developers assume they can vibrate the watch when a temporal event fires at prayer time. They put `Attention.vibrate()` in `onTemporalEvent()` inside the `ServiceDelegate`. This crashes because the Attention module is NOT available in the background context. Garmin staff have explicitly confirmed: "You can only do vibrations in the foreground process."

**Why it happens:** The mental model is "background alarm goes off -> watch vibrates." But Connect IQ's background service is a sandboxed process that can only do HTTP requests and call `Background.exit()`. It cannot interact with the user in any way -- no vibration, no sound, no screen update.

**Consequences:** App crashes in background with an error about Attention module not being available. No notification reaches the user.

**The only viable notification approaches for a widget:**

1. **`Background.requestApplicationWake(message)`** -- Called from `onTemporalEvent()` BEFORE `Background.exit()`. Displays a system-level confirmation dialog: "Launch [App Name]?" with the message. If the user taps "Launch," the widget opens to foreground. Limitation: the user must actively dismiss or accept the dialog. There is NO automatic vibration -- the system dialog may or may not vibrate depending on the device's notification settings. This is the closest thing to a "push notification" for widgets.

2. **Foreground vibration via `onBackgroundData()`** -- The `onBackgroundData()` callback runs in the foreground process where `Attention.vibrate()` IS available. However, `onBackgroundData()` only fires when the app is already active (widget view is showing). If the user is on their watch face, `onBackgroundData()` does NOT fire until the next time they view the widget. This makes it useless for time-sensitive prayer notifications.

3. **Hybrid approach (recommended):** Use `requestApplicationWake()` for the notification dialog. When the user launches the app from the dialog, `getInitialView()` fires -- detect the "just woke for notification" state from Storage, and call `Attention.vibrate()` there to give haptic feedback.

**Consequences of wrong approach:** Silent notifications that never vibrate. Or notifications that only work when the widget is already on screen.

**Confidence:** HIGH -- confirmed by Garmin staff in forum threads and consistent with API documentation showing Attention module supported in "Glance, Watch App, Widget" but NOT "Background."

**Phase:** Must be understood before designing notification UX. Set user expectations: notifications will show a dialog, not a silent vibration in the background.

---

### Pitfall 3: loadResource(Rez.Strings.*) Permanently Loads ALL Resource Tables Into Glance Memory

**What goes wrong:** The first call to `WatchUi.loadResource()` loads the ENTIRE string resource table into application RAM -- not just the requested string, but the table metadata for ALL strings including settings strings. Each resource table entry consumes ~12 bytes. The current app avoids `loadResource()` entirely in the Glance (hardcoded strings like "Fajr", "Dhuhr", etc.). Switching to localized `Rez.Strings` resources for prayer names forces the Glance to pay the resource table tax, eating into the 28KB budget.

**Why it happens:** Developers assume loading one string from resources costs only the memory for that string. In reality, the first `loadResource()` call triggers loading the full resource table structure. With the v1.1 settings additions (5 per-prayer toggles, notification timing, language preference), the settings strings alone could add 15-20+ resource table entries.

**Memory math for the Glance:**
- Current approach (hardcoded strings): 0 bytes for resource tables
- With Rez.Strings: 36 bytes base + (12 bytes x N entries) where N = total string resources across ALL contexts
- If v1.1 adds 25 string resources (prayer names + settings labels + notification strings): 36 + 300 = 336 bytes minimum
- Plus the actual string content loaded into memory when accessed
- In a 28KB budget where the current app may already be at 20-24KB, this can push over the limit

**Prevention:**
- **Keep hardcoded strings in the Glance view.** Prayer names ("Fajr", "Dhuhr", etc.) are the same in both English and French -- they are Arabic transliterations, not translated words. The Glance does not need localized strings.
- **Only use Rez.Strings in the Widget view** (64-128KB budget) where the resource table overhead is negligible.
- **Localize settings strings** (they load in the phone app context, not on the watch) -- these are free from the watch memory perspective.
- If the Glance MUST display a translated string (e.g., "in" vs "dans" for the countdown format), use a single conditional based on `System.getDeviceSettings().systemLanguage` with hardcoded alternatives, NOT Rez.Strings.
- Measure Glance peak memory before and after any resource loading changes.

**Detection:** Glance crashes with OutOfMemoryError after adding localization. Widget works fine (more memory). Simulator may not catch it.

**Confidence:** HIGH -- resource table memory cost is documented in Garmin forums by Garmin engineers, confirmed with specific byte counts.

**Phase:** Must be addressed in the localization phase. The rule is simple: NO `loadResource()` in Glance-annotated code.

---

### Pitfall 4: Garmin Express Settings Fallback Bug -- Missing Translations Show Blank Settings

**What goes wrong:** When an app declares support for French (`<iq:language>fre</iq:language>` in manifest.xml) but does NOT translate every single settings string into French, Garmin Express fails to fall back to English. Instead, it shows blank text or raw resource IDs for untranslated settings. This is a KNOWN BUG that has persisted since at least 2021 and remains unresolved as of 2025.

**Why it happens:** Garmin Connect Mobile correctly implements resource fallback (missing French string falls back to English base). Garmin Express (desktop) does NOT. The developer tests on their phone and sees correct fallback. Users who configure settings via Garmin Express on desktop see blank fields.

**Consequences:** Users on Garmin Express cannot configure their mosque or notification settings because labels are blank. The app appears broken on desktop.

**Prevention:**
- **Duplicate EVERY string in EVERY declared language.** If you declare `fre` and `eng`, both `resources/strings/strings.xml` and `resources-fre/strings/strings.xml` must contain identical sets of string IDs with appropriate translations.
- This includes settings titles, prompts, list entry labels, and any other string referenced in `settings.xml`.
- Create a checklist during development: for every string ID added to base `strings.xml`, immediately add the French translation to `resources-fre/strings/strings.xml`.
- Test settings rendering in BOTH Garmin Connect Mobile AND Garmin Express before release.

**Detection:** Settings display correctly on phone but show blank/missing text on Garmin Express desktop.

**Confidence:** HIGH -- known bug, confirmed in Garmin bug reports forum with multiple developers reproducing it. Still not fixed.

**Phase:** Must be enforced from the start of localization work. Missing even one string causes Garmin Express to break.

---

## Moderate Pitfalls

---

### Pitfall 5: Settings Complexity Explosion With Per-Prayer Toggles

**What goes wrong:** The v1.1 requirements call for per-prayer notification toggles (5 prayers x on/off) plus notification timing (at time, 5min before, 10min before, 15min before). This adds 5 boolean properties + 1 list property = 6 new settings minimum to the existing 1 setting (mosque slug). If per-prayer timing is desired (different advance warning per prayer), that is 5 list properties instead of 1 = 10 new settings. Each setting needs: a property in `properties.xml`, a setting entry in `settings.xml`, a title string in `strings.xml`, and a French translation in `resources-fre/strings/strings.xml`.

**Why it happens:** Feature creep. "Users want fine-grained control" leads to exponential settings growth.

**Consequences:**
- Settings UI on phone becomes a long scrolling list that overwhelms users
- Every property must be read in the background service to determine which prayer to notify for -- increasing background code complexity and memory
- More strings = more resource table entries = more memory pressure (see Pitfall 3)
- Each property read via `Properties.getValue()` is a separate call with type casting
- Bugs multiply: one wrong property key string, one missing default value, one untranslated label

**Prevention:**
- **Start minimal:** One global "Enable notifications" boolean + one global "Notification timing" list (at time / 5min / 10min / 15min before). This is 2 new settings, not 10.
- Defer per-prayer toggles to v1.2 only if users request them.
- If per-prayer toggles ARE needed, consider a single comma-separated property string ("fajr,dhuhr,isha") rather than 5 separate booleans. This reduces settings UI complexity and property count.
- Use `settings.xml` group elements to visually organize settings on the phone app (if supported by the device's Garmin Connect version).
- Read all notification settings once in `getInitialView()` and cache in a single Storage dictionary. Do not read Properties in the background service -- pass the computed schedule via Storage instead.

**Detection:** Settings screen becomes confusing. Bug reports about "wrong prayer notifying." Localization effort doubles per setting added.

**Confidence:** MEDIUM -- the complexity is predictable, but the exact UX impact depends on implementation choices.

**Phase:** Must be decided during feature design, BEFORE writing any settings or notification code.

---

### Pitfall 6: Hardcoded Prayer Names vs Localized Labels -- Two Different Concerns

**What goes wrong:** The current codebase has prayer names hardcoded in two places:
1. `PrayerLogic.PRAYER_LABELS = ["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"]` -- used for display
2. `PrayerLogic.PRAYER_KEYS = ["fajr", "dohr", "asr", "maghreb", "icha"]` -- used as API/storage dictionary keys

Developers conflate these and try to localize the KEYS (breaking API compatibility) or forget to localize the LABELS (showing English names to French users). Or they localize labels but break the constant array pattern, forcing dynamic allocation.

**Why it happens:** Prayer names in Islamic context are Arabic transliterations used universally. "Fajr" is "Fajr" in both English and French. But UI text around them ("in", "now", "Set mosque in Connect app") DOES need translation. The boundary between "transliterate" and "translate" is not obvious.

**Prevention:**
- **PRAYER_KEYS are NEVER localized.** They are internal identifiers matching the API response. Changing them breaks data parsing.
- **PRAYER_LABELS stay hardcoded in the Glance** (28KB budget, Arabic transliterations are universal). "Fajr", "Dhuhr", "Asr", "Maghrib", "Isha" need no French translation.
- **UI chrome text IS localized:** "in" -> "dans", "now" -> "maintenant", "Set mosque in Connect app" -> "Configurez la mosquee dans Connect". These go in Rez.Strings for the Widget view, or use conditional hardcoding for the Glance.
- **Settings labels ARE localized:** "Enable Fajr notification" -> "Activer notification Fajr". These are phone-side strings that do not affect watch memory.
- Document explicitly which strings need translation and which do not. Create a translation matrix before starting.

**Detection:** API parsing breaks after "localization" (keys were changed). Or French users see English UI chrome alongside Arabic prayer names.

**Confidence:** HIGH -- this is directly visible in the current codebase.

**Phase:** Must be decided at the start of localization work with a clear string inventory.

---

### Pitfall 7: monkey.jungle Resource Path Configuration Breaks Existing Resources

**What goes wrong:** Adding language-specific resource folders requires modifying `monkey.jungle` to include them in the build. The current `monkey.jungle` is minimal:
```
base.resourcePath = resources;resources/drawables;resources/settings;resources/strings
```

Adding `resources-fre` naively can cause the resource compiler to lose track of existing resources. Known issues include:
- Language-qualified resource folders overriding device-qualified resource folders
- Font settings applicable for a device being lost when a language folder is added
- Resource paths being resolved incorrectly with relative vs absolute paths

**Why it happens:** The Connect IQ resource compiler uses a qualifier priority system. Language qualifiers, device qualifiers, and shape qualifiers can interact in unexpected ways. Documentation on the interaction is sparse. Developers add a `resources-fre` folder and discover their existing drawables or fonts break.

**Prevention:**
- **Use the automatic resource resolution system.** Create `resources-fre/strings/strings.xml` alongside the existing `resources/strings/strings.xml`. The resource compiler automatically picks the language-appropriate strings if the folder follows the naming convention `resources-{lang}`.
- Do NOT manually add `resources-fre` to the `base.resourcePath` in `monkey.jungle` unless automatic resolution fails. The lang qualifier on folder names is the intended mechanism.
- Test BOTH languages in the simulator (change simulator language via Settings) after adding the French resources.
- Verify that existing drawables (launcher icon) and properties still load correctly after adding language resources.
- Keep non-string resources (drawables, properties) in the base `resources/` folder only. Only strings go in `resources-fre/`.

**Detection:** Build errors about missing resources. Existing icon or settings break after adding French strings. French strings show English text or vice versa.

**Confidence:** MEDIUM -- automatic resolution works for simple cases but the interaction with device qualifiers is poorly documented.

**Phase:** Must be validated early in the localization phase with a test build.

---

### Pitfall 8: requestApplicationWake() Dialog UX is Poor and Uncontrollable

**What goes wrong:** `Background.requestApplicationWake(message)` is the only way to "notify" a user from a widget background service. But the UX is not a clean notification -- it is a CONFIRMATION DIALOG that asks "Launch [App Name]?" with the developer's message. The user must tap to open the app. Key issues:
- No vibration is guaranteed (depends on device notification settings)
- The dialog may not appear if the user has DND mode enabled
- On some devices, tapping "Launch" opens the watch face instead of the widget (known bug)
- The message string is limited and cannot be formatted (no bold, no large text)
- The dialog disappears if the user does not interact with it within a timeout

**Why it happens:** Connect IQ does not have a proper push notification API for widgets. `requestApplicationWake` was designed as a "hey, open me" mechanism, not a notification system. Developers expect iOS/Android notification quality and get a basic dialog.

**Prevention:**
- **Set clear user expectations.** Document that notifications are "soft alerts" -- a dialog will appear that must be acknowledged. This is not a standard phone notification.
- **Combine with `Background.exit()` data:** Store the prayer name and time in the data passed to `Background.exit()`. In `onBackgroundData()`, if the app happens to be in the foreground, call `Attention.vibrate()` for immediate haptic feedback. This covers the case where the user is already looking at the widget.
- **Keep the wake message concise and useful:** "Fajr 04:30" is better than "It's time for Fajr prayer at 04:30 AM."
- **Test DND mode behavior** on target devices -- some devices suppress requestApplicationWake dialogs entirely in DND.
- Consider adding a note in the app's Connect IQ Store description about notification behavior so users know what to expect.

**Detection:** Users report "notifications don't work" when they mean "I didn't see/hear anything." The dialog appeared but they missed it.

**Confidence:** HIGH -- requestApplicationWake behavior is well-documented and its limitations are widely discussed in forums.

**Phase:** Must be understood during UX design for notifications. Do not promise "alerts" if the platform only supports "dialogs."

---

### Pitfall 9: Temporal Event Re-Registration Race Condition After Background Exit

**What goes wrong:** After a background temporal event fires and `onTemporalEvent()` completes with `Background.exit(data)`, the foreground receives data in `onBackgroundData()`. The developer wants to register the NEXT temporal event from `onBackgroundData()`. But there is a race: if the app is not currently in the foreground (widget not visible), `onBackgroundData()` may be deferred or batched. Meanwhile, no temporal event is registered, so no future events fire. The notification schedule dies.

**Why it happens:** The developer assumes `onBackgroundData()` fires immediately and synchronously after `Background.exit()`. In practice, the foreground callback timing depends on whether the app is visible, whether the system is busy, and device-specific behavior.

**Prevention:**
- **Register the next temporal event BEFORE calling `Background.exit()` from `onTemporalEvent()`.** The `registerForTemporalEvent()` call works from the background service context. This ensures the next event is always scheduled regardless of foreground state.
- Compute the next event Moment in the background service using stored prayer times from Storage. The background service CAN read from `Application.Storage`.
- Use `onBackgroundData()` only for UI updates and optional vibration -- NOT for critical scheduling decisions.
- Store the "next event plan" in Storage so both background and foreground can read it. If the foreground needs to override (e.g., user changed notification settings), it can re-register in `onSettingsChanged()`.

**Detection:** Notifications work once then stop. Or the schedule becomes progressively wrong after the first event.

**Confidence:** MEDIUM -- the exact timing of `onBackgroundData()` depends on device and firmware version. The "register before exit" approach is a documented safe pattern.

**Phase:** Must be solved in notification scheduling implementation.

---

### Pitfall 10: manifest.xml Language Declaration Without Complete Resources Breaks Build

**What goes wrong:** Adding `<iq:language>fre</iq:language>` to `manifest.xml` tells the resource compiler to expect French resources. If the `resources-fre/strings/strings.xml` file is missing or incomplete, the build may succeed but the app will show resource IDs instead of text when the device language is French. Combined with the Garmin Express fallback bug (Pitfall 4), this creates invisible failures.

**Why it happens:** The manifest language declaration is a commitment. It tells the system "this app supports French." If the actual resources do not back up that claim, behavior is undefined.

**Prevention:**
- Add the `<iq:language>fre</iq:language>` declaration AND create `resources-fre/strings/strings.xml` with ALL string translations in the SAME commit. Never one without the other.
- Create a build verification step: after adding French support, build the app and switch the simulator to French. Verify every screen and every settings page shows correct text.
- Use the existing `resources/strings/strings.xml` as the English base. Copy it to `resources-fre/strings/strings.xml` and translate the values. Same IDs, different values.

**Detection:** French users see `"MosqueSettingTitle"` literal text instead of the translated label.

**Confidence:** HIGH -- standard resource compiler behavior, documented.

**Phase:** First step of localization implementation. Atomic commit: manifest + resources together.

---

## Minor Pitfalls

---

### Pitfall 11: PrayerLogic.formatCountdown() Has Hardcoded English Strings

**What goes wrong:** The current `formatCountdown()` function builds strings like `"Fajr in 2h 15m"` and `"Asr now"` using hardcoded English prepositions ("in", "now"). Localizing these requires changing the function signature or string building logic.

**Prevention:**
- For the **Widget view** (has memory for Rez.Strings): load localized format strings and use them in a new `formatCountdownLocalized()` variant.
- For the **Glance view** (no Rez.Strings): use `System.getDeviceSettings().systemLanguage` to check if the language is French. French uses `Toybox.WatchUi.LANG_FRE` constant (value 7). Hardcode the two variants: `"in"/"now"` for English, `"dans"/"maintenant"` for French. Only 4 extra string constants, no resource loading.
- PRAYER_LABELS ("Fajr", "Dhuhr", etc.) do NOT change between English and French -- they are universal Arabic transliterations.
- Keep the existing `formatCountdown()` as-is for backward compatibility. Add a new localization-aware wrapper.

**Detection:** French users see "Asr in 2h 15m" instead of "Asr dans 2h 15m."

**Confidence:** HIGH -- directly visible in the codebase.

**Phase:** Localization phase, after the resource structure is set up.

---

### Pitfall 12: Attention Module Requires has-Check and Permission

**What goes wrong:** Not all Garmin devices support all Attention module features. Calling `Attention.vibrate()` without checking `Attention has :vibrate` crashes on devices without vibration hardware. Additionally, some Forerunner devices do not support vibration duty cycle patterns -- vibrations always run at a fixed strength.

**Prevention:**
- Always guard with `if (Attention has :vibrate)` before calling `Attention.vibrate()`.
- Use a simple vibration profile: one `VibeProfile(100, 500)` (100% duty cycle, 500ms duration). Do not rely on complex multi-step patterns that may not work on all devices.
- Consider also checking `Attention has :playTone` for an audible alert as a complement to vibration.
- The manifest already declares `PushNotification` permission. Verify that no additional permission is needed for Attention module (it should work with existing permissions for widget apps).

**Detection:** Crash on specific device models when vibration is triggered. Silent failure on devices that lack vibration hardware.

**Confidence:** HIGH -- documented in Attention API docs with explicit recommendation for has-checks.

**Phase:** Notification implementation phase.

---

### Pitfall 13: Background Service Memory Pressure From Notification Logic

**What goes wrong:** The background service (`:background` annotated code) shares the same 28KB budget with the Glance. Adding notification scheduling logic to the background service -- computing next prayer time, comparing against notification settings, deciding whether to call `requestApplicationWake()` -- increases the code and data loaded into this constrained context.

**Why it happens:** The existing `MawaqitServiceDelegate` is lean (53 lines, one HTTP request). Adding notification logic requires: reading prayer times from Storage, reading notification preferences from Properties, computing time comparisons, conditional wake requests. Each line of code and each variable consumes memory in the 28KB space.

**Prevention:**
- Keep the background service delegate as lean as possible. Pre-compute the "next notification Moment" in the FOREGROUND (in `onBackgroundData()` or `getInitialView()`) and store it in Storage.
- The background service only needs to: (1) read the pre-computed next event from Storage, (2) compare against current time, (3) call `requestApplicationWake()` if it matches, (4) optionally make HTTP request if it is a refresh event, (5) `Background.exit()`.
- Do NOT put prayer time parsing logic in background-annotated code. The foreground computes, the background executes.
- Monitor background memory separately from Glance memory. They share the same pool.

**Detection:** Glance crashes with OutOfMemoryError after notification code is added (the background code increased the shared memory footprint).

**Confidence:** HIGH -- memory sharing between background and glance is documented and was a key architectural decision in v1.0.

**Phase:** Notification implementation phase. Lean background delegate is a hard requirement.

---

### Pitfall 14: System Language Detection API Nuances

**What goes wrong:** `System.getDeviceSettings().systemLanguage` returns a numeric constant, not a string. The mapping is: `WatchUi.LANG_ENG = 2`, `WatchUi.LANG_FRE = 7`. Developers may check for the wrong value, use string comparison, or forget that the user's watch language may be NEITHER English nor French (e.g., Arabic, German). The app must handle unsupported languages gracefully.

**Prevention:**
- Check for French explicitly: `if (System.getDeviceSettings().systemLanguage == WatchUi.LANG_FRE)`. Fall back to English for ALL other languages.
- Do NOT try to enumerate every possible language. The fallback is always English.
- The Rez.Strings resource system handles this automatically for the Widget (French folder exists, everything else falls back to base). But for Glance hardcoded strings, you must code the conditional manually.
- Test with the simulator set to a THIRD language (e.g., German) to verify fallback works.

**Detection:** App shows wrong language for unexpected system language settings. Or crashes on numeric comparison error.

**Confidence:** HIGH -- API is documented, but the numeric constant format surprises developers expecting string codes.

**Phase:** Early localization phase. Simple but must be done correctly.

---

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Severity | Mitigation |
|-------------|---------------|----------|------------|
| Notification architecture design | Pitfall 1: Single temporal event conflict | CRITICAL | Unified event scheduler: always point to next interesting Moment |
| Notification architecture design | Pitfall 2: No background vibration | CRITICAL | Use requestApplicationWake + foreground vibration hybrid |
| Notification scheduling | Pitfall 9: Re-registration race condition | MODERATE | Register next event in background BEFORE exit, not in onBackgroundData |
| Notification UX | Pitfall 8: Poor dialog UX | MODERATE | Set expectations, keep messages concise, test DND mode |
| Notification settings | Pitfall 5: Settings explosion | MODERATE | Start with 2 global settings, defer per-prayer toggles |
| Localization resource setup | Pitfall 4: Garmin Express fallback bug | CRITICAL | Duplicate ALL strings in ALL declared languages |
| Localization resource setup | Pitfall 7: monkey.jungle resource paths | MODERATE | Use automatic lang-qualified folder resolution |
| Localization resource setup | Pitfall 10: Manifest without resources | MODERATE | Atomic commit: manifest + resources together |
| Localization Glance view | Pitfall 3: loadResource memory in Glance | CRITICAL | NO Rez.Strings in Glance, use conditional hardcoded strings |
| Localization Widget view | Pitfall 6: Hardcoded vs localized labels | MODERATE | Prayer names stay hardcoded, UI chrome gets localized |
| Localization countdown format | Pitfall 11: Hardcoded English strings | MINOR | Conditional "in"/"dans" based on systemLanguage |
| Notification implementation | Pitfall 12: Attention has-check | MINOR | Guard all Attention calls with has-check |
| Notification implementation | Pitfall 13: Background memory pressure | MODERATE | Pre-compute in foreground, lean background delegate |
| Localization testing | Pitfall 14: System language detection | MINOR | Check for FRE, fall back to ENG for everything else |

---

## Integration Risk Summary

The two features (localization and notifications) have an important interaction: localization adds string resources that increase memory pressure (Pitfall 3), while notifications add background logic that increases background memory (Pitfall 13). Both share the same 28KB glance/background budget. Adding them simultaneously without monitoring memory at each step risks a combined overflow that is hard to attribute to either feature alone.

**Recommended approach:** Add localization FIRST (lower risk, no architectural changes), verify Glance memory is still within budget, THEN add notifications (higher risk, architectural change to temporal event system). Do not develop both in parallel.

---

## Sources

- [Garmin Developer: Toybox.Background Module](https://developer.garmin.com/connect-iq/api-docs/Toybox/Background.html) -- single temporal event limitation, requestApplicationWake, 5-minute minimum
- [Garmin Developer: Toybox.Attention Module](https://developer.garmin.com/connect-iq/api-docs/Toybox/Attention.html) -- supported app types (widget yes, background no), vibrate API, has-check
- [Garmin Developer: Resources Core Topic](https://developer.garmin.com/connect-iq/core-topics/resources/) -- resource compiler, language-qualified folders
- [Garmin Developer: Build Configuration](https://developer.garmin.com/connect-iq/core-topics/build-configuration/) -- monkey.jungle resource paths, language qualifiers
- [Garmin Developer: Properties and App Settings](https://developer.garmin.com/connect-iq/core-topics/properties-and-app-settings/) -- settings.xml configuration
- [Garmin Developer: Localization Guidelines](https://developer.garmin.com/connect-iq/user-experience-guidelines/localization/) -- supported language codes (ISO 639-2: fre for French, eng for English)
- [Forum: Triggering vibrations in the background](https://forums.garmin.com/developer/connect-iq/f/discussion/357743/triggering-vibrations-in-the-background) -- confirmed: "can only do vibrations in the foreground process"
- [Forum: Feature request: vibration from background process](https://forums.garmin.com/developer/connect-iq/f/discussion/5130/feature-request-vibration-from-watchface-and-or-vibration-from-background-process) -- requestApplicationWake as workaround
- [Forum: Conditional onTemporalEvent and requestApplicationWake](https://forums.garmin.com/developer/connect-iq/f/discussion/232368/conditional-ontemporalevent-and-requestapplicationwake-for-user-interaction) -- wake dialog mechanics, "Launch" button behavior
- [Forum: Garmin Express does not implement fallback to default language](https://forums.garmin.com/developer/connect-iq/i/bug-reports/garmin-express-does-not-implement-fallback-to-default-language-english-resources) -- known unfixed bug since 2021
- [Forum: Resources/Strings available languages](https://forums.garmin.com/developer/connect-iq/f/discussion/290576/resources-strings-available-languages) -- supported language codes, simulator limitations
- [Forum: Localization, jungle files, screen size/devices](https://forums.garmin.com/developer/connect-iq/f/discussion/261219/localization-jungle-files-screen-size-devices) -- resource path conflicts with language folders
- [Forum: WatchUI.loadResource() overhead](https://forums.garmin.com/developer/connect-iq/f/discussion/5470/watchui-loadresource-overhead) -- resource table memory cost (36 bytes base + 12 per entry)
- [Forum: loadResource mem usage](https://forums.garmin.com/developer/connect-iq/f/discussion/224423/loadresource-mem-usage) -- ALL resource tables load on first loadResource call
- [Forum: registerForTemporalEvent update problem](https://forums.garmin.com/developer/connect-iq/f/discussion/408958/background-registerfortemporalevent-update-problem/1922819) -- double registration overwrite behavior
- [Forum: Background temporal event](https://forums.garmin.com/developer/connect-iq/f/discussion/5443/background-temporal-event) -- Moment vs Duration, 5-minute restriction behavior
