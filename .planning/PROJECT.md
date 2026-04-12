# Garmin Mawaqit

## What This Is

A Garmin Connect IQ app that displays Islamic prayer times on modern Garmin watches. It provides a Glance (compact quick-peek) and a Widget (larger readable view) showing the next prayer name, its scheduled time, and a countdown. Prayer data comes from the unofficial Mawaqit API, with the mosque configurable through the Garmin Connect phone app.

## Core Value

The next prayer time is always one glance away on the wrist — accurate, clear, and effortless.

## Requirements

### Validated

- [x] Data fetched from unofficial Mawaqit API — Validated in Phase 1: Data Pipeline & Configuration
- [x] Mosque configurable via Garmin Connect phone app settings (slug-based) — Validated in Phase 1: Data Pipeline & Configuration
- [x] Glance shows next prayer name, time, and countdown — Validated in Phase 2: Prayer Logic & Glance
- [x] After Isha, rolls over to next day's Fajr with countdown — Validated in Phase 2: Prayer Logic & Glance
- [x] Widget shows full 5-prayer schedule with highlighted next prayer, iqama offsets, and countdown — Validated in Phase 3: Widget & Background Service
- [x] Targets modern Garmin watches (Connect IQ 4.x+ — Venu, Fenix 7+, Forerunner 265+) — Validated in Phase 3: Widget & Background Service

### Active

(All v1.0 requirements validated)

### Out of Scope

- ~~Full daily prayer schedule on widget~~ — Delivered in Phase 3 (Widget shows all 5 prayers)
- Search/browse mosques on the watch — settings via phone app is sufficient
- Older device support (CIQ 3.x) — modern devices only for v1
- Prayer notifications/alarms — display only for now
- Compass/Qibla direction — separate concern

## Context

- **API**: Unofficial Mawaqit API at `https://mawaqit.naj.ovh/api/v1/{mosque-slug}/`
- **Example slug**: `tawba-bussy-saint-georges`
- **Platform**: Garmin Connect IQ SDK, Monkey C language
- **Target CIQ version**: 4.x+ (modern devices only)
- **App types**: Glance + Widget (both showing next prayer)
- **5 daily prayers**: Fajr, Dhuhr, Asr, Maghrib, Isha

## Constraints

- **Platform**: Garmin Connect IQ SDK with Monkey C — no choice here
- **API**: Unofficial Mawaqit API — may change without notice
- **Device resources**: Garmin watches have limited memory and processing power
- **Network**: Watch relies on phone Bluetooth connection for HTTP requests
- **Display**: Small screen real estate — information must be glanceable

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Next prayer only (not all 5) | Keep display focused and glanceable | — Pending |
| Mosque via phone app settings | Simpler than on-watch search, slug-based API | — Pending |
| Modern devices only (CIQ 4.x+) | Simpler development, better APIs available | — Pending |
| Roll to Fajr after Isha | Always show actionable next prayer | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-04-12 after Phase 3 completion — all v1.0 phases complete*
