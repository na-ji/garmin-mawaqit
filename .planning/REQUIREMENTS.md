# Requirements: Garmin Mawaqit

**Defined:** 2026-04-12
**Core Value:** The next prayer time is always one glance away on the wrist — accurate, clear, and effortless.

## v1.1 Requirements

Requirements for localization and notifications milestone. Each maps to roadmap phases.

### Localization

- [ ] **LOC-01**: App auto-detects device language and displays UI in French or English
- [ ] **LOC-02**: All Glance UI strings (next prayer label, countdown prefix, empty states) display in the detected language
- [ ] **LOC-03**: All Widget UI strings (header, prayer labels, empty states) display in the detected language
- [ ] **LOC-04**: All phone app settings labels display in the detected language
- [ ] **LOC-05**: App falls back to English when device language is neither French nor English

### Notifications

- [ ] **NOTIF-01**: User can enable/disable all prayer notifications via a master toggle in phone app settings
- [ ] **NOTIF-02**: User can enable/disable notifications individually for each of the 5 daily prayers
- [ ] **NOTIF-03**: User can choose notification timing from presets: at prayer time, 5 min before, 10 min before, 15 min before
- [ ] **NOTIF-04**: App sends a notification at the configured time for each enabled prayer
- [ ] **NOTIF-05**: Background service schedules notifications using Moment-based temporal events, chaining to the next enabled prayer after each fires
- [ ] **NOTIF-06**: Daily data refresh continues to work alongside notification scheduling (unified temporal event)

## Future Requirements

### Additional Languages

- **LANG-01**: Support for Arabic language
- **LANG-02**: Support for Turkish language
- **LANG-03**: Support for additional languages based on user demand

### Advanced Notifications

- **ADVN-01**: Custom minute input for notification timing
- **ADVN-02**: Different timing presets per prayer (e.g., 15 min before Fajr, at time for Dhuhr)

## Out of Scope

| Feature | Reason |
|---------|--------|
| Custom minute input for notification timing | Preset list (0/5/10/15) covers common needs; avoids settings complexity |
| Guaranteed vibration on notification | Device-dependent platform limitation; best-effort via Notifications.showNotification() |
| Languages beyond FR/EN | Two covers primary user base for v1.1; more can be added later |
| On-watch language picker | Device language auto-detection is the Connect IQ standard pattern |
| Per-prayer timing presets | Single global timing setting keeps v1.1 settings simple |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| LOC-01 | Phase 4 | Pending |
| LOC-02 | Phase 4 | Pending |
| LOC-03 | Phase 4 | Pending |
| LOC-04 | Phase 4 | Pending |
| LOC-05 | Phase 4 | Pending |
| NOTIF-01 | Phase 5 | Pending |
| NOTIF-02 | Phase 5 | Pending |
| NOTIF-03 | Phase 5 | Pending |
| NOTIF-04 | Phase 5 | Pending |
| NOTIF-05 | Phase 5 | Pending |
| NOTIF-06 | Phase 5 | Pending |

**Coverage:**
- v1.1 requirements: 11 total
- Mapped to phases: 11
- Unmapped: 0

---
*Requirements defined: 2026-04-12*
*Last updated: 2026-04-12 after roadmap creation*
