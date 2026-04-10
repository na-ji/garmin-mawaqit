# Requirements: Garmin Mawaqit

**Defined:** 2026-04-10
**Core Value:** The next prayer time is always one glance away on the wrist — accurate, clear, and effortless.

## v1 Requirements

Requirements for initial release. Each maps to roadmap phases.

### Data & API

- [ ] **DATA-01**: App fetches prayer times from the Mawaqit API via `https://mawaqit.naj.ovh/api/v1/{slug}/`
- [ ] **DATA-02**: Prayer data cached in Application.Storage for offline use
- [ ] **DATA-03**: App displays last cached data when phone/API is unavailable
- [ ] **DATA-04**: App stores two days of prayer data for Isha-to-Fajr rollover
- [ ] **DATA-05**: App fetches and displays iqama times from the API

### Configuration

- [ ] **CONF-01**: User can set mosque slug via Garmin Connect phone app settings
- [ ] **CONF-02**: Settings sync to watch via Properties and trigger data re-fetch

### Prayer Logic

- [ ] **PRAY-01**: App calculates the next prayer from current time
- [ ] **PRAY-02**: After Isha, app rolls over to show next day's Fajr with countdown
- [ ] **PRAY-03**: Countdown updates in real-time (minutes/hours remaining)

### Glance

- [ ] **GLNC-01**: Glance displays next prayer name, scheduled time, and countdown
- [ ] **GLNC-02**: Glance fits within 28KB memory budget using annotations

### Widget

- [ ] **WDGT-01**: Widget shows all 5 daily prayers with next prayer highlighted
- [ ] **WDGT-02**: Widget shows iqama times alongside prayer times
- [ ] **WDGT-03**: Widget displays visual progress indicator between prayers

### Background Service

- [ ] **BKGD-01**: Background service refreshes data periodically via temporal events
- [ ] **BKGD-02**: Background service re-fetches when mosque settings change

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### Enhanced Display

- **DISP-01**: Hijri calendar date display
- **DISP-02**: Sunrise/Shuruq time display
- **DISP-03**: Multiple mosque profiles (quick-switch)

### Wider Compatibility

- **COMPAT-01**: Support for older devices (CIQ 3.x)
- **COMPAT-02**: Localization (Arabic, French, Turkish)

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| Prayer notifications/alarms | Garmin platform does not allow background scheduling from widgets |
| Qibla compass direction | Separate concern, dedicated apps exist |
| On-watch prayer calculation (GPS-based) | Using real mosque data from API, not calculation |
| Search/browse mosques on watch | Phone app settings is simpler and sufficient |
| Older device support (CIQ 3.x) | Modern devices only for v1, reduces complexity |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| DATA-01 | — | Pending |
| DATA-02 | — | Pending |
| DATA-03 | — | Pending |
| DATA-04 | — | Pending |
| DATA-05 | — | Pending |
| CONF-01 | — | Pending |
| CONF-02 | — | Pending |
| PRAY-01 | — | Pending |
| PRAY-02 | — | Pending |
| PRAY-03 | — | Pending |
| GLNC-01 | — | Pending |
| GLNC-02 | — | Pending |
| WDGT-01 | — | Pending |
| WDGT-02 | — | Pending |
| WDGT-03 | — | Pending |
| BKGD-01 | — | Pending |
| BKGD-02 | — | Pending |

**Coverage:**
- v1 requirements: 17 total
- Mapped to phases: 0
- Unmapped: 17

---
*Requirements defined: 2026-04-10*
*Last updated: 2026-04-10 after initial definition*
