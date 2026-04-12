# Roadmap: Garmin Mawaqit

## Milestones

- v1.0 MVP -- Phases 1-3 (shipped 2026-04-12)
- **v1.1 Localization & Notifications** -- Phases 4-5 (in progress)

## Phases

<details>
<summary>v1.0 MVP (Phases 1-3) -- SHIPPED 2026-04-12</summary>

- [x] Phase 1: Data Pipeline & Configuration (2/2 plans) -- completed 2026-04-11
- [x] Phase 2: Prayer Logic & Glance (2/2 plans) -- completed 2026-04-12
- [x] Phase 3: Widget & Background Service (2/2 plans) -- completed 2026-04-12

Full details: `.planning/milestones/v1.0-ROADMAP.md`

</details>

### v1.1 Localization & Notifications (In Progress)

**Milestone Goal:** Make the app accessible in French and English, and let users receive alerts when prayer times arrive.

- [ ] **Phase 4: Multi-Language Support** - French/English localization across Glance, Widget, and phone app settings
- [ ] **Phase 5: Prayer Notifications** - Per-prayer alerts with configurable timing via Moment-based background scheduling

## Phase Details

### Phase 4: Multi-Language Support
**Goal**: Users see all app text in their device language (French or English) without any manual configuration
**Depends on**: Phase 3 (existing widget, glance, and settings infrastructure)
**Requirements**: LOC-01, LOC-02, LOC-03, LOC-04, LOC-05
**Success Criteria** (what must be TRUE):
  1. User with a French-language Garmin device sees all Glance text (countdown prefix, empty states) in French
  2. User with a French-language device sees all Widget text (header, prayer schedule, empty states) in French
  3. User with a French-language device sees all phone app settings labels in French
  4. User with a device language other than French or English sees all text in English (fallback)
**Plans:** 2 plans

Plans:
- [x] 04-01-PLAN.md -- String resource infrastructure, manifest language, PrayerLogic localization, Glance view localization
- [x] 04-02-PLAN.md -- Widget view localization and visual verification checkpoint

**UI hint**: yes

### Phase 5: Prayer Notifications
**Goal**: Users receive timely prayer alerts on their watch, with full control over which prayers trigger notifications and when
**Depends on**: Phase 4 (notification setting labels must be localized; TimeUtil extraction shared with background)
**Requirements**: NOTIF-01, NOTIF-02, NOTIF-03, NOTIF-04, NOTIF-05, NOTIF-06
**Success Criteria** (what must be TRUE):
  1. User can toggle a master switch in phone app settings to enable/disable all prayer notifications
  2. User can enable/disable notifications individually for each of the 5 daily prayers (Fajr, Dhuhr, Asr, Maghrib, Isha)
  3. User can choose notification timing from a preset list (at prayer time, 5 min before, 10 min before, 15 min before)
  4. User receives a notification on their watch at the configured time for each enabled prayer, even when the widget is not being viewed
  5. Daily prayer data refresh continues to work correctly alongside notification scheduling (no stale data)
**Plans**: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 4 -> 5

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1. Data Pipeline & Configuration | v1.0 | 2/2 | Complete | 2026-04-11 |
| 2. Prayer Logic & Glance | v1.0 | 2/2 | Complete | 2026-04-12 |
| 3. Widget & Background Service | v1.0 | 2/2 | Complete | 2026-04-12 |
| 4. Multi-Language Support | v1.1 | 0/2 | Planned | - |
| 5. Prayer Notifications | v1.1 | 0/? | Not started | - |
