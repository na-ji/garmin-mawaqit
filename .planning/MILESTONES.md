# Milestones

## v1.0 MVP (Shipped: 2026-04-12)

**Phases completed:** 3 phases, 6 plans, 9 tasks

**Key accomplishments:**

- Connect IQ widget scaffold with mosque slug settings via Garmin Connect phone app and AppBase settings-change detection
- MawaqitService HTTP fetch chain with 6 sequential per-month/metadata requests, PrayerDataStore read layer, and AppBase lifecycle wiring for prayer data pipeline
- Stateless PrayerLogic module with seconds-since-midnight arithmetic for next-prayer identification, Isha-to-Fajr overnight rollover, threshold-based countdown formatting, and 5-segment progress bar data
- Root cause
- Full-screen 5-row prayer schedule widget with countdown header, green-accent highlighted next prayer, iqama offsets, and empty states
- Lightweight background ServiceDelegate with single /prayer-times HTTP request, 24h temporal event, and Background.exit() data flow to foreground -- verified on real watch

---
