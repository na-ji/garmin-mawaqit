# Roadmap: Garmin Mawaqit

## Overview

This roadmap delivers a Garmin Connect IQ app that shows the next Islamic prayer time on modern watches. The project progresses from data infrastructure (API + caching + configuration) through core prayer logic with the Glance view, to the full Widget and background refresh. Each phase delivers a verifiable capability: Phase 1 ensures the watch can fetch and store prayer data from a configured mosque; Phase 2 delivers the primary user experience (next prayer at a glance); Phase 3 completes the app with the detailed Widget and automatic data freshness.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [ ] **Phase 1: Data Pipeline & Configuration** - Fetch, cache, and configure prayer data from the Mawaqit API
- [ ] **Phase 2: Prayer Logic & Glance** - Calculate next prayer and display it on the Glance view
- [ ] **Phase 3: Widget & Background Service** - Full prayer schedule Widget and automatic data refresh

## Phase Details

### Phase 1: Data Pipeline & Configuration
**Goal**: The watch can fetch prayer data from a user-configured mosque and store it reliably for offline use
**Depends on**: Nothing (first phase)
**Requirements**: DATA-01, DATA-02, DATA-03, DATA-04, DATA-05, CONF-01, CONF-02
**Success Criteria** (what must be TRUE):
  1. App fetches prayer times (including iqama times) from the Mawaqit API for a given mosque slug
  2. User can set the mosque slug in Garmin Connect phone app settings and the watch receives it
  3. Fetched prayer data persists in Application.Storage and is available after app restart
  4. Two days of prayer data are stored so Isha-to-Fajr rollover has the data it needs
  5. When phone/API is unreachable, app loads and displays last cached data without crashing
**Plans:** 2 plans

Plans:
- [x] 01-01-PLAN.md — Project scaffolding and mosque configuration (CONF-01, CONF-02)
- [x] 01-02-PLAN.md — Data fetching service and storage layer (DATA-01 through DATA-05)

### Phase 2: Prayer Logic & Glance
**Goal**: Users can glance at their wrist and see the next prayer name, time, and countdown
**Depends on**: Phase 1
**Requirements**: PRAY-01, PRAY-02, PRAY-03, GLNC-01, GLNC-02
**Success Criteria** (what must be TRUE):
  1. App correctly identifies the next upcoming prayer based on current time
  2. After Isha, the display rolls over to show next day's Fajr with accurate countdown
  3. Countdown to next prayer updates in real-time showing hours and minutes remaining
  4. Glance view displays next prayer name, scheduled time, and countdown within the 28KB memory budget
**Plans:** 2 plans

Plans:
- [ ] 02-01-PLAN.md — PrayerLogic computation module (PRAY-01, PRAY-02, PRAY-03)
- [ ] 02-02-PLAN.md — GlanceView rendering and timer refresh (GLNC-01, GLNC-02)

### Phase 3: Widget & Background Service
**Goal**: Users have a detailed prayer schedule Widget and the app keeps data fresh automatically
**Depends on**: Phase 2
**Requirements**: WDGT-01, WDGT-02, WDGT-03, BKGD-01, BKGD-02
**Success Criteria** (what must be TRUE):
  1. Widget displays all 5 daily prayers with the next prayer visually highlighted
  2. Widget shows iqama times alongside each prayer time
  3. Widget shows a visual progress indicator between the current and next prayer
  4. Background service periodically refreshes prayer data via temporal events without user intervention
  5. Changing the mosque setting triggers an automatic data re-fetch
**Plans**: TBD
**UI hint**: yes

Plans:
- [ ] 03-01: TBD
- [ ] 03-02: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 -> 2 -> 3

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Data Pipeline & Configuration | 0/2 | Planned | - |
| 2. Prayer Logic & Glance | 0/2 | Planned | - |
| 3. Widget & Background Service | 0/? | Not started | - |
