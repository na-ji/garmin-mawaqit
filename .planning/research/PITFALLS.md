# Domain Pitfalls

**Domain:** Garmin Connect IQ Widget/Glance -- Islamic prayer times with HTTP API
**Researched:** 2026-04-10

---

## Critical Pitfalls

Mistakes that cause rewrites, app crashes, or store rejection.

---

### Pitfall 1: Glance 28KB Memory Ceiling Causes Silent Crashes

**What goes wrong:** The Glance view has only ~32KB total memory, of which ~28KB is usable after the VM takes its share. This is shockingly small. The Glance loads ALL code annotated with `:glance` PLUS all code annotated with `:background` PLUS `AppBase` into this 28KB. Developers who share utility classes, data models, or helper functions between Glance and Widget without careful annotation blow through the limit and get `OutOfMemoryError` on real devices -- often while the simulator works fine because it has relaxed limits.

**Why it happens:** Developers treat the Glance as "a smaller Widget" and share code freely. They don't realize the annotation system controls what bytecode gets loaded into the Glance process. Every class, every constant, every string literal annotated `:glance` counts against the 28KB.

**Consequences:** App crashes immediately on Glance display. Users see "IQ!" error icon. Since modern CIQ 4+ devices show Glances in the carousel, the app appears permanently broken. One-star reviews follow.

**Prevention:**
- Architect from day one: Glance code path must be a SEPARATE, minimal class. Do not reuse Widget view classes.
- Use `:glance` annotation sparingly -- only on what the Glance truly needs.
- Create a dedicated `GlanceView` class that reads pre-computed data from `Application.Storage` and renders it. No parsing, no computation, no shared models.
- Monitor memory in simulator: Settings > Memory > watch peak usage. If Glance peak exceeds 20KB, refactor immediately.
- Test on real hardware early. Simulator memory limits are often more lenient than real devices.

**Detection:** Peak memory in simulator approaching 24KB+. Any `OutOfMemoryError` in ERA (crash report) logs. App works in simulator but crashes on device.

**Phase:** Must be addressed in Phase 1 (architecture). Cannot be retrofitted easily.

---

### Pitfall 2: Background Service 30-Second Timeout Kills HTTP Requests Silently

**What goes wrong:** Background temporal events run the background service process, which has a hard 30-second timeout. The HTTP request goes: Watch -> BLE -> Phone -> Internet -> API -> Phone -> BLE -> Watch. If any hop is slow (weak BLE, phone in power-saving mode, API cold start), the 30 seconds expire. The background process terminates BEFORE the HTTP callback fires. No error is returned. No data. No way to tell the user what happened. The app simply shows stale data with no indication of failure.

**Why it happens:** Developers test on simulator where HTTP is instant (localhost). They never encounter the timeout. On real devices, BLE latency alone can eat 5-10 seconds. Add API latency, and 30 seconds becomes tight.

**Consequences:** App appears to "randomly" stop updating. Users see hours-old prayer times. No error message appears because the background process died before it could report one. Debugging is extremely difficult because the failure is silent.

**Prevention:**
- Design the API proxy (`mawaqit.naj.ovh`) to return minimal JSON. Strip everything except the 5 prayer times and date. Target under 500 bytes of JSON response.
- Implement a "last updated" timestamp shown in the Widget. Store the timestamp of the last successful fetch in `Application.Storage`. If data is older than the background interval, show a staleness indicator.
- In the background service, check `System.getDeviceSettings().phoneConnected` before making the request. If false, call `Background.exit(null)` immediately rather than wasting the 30-second window.
- Handle `onBackgroundData(null)` gracefully in the foreground -- it means the background service failed or timed out.

**Detection:** Prayer times stop updating but no error is visible. "Last updated" timestamp (if implemented) grows stale. Works perfectly in simulator, fails intermittently on device.

**Phase:** Must be addressed in Phase 1 (background service design). The data contract with the API proxy should be locked down early.

---

### Pitfall 3: CIQ 4+ App Type Confusion -- Widget Type is Gone

**What goes wrong:** In Connect IQ 4.0+, the "widget" app type was merged into "watch-app." Building a CIQ 4+ app as type "widget" in manifest.xml actually produces a watch-app. If `getGlanceView()` is not implemented, the app will NOT appear in the Glance carousel on modern devices -- it becomes invisible to the user. Conversely, if built as a watch-app with `getGlanceView()`, it appears in BOTH the glance loop AND the activity/app launcher, which may confuse users who expect it only in glances.

**Why it happens:** Garmin's documentation still references "widgets" loosely. Developers targeting CIQ 4+ don't realize the widget concept was absorbed. Forum examples and older tutorials show the widget app type, leading to copy-paste errors.

**Consequences:** App installs but users can't find it in the glance carousel. Or app appears in two places (glance + app launcher) causing confusion. Wrong app type means wrong lifecycle behavior.

**Prevention:**
- Use app type `widget` in manifest.xml (which compiles as watch-app on CIQ 4+ devices automatically).
- ALWAYS implement `AppBase.getGlanceView()` -- this is mandatory for the app to appear in the glance carousel.
- Test the full user flow: install -> find in glance loop -> tap to open Widget view -> back to glance.
- Accept that on CIQ 4+ the app will also appear in the activity launcher. This is normal Garmin behavior for "super apps."

**Detection:** App installs successfully but user cannot find it on the watch. No entry in the glance carousel.

**Phase:** Must be correct from Phase 1 (project setup / manifest configuration).

---

### Pitfall 4: JSON Response Must Be a Top-Level Object, Not Array

**What goes wrong:** `Communications.makeWebRequest()` with `HTTP_RESPONSE_CONTENT_TYPE_JSON` requires the JSON response to be a top-level object (dictionary), not an array. If the API returns `[...]` instead of `{...}`, the request fails with error code -400 (invalid response). This is a fundamental Connect IQ limitation with no workaround on the watch side.

**Why it happens:** Many REST APIs return arrays at the top level. Developers assume standard JSON parsing. Connect IQ's JSON parser only converts to `Dictionary`, never `Array`, at the top level.

**Consequences:** HTTP requests fail with -400. Developer spends hours debugging thinking it's a network issue. If the Mawaqit API proxy returns an array, every single request will fail.

**Prevention:**
- The API proxy at `mawaqit.naj.ovh` MUST return a top-level JSON object: `{"fajr": "04:30", "dhuhr": "13:00", ...}` -- never `["04:30", "13:00", ...]`.
- If the proxy cannot be changed, use `HTTP_RESPONSE_CONTENT_TYPE_TEXT_PLAIN` and parse the response string manually in Monkey C (complex and memory-expensive -- avoid this).
- Validate the proxy response format early in development before writing any watch-side parsing code.

**Detection:** All HTTP requests return error code -400 despite the URL being correct and reachable.

**Phase:** Must be validated in Phase 1 before any HTTP code is written. The proxy contract is a prerequisite.

---

### Pitfall 5: Background.exit() Data Limited to ~8KB

**What goes wrong:** The data payload passed from the background service to the foreground via `Background.exit(data)` is limited to approximately 8KB. If the parsed API response (as a Monkey C Dictionary) exceeds this, `Background.exit()` throws an exception, the background process fails, and no data reaches the foreground.

**Why it happens:** The 8KB limit is not prominently documented. Developers parse the full API response into a dictionary and pass it through. JSON-to-Dictionary conversion in Monkey C inflates size (hash tables double in size at packing thresholds). A 2KB JSON response can become a 6KB+ Dictionary.

**Consequences:** Background service silently fails to deliver data. Same symptoms as Pitfall 2 (stale data, no error) but with a different root cause.

**Prevention:**
- Keep the API response minimal. For this app: 5 prayer time strings + date = well under 1KB of JSON.
- In the background service, extract ONLY what the foreground needs before calling `Background.exit()`. Don't pass the raw parsed response. Build a minimal Dictionary: `{"f":"04:30","d":"13:00","a":"16:45","m":"20:15","i":"21:45","dt":"2026-04-10"}`.
- Alternative: Write data to `Application.Storage` in the background service and pass only a success flag via `Background.exit(true)`. The foreground reads from Storage. This avoids the 8KB limit entirely.

**Detection:** `Background.exit()` throws an exception (visible in simulator console). Foreground `onBackgroundData()` never fires or receives null.

**Phase:** Phase 1 (background service architecture).

---

## Moderate Pitfalls

---

### Pitfall 6: Temporal Event 5-Minute Minimum Interval

**What goes wrong:** Background temporal events cannot fire more frequently than every 5 minutes. Only ONE temporal event can be registered at a time. Developers who want frequent updates (e.g., countdown accuracy) or who try to schedule prayer-specific events find they cannot control timing granularly.

**Prevention:**
- Accept the 5-minute minimum. Design around it: fetch prayer times once every 15-30 minutes via background service.
- For countdown accuracy, do NOT rely on background updates. Instead, compute the countdown in `onUpdate()` using `Time.now()` and the stored next-prayer time. The countdown display is a real-time calculation, not a fetched value.
- Register the next temporal event using a `Time.Moment` (specific time) rather than a `Time.Duration` (interval). For watch-apps/widgets, the 5-minute restriction resets on app startup when using Moments.

**Phase:** Phase 1 (background service scheduling design).

---

### Pitfall 7: Glance Lifecycle Runs Every ~30 Seconds, Full Start-to-Stop

**What goes wrong:** The Glance is not a persistent view. Every ~30 seconds, the system runs the FULL lifecycle: `onStart()` -> `getGlanceView()` -> `onLayout()` -> `onShow()` -> `onUpdate()` -> `onHide()` -> `onStop()`. The rendered frame is cached as a bitmap. Developers who put expensive initialization in `onStart()` or `getGlanceView()` (API calls, complex parsing, heavy computation) cause the Glance to lag or fail.

**Prevention:**
- Glance `onUpdate()` must be ultra-fast: read from `Application.Storage`, format two strings (prayer name + time), draw them. Nothing else.
- NEVER make HTTP requests from the Glance lifecycle. All data fetching happens in the background service.
- Pre-compute the "next prayer" in the background service or Widget and store the result. The Glance just reads and displays.
- Keep Glance code path deterministic and allocation-minimal.

**Phase:** Phase 1 (Glance view implementation).

---

### Pitfall 8: Simulator vs. Real Device Behavioral Differences

**What goes wrong:** The Connect IQ Simulator is a simulator, not an emulator. Significant differences exist:
- Memory limits are often more relaxed in the simulator.
- `System.getDeviceSettings().isGlanceModeEnabled` is always `false` in the simulator even when Glance mode is configured.
- HTTP requests are instantaneous in the simulator (no BLE hop).
- Font rendering and text positioning differ between simulator and real hardware.
- Background services from previously tested apps can persist in the simulator, causing phantom behavior.

**Prevention:**
- Test on real hardware as early as possible. Don't wait until "it works in the simulator."
- Use the simulator for rapid iteration, but validate every milestone on at least one physical device.
- Reset the simulator between test sessions (File > Reset Simulator) to clear stale background services.
- Do not rely on `isGlanceModeEnabled` in development logic; detect Glance context by checking which view class is active.

**Phase:** Every phase. Establish device testing practice in Phase 1.

---

### Pitfall 9: Settings Sync Delay Between Phone and Watch

**What goes wrong:** When a user changes the mosque slug in the Garmin Connect mobile app settings, the `onSettingsChanged()` callback on the watch may not fire immediately. The property change requires a Bluetooth sync, which can take 30 seconds to several minutes. In some reported cases, the callback never fires while the app is running, and settings only take effect after restarting the app. Additionally, `onSettingsChanged()` behavior has known bugs where reverted property values display incorrectly in the mobile app for up to a minute.

**Prevention:**
- Do not assume `onSettingsChanged()` fires in real time. Always read settings from `Properties.getValue()` on app startup as the primary mechanism.
- After reading a new mosque slug, validate it (non-null, non-empty) before triggering a data fetch. Show a "Configure mosque in Garmin Connect app" message if the slug is missing.
- Store the current mosque slug in `Application.Storage` alongside the prayer data. On every background fetch, compare the stored slug to the current property value. If they differ, fetch new data.
- Test the settings flow: change setting on phone -> sync -> verify watch picks up the change.

**Phase:** Phase 2 (settings integration). But the validation logic belongs in Phase 1 architecture.

---

### Pitfall 10: Isha-to-Fajr Rollover Across Midnight

**What goes wrong:** After Isha (the last prayer), the app must show tomorrow's Fajr with an accurate countdown. This requires:
1. Having tomorrow's prayer times available (today's Fajr is already past).
2. Correctly handling the date boundary at midnight.
3. Handling edge cases: What if the background service hasn't fetched tomorrow's data yet? What if it's 11:55 PM and the next fetch is at 12:10 AM?

Developers who only store today's 5 prayer times hit a dead end after Isha. The countdown shows negative time or "no next prayer."

**Prevention:**
- Always fetch and store at least TWO days of prayer times: today and tomorrow. The API proxy should support this (or the watch fetches twice).
- Alternatively, have the API proxy return tomorrow's Fajr time as a 6th field in the response.
- Implement the next-prayer logic as: scan today's times, if all are past, use tomorrow's Fajr. If tomorrow's Fajr is also past (shouldn't happen), show a "refreshing..." state.
- Schedule a background fetch shortly after midnight to refresh the day's data.

**Detection:** App shows no prayer or negative countdown after Isha. App shows incorrect prayer at midnight boundary.

**Phase:** Phase 1 (core prayer logic). This is a fundamental data model decision.

---

### Pitfall 11: Unofficial API Instability and Availability

**What goes wrong:** The Mawaqit API at `mawaqit.naj.ovh` is unofficial and self-hosted. It could go down, change its response format, or become rate-limited without notice. The official Mawaqit API is private and not publicly available. Building a watch app that depends entirely on an unofficial proxy creates a single point of failure.

**Prevention:**
- Design the watch app to be resilient to API failure. Cache the last successful response in `Application.Storage` with a timestamp. Show cached data with a staleness indicator rather than showing nothing.
- Keep the API response contract simple and documented so the proxy can be rehosted or replaced quickly.
- Consider adding a fallback: if the primary proxy is down for extended periods, show cached data with a clear "offline" indicator.
- The proxy should be stateless and simple enough to deploy anywhere (Vercel, Cloudflare Workers, etc.) in under an hour if the current host fails.
- Document the expected JSON contract in the project so any replacement proxy knows exactly what to return.

**Detection:** HTTP requests return non-200 status codes. Prayer times stop updating for hours/days.

**Phase:** Phase 1 (API proxy contract) and ongoing operational concern.

---

## Minor Pitfalls

---

### Pitfall 12: Monkey C Type Checker Quirks at Strict Level

**What goes wrong:** Monkey C's type checker at `strict` level has known issues: it doesn't treat `&&` as short-circuiting for null checks (requiring nested `if` statements), incorrectly infers types on container access, and breaks with the `has` keyword in background-annotated code. Developers enabling strict mode spend excessive time fighting the type checker rather than building features.

**Prevention:**
- Use type check level 2 (gradual) instead of strict for development velocity. Gradual provides most benefits without the false positives.
- Where the type checker fights you, use `:typecheck(false)` on specific functions as a targeted escape hatch.
- Use explicit `as` casts for Dictionary values from API responses and Storage reads.

**Phase:** Phase 1 (project configuration).

---

### Pitfall 13: Widget Memory is Separate and Larger, But Still Limited

**What goes wrong:** The Widget (full view when user taps the Glance) has more memory than the Glance (~64-128KB depending on device) but is still limited compared to any modern platform. Developers who build complex multi-screen UIs, load images, or keep large data structures in memory hit the ceiling.

**Prevention:**
- The Widget for this app is simple: display next prayer name, time, and countdown. This should comfortably fit in any Widget memory budget.
- Avoid loading bitmap resources. Use text rendering only.
- Release references to data structures when not needed (set to `null`).
- Monitor peak memory in the simulator for Widget mode separately from Glance mode.

**Phase:** Phase 1 (Widget view implementation).

---

### Pitfall 14: requestUpdate() Frequency and Battery Drain

**What goes wrong:** Calling `WatchUi.requestUpdate()` triggers a screen redraw. In the Widget view, using a `Timer` to call `requestUpdate()` every second (for a countdown) works but drains battery faster than necessary. Every redraw costs power.

**Prevention:**
- Update the countdown every 1 second only when the Widget is visible (active in `onShow()`, stopped in `onHide()`).
- For the Glance, do NOT use a timer. The system controls Glance refresh (~30 seconds). Just render whatever is current in `onUpdate()`.
- Consider updating every 10-15 seconds in the Widget if sub-minute countdown precision isn't critical. Even every-minute updates are acceptable since prayer times change on 1-minute boundaries.
- Stop the timer in `onHide()` without fail. Forgetting this is a common battery drain source.

**Phase:** Phase 1 (Widget view timer management).

---

### Pitfall 15: Store Submission and Permissions

**What goes wrong:** The Connect IQ Store review process can reject apps for unclear reasons. Common issues: missing permissions in manifest (Communications permission for HTTP), supporting devices the app wasn't tested on, vague app descriptions, or using trademarked terms.

**Prevention:**
- Declare `Communications` permission in manifest.xml.
- Declare `Background` permission for background temporal events.
- Only list devices you have tested (or at minimum, tested in the simulator with correct memory constraints).
- Write a clear app description mentioning it connects to an external API for prayer times.
- Do not use the word "Mawaqit" as a trademark in the app name without checking usage rights. Consider a generic name like "Prayer Times" or "Salat Widget."

**Phase:** Final phase (store submission).

---

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|-------------|---------------|------------|
| Project setup / manifest | Pitfall 3: Wrong app type for CIQ 4+ | Use widget type, implement `getGlanceView()` |
| API proxy contract | Pitfall 4: JSON must be top-level object | Validate proxy returns `{...}` not `[...]` |
| API proxy contract | Pitfall 11: Unofficial API instability | Document response contract, keep proxy simple and portable |
| Background service | Pitfall 2: 30-second timeout kills requests | Minimal JSON payload, phone-connected check |
| Background service | Pitfall 5: 8KB exit data limit | Pass minimal dict or use Storage |
| Background service | Pitfall 6: 5-minute minimum interval | Use Moments, compute countdown locally |
| Glance implementation | Pitfall 1: 28KB memory ceiling | Separate minimal GlanceView, read-only from Storage |
| Glance implementation | Pitfall 7: Full lifecycle every 30s | Ultra-fast onUpdate, no computation |
| Widget implementation | Pitfall 14: Battery drain from frequent updates | Timer discipline, stop in onHide |
| Prayer time logic | Pitfall 10: Isha-to-Fajr rollover | Store two days of data, scan-and-rollover logic |
| Settings | Pitfall 9: Sync delay from phone | Read on startup, validate slug, compare-and-fetch |
| Testing | Pitfall 8: Simulator vs real device | Test on hardware every phase |
| Store submission | Pitfall 15: Rejection risks | Correct permissions, tested devices, clear description |

---

## Sources

- [Garmin Developer: Glances Core Topic](https://developer.garmin.com/connect-iq/core-topics/glances/)
- [Garmin Developer: App Types](https://developer.garmin.com/connect-iq/connect-iq-basics/app-types/)
- [Garmin Developer: Background Service FAQ](https://developer.garmin.com/connect-iq/connect-iq-faq/how-do-i-create-a-connect-iq-background-service/)
- [Garmin Developer: HTTPS / JSON REST Requests](https://developer.garmin.com/connect-iq/core-topics/https/)
- [Garmin Developer: Toybox.Background Module](https://developer.garmin.com/connect-iq/api-docs/Toybox/Background.html)
- [Garmin Developer: Objects and Memory](https://developer.garmin.com/connect-iq/monkey-c/objects-and-memory/)
- [Garmin Developer: Persisting Data](https://developer.garmin.com/connect-iq/core-topics/persisting-data/)
- [Garmin Developer: Properties and App Settings](https://developer.garmin.com/connect-iq/core-topics/properties-and-app-settings/)
- [Garmin Developer: App Review Guidelines](https://developer.garmin.com/connect-iq/app-review-guidelines/)
- [Forum: Glance Views Out of Memory](https://forums.garmin.com/developer/connect-iq/f/discussion/210767/glance-views-out-of-memory)
- [Forum: Background Process Exits Before Timeout](https://forums.garmin.com/developer/connect-iq/i/bug-reports/background-process-exits-before-makewebrequest-times-out)
- [Forum: Understanding -402 Response Limit](https://forums.garmin.com/developer/connect-iq/f/discussion/414966/understanding--402-response-limit-for-makewebrequest)
- [Forum: onBackgroundData Not Called](https://forums.garmin.com/developer/connect-iq/f/discussion/324155/onbackgrounddata-not-called/1574861)
- [Forum: How to Hand Over Data to Background Service](https://forums.garmin.com/developer/connect-iq/f/discussion/358782/how-to-hand-over-data-to-a-background-service)
- [Forum: Background Temporal Event](https://forums.garmin.com/developer/connect-iq/f/discussion/5443/background-temporal-event)
- [Forum: Widget onShow Not Called Always](https://forums.garmin.com/developer/connect-iq/i/bug-reports/widget-onshow-is-not-called-always-on-some-devices)
- [Forum: Settings Sync Issues](https://forums.garmin.com/developer/connect-iq/i/bug-reports/watch-face-settings-not-updated-synced-correctly-in-the-connect-iq-mobile-apps-after-performing-settings-change)
- [Forum: Strict Type Checker Issues](https://forums.garmin.com/developer/connect-iq/b/news-announcements/posts/the-road-to-strict-typing-is-paved-with-good-intentions)
- [Forum: JSON Array Parsing](https://forums.garmin.com/developer/connect-iq/f/discussion/1604/parsing-as-json-array)
- [Forum: Simulator vs Real Device](https://forums.garmin.com/developer/connect-iq/f/discussion/5430/code-tuning-and-differences-between-simulator-and-real-devices)
- [Garmin Blog: Improve App Performance](https://www.garmin.com/en-US/blog/developer/improve-your-app-performance/)
- [Mawaqit Help: API Availability](https://help.mawaqit.net/en/articles/11991838-can-i-use-your-api)
