# Phase 1: Data Pipeline & Configuration - Context

**Gathered:** 2026-04-10
**Status:** Ready for planning

<domain>
## Phase Boundary

This phase delivers the data infrastructure: fetching prayer times from the Mawaqit API for a user-configured mosque, parsing the response into a usable model, and persisting it in Application.Storage for offline use. No UI display logic (that's Phase 2+) — this phase ensures data is available and reliable.

</domain>

<decisions>
## Implementation Decisions

### API Response & Data Model
- **D-01:** Store prayer-relevant fields only from the API response: `calendar`, `iqamaCalendar`, `times`, `shuruq`, `jumua`/`jumua2`, `name`, `timezone`, `hijriAdjustment`. Skip announcements, images, facility flags, flash messages, and other mosque metadata.
- **D-02:** Store the full 12-month calendar (not just two days). User confirmed the full calendar response is under 36KB. This gives maximum offline resilience — accurate prayer times for months without a refresh.
- **D-03:** The API response is wrapped in a `rawdata` top-level key. Calendar is an array of 12 monthly objects, each with days 1-31. Each day has 6 time strings (Fajr, Shuruq, Dhuhr, Asr, Maghrib, Isha). Iqama calendar has 5 offset strings per day (relative offsets like `"+10"`).

### First-Launch Experience
- **D-04:** No default mosque slug. `properties.xml` ships with an empty value. User must configure their mosque slug via the Garmin Connect phone app.
- **D-05:** Before a mosque is configured, show an empty state with instructions — the normal layout with placeholder dashes and a brief message directing the user to Garmin Connect to set their mosque.

### Stale Data Policy
- **D-06:** Always show cached data without any staleness warning or age indicator. With the full 12-month calendar, times remain accurate for months. Simplest UX.
- **D-07:** When cached calendar data has fully expired (no entry for the current date and no future data), switch to the empty state — same as first launch. Do not extrapolate from old data.

### Claude's Discretion
- **Error communication:** How much detail to show when things go wrong (bad slug, API down, no BLE connection). Claude has flexibility to design appropriate error handling — silent fallback to cache vs. subtle error indicators.
- **Storage key structure:** How to organize keys in Application.Storage (single blob vs. separate keys for calendar, metadata, etc.).
- **HTTP request configuration:** Request headers, timeout handling, retry logic for `Communications.makeWebRequest()`.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### API
- `https://mawaqit.naj.ovh/api/v1/{mosque-slug}/` — Live API endpoint. Response structure documented in D-03 above. Test slug: `tawba-bussy-saint-georges`.

### Project Documentation
- `.planning/PROJECT.md` — Core value, constraints, key decisions
- `.planning/REQUIREMENTS.md` — DATA-01 through DATA-05, CONF-01, CONF-02
- `.planning/ROADMAP.md` — Phase 1 success criteria and requirement mapping

### Platform References (external)
- Garmin Connect IQ API: `Toybox.Communications.makeWebRequest()` for HTTP requests
- Garmin Connect IQ API: `Toybox.Application.Storage` for data persistence
- Garmin Connect IQ API: `Toybox.Application.Properties` for user settings
- See CLAUDE.md "Recommended Stack" section for full API reference with code examples

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- None — greenfield project, no existing source code.

### Established Patterns
- None yet. This phase establishes the foundational patterns for data fetching, storage, and configuration that Phase 2 and 3 will build on.

### Integration Points
- `properties.xml` — will define the mosque slug setting
- `settings.xml` — will define the phone app settings UI
- `manifest.xml` — will declare Communications permission and target devices
- `Application.Storage` — Phase 2 will read cached data from here to display prayer times

</code_context>

<specifics>
## Specific Ideas

- API response is wrapped in `rawdata` top-level key — extract fields from `rawdata.*`
- Calendar array has 12 monthly objects indexed by day number (1-31), with 6 time strings per day
- Iqama offsets are relative strings like `"+10"` (minutes after prayer time), not absolute times
- Full calendar under 36KB per user's measurement — fits comfortably in Garmin storage

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 01-data-pipeline-configuration*
*Context gathered: 2026-04-10*
