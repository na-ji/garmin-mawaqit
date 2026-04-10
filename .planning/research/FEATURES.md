# Feature Landscape

**Domain:** Garmin Connect IQ Islamic Prayer Times (Widget/Glance)
**Researched:** 2026-04-10
**Source Ecosystem:** Garmin Connect IQ Store apps, Apple Watch prayer apps, Mawaqit platform

## Table Stakes

Features users expect from any prayer times widget on a smartwatch. Missing any of these and users leave immediately.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Next prayer name display | Every competitor shows this. Core value proposition. | Low | Fajr, Dhuhr, Asr, Maghrib, Isha |
| Next prayer time display | Useless without knowing when the prayer is. Universal across all apps. | Low | HH:MM format |
| Countdown to next prayer | All major competitors (Muslim Prayer Time Pro, Mecca Finder, Pray Watch) show remaining time. Users expect it on wrist. | Low | "1h 23m" or similar compact format |
| Isha-to-Fajr rollover | Without this, the widget is blank/wrong after Isha until midnight or next day. Every competitor handles this. | Medium | Must fetch next day's Fajr time. PROJECT.md already specifies this. |
| Configurable mosque (via phone) | The entire point of Mawaqit integration -- real mosque times, not calculated. Must be settable from Garmin Connect mobile app. | Medium | Slug-based setting in Garmin Connect companion app |
| Glance view (compact) | CIQ 4+ devices use glances as the primary quick-look surface. Without a glance, the app is invisible in the widget carousel. | Medium | Restricted drawing context: partial screen, no layers, limited fonts (FONT_GLANCE) |
| Graceful offline/error state | Network depends on phone Bluetooth. Users will see errors frequently. Must show last-known data or clear "no data" state, not crash. | Medium | Cache last successful fetch; show stale data with indicator |

## Differentiators

Features that set this app apart from existing Garmin prayer apps. Not expected, but valued.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Mosque-specific iqama times | Mawaqit API provides iqama offsets (e.g., '+10', '+5'). No existing Garmin app shows iqama times. All competitors use calculated prayer times only. This is the killer feature. | Medium | Mawaqit API returns iqama offsets per prayer. Display as separate line or toggle. |
| Visual progress indicator | Pray Watch's "prayer ring" and Muslim Prayer Time Pro's progress bar are praised. A visual arc/bar showing elapsed time within current prayer window is more glanceable than numbers alone. | Medium | Arc or linear bar showing position between current prayer and next prayer |
| Mosque name display | Shows which mosque's times you're viewing. Builds trust in the data. No Garmin competitor does this since they calculate locally. | Low | From Mawaqit API response. Show in Widget view (not glance -- too small). |
| Smart data refresh | Muslim Prayer Time Pro offers auto-refresh on glance view and daily auto-refresh. Intelligent caching (refresh once per day, re-fetch on mosque change) saves battery and reduces errors. | Medium | Fetch daily at midnight or on first view of new day; cache in persistent storage |
| All five prayer times in Widget | While Glance shows only next prayer, the full Widget view could show all five with the next one highlighted. Competitors like Mecca Finder and Muslim Prayer Times Widget show the full schedule. | Medium | Only in expanded Widget view, not Glance. Next prayer visually emphasized. |
| Jumua (Friday prayer) time | Mawaqit API includes Jumua times. Relevant once per week. Nice touch for mosque-goers. | Low | Show on Fridays only, replacing or supplementing Dhuhr |

## Anti-Features

Features to explicitly NOT build in v1. Either out of scope, too complex for the value, or actively harmful to the focused UX.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Qibla compass / Mecca direction | Adds significant complexity (compass sensor access, calibration, bearing calculations). Existing Garmin apps (Mecca Finder, Muslim Prayer Times Widget) already do this well. Users who need Qibla can install a dedicated app. Dilutes the focused "next prayer" value prop. | Stay focused on prayer times. PROJECT.md already excludes this. |
| Prayer notifications / alarms | Garmin platform severely limits alarm functionality for widgets -- only one alarm at a time, widget cannot run in background. Mecca Finder developers confirmed this limitation. Attempting it creates unreliable UX worse than no notifications. | Display-only for v1. Revisit if Garmin improves background scheduling. |
| On-watch calculation methods | Muslim Prayer Times Widget and Muslim Prayer Time Pro offer 15+ calculation methods (MWL, ISNA, Egypt, etc.). Unnecessary when using Mawaqit API -- the mosque's imam already set the correct times. Adding calculation is building for a use case (no mosque nearby) this app doesn't serve. | Rely entirely on Mawaqit API data. The mosque handles calculation method. |
| On-watch mosque search/browse | Tiny screen, slow input. Every prayer app that tried this on watch got complaints. Phone-based configuration is the correct UX. | Configure mosque slug through Garmin Connect companion app settings only. |
| Hijri calendar display | Nice-to-have but adds complexity and is not core to "when is my next prayer." Mawaqit API may not reliably provide Hijri dates. Would consume precious glance space. | Omit entirely. Users have phone apps for Hijri dates. |
| Adhan audio playback | Garmin watches have limited/no speaker support for most models. Even on models with speakers, playing audio from a widget is not supported in CIQ. | Not possible on platform. Do not attempt. |
| Multiple mosque support | Switching between mosques adds settings complexity. V1 targets one primary mosque. | Single mosque configuration. Can revisit in v2 if users request. |
| Sunrise/Sunset times | Not prayer times per se. Adds clutter. Fajr and Maghrib already bracket these implicitly. | Omit from display. Available in Mawaqit data if ever needed. |
| Ramadan-specific features | Fasting timers, suhoor/iftar countdowns, etc. Adds seasonal complexity. Muslim Companion does this but it's a full app, not a focused widget. | The standard Fajr/Maghrib times already serve this need implicitly. |

## Feature Dependencies

```
Mosque Configuration (phone settings) --> API Data Fetch --> All display features
                                                        |
                                                        +--> Next Prayer Calculation
                                                        |       |
                                                        |       +--> Glance View (name + time + countdown)
                                                        |       +--> Widget View (all prayers + next highlighted)
                                                        |
                                                        +--> Iqama Time Calculation (from offsets)
                                                        |       |
                                                        |       +--> Iqama display in Widget
                                                        |
                                                        +--> Data Caching (persistent storage)
                                                                |
                                                                +--> Offline/stale data fallback
                                                                +--> Smart refresh logic
```

Key dependency chain:
- `Phone Settings (mosque slug)` is the root -- nothing works without it
- `API Fetch` depends on phone Bluetooth connection and valid slug
- `Next Prayer Calculation` depends on having today's prayer times array + current time
- `Iqama Display` depends on both prayer times and iqama offsets from API
- `Glance View` is the primary surface users see -- must work with cached data
- `Widget View` is the expanded detail view -- can show richer information

## MVP Recommendation

**Phase 1 -- Core (must ship):**
1. Mosque configuration via Garmin Connect companion app settings (slug input)
2. Mawaqit API data fetch with basic error handling
3. Next prayer calculation logic (including Isha-to-Fajr rollover)
4. Glance view: next prayer name, time, countdown
5. Widget view: next prayer name, time, countdown (larger/more readable)
6. Basic data caching (persist last fetch, use when offline)

**Phase 2 -- Polish (makes it good):**
1. All five prayers in Widget view with next prayer highlighted
2. Iqama times display (differentiator)
3. Visual progress indicator (arc or bar)
4. Smart refresh logic (daily auto-refresh, refresh on new day)
5. Mosque name display in Widget view

**Defer to v2+:**
- Jumua time special handling (low value, adds conditional logic)
- Multiple mosque support (wait for user demand)
- Any form of notifications (platform limitation)

## Competitive Landscape Summary

| App | Type | Data Source | Iqama? | Glance? | Key Strength |
|-----|------|-------------|--------|---------|--------------|
| Muslim Prayer Times Widget (slipperybee) | Widget | GPS + calculation | No | Unclear (CIQ 3 era) | Established, Qibla compass, mature |
| Muslim Prayer Time Pro | App+Glance | GPS + 15 calc methods | No | Yes | Feature-rich, progress bar, configurable |
| Mecca Finder (Garmin official) | Widget | GPS + calculation | No | Unclear | Official Garmin, Qibla focus |
| Muslim Companion | App | GPS + calculation | No | Yes | Ramadan features, timer |
| **Garmin Mawaqit (this project)** | **App+Glance** | **Mawaqit API (mosque)** | **Yes** | **Yes** | **Real mosque times + iqama = unique** |

The clear differentiator: every existing Garmin prayer app calculates times from GPS coordinates. None use real mosque-sourced data. None show iqama times. This project's Mawaqit integration is genuinely unique on the platform.

## Sources

- [Muslim Prayer Times Widget - Connect IQ Store](https://apps.garmin.com/apps/4143d035-816f-4790-bb33-da31d8d0201b)
- [Muslim Prayer Time Pro - Connect IQ Store](https://apps.garmin.com/apps/984912bd-1413-4ef3-a062-e6bc52d335de)
- [Muslim Prayer Time Pro Quick User Guide](https://prayer-time-pro-garmin.web.app/)
- [Muslim Companion - Connect IQ Store](https://apps.garmin.com/apps/85076911-0147-4996-86ff-3cda1e766283)
- [Garmin Mecca Finder - Connect IQ Store](https://apps.garmin.com/en-US/apps/503df121-46d7-4dab-8589-2bfcc9741bf1)
- [Islamic Prayer Times Widget Instructions (slipperybee)](https://slipperybee.github.io/islamic-prayer-times-instructions/)
- [Garmin Connect IQ Glances Documentation](https://developer.garmin.com/connect-iq/core-topics/glances/)
- [Garmin Connect IQ App Types](https://developer.garmin.com/connect-iq/connect-iq-basics/app-types/)
- [Pray Watch - Apple Watch](https://praywatch.app/)
- [Mawaqit Platform](https://mawaqit.net/en/)
- [Mawaqit API (community wrapper)](https://github.com/mrsofiane/mawaqit-api)
- [Garmin Forum - Apps for Muslim prayer time](https://forums.garmin.com/developer/connect-iq/f/app-ideas/953/apps-for-muslim-prayer-time)
- [Garmin Forum - Widget Glances announcement](https://forums.garmin.com/developer/connect-iq/b/news-announcements/posts/widget-glances---a-new-way-to-present-your-data)
